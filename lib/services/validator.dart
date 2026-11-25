import '../models/question.dart';
import 'scoring.dart';

/// Validate JSON dữ liệu 1 đảo (chạy ở debug mode lúc khởi động).
/// Trả về danh sách lỗi; rỗng = pass.
/// [allIds] là tập id đã gặp ở các đảo khác (kiểm tra trùng toàn app).

List<String> validateIslandJson(
  Map<String, dynamic> json, {
  Set<String>? allIds,
}) {
  final errors = <String>[];
  final islandId = json['island_id'] as String? ?? '(không có island_id)';
  void err(String msg) => errors.add('[$islandId] $msg');

  if (json['island_id'] == null || (json['island_id'] as String).isEmpty) {
    err('thiếu island_id');
  }
  if (json['title'] == null || (json['title'] as String).isEmpty) {
    err('thiếu title');
  }
  if (json['order'] is! num) err('thiếu/sai order');
  if (json['lessons'] is! List) {
    err('thiếu lessons');
    return errors;
  }
  if (json['questions'] is! List) {
    err('thiếu questions');
    return errors;
  }

  final lessons = json['lessons'] as List;
  final lessonIds = <String>{};
  for (final raw in lessons) {
    if (raw is! Map) {
      err('lesson không phải object');
      continue;
    }
    final l = Map<String, dynamic>.from(raw);
    final lid = l['lesson_id'] as String?;
    if (lid == null || lid.isEmpty) {
      err('lesson thiếu lesson_id');
      continue;
    }
    lessonIds.add(lid);
    final kind = l['kind'] as String? ?? 'lesson';
    if (kind != 'lesson' && kind != 'boss') {
      err('lesson $lid: kind lạ: $kind');
    }
    if ((l['title'] as String?)?.isEmpty ?? true) {
      err('lesson $lid: thiếu title');
    }
    if (kind == 'boss' && l['cards'] is List && (l['cards'] as List).isNotEmpty) {
      err('boss $lid: boss không được có cards');
    }
  }

  final seenIds = allIds ?? <String>{};
  final questions = json['questions'] as List;
  for (final raw in questions) {
    if (raw is! Map) {
      err('question không phải object');
      continue;
    }
    final q = Map<String, dynamic>.from(raw);
    final id = q['id'] as String?;
    if (id == null || id.isEmpty) {
      err('question thiếu id');
      continue;
    }
    if (!seenIds.add(id)) err('question $id: id trùng');
    final lessonId = q['lesson_id'] as String?;
    if (lessonId == null || lessonId.isEmpty) {
      err('question $id: thiếu lesson_id');
    } else if (!lessonIds.contains(lessonId)) {
      err('question $id: lesson_id $lessonId không có trong lessons');
    }
    final type = parseQuestionType(q['type'] as String? ?? '');
    if (type == null) {
      err('question $id: type lạ: ${q['type']}');
      continue;
    }
    if (!mvpQuestionTypes.contains(type)) {
      err('question $id: type $type chưa hỗ trợ ở giai đoạn 1');
    }
    final difficulty = (q['difficulty'] as num?)?.toInt();
    if (difficulty == null || difficulty < 1 || difficulty > 2) {
      err('question $id: difficulty phải là 1 hoặc 2 (giai đoạn 1)');
    }
    final prompt = q['prompt'] as String?;
    if (prompt == null || prompt.isEmpty) {
      err('question $id: thiếu prompt');
    } else if (prompt.length > 300) {
      err('question $id: prompt dài ${prompt.length} ký tự (>300)');
    }
    final explanation = q['explanation'] as String?;
    if (explanation != null && explanation.length > 400) {
      err('question $id: explanation dài ${explanation.length} ký tự (>400)');
    }
    switch (type) {
      case QuestionType.mcq:
        final options = q['options'];
        if (options is! List || options.length != 4) {
          err('question $id (mcq): cần đúng 4 options');
          break;
        }
        final opts = options.map((e) => '$e').toList();
        final answer = q['answer'];
        if (answer is! String || !opts.contains(answer)) {
          err('question $id (mcq): answer không nằm trong options');
        }
        // Không có 2 option trùng giá trị số (kể cả phân số: 1/2 == 2/4).
        final seen = <String>{};
        for (final o in opts) {
          final key = parseRationalNumber(o)?.toString() ?? o.trim();
          if (!seen.add(key)) {
            err('question $id (mcq): có 2 option trùng giá trị: $o');
          }
        }
        break;
      case QuestionType.fillNumber:
        final answer = q['answer'];
        if (answer is! String ||
            parseRationalNumber(answer) == null) {
          err('question $id (fill_number): answer không parse được thành số');
        }
        break;
      case QuestionType.trueFalse:
        final answer = q['answer'];
        if (answer != 'Đúng' && answer != 'Sai') {
          err('question $id (true_false): answer phải là "Đúng" hoặc "Sai"');
        }
        break;
      case QuestionType.match:
      case QuestionType.order:
      case QuestionType.dragUnit:
        break;
    }
  }
  return errors;
}
