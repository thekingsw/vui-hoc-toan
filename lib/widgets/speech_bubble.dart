import 'package:flutter/material.dart';
import '../game/shop/dressed_mascot.dart';
import '../providers/app_providers.dart';
import '../theme/game_theme.dart';
import 'fraction_view.dart';

/// Linh vật kèm khung thoại (SPEC giao diện mục 5–6): lời dẫn, gợi ý và
/// lời giải hiện trong khung thoại của cáo.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.mood,
    required this.text,
    this.mascotSize = 64,
  });

  final MascotMood mood;
  final String text;
  final double mascotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DressedMascot(mood: mood, size: mascotSize),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GameColors.accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: RichMathText(text, fontSize: 17, color: GameColors.ink),
          ),
        ),
      ],
    );
  }
}
