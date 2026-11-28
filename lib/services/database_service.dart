import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'review_logic.dart';

/// Lưu trữ sqflite — bám bảng mục 7 của SPEC (bản đã sửa):
/// - progress(island_id, lesson_id, practice_done, last_played):
///   một dòng cho mỗi bài học.
/// - island_progress(island_id, best_stars, unlocked, unlocked_by_parent,
///   last_played): sao lưu theo đảo, không lưu trong progress.
/// - answer_log, review_box (giai đoạn 2 mới dùng review_box),
///   profile, settings.
///
/// PIN phụ huynh mặc định: 1234 (lưu dạng hash FNV-1a, chỉ là khóa
/// tối giản chống bé bấm nhầm, không phải bảo mật thật).

class IslandProgress {
  IslandProgress({
    required this.islandId,
    this.bestStars = 0,
    this.unlocked = false,
    this.unlockedByParent = false,
  });

  final String islandId;
  final int bestStars;
  final bool unlocked;
  final bool unlockedByParent;
}

/// Hash FNV-1a 32-bit — đủ để đối chiếu PIN, không lưu PIN dạng thô.
String pinHash(String pin) {
  var hash = 0x811c9dc5;
  for (final code in pin.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

const String defaultParentPin = '1234';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final created = await _open();
    _db = created;
    return created;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'toan_lop_5.db');
    final database = await openDatabase(
      path,
      version: 9,
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2: thêm cờ giảm hiệu ứng + đánh dấu đã xem bài Học.
        // Chỉ thêm cột, giữ nguyên tiến độ của bé.
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE settings ADD COLUMN reduce_effects INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE progress ADD COLUMN lesson_viewed INTEGER NOT NULL DEFAULT 0');
        }
        // v3: xu + cửa hàng (SPEC giao diện mục 8, 10).
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE owned_items(
              item_id TEXT PRIMARY KEY,
              equipped INTEGER NOT NULL DEFAULT 0,
              acquired_at INTEGER
            )''');
          await db.execute('''
            CREATE TABLE reward_log(
              key TEXT PRIMARY KEY,
              claimed_at INTEGER
            )''');
          await db.execute(
              'ALTER TABLE island_progress ADD COLUMN completed_at INTEGER');
        }
        // v4: bảng nội dung bài học đồng bộ từ app Soạn bài (máy 92).
        // Tách hẳn khỏi bảng tiến độ; chỉ thêm bảng mới.
        if (oldVersion < 4) {
          await _createContentTables(db);
        }
        // v5: hình minh họa (figure) cho thẻ học + câu hỏi hình học.
        if (oldVersion < 5) {
          await db.execute(
              'ALTER TABLE content_cards ADD COLUMN figure_json TEXT');
          await db.execute(
              'ALTER TABLE content_questions ADD COLUMN figure_json TEXT');
        }
        // v6: Đợt A Học thông minh — tags câu hỏi, hộp ôn Leitner,
        // thống kê kỹ năng.
        if (oldVersion < 6) {
          await db.execute(
              'ALTER TABLE content_questions ADD COLUMN tags_json TEXT');
          await db.execute(
              'ALTER TABLE review_box ADD COLUMN box INTEGER NOT NULL DEFAULT 1');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS skill_stats(
              skill TEXT PRIMARY KEY,
              correct_count INTEGER NOT NULL DEFAULT 0,
              wrong_count INTEGER NOT NULL DEFAULT 0,
              last_at INTEGER
            )''');
        }
        // v7: Đợt C loại câu mới — dữ liệu phụ (pairs/items/bank/column)
        // gộp trong extra_json.
        if (oldVersion < 7) {
          await db.execute(
              'ALTER TABLE content_questions ADD COLUMN extra_json TEXT');
        }
        // v8: biểu thức calc để sinh câu biến thể khi ôn lại.
        if (oldVersion < 8) {
          await db.execute(
              'ALTER TABLE content_questions ADD COLUMN calc TEXT');
        }
        // v9: F1 — công tắc nhạc nền + rung.
        if (oldVersion < 9) {
          await db.execute(
              'ALTER TABLE settings ADD COLUMN music_enabled INTEGER NOT NULL DEFAULT 1');
          await db.execute(
              'ALTER TABLE settings ADD COLUMN haptics_enabled INTEGER NOT NULL DEFAULT 1');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE progress(
            island_id TEXT NOT NULL,
            lesson_id TEXT NOT NULL,
            practice_done INTEGER NOT NULL DEFAULT 0,
            lesson_viewed INTEGER NOT NULL DEFAULT 0,
            last_played INTEGER,
            PRIMARY KEY (island_id, lesson_id)
          )''');
        await db.execute('''
          CREATE TABLE island_progress(
            island_id TEXT PRIMARY KEY,
            best_stars INTEGER NOT NULL DEFAULT 0,
            unlocked INTEGER NOT NULL DEFAULT 0,
            unlocked_by_parent INTEGER NOT NULL DEFAULT 0,
            last_played INTEGER,
            completed_at INTEGER
          )''');
        await db.execute('''
          CREATE TABLE answer_log(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id TEXT NOT NULL,
            correct INTEGER NOT NULL,
            answered_at INTEGER NOT NULL,
            mode TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE review_box(
            question_id TEXT PRIMARY KEY,
            wrong_count INTEGER NOT NULL DEFAULT 0,
            next_review_at INTEGER,
            box INTEGER NOT NULL DEFAULT 1
          )''');
        await db.execute('''
          CREATE TABLE skill_stats(
            skill TEXT PRIMARY KEY,
            correct_count INTEGER NOT NULL DEFAULT 0,
            wrong_count INTEGER NOT NULL DEFAULT 0,
            last_at INTEGER
          )''');
        await db.execute('''
          CREATE TABLE profile(
            id INTEGER PRIMARY KEY,
            name TEXT,
            coins INTEGER NOT NULL DEFAULT 0,
            xp INTEGER NOT NULL DEFAULT 0,
            streak_days INTEGER NOT NULL DEFAULT 0,
            last_active_date TEXT,
            mascot_skin TEXT,
            unlocked_items TEXT
          )''');
        await db.execute('''
          CREATE TABLE settings(
            id INTEGER PRIMARY KEY,
            sound_on INTEGER NOT NULL DEFAULT 1,
            reduce_effects INTEGER NOT NULL DEFAULT 0,
            music_enabled INTEGER NOT NULL DEFAULT 1,
            haptics_enabled INTEGER NOT NULL DEFAULT 1,
            daily_limit_minutes INTEGER,
            parent_pin_hash TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE owned_items(
            item_id TEXT PRIMARY KEY,
            equipped INTEGER NOT NULL DEFAULT 0,
            acquired_at INTEGER
          )''');
        await db.execute('''
          CREATE TABLE reward_log(
            key TEXT PRIMARY KEY,
            claimed_at INTEGER
          )''');
        await db.insert('profile', {'id': 1, 'name': 'Bé'});
        await db.insert('settings', {
          'id': 1,
          'sound_on': 1,
          'reduce_effects': 0,
          'music_enabled': 1,
          'haptics_enabled': 1,
          'daily_limit_minutes': null,
          'parent_pin_hash': pinHash(defaultParentPin),
        });
        // Đảo đầu tiên luôn mở.
        await db.insert('island_progress', {
          'island_id': 'on_tap_bo_sung',
          'best_stars': 0,
          'unlocked': 1,
          'unlocked_by_parent': 0,
        });
        await _createContentTables(db);
      },
    );
    return database;
  }

  /// Bảng nội dung (v4): đảo/bài/thẻ/câu đồng bộ từ app Soạn bài.
  static Future<void> _createContentTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_islands(
        island_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        ord INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_lessons(
        lesson_id TEXT PRIMARY KEY,
        island_id TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'lesson',
        title TEXT NOT NULL,
        ord INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_cards(
        id TEXT PRIMARY KEY,
        lesson_id TEXT NOT NULL,
        ord INTEGER NOT NULL DEFAULT 0,
        heading TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        example TEXT,
        figure_json TEXT
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_questions(
        id TEXT PRIMARY KEY,
        lesson_id TEXT NOT NULL,
        type TEXT NOT NULL,
        difficulty INTEGER NOT NULL DEFAULT 1,
        prompt TEXT NOT NULL DEFAULT '',
        options_json TEXT NOT NULL DEFAULT '[]',
        answer TEXT NOT NULL DEFAULT '',
        hint TEXT DEFAULT '',
        explanation TEXT DEFAULT '',
        unit TEXT,
        min_app_version INTEGER NOT NULL DEFAULT 0,
        figure_json TEXT,
        tags_json TEXT,
        extra_json TEXT,
        calc TEXT
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_meta(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
  }

  // --- Tiến độ bài học ---
  Future<void> markPracticeDone(String islandId, String lessonId) async {
    final d = await db;
    // UPSERT để không xóa cờ lesson_viewed khi ghi đè.
    await d.rawInsert(
      'INSERT INTO progress(island_id, lesson_id, practice_done, last_played) '
      'VALUES(?, ?, 1, ?) '
      'ON CONFLICT(island_id, lesson_id) DO UPDATE SET '
      'practice_done = 1, last_played = excluded.last_played',
      [islandId, lessonId, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<void> markLessonViewed(String islandId, String lessonId) async {
    final d = await db;
    await d.rawInsert(
      'INSERT INTO progress(island_id, lesson_id, lesson_viewed) '
      'VALUES(?, ?, 1) '
      'ON CONFLICT(island_id, lesson_id) DO UPDATE SET lesson_viewed = 1',
      [islandId, lessonId],
    );
  }

  Future<Set<String>> viewedLessonIds(String islandId) async {
    final d = await db;
    final rows = await d.query(
      'progress',
      columns: ['lesson_id'],
      where: 'island_id = ? AND lesson_viewed = 1',
      whereArgs: [islandId],
    );
    return rows.map((r) => r['lesson_id'] as String).toSet();
  }

  Future<Set<String>> doneLessonIds(String islandId) async {
    final d = await db;
    final rows = await d.query(
      'progress',
      columns: ['lesson_id'],
      where: 'island_id = ? AND practice_done = 1',
      whereArgs: [islandId],
    );
    return rows.map((r) => r['lesson_id'] as String).toSet();
  }

  // --- Tiến độ đảo (sao / mở khóa) ---
  Future<Map<String, IslandProgress>> allIslandProgress() async {
    final d = await db;
    final rows = await d.query('island_progress');
    final map = <String, IslandProgress>{};
    for (final r in rows) {
      final id = r['island_id'] as String;
      map[id] = IslandProgress(
        islandId: id,
        bestStars: (r['best_stars'] as int?) ?? 0,
        unlocked: ((r['unlocked'] as int?) ?? 0) == 1,
        unlockedByParent: ((r['unlocked_by_parent'] as int?) ?? 0) == 1,
      );
    }
    return map;
  }

  Future<void> saveBestStars(String islandId, int stars) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await d.query(
      'island_progress',
      columns: ['best_stars'],
      where: 'island_id = ?',
      whereArgs: [islandId],
    );
    final old = current.isEmpty ? 0 : (current.first['best_stars'] as int? ?? 0);
    final best = stars > old ? stars : old;
    // UPSERT: giữ nguyên unlocked_by_parent + completed_at.
    await d.rawInsert(
      'INSERT INTO island_progress(island_id, best_stars, unlocked, last_played) '
      'VALUES(?, ?, 1, ?) '
      'ON CONFLICT(island_id) DO UPDATE SET '
      'best_stars = excluded.best_stars, unlocked = 1, '
      'last_played = excluded.last_played',
      [islandId, best, now],
    );
  }

  /// Ghi thời điểm lần đầu đạt ≥1 sao ở Thử thách (cho huy hiệu đảo).
  Future<void> markIslandCompleted(String islandId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE island_progress SET completed_at = ? '
      'WHERE island_id = ? AND completed_at IS NULL',
      [DateTime.now().millisecondsSinceEpoch, islandId],
    );
  }

  /// Mở đảo kế tiếp khi đạt ≥1 sao ở đảo [islandId].
  /// Giữ nguyên sao tốt nhất nếu đảo sau đã có sao.
  Future<void> unlockNextIsland(String islandId, String nextIslandId) async {
    final d = await db;
    final current = await d.query(
      'island_progress',
      columns: ['best_stars', 'unlocked_by_parent'],
      where: 'island_id = ?',
      whereArgs: [nextIslandId],
    );
    final best =
        current.isEmpty ? 0 : (current.first['best_stars'] as int? ?? 0);
    final byParent = current.isEmpty
        ? 0
        : (current.first['unlocked_by_parent'] as int? ?? 0);
    await d.rawInsert(
      'INSERT INTO island_progress(island_id, best_stars, unlocked, unlocked_by_parent, last_played) '
      'VALUES(?, ?, 1, ?, ?) '
      'ON CONFLICT(island_id) DO UPDATE SET '
      'unlocked = 1, last_played = excluded.last_played',
      [nextIslandId, best, byParent, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<void> setParentUnlock(String islandId, bool unlocked) async {
    final d = await db;
    final current = await d.query(
      'island_progress',
      where: 'island_id = ?',
      whereArgs: [islandId],
    );
    final best =
        current.isEmpty ? 0 : (current.first['best_stars'] as int? ?? 0);
    await d.rawInsert(
      'INSERT INTO island_progress(island_id, best_stars, unlocked, unlocked_by_parent, last_played) '
      'VALUES(?, ?, ?, ?, ?) '
      'ON CONFLICT(island_id) DO UPDATE SET '
      'unlocked = excluded.unlocked, '
      'unlocked_by_parent = excluded.unlocked_by_parent, '
      'last_played = excluded.last_played',
      [
        islandId,
        best,
        unlocked ? 1 : 0,
        unlocked ? 1 : 0,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  // --- Nhật ký trả lời ---
  /// Ghi một lần trả lời, đồng thời cập nhật:
  /// - skill_stats theo tag chính của câu (kỹ năng yếu nhất cho gợi ý học);
  /// - review_box: sai → vào hộp 1, hẹn ôn sau 1 ngày; đúng trong lượt
  ///   ôn (mode 'review') → lên hộp / tốt nghiệp.
  Future<void> logAnswer(
      String questionId, bool correct, String mode) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.insert('answer_log', {
      'question_id': questionId,
      'correct': correct ? 1 : 0,
      'answered_at': now,
      'mode': mode,
    });

    // Kỹ năng chính = tag đầu tiên của câu trong kho nội dung.
    final qRows = await d.query(
      'content_questions',
      columns: ['tags_json'],
      where: 'id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    String? skill;
    if (qRows.isNotEmpty) {
      final raw = qRows.first['tags_json'] as String?;
      if (raw != null && raw.isNotEmpty) {
        try {
          final tags = jsonDecode(raw);
          if (tags is List && tags.isNotEmpty) skill = '${tags.first}';
        } catch (_) {
          skill = null;
        }
      }
    }
    if (skill != null && skill.isNotEmpty) {
      await d.rawInsert(
        'INSERT INTO skill_stats(skill, correct_count, wrong_count, last_at) '
        'VALUES(?, ?, ?, ?) '
        'ON CONFLICT(skill) DO UPDATE SET '
        'correct_count = correct_count + excluded.correct_count, '
        'wrong_count = wrong_count + excluded.wrong_count, '
        'last_at = excluded.last_at',
        [skill, correct ? 1 : 0, correct ? 0 : 1, now],
      );
    }

    // Hộp ôn Leitner.
    final boxRows = await d.query(
      'review_box',
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    if (!correct) {
      final wrong = boxRows.isEmpty
          ? 1
          : ((boxRows.first['wrong_count'] as int?) ?? 0) + 1;
      await d.insert(
        'review_box',
        {
          'question_id': questionId,
          'wrong_count': wrong,
          'box': 1,
          'next_review_at': nextReviewAt(1, now),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else if (mode == 'review' && boxRows.isNotEmpty) {
      final currentBox = (boxRows.first['box'] as int?) ?? 1;
      final nb = nextBox(currentBox, true);
      if (nb == 0) {
        await d.delete('review_box',
            where: 'question_id = ?', whereArgs: [questionId]);
      } else {
        await d.update(
          'review_box',
          {'box': nb, 'next_review_at': nextReviewAt(nb, now)},
          where: 'question_id = ?',
          whereArgs: [questionId],
        );
      }
    }
  }

  /// Các mục trong hộp ôn đã đến hạn (thuần dữ liệu, logic chọn ở review_logic).
  Future<List<ReviewEntry>> reviewEntries() async {
    final d = await db;
    final rows = await d.query('review_box');
    return rows
        .map((r) => ReviewEntry(
              questionId: r['question_id'] as String,
              box: (r['box'] as int?) ?? 1,
              nextReviewAtMs: r['next_review_at'] as int?,
              wrongCount: (r['wrong_count'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<int> dueReviewCount() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = await reviewEntries();
    return entries
        .where((e) => e.nextReviewAtMs == null || e.nextReviewAtMs! <= now)
        .length;
  }

  Future<List<SkillStat>> skillStats() async {
    final d = await db;
    final rows = await d.query('skill_stats');
    return rows
        .map((r) => SkillStat(
              skill: r['skill'] as String,
              correct: (r['correct_count'] as int?) ?? 0,
              wrong: (r['wrong_count'] as int?) ?? 0,
            ))
        .toList();
  }

  /// Hoạt động gần đây cho bảng phụ huynh: (tổng câu đã làm, số câu đúng)
  /// trong [days] ngày qua.
  Future<({int total, int correct})> recentActivity({int days = 7}) async {
    final d = await db;
    final since =
        DateTime.now().millisecondsSinceEpoch - days * 24 * 60 * 60 * 1000;
    final rows = await d.rawQuery(
      'SELECT COUNT(*) AS total, '
      'COALESCE(SUM(correct), 0) AS correct '
      'FROM answer_log WHERE answered_at >= ?',
      [since],
    );
    final r = rows.first;
    return (
      total: (r['total'] as int?) ?? 0,
      correct: (r['correct'] as int?) ?? 0,
    );
  }

  Future<Set<String>> answeredQuestionIds() async {
    final d = await db;
    final rows = await d.query('answer_log', columns: ['question_id']);
    return rows.map((r) => r['question_id'] as String).toSet();
  }

  Future<Set<String>> wrongQuestionIds() async {
    final d = await db;
    final rows = await d.query(
      'answer_log',
      columns: ['question_id'],
      where: 'correct = 0',
    );
    return rows.map((r) => r['question_id'] as String).toSet();
  }

  // --- Cài đặt / PIN ---
  Future<bool> isSoundOn() async {
    final d = await db;
    final rows = await d.query('settings', columns: ['sound_on']);
    if (rows.isEmpty) return true;
    return ((rows.first['sound_on'] as int?) ?? 1) == 1;
  }

  Future<void> setSoundOn(bool value) async {
    final d = await db;
    await d.update(
      'settings',
      {'sound_on': value ? 1 : 0},
      where: 'id = 1',
    );
  }

  /// Giảm hiệu ứng (tắt pháo giấy, parallax, giảm chuyển động) cho máy yếu.
  Future<bool> isReduceEffects() async {
    final d = await db;
    final rows = await d.query('settings', columns: ['reduce_effects']);
    if (rows.isEmpty) return false;
    return ((rows.first['reduce_effects'] as int?) ?? 0) == 1;
  }

  Future<void> setReduceEffects(bool value) async {
    final d = await db;
    await d.update(
      'settings',
      {'reduce_effects': value ? 1 : 0},
      where: 'id = 1',
    );
  }

  /// Nhạc nền ở bản đồ/màn đảo (F1).
  Future<bool> isMusicEnabled() async {
    final d = await db;
    final rows = await d.query('settings', columns: ['music_enabled']);
    if (rows.isEmpty) return true;
    return ((rows.first['music_enabled'] as int?) ?? 1) == 1;
  }

  Future<void> setMusicEnabled(bool value) async {
    final d = await db;
    await d.update(
      'settings',
      {'music_enabled': value ? 1 : 0},
      where: 'id = 1',
    );
  }

  /// Rung phản hồi (F1).
  Future<bool> isHapticsEnabled() async {
    final d = await db;
    final rows = await d.query('settings', columns: ['haptics_enabled']);
    if (rows.isEmpty) return true;
    return ((rows.first['haptics_enabled'] as int?) ?? 1) == 1;
  }

  Future<void> setHapticsEnabled(bool value) async {
    final d = await db;
    await d.update(
      'settings',
      {'haptics_enabled': value ? 1 : 0},
      where: 'id = 1',
    );
  }

  Future<bool> verifyPin(String pin) async {
    final d = await db;
    final rows = await d.query('settings', columns: ['parent_pin_hash']);
    if (rows.isEmpty) return pin == defaultParentPin;
    return (rows.first['parent_pin_hash'] as String?) == pinHash(pin);
  }

  /// Đổi PIN phụ huynh (lưu hash, không lưu PIN thô).
  /// Reset tiến độ không đụng tới PIN.
  Future<void> setPin(String newPin) async {
    final d = await db;
    await d.update(
      'settings',
      {'parent_pin_hash': pinHash(newPin)},
      where: 'id = 1',
    );
  }

  // --- Xu + cửa hàng (SPEC giao diện mục 8, 10) ---
  Future<int> coins() async {
    final d = await db;
    final rows = await d.query('profile', columns: ['coins']);
    if (rows.isEmpty) return 0;
    return (rows.first['coins'] as int?) ?? 0;
  }

  Future<void> addCoins(int amount) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE profile SET coins = coins + ? WHERE id = 1',
      [amount],
    );
  }

  /// Nhận xu theo [key] đúng 1 lần (chống nhận lặp qua reward_log).
  /// Trả về true nếu lần này mới nhận được [amount] xu.
  Future<bool> claimReward(String key, int amount) async {
    final d = await db;
    final inserted = await d.rawInsert(
      'INSERT OR IGNORE INTO reward_log(key, claimed_at) VALUES(?, ?)',
      [key, DateTime.now().millisecondsSinceEpoch],
    );
    if (inserted == 0) return false;
    await addCoins(amount);
    return true;
  }

  /// Đếm số lần đã nhận thưởng theo tiền tố khóa (vd 'practice:<lesson>:').
  Future<int> countRewards(String keyPrefix) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM reward_log WHERE key LIKE ?',
      ['$keyPrefix%'],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<Set<String>> ownedItemIds() async {
    final d = await db;
    final rows = await d.query('owned_items', columns: ['item_id']);
    return rows.map((r) => r['item_id'] as String).toSet();
  }

  Future<Set<String>> equippedItemIds() async {
    final d = await db;
    final rows = await d.query(
      'owned_items',
      columns: ['item_id'],
      where: 'equipped = 1',
    );
    return rows.map((r) => r['item_id'] as String).toSet();
  }

  /// Mua món: đủ xu mới trừ và ghi sở hữu. Trả về true nếu mua được.
  Future<bool> buyItem(String itemId, int price) async {
    final d = await db;
    return d.transaction((txn) async {
      final rows = await txn.query('profile', columns: ['coins']);
      final balance = rows.isEmpty ? 0 : (rows.first['coins'] as int? ?? 0);
      if (balance < price) return false;
      final owned = await txn.query(
        'owned_items',
        where: 'item_id = ?',
        whereArgs: [itemId],
      );
      if (owned.isNotEmpty) return false;
      await txn.rawUpdate(
        'UPDATE profile SET coins = coins - ? WHERE id = 1',
        [price],
      );
      await txn.insert('owned_items', {
        'item_id': itemId,
        'equipped': 0,
        'acquired_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }

  /// Mặc [itemId], đồng thời tháo các món cùng nhóm ([slotItemIds]).
  Future<void> equipOnly(String itemId, List<String> slotItemIds) async {
    final d = await db;
    await d.transaction((txn) async {
      for (final id in slotItemIds) {
        await txn.update(
          'owned_items',
          {'equipped': id == itemId ? 1 : 0},
          where: 'item_id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> unequip(String itemId) async {
    final d = await db;
    await d.update(
      'owned_items',
      {'equipped': 0},
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  // --- Reset ---
  Future<void> resetProgress() async {
    final d = await db;
    await d.delete('progress');
    await d.delete('island_progress');
    await d.delete('answer_log');
    await d.delete('review_box');
    await d.delete('skill_stats');
    await d.delete('owned_items');
    await d.delete('reward_log');
    await d.update('profile', {'coins': 0}, where: 'id = 1');
    await d.insert('island_progress', {
      'island_id': 'on_tap_bo_sung',
      'best_stars': 0,
      'unlocked': 1,
      'unlocked_by_parent': 0,
    });
  }

  Future<void> close() async {
    final existing = _db;
    _db = null;
    await existing?.close();
  }
}
