import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/scoring.dart';
import '../widgets/mascot.dart';
import '../widgets/star_row.dart';
import 'lesson_screen.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';

/// Màn đảo: 3 trạm Học / Luyện tập / Thử thách.
/// - Học / Luyện tập: theo từng bài học.
/// - Thử thách (boss/Quiz cấp đảo): mở khi xong hết bài học của đảo.
class IslandScreen extends ConsumerWidget {
  const IslandScreen({super.key, required this.meta, required this.data});

  final IslandMeta meta;
  final IslandData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(meta.colorValue);
    final progressAsync = ref.watch(islandProgressProvider);
    final doneAsync = ref.watch(doneLessonsProvider(data.islandId));
    final mood = ref.watch(mascotMoodProvider);
    final lessons = data.lessonsOnly;
    final boss = data.bossLesson;

    return Scaffold(
      appBar: AppBar(title: Text(meta.title)),
      body: doneAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (done) {
          final bossUnlocked = isBossUnlocked(done, data);
          final stars = progressAsync.maybeWhen(
            data: (p) => p[data.islandId]?.bestStars ?? 0,
            orElse: () => 0,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  MascotWidget(mood: mood, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meta.subtitle,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        StarRow(stars: stars, size: 24),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle('📖 Học', color),
              ...lessons.map((lesson) {
                final isDone = done.contains(lesson.lessonId);
                return _LessonTile(
                  lesson: lesson,
                  color: color,
                  trailing: isDone
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LessonScreen(
                          island: data,
                          lesson: lesson,
                          meta: meta,
                        ),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
              _sectionTitle('✏️ Luyện tập', color),
              ...lessons.map((lesson) {
                final isDone = done.contains(lesson.lessonId);
                return _LessonTile(
                  lesson: lesson,
                  color: color,
                  trailing: isDone
                      ? const Text('Đã xong',
                          style: TextStyle(color: Colors.green))
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PracticeScreen(
                          island: data,
                          lesson: lesson,
                          meta: meta,
                        ),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
              _sectionTitle('🏆 Thử thách đảo', color),
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Opacity(
                  opacity: bossUnlocked ? 1.0 : 0.55,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Text(
                        '★',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      boss?.title ?? 'Thử thách đảo',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      bossUnlocked
                          ? '10 câu hỏi — đạt 6 câu trở lên để mở đảo sau!'
                          : 'Hoàn thành ${done.length}/${lessons.length} bài học để mở',
                    ),
                    trailing: bossUnlocked
                        ? const Icon(Icons.chevron_right)
                        : const Icon(Icons.lock, color: Colors.grey),
                    onTap: bossUnlocked && boss != null
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => QuizScreen(
                                  island: data,
                                  meta: meta,
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  final Lesson lesson;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(lesson.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
