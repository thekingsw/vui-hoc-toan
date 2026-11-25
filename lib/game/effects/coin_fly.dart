import 'package:flutter/material.dart';
import '../../theme/game_theme.dart';
import '../game_image.dart';

/// Đồng xu vàng (ảnh đợt 3 hoặc vẽ bằng code).
class CoinWidget extends StatelessWidget {
  const CoinWidget({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return GameImage(
      assetPath: 'assets/images/ui/icon_coin.webp',
      width: size,
      height: size,
      fallback: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFCA28),
          shape: BoxShape.circle,
          border: Border.all(color: GameColors.accent, width: 2),
        ),
        child: Icon(Icons.star, size: size * 0.6, color: GameColors.accent),
      ),
    );
  }
}

/// Xu bay từ giữa màn hình lên góc trên phải (SPEC mục 6) — hiện khi
/// câu đúng lần đầu được nhận xu. Đặt với [key] mới mỗi lần bay.
class CoinFly extends StatefulWidget {
  const CoinFly({super.key, this.enabled = true});

  final bool enabled;

  @override
  State<CoinFly> createState() => _CoinFlyState();
}

class _CoinFlyState extends State<CoinFly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return LayoutBuilder(
            builder: (context, constraints) {
              final startX = constraints.maxWidth * 0.5;
              final startY = constraints.maxHeight * 0.55;
              final endX = constraints.maxWidth - 30;
              const endY = 14.0;
              final x = startX + (endX - startX) * t;
              final y = startY + (endY - startY) * t;
              return Stack(
                children: [
                  Positioned(
                    left: x - 11,
                    top: y - 11,
                    child: Opacity(
                      opacity: (1 - t * t).clamp(0.0, 1.0),
                      child: const CoinWidget(size: 22),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
