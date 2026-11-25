import 'package:flutter/material.dart';
import '../chest_widget.dart';

/// Nghi thức mở rương ở màn kết quả Thử thách (SPEC giao diện mục 7):
/// rương rơi xuống (400 ms) → mở nắp → sao bật ra lần lượt (300 ms/viên).
/// 0 sao: rương chỉ hé, không có sao.
class ChestCeremony extends StatefulWidget {
  const ChestCeremony({
    super.key,
    required this.stars,
    this.reduceEffects = false,
  });

  final int stars;
  final bool reduceEffects;

  @override
  State<ChestCeremony> createState() => _ChestCeremonyState();
}

class _ChestCeremonyState extends State<ChestCeremony>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.reduceEffects) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _segment(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final drop = Curves.bounceOut.transform(_segment(t, 0, 0.22));
        final maxOpen = widget.stars == 0 ? 0.35 : 1.0;
        final open = _segment(t, 0.22, 0.45) * maxOpen;
        return Column(
          children: [
            Transform.translate(
              offset: Offset(0, -90 * (1 - drop)),
              child: ChestWidget(size: 150, openAmount: open),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  _star(i, _segment(t, 0.45 + i * 0.17, 0.62 + i * 0.17)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _star(int index, double t) {
    final earned = index < widget.stars;
    final scale = earned ? Curves.elasticOut.transform(t) : 1.0;
    return Transform.scale(
      scale: scale,
      child: Icon(
        earned ? Icons.star : Icons.star_border,
        size: 48,
        color: earned ? const Color(0xFFFFCA28) : Colors.grey.shade400,
      ),
    );
  }
}
