import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/scoring.dart';
import '../widgets/mascot.dart';
import '../widgets/star_row.dart';
import 'island_screen.dart';
import 'parent_screen.dart';

/// Home: bản đồ 12 đảo.
/// - Đảo chưa có dữ liệu: hiện "Sắp có", không vào được.
/// - Đảo khóa: mờ + ổ khóa.
/// - Hiện số sao mỗi đảo.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final islandsAsync = ref.watch(islandsProvider);
    final progressAsync = ref.watch(islandProgressProvider);
    final mood = ref.watch(mascotMoodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hành trình khám phá'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Bật/tắt âm thanh',
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final current = ref.read(soundOnProvider);
              final next = !current;
              ref.read(soundOnProvider.notifier).state = next;
              ref.read(soundServiceProvider).enabled = next;
              await db.setSoundOn(next);
            },
          ),
          IconButton(
            icon: const Icon(Icons.family_restroom),
            tooltip: 'Góc phụ huynh',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ParentScreen()),
              );
            },
          ),
        ],
      ),
      body: islandsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Lỗi dữ liệu:\n$e',
                style: const TextStyle(color: Colors.red)),
          ),
        ),
        data: (islands) {
          return progressAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tiến độ: $e')),
            data: (progress) {
              final bestStars = <String, int>{};
              final parentUnlocked = <String>{};
              final unlockedFlags = <String, bool>{};
              for (final entry in progress.entries) {
                bestStars[entry.key] = entry.value.bestStars;
                if (entry.value.unlockedByParent) {
                  parentUnlocked.add(entry.key);
                }
                unlockedFlags[entry.key] = entry.value.unlocked;
              }
              final ids = islandOrderIds;
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        MascotWidget(mood: mood, size: 72),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Chào bé! Hôm nay mình khám phá đảo nào?',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: islandCatalog.length,
                      itemBuilder: (context, index) {
                        final meta = islandCatalog[index];
                        final data = islands[meta.id];
                        final hasData = data != null;
                        final unlocked = hasData &&
                            ((unlockedFlags[meta.id] ?? false) ||
                                isIslandUnlocked(
                                    index, bestStars, parentUnlocked, ids));
                        final stars = bestStars[meta.id] ?? 0;
                        return _IslandCard(
                          meta: meta,
                          data: data,
                          unlocked: unlocked,
                          hasData: hasData,
                          stars: stars,
                          onTap: !unlocked || !hasData
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => IslandScreen(
                                          meta: meta, data: data),
                                    ),
                                  );
                                },
                        );
                      },
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

class _IslandCard extends StatelessWidget {
  const _IslandCard({
    required this.meta,
    required this.data,
    required this.unlocked,
    required this.hasData,
    required this.stars,
    required this.onTap,
  });

  final IslandMeta meta;
  final IslandData? data;
  final bool unlocked;
  final bool hasData;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(meta.colorValue);
    final card = Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Opacity(
        opacity: unlocked && hasData ? 1.0 : 0.55,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Text(
              '${meta.order}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            meta.title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta.subtitle),
              const SizedBox(height: 4),
              if (!hasData)
                const Text('Sắp có',
                    style: TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold))
              else if (!unlocked)
                const Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Đảo khóa — hoàn thành đảo trước để mở'),
                  ],
                )
              else
                StarRow(stars: stars, size: 22),
            ],
          ),
          trailing: (!unlocked || !hasData)
              ? const Icon(Icons.lock, color: Colors.grey)
              : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
    return card;
  }
}
