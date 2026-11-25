import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../game/effects/coin_fly.dart';
import '../game/result/chest_ceremony.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../widgets/mascot.dart';
import 'lesson_screen.dart';
import 'practice_screen.dart';

/// Màn kết quả (SPEC giao diện mục 7):
/// - Thử thách: nghi thức mở rương + sao, câu sai thành "bản đồ cần ôn"
///   kèm nút luyện lại đúng bài.
/// - Luyện tập: màn ngắn, nút "Luyện tiếp" và "Về đảo".
class ResultScreen extends ConsumerWidget {
  const ResultScreen({
    super.key,
    required this.title,
    required this.correct,
    required this.total,
    required this.wrongQuestions,
    this.stars,
    this.subtitle,
    this.elapsedText,
    this.island,
    this.lesson,
    this.meta,
    this.firstCompletion = false,
    this.coinsEarned = 0,
  });

  final String title;
  final int correct;
  final int total;
  final List<Question> wrongQuestions;

  /// null = lượt Luyện tập (không chấm sao).
  final int? stars;
  final String? subtitle;
  final String? elapsedText;

  /// Dữ liệu để nút "Luyện lại bài này" / "Luyện tiếp" dẫn đúng bài.
  final IslandData? island;
  final Lesson? lesson;
  final IslandMeta? meta;

  /// Lần đầu đạt ≥1 sao ở Thử thách (mở đảo mới).
  final bool firstCompletion;

  /// Số xu nhận được trong lượt này.
  final int coinsEarned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isQuiz = stars != null;
    final reduceEffects = ref.watch(reduceEffectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isQuiz)
            ChestCeremony(
              stars: stars!,
              reduceEffects: reduceEffects,
              onChestOpen: () => ref.read(soundServiceProvider).playChest(),
              onStar: (_) => ref.read(soundServiceProvider).playStar(),
            )
          else
            Center(
              child: MascotWidget(
                mood: correct >= total * 0.6
                    ? MascotMood.excited
                    : MascotMood.neutral,
                size: 110,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Đúng $correct/$total câu',
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (elapsedText != null)
            Text(
              'Thời gian: $elapsedText',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          if (coinsEarned > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CoinWidget(size: 24),
                const SizedBox(width: 6),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: coinsEarned),
                  duration: reduceEffects
                      ? Duration.zero
                      : const Duration(milliseconds: 900),
                  builder: (context, value, _) => Text(
                    '+$value xu',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
          ],
          if (isQuiz && stars == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Rương mới hé thôi — luyện thêm một chút rồi mở tiếp nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
          const SizedBox(height: 20),
          if (wrongQuestions.isNotEmpty) ...[
            const Text(
              '🗺️ Bản đồ cần ôn:',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...wrongQuestions.map((q) => _wrongCard(context, q)),
          ] else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tuyệt vời, không sai câu nào! 🌟',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (!isQuiz && island != null && lesson != null && meta != null) ...[
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => PracticeScreen(
                        island: island!,
                        lesson: lesson!,
                        meta: meta!,
                      ),
                    ),
                  );
                },
                child: const Text('Luyện tiếp',
                    style: TextStyle(fontSize: 19)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Về đảo', style: TextStyle(fontSize: 19)),
              ),
            ),
          ] else
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  firstCompletion ? 'Ra khơi!' : 'Về bản đồ đảo',
                  style: const TextStyle(fontSize: 19),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _wrongCard(BuildContext context, Question q) {
    Lesson? targetLesson;
    if (island != null && meta != null) {
      for (final l in island!.lessonsOnly) {
        if (l.lessonId == q.lessonId) targetLesson = l;
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.prompt, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Đáp án: ${q.answerText ?? ''}${q.unit != null ? ' ${q.unit}' : ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            if (q.explanation != null)
              Text('Lời giải: ${q.explanation}',
                  style: const TextStyle(fontSize: 15)),
            if (targetLesson != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.replay),
                  label: const Text('Luyện lại bài này'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LessonScreen(
                          island: island!,
                          lesson: targetLesson!,
                          meta: meta!,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
