import 'package:flutter/material.dart';
import 'game_image.dart';

/// Rương kho báu vẽ bằng code (đợt 3 có ảnh thì dùng ảnh).
/// [openAmount]: 0 = đóng, 1 = mở hẳn. [locked]: quấn xích + ổ khóa.
class ChestWidget extends StatelessWidget {
  const ChestWidget({
    super.key,
    this.size = 96,
    this.openAmount = 0,
    this.locked = false,
  });

  final double size;
  final double openAmount;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final asset = openAmount > 0.6
        ? 'assets/images/ui/chest_open.webp'
        : openAmount > 0.15
            ? 'assets/images/ui/chest_half.webp'
            : 'assets/images/ui/chest_closed.webp';
    return Stack(
      alignment: Alignment.center,
      children: [
        GameImage(
          assetPath: asset,
          width: size,
          height: size,
          fallback: CustomPaint(
            size: Size(size, size),
            painter: _ChestPainter(openAmount.clamp(0.0, 1.0)),
          ),
        ),
        if (locked)
          Icon(Icons.lock, size: size * 0.34, color: const Color(0xFF78909C)),
      ],
    );
  }
}

class _ChestPainter extends CustomPainter {
  _ChestPainter(this.open);

  final double open;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wood = Paint()..color = const Color(0xFF8D6E63);
    final woodDark = Paint()..color = const Color(0xFF6D4C41);
    final gold = Paint()..color = const Color(0xFFFFCA28);

    final bodyRect = Rect.fromLTWH(w * 0.1, h * 0.48, w * 0.8, h * 0.4);
    // Thân rương.
    canvas.drawRRect(
      RRect.fromRectAndCorners(bodyRect,
          bottomLeft: Radius.circular(w * 0.06),
          bottomRight: Radius.circular(w * 0.06)),
      wood,
    );
    // Ánh sáng vàng khi mở.
    if (open > 0) {
      final glow = Paint()
        ..color = const Color(0xFFFFECB3).withOpacity(0.9 * open);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.48), width: w * 0.7, height: h * 0.16),
        glow,
      );
    }
    // Nắp rương: xoay quanh mép sau theo mức mở.
    canvas.save();
    canvas.translate(w * 0.1, h * 0.48);
    canvas.rotate(-open * 1.9);
    final lidRect = Rect.fromLTWH(0, -h * 0.26, w * 0.8, h * 0.26);
    canvas.drawRRect(
      RRect.fromRectAndCorners(lidRect,
          topLeft: Radius.circular(w * 0.16),
          topRight: Radius.circular(w * 0.16)),
      woodDark,
    );
    canvas.restore();
    // Đai vàng + ổ khóa.
    canvas.drawRect(Rect.fromLTWH(w * 0.46, h * 0.48, w * 0.08, h * 0.4), gold);
    canvas.drawCircle(Offset(w * 0.5, h * 0.56), w * 0.07, gold);
    canvas.drawCircle(Offset(w * 0.5, h * 0.56), w * 0.03, woodDark);
  }

  @override
  bool shouldRepaint(_ChestPainter old) => old.open != open;
}
