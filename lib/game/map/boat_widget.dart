import 'dart:math';

import 'package:flutter/material.dart';
import '../../theme/game_theme.dart';
import '../game_image.dart';

/// Thuyền của linh vật trên bản đồ. Đợt 3 có ảnh thì tự dùng ảnh,
/// chưa có thì vẽ bằng code. [assetPath] đổi theo thuyền đang dùng.
class BoatWidget extends StatelessWidget {
  const BoatWidget({
    super.key,
    this.size = 56,
    this.assetPath = 'assets/images/items/boat_wood.webp',
  });

  final double size;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return GameImage(
      assetPath: assetPath,
      width: size,
      height: size,
      fallback: CustomPaint(
        size: Size(size, size),
        painter: _BoatPainter(),
      ),
    );
  }
}

class _BoatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hull = Paint()..color = const Color(0xFF8D6E63);
    final sail = Paint()..color = Colors.white;
    final mast = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;

    // Cột buồm.
    canvas.drawLine(
        Offset(w * 0.5, h * 0.12), Offset(w * 0.5, h * 0.68), mast);
    // Buồm.
    final sailPath = Path()
      ..moveTo(w * 0.54, h * 0.16)
      ..quadraticBezierTo(w * 0.86, h * 0.4, w * 0.54, h * 0.62)
      ..close();
    canvas.drawPath(sailPath, sail);
    final sailPath2 = Path()
      ..moveTo(w * 0.46, h * 0.24)
      ..quadraticBezierTo(w * 0.24, h * 0.42, w * 0.46, h * 0.62)
      ..close();
    canvas.drawPath(sailPath2, Paint()..color = GameColors.accent);
    // Thân thuyền.
    final hullPath = Path()
      ..moveTo(w * 0.08, h * 0.66)
      ..lineTo(w * 0.92, h * 0.66)
      ..quadraticBezierTo(w * 0.8, h * 0.92, w * 0.5, h * 0.94)
      ..quadraticBezierTo(w * 0.2, h * 0.92, w * 0.08, h * 0.66)
      ..close();
    canvas.drawPath(hullPath, hull);
    // Sóng nhỏ dưới thuyền.
    final wave = Paint()
      ..color = GameColors.seaLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    final wavePath = Path();
    for (var x = 0.05; x <= 0.95; x += 0.05) {
      final y = h * 0.97 + sin(x * pi * 4) * h * 0.015;
      if (x == 0.05) {
        wavePath.moveTo(w * x, y);
      } else {
        wavePath.lineTo(w * x, y);
      }
    }
    canvas.drawPath(wavePath, wave);
  }

  @override
  bool shouldRepaint(_BoatPainter old) => false;
}
