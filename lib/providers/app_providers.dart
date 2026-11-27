import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_loader.dart';
import '../data/island_catalog.dart';
import '../game/shop/shop_items.dart';
import '../models/question.dart';

import '../services/database_service.dart';
import '../services/review_logic.dart';
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

/// Giảm hiệu ứng cho máy yếu (đồng bộ với bảng settings).
final reduceEffectsProvider = StateProvider<bool>((ref) => false);

/// Thuyền cần chạy sang đảo mới khi về bản đồ (sau lần đầu mở đảo).
/// Giá trị là id đảo đích; bản đồ chạy xong thì xóa về null.
final pendingSailProvider = StateProvider<String?>((ref) => null);

/// Dữ liệu các đảo: đọc từ kho nội dung SQLite (đồng bộ từ app Soạn
/// bài trên máy 92); lần mở đầu kho trống thì nạp bản dự phòng đảo 1
/// đóng gói trong assets. Đảo chưa có nội dung thì vắng mặt ("Sắp có").
final islandsProvider = FutureProvider<Map<String, IslandData>>((ref) async {
  final result = await DataLoader().loadAll(islandOrderIds);
  if (result.errors.isNotEmpty) {
    // Debug mode: báo rõ lỗi dữ liệu thay vì im lặng.
    throw StateError(
        'Lỗi dữ liệu:\n${result.errors.join('\n')}');
  }
  return result.islands;
});

/// Thông báo "có bài học mới" sau khi cập nhật dữ liệu qua mạng.
/// Màn hình chính đọc rồi xóa về null.
final dataUpdateNoticeProvider = StateProvider<String?>((ref) => null);

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

/// Các bài học đã xem (mở màn Học) của 1 đảo.
final viewedLessonsProvider =
    FutureProvider.family<Set<String>, String>((ref, islandId) async {
  ref.watch(progressRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.viewedLessonIds(islandId);
});

/// Cảm xúc linh vật hiện tại.
enum MascotMood { neutral, happy, sad, excited }

final mascotMoodProvider = StateProvider<MascotMood>((ref) => MascotMood.neutral);

/// Danh mục cửa hàng (assets/config/shop_items.json).
final shopItemsProvider = FutureProvider<List<ShopItem>>((ref) async {
  return loadShopItems();
});

/// Số xu hiện có của bé.
final coinsProvider = FutureProvider<int>((ref) async {
  ref.watch(progressRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.coins();
});

/// Số câu trong Hộp ôn đã đến hạn hôm nay (Đợt A).
final dueReviewCountProvider = FutureProvider<int>((ref) async {
  ref.watch(progressRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.dueReviewCount();
});

/// Thống kê kỹ năng (tag chính của câu) — cho gợi ý kỹ năng yếu.
final skillStatsProvider = FutureProvider<List<SkillStat>>((ref) async {
  ref.watch(progressRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.skillStats();
});

/// Các món đã mua.
final ownedItemsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(progressRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.ownedItemIds();
});

/// Các món đang mặc/dùng.
final equippedItemsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(progressRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.equippedItemIds();
});
