import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../game/question_play_area.dart';
import '../game/shop/rewards.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/scoring.dart';
import 'result_screen.dart';

/// Luyện tập theo bài học: 10 câu từ kho 20 câu của bài
/// (ưu tiên câu từng sai, rồi câu chưa làm).
/// Sai: hiện gợi ý -> thử lại 1 lần -> hiện lời giải.
/// Xong 1 lượt: bài học được tính là hoàn thành.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({
    super.key,
    required this.island,
    required this.lesson,
    required this.meta,
  });

  final IslandData island;
  final Lesson lesson;
  final IslandMeta meta;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  List<Question>? _questions;
  int _index = 0;
  final Map<int, bool> _results = {};
  bool _settled = false;
  bool _loading = true;
  int _coinsEarned = 0;
  int _coinFlyKey = 0;

  /// Nhận xu câu đúng lần đầu (mỗi câu chỉ 1 lần — reward_log chống lặp).
  Future<void> _claimFirstCorrect(Question q) async {
    final db = ref.read(databaseProvider);
    final claimed =
        await db.claimReward(questionRewardKey(q.id), coinFirstCorrect);
    if (claimed && mounted) {
      setState(() {
        _coinsEarned += coinFirstCorrect;
        _coinFlyKey++;
      });
      ref.read(progressRefreshProvider.notifier).state++;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final db = ref.read(databaseProvider);
    final answered = await db.answeredQuestionIds();
    final wrong = await db.wrongQuestionIds();
    final pool = widget.island.questionsForLesson(widget.lesson.lessonId);
    setState(() {
      _questions = selectPracticeQuestions(pool, answered, wrong);
      _loading = false;
    });
  }

  Future<void> _finish() async {
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
      await db.logAnswer(questions[i].id, ok, 'practice');
    }
    await db.markPracticeDone(
        widget.island.islandId, widget.lesson.lessonId);
    // Xu xong 1 lượt Luyện tập (khóa theo số lượt đã nhận).
    final runIndex =
        await db.countRewards('practice:${widget.lesson.lessonId}:');
    final practiceClaimed = await db.claimReward(
      practiceRewardKey(widget.lesson.lessonId, runIndex),
      coinPracticeDone,
    );
    if (practiceClaimed) _coinsEarned += coinPracticeDone;
    ref.read(progressRefreshProvider.notifier).state++;
    ref.read(mascotMoodProvider.notifier).state =
        correct >= questions.length * 0.6
            ? MascotMood.happy
            : MascotMood.neutral;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Luyện tập: ${widget.lesson.title}',
          correct: correct,
          total: questions.length,
          wrongQuestions: wrongQuestions,
          stars: null,
          subtitle: 'Bài học đã được tính là hoàn thành! 🎉',
          island: widget.island,
          lesson: widget.lesson,
          meta: widget.meta,
          coinsEarned: _coinsEarned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _questions == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.lesson.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final questions = _questions!;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.lesson.title)),
        body: const Center(
          child: Text('Bài này chưa có câu hỏi.'),
        ),
      );
    }
    final q = questions[_index];
    final isLast = _index == questions.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Luyện tập ${_index + 1}/${questions.length}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestionPlayArea(
              question: q,
              totalQuestions: questions.length,
              allowRetry: true,
              reduceEffects: ref.watch(reduceEffectsProvider),
              coins: ref.watch(coinsProvider).maybeWhen(
                    data: (c) => c,
                    orElse: () => 0,
                  ),
              coinFlyKey: _coinFlyKey,
              onAnswered: (correct, input) {
                setState(() => _results[_index] = correct);
                final sound = ref.read(soundServiceProvider);
                if (correct) {
                  sound.playCorrect();
                  ref.read(mascotMoodProvider.notifier).state =
                      MascotMood.happy;
                  _claimFirstCorrect(q);
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
