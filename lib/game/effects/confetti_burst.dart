import 'dart:math';

import 'package:flutter/material.dart';

/// Pháo giấy tự vẽ: bùng ≤ 30 hạt trong ~600 ms (SPEC giao diện mục 6).
/// Đặt widget này với [key] mới mỗi lần muốn bùng; [enabled] = false
/// (chế độ giảm hiệu ứng) thì không vẽ gì.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.enabled = true, this.particles = 24});

  final bool enabled;
  final int particles;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(widget.particles.clamp(0, 30), (_) {
      final angle = rng.nextDouble() * pi * 2;
      final speed = 0.35 + rng.nextDouble() * 0.65;
      return _Particle(
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 0.7,
        size: 4 + rng.nextDouble() * 5,
        color: _palette[rng.nextInt(_palette.length)],
        spin: rng.nextDouble() * pi * 2,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _palette = [
    Color(0xFFFF8F00),
    Color(0xFF43A047),
    Color(0xFF4FC3F7),
    Color(0xFFFFD54F),
    Color(0xFFF06292),
  ];

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_particles, _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.spin,
  });

  final double vx;
  final double vy;
  final double size;
  final Color color;
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final spread = min(size.width, size.height) * 0.45;
    for (final p in particles) {
      final x = center.dx + p.vx * spread * t;
      // Rơi xuống theo trọng lực.
      final y = center.dy + p.vy * spread * t + spread * 0.9 * t * t;
      final paint = Paint()
        ..color = p.color.withOpacity((1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin + t * 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
