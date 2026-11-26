import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/services/validator.dart';

/// Kiểm tra dữ liệu dự phòng đóng gói trong app: chỉ đảo 1 (bản dự
/// phòng lần mở đầu khi chưa đồng bộ được từ máy 92). Toàn bộ nội dung
/// còn lại do app Soạn bài quản lý và kiểm tra phía server.
/// Nếu file dữ liệu sai (vd. đáp án phân số không parse được) thì test
/// này đỏ trước khi build, thay vì chỉ lộ lúc chạy trên máy.
void main() {
  test('dữ liệu dự phòng đảo 1: validator pass, đủ 180 câu, id duy nhất', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const files = [
      'assets/data/island_on_tap_bo_sung.json',
    ];
    const expectedCounts = [180];
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
    expect(total, 180);
    expect(allIds.length, 180);
  });
}
