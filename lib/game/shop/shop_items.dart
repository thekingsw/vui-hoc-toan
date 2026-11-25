import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Một món trong cửa hàng (assets/config/shop_items.json — SPEC mục 8, 9).
/// [slot]: hat | eyes | neck | body | pet | boat | flag — mỗi nhóm chỉ
/// mặc được một món một lúc. [anchor] là vị trí đặt lên linh vật
/// (tọa độ chuẩn hóa theo khung linh vật).
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.price,
    required this.asset,
    required this.anchorX,
    required this.anchorY,
    required this.anchorScale,
  });

  final String id;
  final String name;
  final String slot;
  final int price;
  final String asset;
  final double anchorX;
  final double anchorY;
  final double anchorScale;

  /// Món mặc lên linh vật (thuyền + cờ hiển thị ở bản đồ).
  bool get isMascotItem =>
      slot == 'hat' || slot == 'eyes' || slot == 'neck' || slot == 'body' || slot == 'pet';
}

List<ShopItem> parseShopItems(Map<String, dynamic> json) {
  final items = <ShopItem>[];
  final rawItems = json['items'];
  if (rawItems is List) {
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final anchor = raw['anchor'];
      items.add(ShopItem(
        id: '${raw['id'] ?? ''}',
        name: '${raw['name'] ?? ''}',
        slot: '${raw['slot'] ?? ''}',
        price: (raw['price'] as num?)?.toInt() ?? 0,
        asset: '${raw['asset'] ?? ''}',
        anchorX: anchor is Map ? (anchor['x'] as num?)?.toDouble() ?? 0.5 : 0.5,
        anchorY: anchor is Map ? (anchor['y'] as num?)?.toDouble() ?? 0.5 : 0.5,
        anchorScale:
            anchor is Map ? (anchor['scale'] as num?)?.toDouble() ?? 0.5 : 0.5,
      ));
    }
  }
  return items;
}

Future<List<ShopItem>> loadShopItems() async {
  final text = await rootBundle.loadString('assets/config/shop_items.json');
  return parseShopItems(jsonDecode(text) as Map<String, dynamic>);
}

/// Các món cùng nhóm với [item] (để tháo khi mặc món khác cùng nhóm).
List<String> slotItemIds(List<ShopItem> items, ShopItem item) =>
    items.where((i) => i.slot == item.slot).map((i) => i.id).toList();
