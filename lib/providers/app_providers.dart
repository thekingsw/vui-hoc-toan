import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_loader.dart';
import '../data/island_catalog.dart';
import '../models/question.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';

/// Riverpod state — đã chốt dùng Riverpod (không dùng Provider).

/// Database singleton.
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

/// Dịch vụ âm thanh (1 instance cho cả app).
final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});

/// Bật/tắt âm thanh (đồng bộ với bảng settings).
final soundOnProvider = StateProvider<bool>((ref) => true);

/// Dữ liệu các đảo (nạp từ assets). Đảo chưa có file thì vắng mặt.
final islandsProvider = FutureProvider<Map<String, IslandData>>((ref) async {
  final result = await DataLoader().loadAll(islandOrderIds);
  if (result.errors.isNotEmpty) {
    // Debug mode: báo rõ lỗi dữ liệu thay vì im lặng.
    throw StateError(
        'Lỗi dữ liệu:\n${result.errors.join('\n')}');
  }
  return result.islands;
});

/// Đếm số lần cần nạp lại tiến độ (tăng sau mỗi lượt chơi xong).
final progressRefreshProvider = StateProvider<int>((ref) => 0);

/// Tiến độ các đảo (sao + mở khóa).
final islandProgressProvider =
    FutureProvider<Map<String, IslandProgress>>((ref) async {
  ref.watch(progressRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.allIslandProgress();
});

/// Các bài học đã hoàn thành của 1 đảo.
final doneLessonsProvider =
    FutureProvider.family<Set<String>, String>((ref, islandId) async {
  ref.watch(progressRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.doneLessonIds(islandId);
});

/// Cảm xúc linh vật hiện tại.
enum MascotMood { neutral, happy, sad, excited }

final mascotMoodProvider = StateProvider<MascotMood>((ref) => MascotMood.neutral);
