import 'dart:math';

import 'package:flutter/material.dart';

/// Rung ngang ~300 ms mỗi khi [shakeKey] thay đổi (sai lần 1 — SPEC mục 6).
/// [enabled] = false (giảm hiệu ứng) thì đứng yên.
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    super.key,
    required this.shakeKey,
    required this.child,
    this.enabled = true,
  });

  final int shakeKey;
  final Widget child;
  final bool enabled;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(ShakeWidget old) {
    super.didUpdateWidget(old);
    if (widget.enabled && widget.shakeKey != old.shakeKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = sin(t * pi * 4) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
