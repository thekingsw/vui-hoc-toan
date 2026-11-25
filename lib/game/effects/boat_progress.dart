import 'package:flutter/material.dart';
import '../../theme/game_theme.dart';

/// Đường đi của thuyền trên màn câu hỏi (SPEC mục 6): [total] điểm,
/// thuyền tiến 1 điểm mỗi câu đúng.
class BoatProgress extends StatelessWidget {
  const BoatProgress({super.key, required this.total, required this.done});

  final int total;

  /// Số điểm thuyền đã đi qua (0..total).
  final int done;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final step = total <= 1 ? width : width / (total - 1);
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 22,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: GameColors.seaLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              for (var i = 0; i < total; i++)
                Positioned(
                  left: (i * step - 5).clamp(0.0, width - 10),
                  top: 18,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < done
                          ? GameColors.correct
                          : Colors.white,
                      border: Border.all(color: GameColors.seaDeep, width: 2),
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                left: ((done.clamp(0, total - 1)) * step - 11)
                    .clamp(0.0, width - 22),
                top: 0,
                child: const Icon(
                  Icons.sailing,
                  size: 22,
                  color: GameColors.accent,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
