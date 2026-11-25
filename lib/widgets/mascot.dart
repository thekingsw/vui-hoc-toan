import 'package:flutter/material.dart';
import '../providers/app_providers.dart';

/// Linh vật cáo vẽ bằng Flutter widget (không cần ảnh ngoài).
/// Đổi biểu cảm theo [mood]: vui / buồn / hào hứng / bình thường.

class MascotWidget extends StatelessWidget {
  const MascotWidget({super.key, required this.mood, this.size = 96});

  final MascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FoxPainter(mood)),
    );
  }
}

class _FoxPainter extends CustomPainter {
  _FoxPainter(this.mood);

  final MascotMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final cy = w / 2;
    final orange = Paint()..color = const Color(0xFFF57C00);
    final cream = Paint()..color = const Color(0xFFFFF3E0);
    final dark = Paint()
      ..color = const Color(0xFF4E342E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;

    // Tai.
    final ear = Path()
      ..moveTo(cx - w * 0.34, cy - w * 0.18)
      ..lineTo(cx - w * 0.42, cy - w * 0.48)
      ..lineTo(cx - w * 0.12, cy - w * 0.32)
      ..close();
    canvas.drawPath(ear, orange);
    final ear2 = Path()
      ..moveTo(cx + w * 0.34, cy - w * 0.18)
      ..lineTo(cx + w * 0.42, cy - w * 0.48)
      ..lineTo(cx + w * 0.12, cy - w * 0.32)
      ..close();
    canvas.drawPath(ear2, orange);

    // Mặt.
    canvas.drawCircle(Offset(cx, cy), w * 0.36, orange);
    // Má trắng.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + w * 0.16),
        width: w * 0.42,
        height: w * 0.3,
      ),
      cream,
    );

    // Mắt.
    final eyeY = cy - w * 0.06;
    if (mood == MascotMood.happy || mood == MascotMood.excited) {
      // Mắt cười: 2 cung cong.
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx - w * 0.15, eyeY), width: w * 0.14, height: w * 0.14),
        3.1416,
        3.1416,
        false,
        dark,
      );
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx + w * 0.15, eyeY), width: w * 0.14, height: w * 0.14),
        3.1416,
        3.1416,
        false,
        dark,
      );
    } else if (mood == MascotMood.sad) {
      // Mắt buồn: 2 chấm + lông mày xiên.
      final dot = Paint()..color = const Color(0xFF4E342E);
      canvas.drawCircle(Offset(cx - w * 0.15, eyeY), w * 0.035, dot);
      canvas.drawCircle(Offset(cx + w * 0.15, eyeY), w * 0.035, dot);
      canvas.drawLine(
        Offset(cx - w * 0.22, eyeY - w * 0.1),
        Offset(cx - w * 0.08, eyeY - w * 0.06),
        dark,
      );
      canvas.drawLine(
        Offset(cx + w * 0.22, eyeY - w * 0.1),
        Offset(cx + w * 0.08, eyeY - w * 0.06),
        dark,
      );
    } else {
      final dot = Paint()..color = const Color(0xFF4E342E);
      canvas.drawCircle(Offset(cx - w * 0.15, eyeY), w * 0.04, dot);
      canvas.drawCircle(Offset(cx + w * 0.15, eyeY), w * 0.04, dot);
    }

    // Mũi.
    final nose = Paint()..color = const Color(0xFF4E342E);
    canvas.drawCircle(Offset(cx, cy + w * 0.1), w * 0.045, nose);

    // Miệng theo cảm xúc.
    final mouthY = cy + w * 0.18;
    switch (mood) {
      case MascotMood.happy:
      case MascotMood.excited:
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(cx, mouthY - w * 0.05),
              width: w * 0.26,
              height: w * 0.2),
          0.15 * 3.1416,
          0.7 * 3.1416,
          false,
          dark,
        );
        break;
      case MascotMood.sad:
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(cx, mouthY + w * 0.08),
              width: w * 0.22,
              height: w * 0.16),
          1.15 * 3.1416,
          0.7 * 3.1416,
          false,
          dark,
        );
        break;
      case MascotMood.neutral:
        canvas.drawLine(
          Offset(cx - w * 0.08, mouthY),
          Offset(cx + w * 0.08, mouthY),
          dark,
        );
        break;
    }

    // Má hồng khi hào hứng.
    if (mood == MascotMood.excited) {
      final blush = Paint()..color = const Color(0xFFFF8A80);
      canvas.drawCircle(Offset(cx - w * 0.24, cy + w * 0.1), w * 0.05, blush);
      canvas.drawCircle(Offset(cx + w * 0.24, cy + w * 0.1), w * 0.05, blush);
    }
  }

  @override
  bool shouldRepaint(covariant _FoxPainter oldDelegate) =>
      oldDelegate.mood != mood;
}
