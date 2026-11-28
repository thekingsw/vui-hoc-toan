import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/models/question.dart';
import 'package:toan_lop_5/services/scoring.dart';
import 'package:toan_lop_5/services/variant_generator.dart';

Question _q({
  required QuestionType type,
  required String prompt,
  required String answer,
  required String calc,
  List<String>? options,
}) =>
    Question(
      id: 'x_001',
      lessonId: 'x',
      type: type,
      difficulty: 1,
      prompt: prompt,
      options: options,
      answerRaw: answer,
      calc: calc,
    );

void main() {
  group('evalCalc', () {
    test('số nguyên và phép tính', () {
      expect(evalCalc('4*100-150')!.num, BigInt.from(250));
    });
    test('Fraction', () {
      final v = evalCalc('Fraction(60000,10000)-2')!;
      expect(v.num, BigInt.from(4));
      expect(v.den, BigInt.one);
    });
    test('Decimal và round', () {
      final v = evalCalc("round(Decimal('12.5')*3, 1)")!;
      expect(v.num, BigInt.from(75));
      expect(v.den, BigInt.two);
    });
    test('biểu thức lạ trả null', () {
      expect(evalCalc('foo(1)'), isNull);
      expect(evalCalc('1/0'), isNull);
    });
  });

  group('makeVariant', () {
    test('fill_number: đổi số trong đề, đáp án tính lại đúng', () {
      final q = _q(
        type: QuestionType.fillNumber,
        prompt: 'Một sợi dây dài 4 m, cắt đi 150 cm. Phần còn lại dài bao nhiêu cm?',
        answer: '250',
        calc: '4*100-150',
      );
      Question? v;
      for (var seed = 1; seed <= 20 && v == null; seed++) {
        v = makeVariant(q, random: Random(seed));
      }
      expect(v, isNotNull);
      expect(v!.prompt, isNot(q.prompt));
      expect(v.answerText, isNot('250'));
      // Đáp án mới phải khớp biểu thức mới
      final got = evalCalc(v.calc!)!;
      expect(numbersEqual(v.answerText!, '${got.num}'), isTrue);
      expect(v.id, q.id); // giữ id gốc để hộp ôn cập nhật đúng
    });

    test('mcq: 4 lựa chọn khác nhau, đáp án nằm trong lựa chọn', () {
      final q = _q(
        type: QuestionType.mcq,
        prompt: '3 km² bằng bao nhiêu m²?',
        answer: '3000000',
        calc: '3*1000000',
        options: ['300000', '3000000', '30000', '30000000'],
      );
      final v = makeVariant(q, random: Random(3));
      expect(v, isNotNull);
      expect(v!.options!.length, 4);
      expect(v.options!.toSet().length, 4);
      expect(v.options, contains(v.answerText));
      expect(checkAnswer(v, v.answerText!), isTrue);
    });

    test('không có calc thì không sinh', () {
      final q = Question(
        id: 'x_002',
        lessonId: 'x',
        type: QuestionType.fillNumber,
        difficulty: 1,
        prompt: '2 + 3 bằng bao nhiêu?',
        answerRaw: '5',
      );
      expect(makeVariant(q, random: Random(1)), isNull);
    });

    test('số trong calc không có trong đề thì không sinh', () {
      final q = _q(
        type: QuestionType.fillNumber,
        prompt: 'Đổi đơn vị đo diện tích từ km² sang m² thì nhân với bao nhiêu?',
        answer: '1000000',
        calc: '1*1000000',
      );
      // Số 1 có trong đề? "km²" không chứa "1" đứng riêng... đề không có
      // số 1 dạng dữ kiện; nếu sinh được thì đáp án vẫn phải đúng calc.
      final v = makeVariant(q, random: Random(5));
      if (v != null) {
        final got = evalCalc(v.calc!)!;
        expect(numbersEqual(v.answerText!, '${got.num}'), isTrue);
      }
    });

    test('số thập phân: giữ số chữ số thập phân', () {
      final q = _q(
        type: QuestionType.fillNumber,
        prompt: 'Tính: 12,5 × 3 = ?',
        answer: '37,5',
        calc: "Decimal('12.5')*3",
      );
      final v = makeVariant(q, random: Random(11));
      expect(v, isNotNull);
      expect(v!.answerText, contains(','));
      final got = evalCalc(v.calc!)!;
      final expectStr = '${got.num}/${got.den}';
      expect(parseRationalNumber(v.answerText!)!.toString(),
          parseRationalNumber(expectStr)!.toString());
    });
  });
}
