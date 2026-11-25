import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/services/validator.dart';

/// Kiểm tra dữ liệu thật đóng gói trong app: 2 đảo Giai đoạn 1.
/// Nếu file dữ liệu sai (vd. đáp án phân số không parse được) thì test này
/// đỏ trước khi build, thay vì chỉ lộ lúc chạy trên máy.
void main() {
  test('dữ liệu thật 2 đảo: validator pass, đủ 280 câu, id duy nhất', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const files = [
      'assets/data/island_on_tap_bo_sung.json',
      'assets/data/island_so_thap_phan.json',
    ];
    const expectedCounts = [180, 100];
    final allIds = <String>{};
    var total = 0;
    for (var i = 0; i < files.length; i++) {
      final raw = await rootBundle.loadString(files[i]);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final errors = validateIslandJson(json, allIds: allIds);
      expect(errors, isEmpty, reason: 'Lỗi ở ${files[i]}: $errors');
      final questions = json['questions'] as List;
      expect(questions.length, expectedCounts[i]);
      total += questions.length;
    }
    expect(total, 280);
    expect(allIds.length, 280);
  });
}
