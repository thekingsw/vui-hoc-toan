import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE progress(
            island_id TEXT NOT NULL,
            lesson_id TEXT NOT NULL,
            practice_done INTEGER NOT NULL DEFAULT 0,
            last_played INTEGER,
            PRIMARY KEY (island_id, lesson_id)
          )''');
        await db.execute('''
          CREATE TABLE island_progress(
            island_id TEXT PRIMARY KEY,
            best_stars INTEGER NOT NULL DEFAULT 0,
            unlocked INTEGER NOT NULL DEFAULT 0,
            unlocked_by_parent INTEGER NOT NULL DEFAULT 0,
            last_played INTEGER
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
            next_review_at INTEGER
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
            daily_limit_minutes INTEGER,
            parent_pin_hash TEXT NOT NULL
          )''');
        await db.insert('profile', {'id': 1, 'name': 'Bé'});
        await db.insert('settings', {
          'id': 1,
          'sound_on': 1,
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
      },
    );
    return database;
  }

  // --- Tiến độ bài học ---
  Future<void> markPracticeDone(String islandId, String lessonId) async {
    final d = await db;
    await d.insert(
      'progress',
      {
        'island_id': islandId,
        'lesson_id': lessonId,
        'practice_done': 1,
        'last_played': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    await d.insert(
      'island_progress',
      {
        'island_id': islandId,
        'best_stars': best,
        'unlocked': 1,
        'unlocked_by_parent': 0,
        'last_played': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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
    await d.insert(
      'island_progress',
      {
        'island_id': nextIslandId,
        'best_stars': best,
        'unlocked': 1,
        'unlocked_by_parent': byParent,
        'last_played': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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
    await d.insert(
      'island_progress',
      {
        'island_id': islandId,
        'best_stars': best,
        'unlocked': unlocked ? 1 : 0,
        'unlocked_by_parent': unlocked ? 1 : 0,
        'last_played': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Nhật ký trả lời ---
  Future<void> logAnswer(
      String questionId, bool correct, String mode) async {
    final d = await db;
    await d.insert('answer_log', {
      'question_id': questionId,
      'correct': correct ? 1 : 0,
      'answered_at': DateTime.now().millisecondsSinceEpoch,
      'mode': mode,
    });
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

  // --- Reset ---
  Future<void> resetProgress() async {
    final d = await db;
    await d.delete('progress');
    await d.delete('island_progress');
    await d.delete('answer_log');
    await d.delete('review_box');
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
