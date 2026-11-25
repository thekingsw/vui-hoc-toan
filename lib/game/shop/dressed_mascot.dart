import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../widgets/mascot.dart';
import '../game_image.dart';
import 'shop_items.dart';

/// Linh vật mặc đồ đã mua (SPEC giao diện mục 8): món đang mặc hiển thị
/// ở mọi màn hình có linh vật. Đợt 3 có ảnh thì dùng ảnh món đồ, chưa có
/// thì vẽ hình đơn giản bằng code theo nhóm.
class DressedMascot extends ConsumerWidget {
  const DressedMascot({super.key, required this.mood, this.size = 96});

  final MascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipped = ref.watch(equippedItemsProvider).maybeWhen(
          data: (ids) => ids,
          orElse: () => const <String>{},
        );
    final items = ref.watch(shopItemsProvider).maybeWhen(
          data: (list) => list
              .where((i) => i.isMascotItem && equipped.contains(i.id))
              .toList(),
          orElse: () => const <ShopItem>[],
        );
    return MascotWithItems(mood: mood, size: size, items: items);
  }
}

/// Linh vật + danh sách món mặc lên (dùng cho xem trước trong cửa hàng).
class MascotWithItems extends StatelessWidget {
  const MascotWithItems({
    super.key,
    required this.mood,
    required this.size,
    required this.items,
  });

  final MascotMood mood;
  final double size;
  final List<ShopItem> items;

  @override
  Widget build(BuildContext context) {
    final behind = items.where((i) => i.slot == 'body');
    final front = items.where((i) => i.slot != 'body');
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in behind) _placed(item),
          MascotWidget(mood: mood, size: size),
          for (final item in front) _placed(item),
        ],
      ),
    );
  }

  Widget _placed(ShopItem item) {
    final w = size * item.anchorScale;
    return Positioned(
      left: size * item.anchorX - w / 2,
      top: size * item.anchorY,
      child: GameImage(
        assetPath: item.asset,
        width: w,
        height: w,
        fallback: _ItemFallback(slot: item.slot, size: w),
      ),
    );
  }
}

/// Hình dự phòng đơn giản theo nhóm đồ khi chưa có ảnh.
class _ItemFallback extends StatelessWidget {
  const _ItemFallback({required this.slot, required this.size});

  final String slot;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (slot) {
      case 'hat':
        return Container(
          width: size,
          height: size * 0.45,
          decoration: const BoxDecoration(
            color: Color(0xFF1A237E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
        );
      case 'eyes':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _lens(),
            Container(width: size * 0.1, height: 3, color: Colors.black87),
            _lens(),
          ],
        );
      case 'neck':
        return Container(
          width: size,
          height: size * 0.3,
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(size * 0.15),
          ),
        );
      case 'body':
        return Container(
          width: size,
          height: size * 0.9,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: BorderRadius.circular(size * 0.2),
          ),
        );
      case 'pet':
        return Container(
          width: size * 0.7,
          height: size * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF43A047),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.flutter_dash,
              color: Colors.white, size: size * 0.4),
        );
      default:
        return SizedBox(width: size, height: size);
    }
  }

  Widget _lens() => Container(
        width: size * 0.32,
        height: size * 0.32,
        decoration: const BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
        ),
      );
}
