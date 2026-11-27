import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import 'database_service.dart';

/// Kho nội dung bài học trong SQLite (bảng content_*).
///
/// Nội dung do app Soạn bài trên máy 92 xuất bản, app điện thoại pull về
/// (xem data_update_service.dart) và ghi vào đây. Bảng tiến độ học
/// (progress, island_progress, answer_log...) nằm riêng, không đụng vào
/// khi thay nội dung — tiến độ gắn theo id nên giữ nguyên.

class ContentStore {
  ContentStore([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<Database> get _database => _db.db;

  /// Phiên bản nội dung từng đảo đang có trên máy (đảo chưa có = vắng mặt).
  Future<Map<String, int>> islandVersions() async {
    final d = await _database;
    final rows = await d.query('content_islands',
        columns: ['island_id', 'version']);
    return {
      for (final r in rows)
        r['island_id'] as String: (r['version'] as int?) ?? 0,
    };
  }

  Future<int> dataVersion() async {
    final d = await _database;
    final rows = await d.query('content_meta',
        where: 'key = ?', whereArgs: ['data_version']);
    if (rows.isEmpty) return 0;
    return int.tryParse('${rows.first['value']}') ?? 0;
  }

  Future<void> setDataVersion(int version) async {
    final d = await _database;
    await d.insert(
      'content_meta',
      {'key': 'data_version', 'value': '$version'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isEmpty() async {
    final d = await _database;
    final rows =
        await d.rawQuery('SELECT COUNT(*) AS c FROM content_islands');
    return ((rows.first['c'] as int?) ?? 0) == 0;
  }

  /// Thay toàn bộ nội dung một đảo bằng [islandJson] (đúng schema app
  /// đang dùng), trong một giao dịch: lỗi giữa chừng thì giữ bản cũ.
  /// Câu có min_app_version (số build) lớn hơn [appBuild] bị bỏ qua.
  Future<void> replaceIsland(
    Map<String, dynamic> islandJson,
    int version, {
    required int appBuild,
  }) async {
    final d = await _database;
    final islandId = islandJson['island_id'] as String;
    final lessons = (islandJson['lessons'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final questions = filterQuestionsForBuild(
      (islandJson['questions'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      appBuild,
    );
    await d.transaction((txn) async {
      final oldLessons = await txn.query('content_lessons',
          columns: ['lesson_id'], where: 'island_id = ?', whereArgs: [islandId]);
      for (final l in oldLessons) {
        final lid = l['lesson_id'] as String;
        await txn.delete('content_cards',
            where: 'lesson_id = ?', whereArgs: [lid]);
        await txn.delete('content_questions',
            where: 'lesson_id = ?', whereArgs: [lid]);
      }
      await txn.delete('content_lessons',
          where: 'island_id = ?', whereArgs: [islandId]);
      await txn.insert(
        'content_islands',
        {
          'island_id': islandId,
          'title': islandJson['title'] as String? ?? '',
          'ord': (islandJson['order'] as num?)?.toInt() ?? 0,
          'version': version,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var i = 0; i < lessons.length; i++) {
        final les = lessons[i];
        final lid = les['lesson_id'] as String;
        await txn.insert('content_lessons', {
          'lesson_id': lid,
          'island_id': islandId,
          'kind': les['kind'] as String? ?? 'lesson',
          'title': les['title'] as String? ?? '',
          'ord': i,
        });
        final cards = (les['cards'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (var j = 0; j < cards.length; j++) {
          await txn.insert('content_cards', {
            'id': '${lid}_card_${j + 1}',
            'lesson_id': lid,
            'ord': j,
            'heading': cards[j]['heading'] as String? ?? '',
            'body': cards[j]['body'] as String? ?? '',
            'example': cards[j]['example'] as String?,
            'figure_json': cards[j]['figure'] != null
                ? jsonEncode(cards[j]['figure'])
                : null,
          });
        }
      }
      for (final q in questions) {
        await txn.insert('content_questions', {
          'id': q['id'] as String,
          'lesson_id': q['lesson_id'] as String,
          'type': q['type'] as String,
          'difficulty': (q['difficulty'] as num?)?.toInt() ?? 1,
          'prompt': q['prompt'] as String? ?? '',
          'options_json': jsonEncode(q['options'] ?? const []),
          'answer': '${q['answer'] ?? ''}',
          'hint': q['hint'] as String? ?? '',
          'explanation': q['explanation'] as String? ?? '',
          'unit': q['unit'] as String?,
          'min_app_version': (q['min_app_version'] as num?)?.toInt() ?? 0,
          'figure_json': q['figure'] != null ? jsonEncode(q['figure']) : null,
          'tags_json': q['tags'] != null ? jsonEncode(q['tags']) : null,
        });
      }
    });
  }

  /// Đọc một đảo từ kho nội dung; null nếu đảo chưa có nội dung.
  Future<IslandData?> loadIsland(String islandId) async {
    final d = await _database;
    final isl = await d.query('content_islands',
        where: 'island_id = ?', whereArgs: [islandId]);
    if (isl.isEmpty) return null;
    final lessonRows = await d.query('content_lessons',
        where: 'island_id = ?', whereArgs: [islandId], orderBy: 'ord');
    final lessons = <Map<String, dynamic>>[];
    for (final l in lessonRows) {
      final lid = l['lesson_id'] as String;
      final cardRows = await d.query('content_cards',
          where: 'lesson_id = ?', whereArgs: [lid], orderBy: 'ord');
      lessons.add({
        'lesson_id': lid,
        'kind': l['kind'],
        'title': l['title'],
        'cards': [
          for (final c in cardRows)
            {
              'heading': c['heading'],
              'body': c['body'],
              if (c['example'] != null) 'example': c['example'],
              if (c['figure_json'] != null)
                'figure': jsonDecode(c['figure_json'] as String),
            },
        ],
      });
    }
    final qRows = await d.rawQuery(
      'SELECT q.* FROM content_questions q '
      'JOIN content_lessons l ON l.lesson_id = q.lesson_id '
      'WHERE l.island_id = ? ORDER BY q.id',
      [islandId],
    );
    final questions = [
      for (final q in qRows)
        {
          'id': q['id'],
          'lesson_id': q['lesson_id'],
          'type': q['type'],
          'difficulty': q['difficulty'],
          'prompt': q['prompt'],
          'options': jsonDecode(q['options_json'] as String? ?? '[]'),
          'answer': q['answer'],
          'hint': q['hint'],
          'explanation': q['explanation'],
          if (q['unit'] != null) 'unit': q['unit'],
          if (q['figure_json'] != null)
            'figure': jsonDecode(q['figure_json'] as String),
          if (q['tags_json'] != null)
            'tags': jsonDecode(q['tags_json'] as String),
        },
    ];
    return IslandData.fromJson({
      'island_id': islandId,
      'title': isl.first['title'],
      'order': isl.first['ord'],
      'lessons': lessons,
      'questions': questions,
    });
  }
}

/// Bỏ các câu đòi app mới hơn [appBuild] (min_app_version = số build tối
/// thiểu). App cũ bỏ qua câu loại mới thay vì từ chối cả gói cập nhật.
List<Map<String, dynamic>> filterQuestionsForBuild(
  List<Map<String, dynamic>> questions,
  int appBuild,
) {
  return questions.where((q) {
    final minBuild = (q['min_app_version'] as num?)?.toInt() ?? 0;
    return minBuild <= appBuild;
  }).toList();
}
