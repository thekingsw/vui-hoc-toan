import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/models/question.dart';
import 'package:toan_lop_5/services/review_logic.dart';
import 'package:toan_lop_5/services/scoring.dart';

void main() {
  group('examScore', () {
    test('thang 10 làm tròn 1 chữ số thập phân', () {
      expect(examScore(20, 20), 10);
      expect(examScore(17, 20), 8.5);
      expect(examScore(2, 3), 6.7);
      expect(examScore(0, 20), 0);
      expect(examScore(5, 0), 0);
    });
  });

  group('nextBox', () {
    test('sai thì về hộp 1', () {
      expect(nextBox(3, false), 1);
      expect(nextBox(5, false), 1);
    });
    test('đúng thì lên 1 hộp', () {
      expect(nextBox(1, true), 2);
      expect(nextBox(4, true), 5);
    });
    test('đúng ở hộp 5 thì tốt nghiệp (0)', () {
      expect(nextBox(5, true), 0);
    });
  });

  group('intervalDaysForBox', () {
    test('lịch 1/3/7/14/30', () {
      expect(intervalDaysForBox(1), 1);
      expect(intervalDaysForBox(2), 3);
      expect(intervalDaysForBox(3), 7);
      expect(intervalDaysForBox(4), 14);
      expect(intervalDaysForBox(5), 30);
    });
    test('ngoài khoảng thì kẹp lại', () {
      expect(intervalDaysForBox(0), 1);
      expect(intervalDaysForBox(9), 30);
    });
  });

  group('pickDueReview', () {
    const now = 1000000;
    test('chỉ lấy câu đến hạn, hộp thấp trước', () {
      final entries = [
        const ReviewEntry(questionId: 'a', box: 3, nextReviewAtMs: 0, wrongCount: 1),
        const ReviewEntry(questionId: 'b', box: 1, nextReviewAtMs: 0, wrongCount: 1),
        const ReviewEntry(questionId: 'c', box: 1, nextReviewAtMs: now + 1000, wrongCount: 5),
      ];
      final due = pickDueReview(entries, now);
      expect(due.map((e) => e.questionId), ['b', 'a']);
    });
    test('giới hạn số câu một lượt', () {
      final entries = [
        for (var i = 0; i < 15; i++)
          ReviewEntry(questionId: 'q$i', box: 1, nextReviewAtMs: 0, wrongCount: 1),
      ];
      expect(pickDueReview(entries, now).length, 10);
    });
  });

  group('weakestSkill', () {
    test('chọn kỹ năng tỉ lệ đúng thấp nhất, đủ 3 lần làm', () {
      final stats = [
        const SkillStat(skill: 'cong', correct: 8, wrong: 2),
        const SkillStat(skill: 'tru', correct: 2, wrong: 4),
        const SkillStat(skill: 'nhan', correct: 0, wrong: 1),
      ];
      expect(weakestSkill(stats)?.skill, 'tru');
    });
    test('chưa đủ dữ liệu thì null', () {
      final stats = [const SkillStat(skill: 'cong', correct: 1, wrong: 1)];
      expect(weakestSkill(stats), isNull);
    });
  });

  group('checkAnswer loại câu mới (Đợt C)', () {
    Question q(QuestionType type,
            {dynamic answer,
            List<List<String>>? pairs,
            List<String>? items,
            List<String>? bank,
            Map<String, dynamic>? column}) =>
        Question(
          id: 'x',
          lessonId: 'l',
          type: type,
          difficulty: 1,
          prompt: 'p',
          answerRaw: answer,
          pairs: pairs,
          items: items,
          bank: bank,
          column: column,
        );

    test('match: đúng theo tập hợp cặp, sai khi nối lệch', () {
      final question = q(QuestionType.match, pairs: [
        ['1 km', '1000 m'],
        ['1 m', '100 cm'],
        ['1 dm', '10 cm'],
      ]);
      expect(checkAnswer(question, '1 m=100 cm|1 km=1000 m|1 dm=10 cm'),
          isTrue);
      expect(checkAnswer(question, '1 km=100 cm|1 m=1000 m|1 dm=10 cm'),
          isFalse);
    });

    test('order: đúng thứ tự mới đạt', () {
      final question = q(QuestionType.order,
          items: ['3,5', '2,75', '4,1'], answer: ['2,75', '3,5', '4,1']);
      expect(checkAnswer(question, '2,75|3,5|4,1'), isTrue);
      expect(checkAnswer(question, '3,5|2,75|4,1'), isFalse);
    });

    test('drag_unit: đúng từng chỗ trống', () {
      final question = q(QuestionType.dragUnit,
          bank: ['kg', 'km', 'g'], answer: ['kg', 'km']);
      expect(checkAnswer(question, 'kg|km'), isTrue);
      expect(checkAnswer(question, 'km|kg'), isFalse);
    });

    test('column_calc: chấm như số', () {
      final question = q(QuestionType.columnCalc,
          column: {'a': '12,5', 'op': '+', 'b': '3,75'}, answer: '16,25');
      expect(checkAnswer(question, '16,25'), isTrue);
      expect(checkAnswer(question, '16.25'), isTrue);
      expect(checkAnswer(question, '16,2'), isFalse);
    });
  });
}
