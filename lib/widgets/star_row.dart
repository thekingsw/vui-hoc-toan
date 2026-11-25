import 'package:flutter/material.dart';

/// Hàng 3 ngôi sao: sao đạt được màu vàng, sao chưa đạt màu xám.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 28});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final earned = i < stars;
        return Icon(
          earned ? Icons.star : Icons.star_border,
          color: earned ? Colors.amber : Colors.grey,
          size: size,
        );
      }),
    );
  }
}
