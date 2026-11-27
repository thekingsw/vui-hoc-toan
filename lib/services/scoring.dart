import 'dart:math';
import '../models/question.dart';

/// Logic thuần (không phụ thuộc Flutter): chấm điểm, tính sao,
/// chọn câu Luyện tập / Quiz, mở khóa đảo. Có unit test riêng.

/// Điểm thi thử thang 10: đúng/tổng × 10, làm tròn 1 chữ số thập phân.
/// total = 0 → 0.
double examScore(int correct, int total) {
  if (total <= 0) return 0;
  return (correct * 100 / total).round() / 10;
}

/// Trả về bản sao options đã xáo trộn cho câu mcq (chỉ đổi vị trí hiển
/// thị, đáp án đúng vẫn nằm trong danh sách). Dữ liệu sinh ra có xu
/// hướng để đáp án ở vị trí đầu (90% ở đợt 280 câu đầu), nên app phải
/// xáo mỗi lần hiển thị để bé không đoán theo vị trí. Loại khác mcq
/// giữ nguyên thứ tự.
List<String> shuffledOptions(Question q, {Random? random}) {
  final opts = List<String>.of(q.options ?? const []);
  if (q.type != QuestionType.mcq || opts.length < 2) return opts;
  opts.shuffle(random ?? Random());
  return opts;
}

/// Chuẩn hóa chuỗi số Việt Nam: "3,5" / "3.5" / "3,50" / "12 500" -> 3.5.
/// Trả về null nếu không parse được.
double? parseVietnameseNumber(String raw) {
  var s = raw.trim().replaceAll(' ', '').replaceAll('\u00A0', '');
  if (s.isEmpty) return null;
  // Dấu phẩy thập phân -> dấu chấm. Nếu có cả '.' và ',' thì ',' là thập phân.
  if (s.contains(',') && s.contains('.')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

/// Parse số hữu tỉ: số thường ("3,5") hoặc phân số ("1/2", "60/100").
/// Phân số so theo giá trị (2/4 == 1/2 == 0,5). Trả về null nếu không parse được.
double? parseRationalNumber(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.contains('/')) {
    final parts = s.split('/');
    if (parts.length != 2) return null;
    final num = parseVietnameseNumber(parts[0]);
    final den = parseVietnameseNumber(parts[1]);
    if (num == null || den == null || den == 0) return null;
    return num / den;
  }
  return parseVietnameseNumber(s);
}

/// So sánh 2 số với sai số nhỏ (tránh lỗi float).
/// Chấp nhận cả phân số: "1/2" == "2/4" == "0,5".
bool numbersEqual(String a, String b, {double epsilon = 1e-9}) {
  final x = parseRationalNumber(a);
  final y = parseRationalNumber(b);
  if (x == null || y == null) return false;
  return (x - y).abs() < epsilon;
}

/// Chấm 1 câu. [userInput] là đáp án bé chọn / nhập (chuỗi).
/// - mcq / true_false: so chuỗi sau khi trim.
/// - fill_number: so giá trị số, chấp nhận cả ',' và '.'.
bool checkAnswer(Question q, String userInput) {
  final input = userInput.trim();
  if (input.isEmpty) return false;
  // Loại câu Đợt C: đáp án bé nhập được mã hóa thành chuỗi:
  // - match: "trái=phải|trái=phải|..." (chấm theo tập hợp cặp)
  // - order / drag_unit: các mục nối bằng "|"
  switch (q.type) {
    case QuestionType.match:
      final pairs = q.pairs;
      if (pairs == null || pairs.isEmpty) return false;
      final expected = pairs.map((p) => '${p[0]}=${p[1]}').toSet();
      final got = input.split('|').map((s) => s.trim()).toSet();
      return expected.length == got.length && expected.containsAll(got);
    case QuestionType.order:
    case QuestionType.dragUnit:
      final expected = q.answerList;
      if (expected == null || expected.isEmpty) return false;
      final got = input.split('|').map((s) => s.trim()).toList();
      if (got.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (got[i] != expected[i].trim()) return false;
      }
      return true;
    default:
      break;
  }
  final expected = q.answerText;
  if (expected == null) return false;
  switch (q.type) {
    case QuestionType.fillNumber:
    case QuestionType.columnCalc:
      return numbersEqual(expected, input);
    case QuestionType.mcq:
    case QuestionType.trueFalse:
      // Đáp án trắc nghiệm có thể là số ("3,5") hoặc phân số ("1/2"):
      // so theo giá trị số nếu cả hai đều parse được, còn không thì so chuỗi.
      if (parseRationalNumber(expected) != null &&
          parseRationalNumber(input) != null) {
        return numbersEqual(expected, input);
      }
      return expected.trim() == input;
    case QuestionType.match:
    case QuestionType.order:
    case QuestionType.dragUnit:
      return false;
  }
}

/// Sao Quiz: số câu đúng trên 10 câu.
/// ≥9 = 3 sao, ≥8 = 2 sao, ≥6 = 1 sao, còn lại 0 sao.
int starsFor(int correct, {int total = 10}) {
  if (total <= 0) return 0;
  final ratio = correct / total;
  if (ratio >= 0.9) return 3;
  if (ratio >= 0.8) return 2;
  if (ratio >= 0.6) return 1;
  return 0;
}

/// Chọn câu cho 1 lượt Luyện tập: 10 câu từ kho của bài.
/// Ưu tiên: câu từng sai -> câu chưa làm -> câu còn lại.
/// Trong mỗi nhóm xáo trộn ngẫu nhiên.
List<Question> selectPracticeQuestions(
  List<Question> pool,
  Set<String> answeredIds,
  Set<String> wrongIds, {
  int count = 10,
  Random? random,
}) {
  final rng = random ?? Random();
  final wrong = <Question>[];
  final unanswered = <Question>[];
  final rest = <Question>[];
  for (final q in pool) {
    if (wrongIds.contains(q.id)) {
      wrong.add(q);
    } else if (!answeredIds.contains(q.id)) {
      unanswered.add(q);
    } else {
      rest.add(q);
    }
  }
  wrong.shuffle(rng);
  unanswered.shuffle(rng);
  rest.shuffle(rng);
  final picked = [...wrong, ...unanswered, ...rest];
  return picked.take(count).toList();
}

/// Chọn câu cho Quiz cấp đảo: rút phân tầng đúng tỉ lệ kho boss
/// (8 mức 1 + 12 mức 2 -> 4 mức 1 + 6 mức 2), rồi xáo trộn.
/// Nếu kho thiếu câu ở 1 mức thì bù bằng mức còn lại.
List<Question> selectQuizQuestions(
  List<Question> bossPool, {
  int easyCount = 4,
  int mediumCount = 6,
  Random? random,
}) {
  final rng = random ?? Random();
  final easy =
      bossPool.where((q) => q.difficulty == 1).toList()..shuffle(rng);
  final medium =
      bossPool.where((q) => q.difficulty == 2).toList()..shuffle(rng);
  final picked = <Question>[];
  picked.addAll(easy.take(easyCount));
  picked.addAll(medium.take(mediumCount));
  // Bù nếu thiếu.
  final remaining = [...easy.skip(picked.where((q) => q.difficulty == 1).length),
      ...medium.skip(picked.where((q) => q.difficulty == 2).length)]
    ..shuffle(rng);
  final target = easyCount + mediumCount;
  while (picked.length < target && remaining.isNotEmpty) {
    picked.add(remaining.removeAt(0));
  }
  picked.shuffle(rng);
  return picked;
}

/// Boss/Quiz của đảo mở khi bé đã xong hết bài học của đảo.
bool isBossUnlocked(Set<String> doneLessonIds, IslandData island) {
  final ids = island.lessonsOnly.map((l) => l.lessonId);
  return ids.every(doneLessonIds.contains);
}

/// Đảo thứ [index] (0-based) mở khi:
/// - là đảo đầu tiên, hoặc
/// - đảo trước đó đạt ≥1 sao, hoặc
/// - đảo này được phụ huynh mở khóa tay.
bool isIslandUnlocked(
  int index,
  Map<String, int> bestStarsByIsland,
  Set<String> parentUnlockedIds,
  List<String> islandOrder,
) {
  if (index <= 0) return true;
  final id = islandOrder[index];
  if (parentUnlockedIds.contains(id)) return true;
  final prevId = islandOrder[index - 1];
  return (bestStarsByIsland[prevId] ?? 0) >= 1;
}
