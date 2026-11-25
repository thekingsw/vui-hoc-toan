import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/game_theme.dart';
import '../effects/coin_fly.dart';
import '../game_image.dart';
import 'dressed_mascot.dart';
import 'shop_items.dart';

/// Cửa hàng + Tủ đồ (SPEC giao diện mục 8): chạm món để xem trước trên
/// linh vật, đủ xu thì mua; mỗi nhóm chỉ mặc một món một lúc.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  ShopItem? _preview;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _buy(ShopItem item) async {
    final db = ref.read(databaseProvider);
    final ok = await db.buyItem(item.id, item.price);
    if (!mounted) return;
    if (ok) {
      ref.read(soundServiceProvider).playBuy();
      final items = ref.read(shopItemsProvider).valueOrNull ?? const [];
      await db.equipOnly(item.id, slotItemIds(items, item));
      ref.read(progressRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã mua ${item.name}! 🎉')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa đủ xu — luyện thêm để kiếm xu nhé!')),
      );
    }
  }

  Future<void> _toggleEquip(ShopItem item, bool equipped) async {
    final db = ref.read(databaseProvider);
    if (equipped) {
      await db.unequip(item.id);
    } else {
      final items = ref.read(shopItemsProvider).valueOrNull ?? const [];
      await db.equipOnly(item.id, slotItemIds(items, item));
    }
    ref.read(progressRefreshProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(shopItemsProvider);
    final coins = ref.watch(coinsProvider).maybeWhen(
          data: (c) => c,
          orElse: () => 0,
        );
    final owned = ref.watch(ownedItemsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const <String>{},
        );
    final equipped = ref.watch(equippedItemsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const <String>{},
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cửa hàng'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinWidget(size: 22),
                  const SizedBox(width: 4),
                  Text('$coins',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Cửa hàng'),
            Tab(text: 'Tủ đồ'),
          ],
        ),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (items) {
          final previewItems = _previewItems(items, equipped);
          return Column(
            children: [
              // Khu xem trước linh vật.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: GameColors.seaLight.withOpacity(0.18),
                child: Column(
                  children: [
                    MascotWithItems(
                      mood: MascotMood.happy,
                      size: 140,
                      items: previewItems,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _preview?.name ?? 'Chạm một món để xem trước',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _grid(items, owned, equipped, coins, wardrobe: false),
                    _grid(
                      items.where((i) => owned.contains(i.id)).toList(),
                      owned,
                      equipped,
                      coins,
                      wardrobe: true,
                    ),
                  ],
                ),
              ),
              if (_preview != null)
                _actionBar(_preview!, owned, equipped, coins),
            ],
          );
        },
      ),
    );
  }

  /// Đồ đang mặc, thay món cùng nhóm bằng món đang xem trước.
  List<ShopItem> _previewItems(List<ShopItem> items, Set<String> equipped) {
    final worn = items
        .where((i) => i.isMascotItem && equipped.contains(i.id))
        .toList();
    final preview = _preview;
    if (preview == null || !preview.isMascotItem) return worn;
    return [
      ...worn.where((i) => i.slot != preview.slot),
      preview,
    ];
  }

  Widget _grid(
    List<ShopItem> items,
    Set<String> owned,
    Set<String> equipped,
    int coins, {
    required bool wardrobe,
  }) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Tủ đồ còn trống — mua món đầu tiên nào!',
            style: TextStyle(fontSize: 16)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final isOwned = owned.contains(item.id);
        final isEquipped = equipped.contains(item.id);
        final selected = _preview?.id == item.id;
        return GestureDetector(
          onTap: () => setState(() => _preview = item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? GameColors.accent : Colors.grey.shade300,
                width: selected ? 3 : 1,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameImage(
                  assetPath: item.asset,
                  width: 52,
                  height: 52,
                  fallback: Icon(
                    _slotIcon(item.slot),
                    size: 44,
                    color: GameColors.seaDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                if (isEquipped)
                  const Text('Đang dùng',
                      style: TextStyle(
                          fontSize: 12,
                          color: GameColors.correct,
                          fontWeight: FontWeight.bold))
                else if (isOwned)
                  const Text('Đã có',
                      style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CoinWidget(size: 14),
                      const SizedBox(width: 3),
                      Text('${item.price}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: coins >= item.price
                                ? GameColors.ink
                                : Colors.grey,
                          )),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionBar(
    ShopItem item,
    Set<String> owned,
    Set<String> equipped,
    int coins,
  ) {
    final isOwned = owned.contains(item.id);
    final isEquipped = equipped.contains(item.id);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: isOwned
              ? FilledButton(
                  onPressed: () => _toggleEquip(item, isEquipped),
                  child: Text(
                    isEquipped ? 'Tháo ra' : 'Mặc vào',
                    style: const TextStyle(fontSize: 18),
                  ),
                )
              : FilledButton.icon(
                  onPressed: coins >= item.price ? () => _buy(item) : null,
                  icon: const CoinWidget(size: 20),
                  label: Text(
                    coins >= item.price
                        ? 'Mua — ${item.price} xu'
                        : 'Cần ${item.price} xu (đang có $coins)',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
        ),
      ),
    );
  }

  IconData _slotIcon(String slot) => switch (slot) {
        'hat' => Icons.sports_baseball,
        'eyes' => Icons.visibility,
        'neck' => Icons.checkroom,
        'body' => Icons.shield,
        'pet' => Icons.flutter_dash,
        'boat' => Icons.sailing,
        'flag' => Icons.flag,
        _ => Icons.star,
      };
}
