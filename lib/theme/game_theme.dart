import 'package:flutter/material.dart';

/// Bảng màu game (SPEC giao diện mục 1) — mọi widget lấy màu từ đây,
/// không rải mã màu trong widget.
class GameColors {
  static const seaLight = Color(0xFF4FC3F7);
  static const seaDeep = Color(0xFF0288D1);
  static const sand = Color(0xFFFFE0A3);
  static const grass = Color(0xFF7CB342);
  static const accent = Color(0xFFFF8F00);
  static const correct = Color(0xFF43A047);
  static const wrongSoft = Color(0xFFFB8C00);
  static const ink = Color(0xFF263238);
  static const fog = Color(0xFFF5F7F8);
  static const mystery = Color(0xFF90A4AE);
}

/// Kích thước dùng chung.
class GameSizes {
  /// Nút bấm tối thiểu cho trẻ (SPEC: ≥ 56 dp).
  static const minButton = 56.0;

  /// Cỡ chữ câu hỏi tối thiểu (SPEC: ≥ 20 sp).
  static const questionFont = 20.0;
}
