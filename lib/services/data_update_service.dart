import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'content_store.dart';
import 'validator.dart';

/// Đồng bộ nội dung bài học từ app Soạn bài trên máy 92 (qua Tailscale).
///
/// Cách hoạt động:
/// - App Soạn bài xuất bản `manifest.json` + file từng đảo tại
///   [contentBaseUrl]. Manifest gồm data_version, schema_version,
///   min_app_version và danh sách đảo kèm version + sha256.
/// - App tải manifest, đảo nào có version mới hơn bản trong SQLite
///   (bảng content_*) thì tải file về, kiểm tra sha256 + validator,
///   rồi thay nội dung đảo đó trong một giao dịch.
/// - Lần mở đầu chưa có mạng: DataLoader nạp bản dự phòng đảo 1 đóng
///   gói trong app. Mất mạng thì app chạy như thường (offline).

const String contentBaseUrl = 'http://100.92.107.114:8097/sync/';

/// Phiên bản cấu trúc dữ liệu cao nhất app này đọc được.
const int supportedSchemaVersion = 1;

class IslandDataEntry {
  const IslandDataEntry({
    required this.islandId,
    required this.file,
    required this.version,
    this.sha256 = '',
  });

  final String islandId;
  final String file;
  final int version;
  final String sha256;
}

class DataManifest {
  const DataManifest({
    required this.version,
    required this.schemaVersion,
    required this.minAppVersion,
    required this.islands,
  });

  /// Phiên bản chung của bộ dữ liệu (data_version, hiển thị cho phụ huynh).
  final int version;

  /// Phiên bản cấu trúc dữ liệu.
  final int schemaVersion;

  /// Phiên bản app tối thiểu đọc được bộ dữ liệu này (vd '1.4.0').
  final String minAppVersion;

  /// island_id -> thông tin file.
  final Map<String, IslandDataEntry> islands;
}

/// Đọc manifest JSON (định dạng app Soạn bài); trả về null nếu cấu trúc lạ.
DataManifest? parseDataManifest(Map<String, dynamic> json) {
  final versionRaw = json['data_version'];
  final version = versionRaw is num ? versionRaw.toInt() : null;
  final islandsRaw = json['islands'];
  if (version == null || islandsRaw is! List) return null;
  final islands = <String, IslandDataEntry>{};
  for (final e in islandsRaw) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final islandId = m['island_id'] as String?;
    final file = m['file'] as String?;
    final vRaw = m['version'];
    final v = vRaw is num ? vRaw.toInt() : null;
    if (islandId == null ||
        islandId.isEmpty ||
        file == null ||
        file.isEmpty ||
        v == null) {
      continue;
    }
    islands[islandId] = IslandDataEntry(
      islandId: islandId,
      file: file,
      version: v,
      sha256: m['sha256'] as String? ?? '',
    );
  }
  final schemaRaw = json['schema_version'];
  return DataManifest(
    version: version,
    schemaVersion: schemaRaw is num ? schemaRaw.toInt() : 1,
    minAppVersion: json['min_app_version'] as String? ?? '',
    islands: islands,
  );
}

/// Tính danh sách đảo cần tải: đảo có phiên bản trên server lớn hơn
/// phiên bản đang có trong kho nội dung trên máy (chưa có = 0).
List<String> planDataUpdates(
  Map<String, int> localVersions,
  DataManifest remote,
) {
  final result = <String>[];
  for (final e in remote.islands.entries) {
    final local = localVersions[e.key] ?? 0;
    if (e.value.version > local) result.add(e.key);
  }
  return result;
}

/// So sánh hai chuỗi phiên bản dạng '1.4.0'. Trả về số âm nếu a < b,
/// 0 nếu bằng, số dương nếu a > b. Phần không phải số tính là 0.
int compareVersions(String a, String b) {
  List<int> parts(String s) => s
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final pa = parts(a);
  final pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

class DataUpdateResult {
  const DataUpdateResult({
    required this.updatedIslands,
    required this.errors,
    required this.currentVersion,
  });

  /// Các đảo vừa tải bản mới thành công.
  final List<String> updatedIslands;

  /// Lỗi gặp phải (mạng, dữ liệu hỏng...) — rỗng = êm.
  final List<String> errors;

  /// Phiên bản dữ liệu hiện tại trên máy sau khi kiểm tra.
  final int currentVersion;

  bool get hasUpdates => updatedIslands.isNotEmpty;
}

/// Phiên bản dữ liệu đang có trên máy (trong kho nội dung SQLite).
Future<int> currentDataVersion([ContentStore? store]) async {
  return (store ?? ContentStore()).dataVersion();
}

/// Kiểm tra và tải nội dung bài học mới từ máy 92. Mọi lỗi đều được ghi
/// vào [DataUpdateResult.errors] thay vì ném ra ngoài, để app chạy tiếp.
Future<DataUpdateResult> checkAndUpdateData([ContentStore? store]) async {
  final contentStore = store ?? ContentStore();
  final errors = <String>[];
  final updated = <String>[];
  var currentVersion = await contentStore.dataVersion();

  DataManifest? remote;
  try {
    final resp = await http
        .get(
          Uri.parse(
              '${contentBaseUrl}manifest.json?t=${DateTime.now().millisecondsSinceEpoch}'),
          headers: const {'User-Agent': 'toan-lop-5-app'},
        )
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      errors.add('Không tải được danh sách bài học (HTTP ${resp.statusCode}).');
      return DataUpdateResult(
          updatedIslands: updated,
          errors: errors,
          currentVersion: currentVersion);
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    if (json is Map<String, dynamic>) remote = parseDataManifest(json);
    if (remote == null) {
      errors.add('Danh sách bài học trên máy chủ không đúng định dạng.');
      return DataUpdateResult(
          updatedIslands: updated,
          errors: errors,
          currentVersion: currentVersion);
    }
  } catch (_) {
    errors.add('Không có mạng hoặc máy chủ không phản hồi.');
    return DataUpdateResult(
        updatedIslands: updated,
        errors: errors,
        currentVersion: currentVersion);
  }

  if (remote.schemaVersion > supportedSchemaVersion) {
    errors.add('Bài học mới cần phiên bản app mới hơn.');
    return DataUpdateResult(
        updatedIslands: updated,
        errors: errors,
        currentVersion: currentVersion);
  }

  final info = await PackageInfo.fromPlatform();
  final appBuild = int.tryParse(info.buildNumber) ?? 0;
  if (remote.minAppVersion.isNotEmpty &&
      compareVersions(info.version, remote.minAppVersion) < 0) {
    errors.add('Bài học mới cần cập nhật app lên ${remote.minAppVersion}.');
    return DataUpdateResult(
        updatedIslands: updated,
        errors: errors,
        currentVersion: currentVersion);
  }

  final localVersions = await contentStore.islandVersions();
  final toUpdate = planDataUpdates(localVersions, remote);

  for (final islandId in toUpdate) {
    final entry = remote.islands[islandId]!;
    try {
      final resp = await http
          .get(Uri.parse('$contentBaseUrl${entry.file}'),
              headers: const {'User-Agent': 'toan-lop-5-app'})
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        errors.add('Đảo $islandId: tải lỗi HTTP ${resp.statusCode}.');
        continue;
      }
      if (entry.sha256.isNotEmpty &&
          sha256.convert(resp.bodyBytes).toString() != entry.sha256) {
        errors.add('Đảo $islandId: file tải về bị hỏng (sai mã kiểm tra).');
        continue;
      }
      final json = jsonDecode(utf8.decode(resp.bodyBytes));
      if (json is! Map<String, dynamic>) {
        errors.add('Đảo $islandId: file không đúng định dạng JSON.');
        continue;
      }
      if (json['island_id'] != islandId) {
        errors.add('Đảo $islandId: island_id trong file không khớp.');
        continue;
      }
      final validationErrors = validateIslandJson(json);
      if (validationErrors.isNotEmpty) {
        errors.add(
            'Đảo $islandId: dữ liệu chưa đạt kiểm tra (${validationErrors.first}).');
        continue;
      }
      await contentStore.replaceIsland(json, entry.version,
          appBuild: appBuild);
      updated.add(islandId);
    } catch (_) {
      errors.add('Đảo $islandId: không tải được (mạng gián đoạn?).');
    }
  }

  if (updated.isNotEmpty) {
    currentVersion = remote.version;
    await contentStore.setDataVersion(remote.version);
  }

  return DataUpdateResult(
    updatedIslands: updated,
    errors: errors,
    currentVersion: currentVersion,
  );
}
