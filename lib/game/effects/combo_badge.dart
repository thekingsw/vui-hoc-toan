import 'package:flutter/material.dart';

/// Huy hiệu Combo ×N (SPEC mục 6): hiện từ 3 câu đúng liên tiếp,
/// chỉ là hiệu ứng, không thêm xu.
class ComboBadge extends StatelessWidget {
  const ComboBadge({super.key, required this.combo});

  final int combo;

  @override
  Widget build(BuildContext context) {
    if (combo < 3) return const SizedBox(height: 36);
    return SizedBox(
      height: 36,
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(combo),
          tween: Tween(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFF8F00), width: 2),
            ),
            child: Text(
              'Combo ×$combo 🔥',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
