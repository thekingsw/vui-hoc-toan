import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../game/chest_widget.dart';
import '../game/game_image.dart';
import '../game/shop/dressed_mascot.dart';
import '../game/scene/node_state.dart';
import '../game/scene/scene_config.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/scoring.dart';
import '../theme/game_theme.dart';
import '../widgets/speech_bubble.dart';
import '../widgets/star_row.dart';
import 'lesson_screen.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';

/// Cảnh đảo (SPEC giao diện mục 4): tranh nền + đường đi nối các điểm
/// dừng (mỗi bài một điểm), kết thúc ở rương Thử thách. Linh vật đứng ở
/// điểm hiện tại và đi bộ sang điểm bé chọn trước khi mở bảng Học/Luyện.
class IslandScreen extends ConsumerStatefulWidget {
  const IslandScreen({super.key, required this.meta, required this.data});

  final IslandMeta meta;
  final IslandData data;

  @override
  ConsumerState<IslandScreen> createState() => _IslandScreenState();
}

class _IslandScreenState extends ConsumerState<IslandScreen>
    with TickerProviderStateMixin {
  IslandSceneConfig? _config;
  bool _configLoaded = false;
  String? _mascotAtLessonId;
  String? _speech;
  Timer? _speechTimer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    loadSceneConfig(widget.data.islandId).then((cfg) {
      if (mounted) {
        setState(() {
          _config = cfg;
          _configLoaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _speechTimer?.cancel();
    super.dispose();
  }

  void _say(String text) {
    setState(() => _speech = text);
    _speechTimer?.cancel();
    _speechTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _speech = null);
    });
  }

  /// Vị trí điểm dừng: từ file cấu hình; thiếu thì tự xếp zig-zag.
  SceneNodeSpot _spotFor(Lesson lesson, int index, int count) {
    final fromConfig = _config?.nodeFor(lesson.lessonId);
    if (fromConfig != null) return fromConfig;
    final t = count <= 1 ? 0.5 : index / (count - 1);
    return SceneNodeSpot(
      lessonId: lesson.lessonId,
      x: index.isEven ? 0.32 : 0.66,
      y: 0.9 - t * 0.68,
      icon: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final doneAsync = ref.watch(doneLessonsProvider(widget.data.islandId));
    final viewedAsync =
        ref.watch(viewedLessonsProvider(widget.data.islandId));
    final progressAsync = ref.watch(islandProgressProvider);
    final reduceEffects = ref.watch(reduceEffectsProvider);
    final lessons = widget.data.lessonsOnly;
    final boss = widget.data.bossLesson;
    final stars = progressAsync.maybeWhen(
      data: (p) => p[widget.data.islandId]?.bestStars ?? 0,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meta.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: StarRow(stars: stars, size: 20)),
          ),
        ],
      ),
      body: !_configLoaded
          ? const Center(child: CircularProgressIndicator())
          : doneAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (done) => viewedAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
                data: (viewed) => _buildScene(
                  context,
                  lessons: lessons,
                  boss: boss,
                  done: done,
                  viewed: viewed,
                  reduceEffects: reduceEffects,
                ),
              ),
            ),
    );
  }

  Widget _buildScene(
    BuildContext context, {
    required List<Lesson> lessons,
    required Lesson? boss,
    required Set<String> done,
    required Set<String> viewed,
    required bool reduceEffects,
  }) {
    final bossUnlocked = isBossUnlocked(done, widget.data);
    final remaining = lessons.where((l) => !done.contains(l.lessonId)).length;
    final lessonIds = lessons.map((l) => l.lessonId).toList();
    final suggested = suggestedLessonIndex(lessonIds, done);
    final heightRatio = _config?.heightRatio ?? 1.7;
    final bossX = _config?.bossX ?? 0.5;
    final bossY = _config?.bossY ?? 0.06;

    // Linh vật đứng ở điểm gợi ý (hoặc điểm bé vừa chạm).
    final mascotLessonId = _mascotAtLessonId ??
        (suggested >= 0 ? lessonIds[suggested] : lessonIds.lastOrNull);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sceneHeight = width * heightRatio;
        final spots = <String, SceneNodeSpot>{
          for (var i = 0; i < lessons.length; i++)
            lessons[i].lessonId: _spotFor(lessons[i], i, lessons.length),
        };
        Offset pointOf(SceneNodeSpot s) =>
            Offset(s.x * width, s.y * sceneHeight);
        final bossPoint = Offset(bossX * width, bossY * sceneHeight);
        final mascotSpot =
            mascotLessonId != null ? spots[mascotLessonId] : null;
        final mascotPoint = mascotSpot != null
            ? pointOf(mascotSpot) + const Offset(34, 6)
            : bossPoint + const Offset(40, 10);

        return Stack(
          children: [
            SingleChildScrollView(
              child: SizedBox(
                width: width,
                height: sceneHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GameImage(
                        assetPath: _config?.background ?? '',
                        fit: BoxFit.cover,
                        fallback: CustomPaint(
                          painter: _SceneBackgroundPainter(
                            color: Color(widget.meta.colorValue),
                            points: [
                              for (final l in lessons)
                                pointOf(spots[l.lessonId]!),
                              bossPoint,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Rương Thử thách.
                    Positioned(
                      left: bossPoint.dx - 48,
                      top: bossPoint.dy - 48,
                      child: GestureDetector(
                        onTap: () {
                          if (bossUnlocked && boss != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => QuizScreen(
                                  island: widget.data,
                                  meta: widget.meta,
                                ),
                              ),
                            );
                          } else {
                            _say('Còn $remaining bài nữa là mở được rương!');
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChestWidget(
                                size: 96, locked: !bossUnlocked),
                            _namePlate(
                                boss?.title ?? 'Thử thách đảo'),
                          ],
                        ),
                      ),
                    ),
                    // Các điểm dừng.
                    for (var i = 0; i < lessons.length; i++)
                      _nodeWidget(
                        context,
                        lesson: lessons[i],
                        index: i,
                        point: pointOf(spots[lessons[i].lessonId]!),
                        spot: spots[lessons[i].lessonId]!,
                        state: nodeDisplayState(
                          lessonId: lessons[i].lessonId,
                          index: i,
                          doneIds: done,
                          viewedIds: viewed,
                          suggestedIndex: suggested,
                        ),
                        reduceEffects: reduceEffects,
                      ),
                    // Linh vật đi bộ tới điểm được chọn.
                    AnimatedPositioned(
                      duration: reduceEffects
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      left: mascotPoint.dx - 28,
                      top: mascotPoint.dy - 28,
                      child: const DressedMascot(
                          mood: MascotMood.neutral, size: 56),
                    ),
                  ],
                ),
              ),
            ),
            // Nút về bản đồ.
            Positioned(
              left: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'scene-back',
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back),
              ),
            ),
            if (_speech != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: SpeechBubble(
                    mood: MascotMood.neutral, text: _speech!),
              ),
          ],
        );
      },
    );
  }

  Widget _namePlate(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: GameColors.ink,
        ),
      ),
    );
  }

  Widget _nodeWidget(
    BuildContext context, {
    required Lesson lesson,
    required int index,
    required Offset point,
    required SceneNodeSpot spot,
    required NodeDisplayState state,
    required bool reduceEffects,
  }) {
    const nodeSize = 72.0;
    Widget badge = GameImage(
      assetPath: spot.icon.isEmpty
          ? ''
          : 'assets/images/nodes/${spot.icon}.webp',
      width: nodeSize,
      height: nodeSize,
      fallback: _NodeBadge(number: index + 1, state: state),
    );
    if (state == NodeDisplayState.suggested && !reduceEffects) {
      badge = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: GameColors.accent
                    .withOpacity(0.35 + 0.3 * _pulse.value),
                blurRadius: 10 + 8 * _pulse.value,
                spreadRadius: 2 + 3 * _pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: badge,
      );
    }

    return Positioned(
      left: point.dx - nodeSize / 2,
      top: point.dy - nodeSize / 2,
      child: GestureDetector(
        onTap: () async {
          setState(() => _mascotAtLessonId = lesson.lessonId);
          if (!reduceEffects) {
            await Future<void>.delayed(
                const Duration(milliseconds: 600));
          }
          if (!context.mounted) return;
          _showLessonSheet(context, lesson);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state == NodeDisplayState.suggested)
              const Icon(Icons.arrow_downward,
                  color: GameColors.accent, size: 22),
            badge,
            _namePlate('Bài ${index + 1}'),
          ],
        ),
      ),
    );
  }

  void _showLessonSheet(BuildContext context, Lesson lesson) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lesson.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                icon: const Text('📖', style: TextStyle(fontSize: 22)),
                label: const Text('Học bài',
                    style: TextStyle(fontSize: 19)),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(
                        island: widget.data,
                        lesson: lesson,
                        meta: widget.meta,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: FilledButton.icon(
                icon: const Text('🎯', style: TextStyle(fontSize: 22)),
                label: const Text('Luyện tập',
                    style: TextStyle(fontSize: 19)),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PracticeScreen(
                        island: widget.data,
                        lesson: lesson,
                        meta: widget.meta,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Huy hiệu điểm dừng vẽ bằng code (khi chưa có ảnh): vòng tròn số bài
/// + biểu tượng trạng thái.
class _NodeBadge extends StatelessWidget {
  const _NodeBadge({required this.number, required this.state});

  final int number;
  final NodeDisplayState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      NodeDisplayState.done => GameColors.correct,
      NodeDisplayState.suggested => GameColors.accent,
      NodeDisplayState.viewed => GameColors.seaDeep,
      NodeDisplayState.todo => const Color(0xFF8D6E63),
    };
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (state == NodeDisplayState.done)
          const Positioned(
            right: 0,
            top: 0,
            child: Icon(Icons.check_circle,
                color: GameColors.correct, size: 24),
          ),
        if (state == NodeDisplayState.viewed)
          const Positioned(
            right: 0,
            top: 0,
            child: Icon(Icons.menu_book,
                color: GameColors.seaDeep, size: 22),
          ),
      ],
    );
  }
}

/// Nền cảnh đảo vẽ bằng code: gradient cát/cỏ + đường đi uốn lượn
/// qua các điểm dừng tới rương.
class _SceneBackgroundPainter extends CustomPainter {
  _SceneBackgroundPainter({required this.color, required this.points});

  final Color color;
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.55)!,
            GameColors.sand,
            Color.lerp(GameColors.grass, Colors.white, 0.35)!,
          ],
        ).createShader(rect),
    );

    // Vài bụi cỏ trang trí hai bên.
    final bush = Paint()..color = GameColors.grass.withOpacity(0.55);
    final rng = Random(7);
    for (var i = 0; i < 14; i++) {
      final x = (i.isEven ? 0.06 : 0.9) * size.width +
          rng.nextDouble() * size.width * 0.05;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 14 + rng.nextDouble() * 16, bush);
    }

    // Đường đi qua các điểm dừng.
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
      path.quadraticBezierTo(b.dx, b.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFECB3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SceneBackgroundPainter old) =>
      old.color != color || old.points != points;
}
