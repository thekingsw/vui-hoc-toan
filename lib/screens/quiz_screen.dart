import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/scoring.dart';
import '../widgets/mascot.dart';
import '../widgets/question_view.dart';
import 'result_screen.dart';

/// Thử thách cấp đảo (boss/Quiz):
/// rút phân tầng 4 mức 1 + 6 mức 2 từ kho boss 20 câu.
/// Đồng hồ đếm giờ nhẹ — hết giờ không thua.
/// Sao: ≥9 = 3, ≥8 = 2, ≥6 = 1. Lưu sao tốt nhất theo đảo.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.island, required this.meta});

  final IslandData island;
  final IslandMeta meta;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<Question>? _questions;
  int _index = 0;
  final Map<int, bool> _results = {};
  bool _settled = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _questions = selectQuizQuestions(widget.island.bossQuestions);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeText {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final questions = _questions!;
    final db = ref.read(databaseProvider);
    int correct = 0;
    final wrongQuestions = <Question>[];
    for (var i = 0; i < questions.length; i++) {
      final ok = _results[i] ?? false;
      if (ok) {
        correct++;
      } else {
        wrongQuestions.add(questions[i]);
      }
      await db.logAnswer(questions[i].id, ok, 'quiz');
    }
    final stars = starsFor(correct, total: questions.length);
    await db.saveBestStars(widget.island.islandId, stars);
    if (stars >= 1) {
      // Mở đảo kế tiếp.
      final ids = islandOrderIds;
      final idx = ids.indexOf(widget.island.islandId);
      if (idx >= 0 && idx + 1 < ids.length) {
        await db.unlockNextIsland(
            widget.island.islandId, ids[idx + 1]);
      }
    }
    ref.read(progressRefreshProvider.notifier).state++;
    ref.read(mascotMoodProvider.notifier).state =
        stars >= 2 ? MascotMood.excited : MascotMood.happy;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Thử thách: ${widget.meta.title}',
          correct: correct,
          total: questions.length,
          wrongQuestions: wrongQuestions,
          stars: stars,
          subtitle: stars >= 1
              ? 'Chúc mừng! Bé đã mở khóa đảo tiếp theo! 🎉'
              : 'Chưa đủ 6 câu đúng để mở đảo sau — thử lại nhé, cố lên!',
          elapsedText: _timeText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions!;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thử thách đảo')),
        body: const Center(child: Text('Đảo này chưa có câu Thử thách.')),
      );
    }
    final q = questions[_index];
    final isLast = _index == questions.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Thử thách ${_index + 1}/${questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('⏱ $_timeText',
                  style: const TextStyle(fontSize: 17)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / questions.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final mood = ref.watch(mascotMoodProvider);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: MascotWidget(mood: mood, size: 64),
                );
              },
            ),
            const SizedBox(height: 8),
            QuestionView(
              key: ValueKey(q.id),
              question: q,
              allowRetry: false,
              onAnswered: (correct, input) {
                setState(() => _results[_index] = correct);
                final sound = ref.read(soundServiceProvider);
                if (correct) {
                  sound.playCorrect();
                  ref.read(mascotMoodProvider.notifier).state =
                      MascotMood.happy;
                } else {
                  sound.playWrong();
                  ref.read(mascotMoodProvider.notifier).state =
                      MascotMood.sad;
                }
              },
              onSettled: () => setState(() => _settled = true),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _settled
                    ? () {
                        if (isLast) {
                          _finish();
                        } else {
                          setState(() {
                            _index++;
                            _settled = false;
                          });
                        }
                      }
                    : null,
                child: Text(
                  isLast ? 'Xem kết quả' : 'Câu tiếp theo',
                  style: const TextStyle(fontSize: 19),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
