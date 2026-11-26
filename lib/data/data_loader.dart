import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../services/content_store.dart';
import '../services/validator.dart';

/// Nạp dữ liệu đảo từ kho nội dung SQLite (bảng content_*), nơi nội
/// dung đồng bộ từ app Soạn bài trên máy 92 được lưu.
///
/// - Lần mở đầu kho còn trống: nạp bản dự phòng đảo 1 đóng gói sẵn
///   trong assets (assets/data/island_on_tap_bo_sung.json, version 0)
///   để bé học được ngay cả khi chưa kết nối được máy 92.
/// - Đảo chưa có nội dung trong kho -> trả về null (hiện "Sắp có").
/// - Debug mode: validate bản dự phòng, báo lỗi nếu có.

/// Đảo có bản dự phòng đóng gói trong app (chỉ đảo 1).
const List<String> bundledFallbackIslands = ['on_tap_bo_sung'];

class DataLoadResult {
  DataLoadResult({required this.islands, required this.errors});

  /// island_id -> dữ liệu đảo (chỉ các đảo có nội dung).
  final Map<String, IslandData> islands;

  /// Lỗi validate (debug mode). Rỗng = pass.
  final List<String> errors;
}

class DataLoader {
  DataLoader({AssetBundle? bundle, ContentStore? store})
      : _bundle = bundle ?? rootBundle,
        _store = store ?? ContentStore();

  final AssetBundle _bundle;
  final ContentStore _store;

  /// Nạp bản dự phòng đóng gói vào kho nếu kho còn trống.
  Future<List<String>> _seedBundledIfEmpty() async {
    final errors = <String>[];
    if (!await _store.isEmpty()) return errors;
    for (final islandId in bundledFallbackIslands) {
      try {
        final raw =
            await _bundle.loadString('assets/data/island_$islandId.json');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (kDebugMode) {
          errors.addAll(validateIslandJson(json));
        }
        // Version 0: bản xuất bản nào từ máy 92 cũng mới hơn và thay thế.
        await _store.replaceIsland(json, 0, appBuild: 1 << 30);
      } catch (e) {
        errors.add('[$islandId] không nạp được bản dự phòng: $e');
      }
    }
    return errors;
  }

  Future<IslandData?> loadIsland(String islandId) async {
    await _seedBundledIfEmpty();
    return _store.loadIsland(islandId);
  }

  /// Nạp tất cả đảo trong [islandIds] từ kho nội dung.
  Future<DataLoadResult> loadAll(List<String> islandIds) async {
    final islands = <String, IslandData>{};
    final errors = await _seedBundledIfEmpty();
    for (final id in islandIds) {
      try {
        final data = await _store.loadIsland(id);
        if (data != null) islands[id] = data;
      } catch (e) {
        errors.add('[$id] lỗi đọc kho nội dung: $e');
      }
    }
    return DataLoadResult(islands: islands, errors: errors);
  }
}
