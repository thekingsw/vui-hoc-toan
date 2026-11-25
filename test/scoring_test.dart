import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/models/question.dart';
import 'package:toan_lop_5/services/scoring.dart';

Question _mcq({
  String id = 'q1',
  String answer = '3,5',
  List<String> options = const ['3,45', '3,5', '3,05', '2,99'],
  int difficulty = 1,
}) =>
    Question(
      id: id,
      lessonId: 'lesson1',
      type: QuestionType.mcq,
      difficulty: difficulty,
      prompt: 'Số nào lớn nhất?',
      options: options,
      answerRaw: answer,
    );

Question _fill({
  String id = 'f1',
  String answer = '200',
  int difficulty = 1,
}) =>
    Question(
      id: id,
      lessonId: 'lesson1',
      type: QuestionType.fillNumber,
      difficulty: difficulty,
      prompt: 'Tính diện tích.',
      answerRaw: answer,
    );

Question _tf({String id = 't1', String answer = 'Đúng'}) => Question(
      id: id,
      lessonId: 'lesson1',
      type: QuestionType.trueFalse,
      difficulty: 1,
      prompt: 'Khẳng định.',
      answerRaw: answer,
    );

void main() {
  group('parseVietnameseNumber', () {
    test('dấu phẩy thập phân', () {
      expect(parseVietnameseNumber('3,5'), 3.5);
      expect(parseVietnameseNumber('3.5'), 3.5);
      expect(parseVietnameseNumber('3,50'), 3.5);
    });
    test('số hàng nghìn cách bằng dấu cách', () {
      expect(parseVietnameseNumber('12 500'), 12500);
    });
    test('không parse được trả về null', () {
      expect(parseVietnameseNumber('abc'), isNull);
      expect(parseVietnameseNumber(''), isNull);
    });
  });

  group('checkAnswer — mcq', () {
    test('chọn đúng đáp án', () {
      expect(checkAnswer(_mcq(), '3,5'), isTrue);
    });
    test('chọn sai đáp án', () {
      expect(checkAnswer(_mcq(), '3,45'), isFalse);
    });
    test('đáp án số viết bằng dấu chấm vẫn đúng', () {
      expect(checkAnswer(_mcq(), '3.5'), isTrue);
      expect(checkAnswer(_mcq(), '3,50'), isTrue);
    });
  });

  group('parseRationalNumber — phân số', () {
    test('phân số bằng giá trị thập phân', () {
      expect(parseRationalNumber('1/2'), 0.5);
      expect(parseRationalNumber('60/100'), 0.6);
    });
    test('không parse được trả về null', () {
      expect(parseRationalNumber('1/0'), isNull);
      expect(parseRationalNumber('1/2/3'), isNull);
      expect(parseRationalNumber('abc'), isNull);
    });
  });

  group('checkAnswer — fill_number', () {
    test('nhập đúng với dấu phẩy', () {
      expect(checkAnswer(_fill(), '200'), isTrue);
    });
    test('nhập đúng với dấu chấm', () {
      expect(checkAnswer(_fill(answer: '3,5'), '3.5'), isTrue);
      expect(checkAnswer(_fill(answer: '3,5'), '3,5'), isTrue);
      expect(checkAnswer(_fill(answer: '3,5'), '3,50'), isTrue);
    });
    test('nhập sai', () {
      expect(checkAnswer(_fill(), '20'), isFalse);
      expect(checkAnswer(_fill(), ''), isFalse);
      expect(checkAnswer(_fill(), 'hai trăm'), isFalse);
    });
    test('khoảng trắng thừa vẫn đúng', () {
      expect(checkAnswer(_fill(answer: '12 500'), '12500'), isTrue);
    });
    test('đáp án phân số: dạng rút gọn và thập phân đều đúng', () {
      expect(checkAnswer(_fill(answer: '1/2'), '1/2'), isTrue);
      expect(checkAnswer(_fill(answer: '1/2'), '2/4'), isTrue);
      expect(checkAnswer(_fill(answer: '1/2'), '0,5'), isTrue);
      expect(checkAnswer(_fill(answer: '60/100'), '3/5'), isTrue);
      expect(checkAnswer(_fill(answer: '3/4'), '0,75'), isTrue);
    });
    test('đáp án phân số: sai thì vẫn sai', () {
      expect(checkAnswer(_fill(answer: '1/2'), '1/3'), isFalse);
      expect(checkAnswer(_fill(answer: '1/2'), '2/3'), isFalse);
    });
  });

  group('checkAnswer — true_false', () {
    test('Đúng/Sai chính xác', () {
      expect(checkAnswer(_tf(), 'Đúng'), isTrue);
      expect(checkAnswer(_tf(), 'Sai'), isFalse);
      expect(checkAnswer(_tf(answer: 'Sai'), 'Sai'), isTrue);
    });
  });

  group('starsFor', () {
    test('ngưỡng sao theo SPEC: 9=3, 8=2, 6=1', () {
      expect(starsFor(10), 3);
      expect(starsFor(9), 3);
      expect(starsFor(8), 2);
      expect(starsFor(7), 1);
      expect(starsFor(6), 1);
      expect(starsFor(5), 0);
      expect(starsFor(0), 0);
    });
  });

  group('selectPracticeQuestions', () {
    test('ưu tiên câu từng sai, rồi câu chưa làm', () {
      final pool = List.generate(
        5,
        (i) => _mcq(id: 'q$i'),
      );
      final picked = selectPracticeQuestions(
        pool,
        {'q0', 'q1', 'q2'}, // đã làm
        {'q1'}, // từng sai
        count: 3,
      );
      expect(picked.length, 3);
      expect(picked.first.id, 'q1'); // câu từng sai lên đầu
    });
    test('không vượt quá số câu trong kho', () {
      final pool = [_mcq(id: 'q0'), _mcq(id: 'q1')];
      final picked = selectPracticeQuestions(pool, {}, {}, count: 10);
      expect(picked.length, 2);
    });
  });

  group('selectQuizQuestions', () {
    test('phân tầng 4 mức 1 + 6 mức 2', () {
      final pool = [
        for (var i = 0; i < 8; i++) _mcq(id: 'e$i', difficulty: 1),
        for (var i = 0; i < 12; i++) _mcq(id: 'm$i', difficulty: 2),
      ];
      final picked = selectQuizQuestions(pool);
      expect(picked.length, 10);
      expect(picked.where((q) => q.difficulty == 1).length, 4);
      expect(picked.where((q) => q.difficulty == 2).length, 6);
    });
    test('kho thiếu thì bù bằng mức còn lại', () {
      final pool = [
        for (var i = 0; i < 2; i++) _mcq(id: 'e$i', difficulty: 1),
        for (var i = 0; i < 12; i++) _mcq(id: 'm$i', difficulty: 2),
      ];
      final picked = selectQuizQuestions(pool);
      expect(picked.length, 10);
      expect(picked.where((q) => q.difficulty == 1).length, 2);
    });
  });

  group('mở khóa', () {
    const order = ['dao1', 'dao2', 'dao3'];
    test('đảo đầu tiên luôn mở', () {
      expect(isIslandUnlocked(0, {}, {}, order), isTrue);
    });
    test('đảo sau mở khi đảo trước ≥1 sao', () {
      expect(isIslandUnlocked(1, {'dao1': 1}, {}, order), isTrue);
      expect(isIslandUnlocked(1, {'dao1': 0}, {}, order), isFalse);
      expect(isIslandUnlocked(2, {'dao1': 3, 'dao2': 0}, {}, order),
          isFalse);
      expect(isIslandUnlocked(2, {'dao1': 3, 'dao2': 2}, {}, order),
          isTrue);
    });
    test('phụ huynh mở khóa tay thì mở dù chưa có sao', () {
      expect(isIslandUnlocked(1, {}, {'dao2'}, order), isTrue);
    });
  });
}
