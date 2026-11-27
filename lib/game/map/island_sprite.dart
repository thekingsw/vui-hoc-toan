import 'dart:math';

import 'package:flutter/material.dart';
import '../../theme/game_theme.dart';
import '../game_image.dart';
import 'island_state.dart';

/// Sprite một đảo trên bản đồ biển. Dùng ảnh AI sinh
/// (assets/images/islands/{id}.webp), chưa có ảnh thì vẽ bằng code.
class IslandSprite extends StatelessWidget {
  const IslandSprite({
    super.key,
    required this.islandId,
    required this.colorValue,
    required this.state,
    required this.size,
  });

  final String islandId;
  final int colorValue;
  final IslandDisplayState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = state == IslandDisplayState.mystery
        ? 'assets/images/islands/mystery.webp'
        : 'assets/images/islands/$islandId.webp';
    return GameImage(
      assetPath: asset,
      width: size,
      height: size,
      fallback: CustomPaint(
        size: Size(size, size),
        painter: _IslandPainter(
          accent: Color(colorValue),
          mystery: state == IslandDisplayState.mystery,
          completed: state == IslandDisplayState.completed,
        ),
      ),
    );
  }
}

class _IslandPainter extends CustomPainter {
  _IslandPainter({
    required this.accent,
    required this.mystery,
    required this.completed,
  });

  final Color accent;
  final bool mystery;
  final bool completed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Color c(Color color) => mystery
        ? Color.lerp(color, GameColors.mystery, 0.75)!.withOpacity(0.85)
        : color;

    // Vòng nước quanh đảo.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.68), width: w * 0.98, height: h * 0.34),
      Paint()..color = c(GameColors.seaLight).withOpacity(0.55),
    );
    // Bãi cát.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.62), width: w * 0.86, height: h * 0.4),
      Paint()..color = c(GameColors.sand),
    );
    // Thảm cỏ.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.46, h * 0.52), width: w * 0.62, height: h * 0.34),
      Paint()..color = c(GameColors.grass),
    );
    // Đồi nhỏ màu chủ đạo của đảo.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.62, h * 0.5), width: w * 0.34, height: h * 0.22),
      Paint()..color = c(accent).withOpacity(0.8),
    );

    // Cây dừa: thân cong + tán lá.
    final trunk = Paint()
      ..color = c(const Color(0xFF8D6E63))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    final trunkPath = Path()
      ..moveTo(w * 0.36, h * 0.56)
      ..quadraticBezierTo(w * 0.34, h * 0.38, w * 0.42, h * 0.26);
    canvas.drawPath(trunkPath, trunk);
    final leaf = Paint()
      ..color = c(const Color(0xFF558B2F))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    final top = Offset(w * 0.42, h * 0.26);
    for (final a in [-2.6, -1.9, -1.2, -0.5, 0.1]) {
      final end = Offset(
          top.dx + cos(a) * w * 0.2, top.dy + sin(a) * w * 0.12 + h * 0.03);
      final p = Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
            top.dx + cos(a) * w * 0.12, top.dy + sin(a) * w * 0.1 - h * 0.04,
            end.dx, end.dy);
      canvas.drawPath(p, leaf);
    }

    // Cờ khi đã hoàn thành.
    if (completed && !mystery) {
      final pole = Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(w * 0.68, h * 0.48), Offset(w * 0.68, h * 0.2), pole);
      final flag = Path()
        ..moveTo(w * 0.68, h * 0.2)
        ..lineTo(w * 0.86, h * 0.26)
        ..lineTo(w * 0.68, h * 0.32)
        ..close();
      canvas.drawPath(flag, Paint()..color = GameColors.accent);
    }
  }

  @override
  bool shouldRepaint(_IslandPainter old) =>
      old.accent != accent || old.mystery != mystery || old.completed != completed;
}
