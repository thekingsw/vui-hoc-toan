import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/services/validator.dart';

Map<String, dynamic> _validIsland() => {
      'island_id': 'so_thap_phan',
      'title': 'Đảo Số Thập Phân',
      'order': 2,
      'lessons': [
        {
          'lesson_id': 'so_sanh_so_thap_phan',
          'kind': 'lesson',
          'title': 'So sánh số thập phân',
          'cards': [
            {
              'heading': 'Cách so sánh',
              'body': 'So phần nguyên trước.',
            }
          ],
        },
        <String, dynamic>{
          'lesson_id': 'boss_chu_de_2',
          'kind': 'boss',
          'title': 'Thử thách',
        },
      ],
      'questions': [
        {
          'id': 'so_sanh_001',
          'lesson_id': 'so_sanh_so_thap_phan',
          'type': 'mcq',
          'difficulty': 1,
          'prompt': 'Số nào lớn nhất?',
          'options': ['3,45', '3,5', '3,05', '2,99'],
          'answer': '3,5',
          'hint': 'So phần nguyên trước.',
          'explanation': '3,5 lớn nhất.',
          // Trường lạ: loader phải bỏ qua, validator không báo lỗi.
          'calc': '3.5',
          'verified': false,
          'source': 'sgk',
        },
        {
          'id': 'so_sanh_002',
          'lesson_id': 'so_sanh_so_thap_phan',
          'type': 'fill_number',
          'difficulty': 2,
          'prompt': 'Viết số ba phẩy năm.',
          'answer': '3,5',
        },
        {
          'id': 'so_sanh_003',
          'lesson_id': 'so_sanh_so_thap_phan',
          'type': 'true_false',
          'difficulty': 1,
          'prompt': '3,5 lớn hơn 3,45. Đúng hay sai?',
          'answer': 'Đúng',
        },
      ],
    };

void main() {
  group('validateIslandJson', () {
    test('dữ liệu đúng thì pass, trường lạ được bỏ qua', () {
      expect(validateIslandJson(_validIsland()), isEmpty);
    });

    test('thiếu trường bắt buộc', () {
      final json = _validIsland()..remove('title');
      final errors = validateIslandJson(json);
      expect(errors.any((e) => e.contains('thiếu title')), isTrue);
    });

    test('id trùng bị báo lỗi', () {
      final json = _validIsland();
      (json['questions'] as List).add({
        'id': 'so_sanh_001',
        'lesson_id': 'so_sanh_so_thap_phan',
        'type': 'mcq',
        'difficulty': 1,
        'prompt': 'Câu trùng id.',
        'options': ['1', '2', '3', '4'],
        'answer': '1',
      });
      final errors = validateIslandJson(json);
      expect(errors.any((e) => e.contains('id trùng')), isTrue);
    });

    test('mcq answer không nằm trong options bị báo lỗi', () {
      final json = _validIsland();
      (json['questions'] as List)[0]['answer'] = '9,9';
      final errors = validateIslandJson(json);
      expect(
          errors.any((e) => e.contains('không nằm trong options')), isTrue);
    });

    test('mcq không đủ 4 options bị báo lỗi', () {
      final json = _validIsland();
      (json['questions'] as List)[0]['options'] = ['3,45', '3,5'];
      final errors = validateIslandJson(json);
      expect(errors.any((e) => e.contains('đúng 4 options')), isTrue);
    });

    test('fill_number answer không phải số bị báo lỗi', () {
      final json = _validIsland();
      (json['questions'] as List)[1]['answer'] = 'ba phẩy năm';
      final errors = validateIslandJson(json);
      expect(
          errors.any((e) => e.contains('không parse được thành số')), isTrue);
    });

    test('fill_number answer là phân số thì pass', () {
      final json = _validIsland();
      (json['questions'] as List)[1]['answer'] = '1/2';
      final errors = validateIslandJson(json);
      expect(errors, isEmpty);
    });

    test('true_false answer lạ bị báo lỗi', () {
      final json = _validIsland();
      (json['questions'] as List)[2]['answer'] = 'Có thể';
      final errors = validateIslandJson(json);
      expect(errors.any((e) => e.contains('phải là "Đúng"')), isTrue);
    });

    test('mức 3 ở giai đoạn 1 bị báo lỗi', () {
      final json = _validIsland();
      (json['questions'] as List)[0]['difficulty'] = 3;
      final errors = validateIslandJson(json);
      expect(errors.any((e) => e.contains('difficulty')), isTrue);
    });

    test('type giai đoạn 2 (match) bị báo lỗi ở giai đoạn 1', () {
      final json = _validIsland();
      (json['questions'] as List)[0]['type'] = 'match';
      final errors = validateIslandJson(json);
      expect(
          errors.any((e) => e.contains('chưa hỗ trợ ở giai đoạn 1')), isTrue);
    });

    test('boss có cards bị báo lỗi', () {
      final json = _validIsland();
      (json['lessons'] as List)[1]['cards'] = [
        {'heading': 'Sai', 'body': 'Boss không có cards.'}
      ];
      final errors = validateIslandJson(json);
      expect(errors.any((e) => e.contains('không được có cards')), isTrue);
    });

    test('lesson_id lạ trong question bị báo lỗi', () {
      final json = _validIsland();
      (json['questions'] as List)[0]['lesson_id'] = 'bai_khong_co';
      final errors = validateIslandJson(json);
      expect(errors.any((e) => e.contains('không có trong lessons')), isTrue);
    });
  });
}
