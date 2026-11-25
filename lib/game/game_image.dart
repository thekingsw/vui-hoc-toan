import 'package:flutter/material.dart';

/// Ảnh game với hình vẽ bằng code dự phòng (SPEC giao diện mục 11):
/// nếu file ảnh chưa có (đợt 3 mới tạo) thì hiện [fallback] để app
/// không vỡ. Khi ảnh đã có, tự dùng ảnh.
class GameImage extends StatelessWidget {
  const GameImage({
    super.key,
    required this.assetPath,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String assetPath;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: fallback,
      ),
    );
  }
}
