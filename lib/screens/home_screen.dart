import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../game/map/boat_widget.dart';
import '../game/map/island_sprite.dart';
import '../game/map/island_state.dart';
import '../game/map/map_layout.dart';
import '../game/effects/coin_fly.dart';
import '../game/shop/shop_screen.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/database_service.dart';
import '../services/review_logic.dart';
import '../services/scoring.dart';
import '../theme/game_theme.dart';
import '../widgets/speech_bubble.dart';
import '../widgets/star_row.dart';
import 'island_screen.dart';
import 'exam_screen.dart';
import 'parent_screen.dart';
import 'review_screen.dart';

/// Home: bản đồ biển cuộn dọc (SPEC giao diện mục 3).
/// Đảo 1 ở dưới cùng, hành trình đi từ dưới lên; thuyền đậu cạnh đảo
/// hiện tại và chạy sang đảo mới khi vừa mở khóa.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  MapLayoutData? _layout;
  final _scroll = ScrollController();
  late final AnimationController _bounce;
  late final AnimationController _sail;
  bool _scrolledToCurrent = false;
  String? _speech;
  Timer? _speechTimer;
  String? _sailingTo;
  String? _shakeIslandId;
  int _shakeCount = 0;
  Timer? _parentHoldTimer;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _sail = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    loadMapLayout().then((layout) {
      if (mounted) setState(() => _layout = layout);
    });
    // Sóng biển nền ở bản đồ (SPEC mục 13).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(soundServiceProvider).startWaves();
    });
  }

  @override
  void dispose() {
    ref.read(soundServiceProvider).stopWaves();
    _bounce.dispose();
    _sail.dispose();
    _scroll.dispose();
    _speechTimer?.cancel();
    _parentHoldTimer?.cancel();
    super.dispose();
  }

  void _say(String text) {
    setState(() => _speech = text);
    _speechTimer?.cancel();
    _speechTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _speech = null);
    });
  }

  void _startSail(String targetId) {
    if (_sailingTo != null) return;
    setState(() => _sailingTo = targetId);
    _sail.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      ref.read(pendingSailProvider.notifier).state = null;
      setState(() => _sailingTo = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final islandsAsync = ref.watch(islandsProvider);
    final progressAsync = ref.watch(islandProgressProvider);
    final reduceEffects = ref.watch(reduceEffectsProvider);
    ref.listen<String?>(dataUpdateNoticeProvider, (prev, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next)),
      );
      ref.read(dataUpdateNoticeProvider.notifier).state = null;
    });
    ref.listen<String?>(pendingSailProvider, (prev, next) {
      if (next != null && _layout != null) _startSail(next);
    });

    return Scaffold(
      body: islandsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Lỗi dữ liệu:\n$e',
                style: const TextStyle(color: Colors.red)),
          ),
        ),
        data: (islands) => progressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Lỗi tiến độ: $e')),
          data: (progress) {
            if (_layout == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildMap(context, islands, progress, reduceEffects);
          },
        ),
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    Map<String, IslandData> islands,
    Map<String, IslandProgress> progress,
    bool reduceEffects,
  ) {
    final layout = _layout!;
    final order = islandOrderIds;
    final bestStars = <String, int>{
      for (final id in order) id: progress[id]?.bestStars ?? 0,
    };
    final parentUnlocked = <String>{
      for (final id in order)
        if (progress[id]?.unlockedByParent ?? false) id,
    };
    final states = <String, IslandDisplayState>{
      for (var i = 0; i < order.length; i++)
        order[i]: islandDisplayState(
          hasData: islands.containsKey(order[i]),
          unlocked:
              isIslandUnlocked(i, bestStars, parentUnlocked, order),
          bestStars: bestStars[order[i]] ?? 0,
        ),
    };
    final currentId = currentIslandId(order, states);
    final totalStars = bestStars.values.fold(0, (a, b) => a + b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final perIsland = layout.canvasHeightPerIsland;
        final maxY = layout.islands.map((s) => s.y).reduce(max);
        final totalHeight = perIsland * (maxY + 1) + 160;

        Offset centerOf(MapIslandSpot spot) {
          final yFromBottom = spot.y * perIsland + perIsland * 0.55 + 60;
          return Offset(spot.x * width, totalHeight - yFromBottom);
        }

        final centers = <String, Offset>{
          for (final spot in layout.islands) spot.id: centerOf(spot),
        };

        // Tự cuộn tới đảo hiện tại khi mở app.
        if (!_scrolledToCurrent) {
          _scrolledToCurrent = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scroll.hasClients) return;
            final cy = centers[currentId]?.dy ?? totalHeight;
            final target = (cy - constraints.maxHeight * 0.55)
                .clamp(0.0, _scroll.position.maxScrollExtent);
            _scroll.jumpTo(target);
          });
        }

        return Stack(
          children: [
            SingleChildScrollView(
              controller: _scroll,
              child: SizedBox(
                height: totalHeight,
                width: width,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size(width, totalHeight),
                        painter: _SeaPainter(
                          centers: [
                            for (final id in order)
                              if (centers.containsKey(id)) centers[id]!,
                          ],
                          dashOn: layout.dashOn,
                          dashOff: layout.dashOff,
                          pathWidth: layout.pathWidth,
                        ),
                      ),
                    ),
                    for (final meta in islandCatalog)
                      if (layout.spotFor(meta.id) != null)
                        _islandWidget(
                          context,
                          meta: meta,
                          spot: layout.spotFor(meta.id)!,
                          center: centers[meta.id]!,
                          state: states[meta.id]!,
                          stars: bestStars[meta.id] ?? 0,
                          data: islands[meta.id],
                          width: width,
                          reduceEffects: reduceEffects,
                        ),
                    AnimatedBuilder(
                      animation: _sail,
                      builder: (context, _) {
                        Offset pos;
                        if (_sailingTo != null &&
                            centers.containsKey(_sailingTo)) {
                          final idx = order.indexOf(_sailingTo!);
                          final from = idx > 0
                              ? centers[order[idx - 1]]!
                              : centers[currentId]!;
                          pos = _pathPoint(
                              from, centers[_sailingTo]!, _sail.value);
                        } else {
                          final c = centers[currentId]!;
                          pos = Offset(c.dx + width * 0.16, c.dy + 30);
                        }
                        return Positioned(
                          left: pos.dx - 28,
                          top: pos.dy - 28,
                          child: IgnorePointer(
                            child: BoatWidget(
                              size: 56,
                              assetPath: _boatAsset(ref),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            _hud(context, totalStars),
            Positioned(
              left: 16,
              right: 16,
              top: 104,
              child: _TodayCard(
                currentIslandId: currentId,
                islands: islands,
              ),
            ),
            if (_speech != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: SpeechBubble(
                  mood: MascotMood.neutral,
                  text: _speech!,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Điểm trên đường cong chữ S giữa hai đảo tại tỉ lệ [t].
  Offset _pathPoint(Offset a, Offset b, double t) {
    final midY = (a.dy + b.dy) / 2;
    final c1 = Offset(a.dx, midY);
    final c2 = Offset(b.dx, midY);
    final u = 1 - t;
    return Offset(
      u * u * u * a.dx +
          3 * u * u * t * c1.dx +
          3 * u * t * t * c2.dx +
          t * t * t * b.dx,
      u * u * u * a.dy +
          3 * u * u * t * c1.dy +
          3 * u * t * t * c2.dy +
          t * t * t * b.dy,
    );
  }

  Widget _islandWidget(
    BuildContext context, {
    required IslandMeta meta,
    required MapIslandSpot spot,
    required Offset center,
    required IslandDisplayState state,
    required int stars,
    required IslandData? data,
    required double width,
    required bool reduceEffects,
  }) {
    final spriteSize = (width * 0.4 * spot.scale).clamp(110.0, 190.0);
    final isSailTarget = _sailingTo == meta.id;
    Widget sprite = IslandSprite(
      islandId: meta.id,
      colorValue: meta.colorValue,
      state: state,
      size: spriteSize,
    );
    if (state == IslandDisplayState.current && !reduceEffects) {
      sprite = AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -4 * _bounce.value),
          child: child,
        ),
        child: sprite,
      );
    }

    final showFog = state == IslandDisplayState.locked || isSailTarget;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            sprite,
            if (showFog)
              AnimatedBuilder(
                animation: _sail,
                builder: (context, _) {
                  final opacity = isSailTarget
                      ? (1 - _sail.value).clamp(0.0, 1.0)
                      : 1.0;
                  return Opacity(
                    opacity: opacity,
                    child: Container(
                      width: spriteSize * 0.95,
                      height: spriteSize * 0.62,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            GameColors.fog.withOpacity(0.95),
                            GameColors.fog.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (state == IslandDisplayState.locked)
              const Icon(Icons.lock, color: Color(0xFF78909C), size: 30),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            state == IslandDisplayState.mystery
                ? '${meta.title} · Sắp có'
                : meta.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: GameColors.ink,
            ),
          ),
        ),
        if (state == IslandDisplayState.completed)
          StarRow(stars: stars, size: 18),
      ],
    );

    Widget tappable = GestureDetector(
      onTap: () {
        switch (state) {
          case IslandDisplayState.current:
          case IslandDisplayState.completed:
            if (data != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IslandScreen(meta: meta, data: data),
                ),
              );
            }
          case IslandDisplayState.locked:
            setState(() {
              _shakeIslandId = meta.id;
              _shakeCount++;
            });
            _say('Hoàn thành đảo trước để mở nhé!');
          case IslandDisplayState.mystery:
            _say('Đảo này sắp mở rồi!');
        }
      },
      child: content,
    );

    if (_shakeIslandId == meta.id) {
      tappable = _IslandShake(key: ValueKey(_shakeCount), child: tappable);
    }

    return Positioned(
      left: center.dx - spriteSize / 2,
      top: center.dy - spriteSize / 2,
      width: spriteSize,
      child: tappable,
    );
  }

  /// Ảnh thuyền theo món đang dùng trong cửa hàng.
  String _boatAsset(WidgetRef ref) {
    final equipped = ref.watch(equippedItemsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const <String>{},
        );
    if (equipped.contains('boat_gold')) {
      return 'assets/images/items/boat_gold.webp';
    }
    if (equipped.contains('boat_star')) {
      return 'assets/images/items/boat_star.webp';
    }
    return 'assets/images/items/boat_wood.webp';
  }

  Widget _hud(BuildContext context, int totalStars) {
    final soundOn = ref.watch(soundOnProvider);
    final coins = ref.watch(coinsProvider).maybeWhen(
          data: (c) => c,
          orElse: () => 0,
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFCA28), size: 22),
                  const SizedBox(width: 4),
                  Text(
                    '$totalStars',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: GameColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinWidget(size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '$coins',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: GameColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _hudButton(
              icon: Icons.assignment_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExamScreen()),
                );
              },
            ),
            const SizedBox(width: 8),
            _hudButton(
              icon: Icons.storefront,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
            ),
            const SizedBox(width: 8),
            _hudButton(
              icon: soundOn ? Icons.volume_up : Icons.volume_off,
              onTap: () async {
                final db = ref.read(databaseProvider);
                final next = !soundOn;
                ref.read(soundOnProvider.notifier).state = next;
                ref.read(soundServiceProvider).enabled = next;
                if (next) ref.read(soundServiceProvider).startWaves();
                await db.setSoundOn(next);
              },
            ),
            const SizedBox(width: 8),
            // Nút phụ huynh: giữ 2 giây mới mở (SPEC mục 3).
            GestureDetector(
              onTapDown: (_) {
                _parentHoldTimer?.cancel();
                _parentHoldTimer = Timer(const Duration(seconds: 2), () {
                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ParentScreen()),
                    );
                  }
                });
              },
              onTapUp: (_) {
                final wasHolding = _parentHoldTimer?.isActive ?? false;
                _parentHoldTimer?.cancel();
                if (wasHolding) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Giữ nút 2 giây để mở Góc phụ huynh'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              onTapCancel: () => _parentHoldTimer?.cancel(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.family_restroom,
                    color: GameColors.ink, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: GameColors.ink, size: 24),
        ),
      ),
    );
  }
}

/// Rung nhẹ một lần khi chạm đảo khóa.
/// Thẻ "Hôm nay học gì" (Đợt A): ưu tiên câu ôn đến hạn → bài chưa học
/// tiếp theo của đảo hiện tại → gợi ý kỹ năng yếu nhất.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.currentIslandId, required this.islands});

  final String currentIslandId;
  final Map<String, IslandData> islands;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueReviewCountProvider).maybeWhen(
          data: (c) => c,
          orElse: () => 0,
        );
    final data = islands[currentIslandId];
    final done = ref.watch(doneLessonsProvider(currentIslandId)).maybeWhen(
          data: (s) => s,
          orElse: () => const <String>{},
        );
    final weak = weakestSkill(ref.watch(skillStatsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const <SkillStat>[],
        ));

    String title;
    String subtitle;
    VoidCallback? onTap;
    if (due > 0) {
      title = 'Hôm nay ôn lại $due câu nhé!';
      subtitle = 'Các câu này đến hạn ôn rồi.';
      onTap = () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReviewScreen()),
          );
    } else if (data != null) {
      Lesson? nextLesson;
      for (final l in data.lessonsOnly) {
        if (!done.contains(l.lessonId)) {
          nextLesson = l;
          break;
        }
      }
      if (nextLesson != null) {
        title = 'Hôm nay học: ${nextLesson.title}';
        subtitle = 'Bài tiếp theo trên đảo ${data.title}.';
        onTap = () {
          final meta =
              islandCatalog.firstWhere((m) => m.id == currentIslandId);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IslandScreen(meta: meta, data: data),
            ),
          );
        };
      } else {
        title = 'Đảo này học xong rồi!';
        subtitle = 'Thử thách để mở đảo mới nhé.';
        onTap = () {
          final meta =
              islandCatalog.firstWhere((m) => m.id == currentIslandId);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IslandScreen(meta: meta, data: data),
            ),
          );
        };
      }
    } else {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF3D6), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GameColors.accent, width: 3),
            boxShadow: [
              BoxShadow(
                color: GameColors.seaDeep.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: GameColors.seaDeep,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Baloo2',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: GameColors.ink,
                        ),
                      ),
                      Text(
                        weak != null && due == 0
                            ? '$subtitle Cần luyện thêm: ${weak.skill}.'
                            : subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: GameColors.ink.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: GameColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward,
                      size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IslandShake extends StatefulWidget {
  const _IslandShake({super.key, required this.child});

  final Widget child;

  @override
  State<_IslandShake> createState() => _IslandShakeState();
}

class _IslandShakeState extends State<_IslandShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
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
        return Transform.translate(
          offset: Offset(sin(t * pi * 4) * 6 * (1 - t), 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Nền biển: gradient + họa tiết sóng + đường thuyền nét đứt.
class _SeaPainter extends CustomPainter {
  _SeaPainter({
    required this.centers,
    required this.dashOn,
    required this.dashOff,
    required this.pathWidth,
  });

  final List<Offset> centers;
  final double dashOn;
  final double dashOff;
  final double pathWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameColors.seaDeep, GameColors.seaLight],
        ).createShader(rect),
    );

    // Họa tiết sóng lặp.
    final wave = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const stepX = 64.0;
    const stepY = 56.0;
    var row = 0;
    for (var y = 20.0; y < size.height; y += stepY, row++) {
      for (var x = (row.isEven ? 10.0 : 42.0); x < size.width; x += stepX) {
        canvas.drawArc(
          Rect.fromLTWH(x, y, 26, 12),
          pi,
          pi,
          false,
          wave,
        );
      }
    }

    // Đường thuyền nét đứt nối các đảo theo thứ tự.
    if (centers.length < 2) return;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1];
      final b = centers[i];
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = pathWidth
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final end = min(dist + dashOn, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), dashPaint);
        dist += dashOn + dashOff;
      }
    }
  }

  @override
  bool shouldRepaint(_SeaPainter old) => old.centers != centers;
}
