import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../services/validator.dart';

/// Nạp dữ liệu đảo từ assets/data/island_{id}.json.
/// - Đảo chưa có file -> trả về null (hiện "Sắp có").
/// - Loader bỏ qua trường lạ (calc, verified, source...) nhờ fromJson
///   chỉ đọc các trường nó biết.
/// - Debug mode: validate toàn bộ, báo lỗi nếu có (ném StateError với
///   danh sách lỗi) thay vì im lặng nạp dữ liệu sai.

class DataLoadResult {
  DataLoadResult({required this.islands, required this.errors});

  /// island_id -> dữ liệu đảo (chỉ các đảo có file).
  final Map<String, IslandData> islands;

  /// Lỗi validate (debug mode). Rỗng = pass.
  final List<String> errors;
}

class DataLoader {
  DataLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<IslandData?> loadIsland(String islandId) async {
    final path = 'assets/data/island_$islandId.json';
    try {
      final raw = await _bundle.loadString(path);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return IslandData.fromJson(json);
    } on FlutterError {
      // Không có file asset -> đảo "Sắp có".
      return null;
    }
  }

  /// Nạp tất cả đảo trong [islandIds]. Validate ở debug mode.
  Future<DataLoadResult> loadAll(List<String> islandIds) async {
    final islands = <String, IslandData>{};
    final errors = <String>[];
    final allIds = <String>{};
    for (final id in islandIds) {
      final path = 'assets/data/island_$id.json';
      String raw;
      try {
        raw = await _bundle.loadString(path);
      } on FlutterError {
        continue; // Chưa có dữ liệu -> "Sắp có".
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (kDebugMode) {
        errors.addAll(validateIslandJson(json, allIds: allIds));
      }
      try {
        islands[id] = IslandData.fromJson(json);
      } catch (e) {
        errors.add('[$id] lỗi parse JSON/model: $e');
      }
    }
    return DataLoadResult(islands: islands, errors: errors);
  }
}
