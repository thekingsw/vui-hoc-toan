// Models cho dữ liệu câu hỏi — bám schema mục 6 của SPEC.
// Loader bỏ qua mọi trường lạ (calc, verified, source...).

enum QuestionType { mcq, fillNumber, trueFalse, match, order, dragUnit }

QuestionType? parseQuestionType(String raw) {
  switch (raw) {
    case 'mcq':
      return QuestionType.mcq;
    case 'fill_number':
      return QuestionType.fillNumber;
    case 'true_false':
      return QuestionType.trueFalse;
    case 'match':
      return QuestionType.match;
    case 'order':
      return QuestionType.order;
    case 'drag_unit':
      return QuestionType.dragUnit;
    default:
      return null;
  }
}

/// MVP chỉ hỗ trợ 3 loại đầu; 3 loại sau là giai đoạn 2.
const Set<QuestionType> mvpQuestionTypes = {
  QuestionType.mcq,
  QuestionType.fillNumber,
  QuestionType.trueFalse,
};

class Question {
  Question({
    required this.id,
    required this.lessonId,
    required this.type,
    required this.difficulty,
    required this.prompt,
    this.options,
    required this.answerRaw,
    this.pairs,
    this.items,
    this.bank,
    this.unit,
    this.hint,
    this.explanation,
    this.tags = const [],
    this.figure,
  });

  final String id;
  final String lessonId;
  final QuestionType type;
  final int difficulty;
  final String prompt;
  final List<String>? options;

  /// mcq / fill_number / true_false: String. order / drag_unit: List<String>.
  /// match: không có answer, dùng [pairs].
  final dynamic answerRaw;

  /// match (giai đoạn 2): các cặp [trái, phải].
  final List<List<String>>? pairs;

  /// order (giai đoạn 2): các mục để sắp xếp.
  final List<String>? items;

  /// drag_unit (giai đoạn 2): ngân hàng đơn vị.
  final List<String>? bank;

  final String? unit;
  final String? hint;
  final String? explanation;
  final List<String> tags;

  /// Object figure (vd. {"kind": "trapezoid", "a": 24, ...}). GĐ1 chưa vẽ.
  final Map<String, dynamic>? figure;

  String? get answerText => answerRaw is String ? answerRaw as String : null;
  List<String>? get answerList =>
      answerRaw is List ? List<String>.from(answerRaw as List) : null;

  factory Question.fromJson(Map<String, dynamic> json) {
    final type = parseQuestionType(json['type'] as String? ?? '');
    if (type == null) {
      throw FormatException('type không hợp lệ: ${json['type']}');
    }
    List<List<String>>? pairs;
    if (json['pairs'] is List) {
      pairs = (json['pairs'] as List)
          .map((p) => List<String>.from((p as List).map((e) => '$e')))
          .toList();
    }
    return Question(
      id: json['id'] as String? ?? '',
      lessonId: json['lesson_id'] as String? ?? '',
      type: type,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 0,
      prompt: json['prompt'] as String? ?? '',
      options: json['options'] is List
          ? List<String>.from((json['options'] as List).map((e) => '$e'))
          : null,
      answerRaw: json['answer'],
      pairs: pairs,
      items: json['items'] is List
          ? List<String>.from((json['items'] as List).map((e) => '$e'))
          : null,
      bank: json['bank'] is List
          ? List<String>.from((json['bank'] as List).map((e) => '$e'))
          : null,
      unit: json['unit'] as String?,
      hint: json['hint'] as String?,
      explanation: json['explanation'] as String?,
      tags: json['tags'] is List
          ? List<String>.from((json['tags'] as List).map((e) => '$e'))
          : const [],
      figure: json['figure'] is Map
          ? Map<String, dynamic>.from(json['figure'] as Map)
          : null,
    );
  }
}

class LessonCard {
  LessonCard({required this.heading, required this.body, this.example, this.figure});

  final String heading;
  final String body;
  final String? example;

  /// Object figure minh họa (vd {"kind": "triangle", "base": 8, "height": 5}).
  final Map<String, dynamic>? figure;

  factory LessonCard.fromJson(Map<String, dynamic> json) => LessonCard(
        heading: json['heading'] as String? ?? '',
        body: json['body'] as String? ?? '',
        example: json['example'] as String?,
        figure: json['figure'] is Map
            ? Map<String, dynamic>.from(json['figure'] as Map)
            : null,
      );
}

class Lesson {
  Lesson({
    required this.lessonId,
    required this.kind,
    required this.title,
    this.cards = const [],
  });

  final String lessonId;

  /// 'lesson' hoặc 'boss'. Boss không có cards.
  final String kind;
  final String title;
  final List<LessonCard> cards;

  bool get isBoss => kind == 'boss';

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        lessonId: json['lesson_id'] as String? ?? '',
        kind: json['kind'] as String? ?? 'lesson',
        title: json['title'] as String? ?? '',
        cards: json['cards'] is List
            ? (json['cards'] as List)
                .map((c) =>
                    LessonCard.fromJson(Map<String, dynamic>.from(c as Map)))
                .toList()
            : const [],
      );
}

class IslandData {
  IslandData({
    required this.islandId,
    required this.title,
    required this.order,
    required this.lessons,
    required this.questions,
  });

  final String islandId;
  final String title;
  final int order;
  final List<Lesson> lessons;
  final List<Question> questions;

  List<Lesson> get lessonsOnly => lessons.where((l) => !l.isBoss).toList();
  Lesson? get bossLesson {
    for (final l in lessons) {
      if (l.isBoss) return l;
    }
    return null;
  }

  List<Question> questionsForLesson(String lessonId) =>
      questions.where((q) => q.lessonId == lessonId).toList();

  List<Question> get bossQuestions {
    final boss = bossLesson;
    if (boss == null) return const [];
    return questionsForLesson(boss.lessonId);
  }

  factory IslandData.fromJson(Map<String, dynamic> json) => IslandData(
        islandId: json['island_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        lessons: json['lessons'] is List
            ? (json['lessons'] as List)
                .map((l) =>
                    Lesson.fromJson(Map<String, dynamic>.from(l as Map)))
                .toList()
            : const [],
        questions: json['questions'] is List
            ? (json['questions'] as List)
                .map((q) =>
                    Question.fromJson(Map<String, dynamic>.from(q as Map)))
                .toList()
            : const [],
      );
}
