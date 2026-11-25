import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Tự cập nhật qua GitHub Releases của repo thekingsw/vui-hoc-toan.
/// App học vẫn offline; chỉ việc kiểm tra bản mới mới dùng mạng,
/// và mọi lỗi mạng đều im lặng (không làm phiền lúc học).

const String _latestReleaseUrl =
    'https://api.github.com/repos/thekingsw/vui-hoc-toan/releases/latest';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
  });

  /// Phiên bản mới, vd "1.0.1" (đã bỏ chữ v ở đầu tag).
  final String version;

  /// Đường tải file APK (bản arm64-v8a).
  final String apkUrl;

  /// Ghi chú phát hành (có thể rỗng).
  final String notes;
}

/// So sánh hai chuỗi phiên bản dạng "1.2.3" (chấp nhận tiền tố "v").
/// Trả về số dương nếu a > b, âm nếu a < b, 0 nếu bằng.
int compareVersions(String a, String b) {
  List<int> parse(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    s = s.split('+').first.split('-').first;
    return s.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  final pa = parse(a);
  final pb = parse(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Đọc JSON của GitHub Release; trả về [UpdateInfo] nếu có bản mới hơn
/// [currentVersion] và có file APK tải được, ngược lại trả về null.
UpdateInfo? parseRelease(Map<String, dynamic> json, String currentVersion) {
  final tag = (json['tag_name'] as String?)?.trim() ?? '';
  if (tag.isEmpty) return null;
  final version =
      (tag.startsWith('v') || tag.startsWith('V')) ? tag.substring(1) : tag;
  if (compareVersions(version, currentVersion) <= 0) return null;

  final assets = json['assets'];
  if (assets is! List) return null;
  String? apkUrl;
  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = (asset['name'] as String?) ?? '';
    final url = (asset['browser_download_url'] as String?) ?? '';
    if (url.isEmpty || !name.endsWith('.apk')) continue;
    // Ưu tiên bản arm64-v8a (máy Android phổ biến hiện nay).
    if (name.contains('arm64-v8a')) {
      apkUrl = url;
      break;
    }
    apkUrl ??= url;
  }
  if (apkUrl == null) return null;

  return UpdateInfo(
    version: version,
    apkUrl: apkUrl,
    notes: ((json['body'] as String?) ?? '').trim(),
  );
}

/// Kiểm tra bản mới trên GitHub. Mọi lỗi (không mạng, timeout, JSON lạ)
/// đều trả về null để app chạy tiếp như thường.
Future<UpdateInfo?> checkForUpdate() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final response = await http
        .get(
          Uri.parse(_latestReleaseUrl),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'toan-lop-5-app',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    return parseRelease(json, info.version);
  } catch (_) {
    return null;
  }
}

/// Tải APK về thư mục tạm rồi mở trình cài đặt của Android.
/// [onProgress] nhận tỉ lệ 0..1 (null khi không biết dung lượng).
/// Ném lỗi nếu tải thất bại để giao diện báo lại.
Future<void> downloadAndInstall(
  UpdateInfo info, {
  void Function(double? progress)? onProgress,
}) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(info.apkUrl));
    final response =
        await client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw HttpException('Tải bản mới lỗi HTTP ${response.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/toan-lop-5-update.apk');
    final sink = file.openWrite();
    final total = response.contentLength;
    var received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (onProgress != null) {
        onProgress(total != null && total > 0 ? received / total : null);
      }
    }
    await sink.flush();
    await sink.close();
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw StateError('Không mở được trình cài đặt: ${result.message}');
    }
  } finally {
    client.close();
  }
}
