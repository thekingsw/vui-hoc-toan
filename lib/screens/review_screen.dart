import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/question_play_area.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/review_logic.dart';
import 'result_screen.dart';

/// Màn Ôn lại (Đợt A — Học thông minh): rút các câu trong Hộp ôn
/// đã đến hạn theo lịch Leitner (1/3/7/14/30 ngày), tối đa 10 câu.
/// Không cho thử lại — đo đúng mức nhớ; đúng lên hộp, sai về hộp 1.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<Question>? _questions;
  int _index = 0;
  final Map<int, bool> _results = {};
  bool _settled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final db = ref.read(databaseProvider);
    final entries = await db.reviewEntries();
    final due = pickDueReview(
        entries, DateTime.now().millisecondsSinceEpoch);
    final islands = await ref.read(islandsProvider.future);
    final byId = <String, Question>{
      for (final island in islands.values)
        for (final q in island.questions) q.id: q,
    };
    setState(() {
      _questions = [
        for (final e in due)
          if (byId.containsKey(e.questionId)) byId[e.questionId]!,
      ];
      _loading = false;
    });
  }

  Future<void> _finish() async {
    final questions = _questions!;
    final db = ref.read(databaseProvider);
    var correct = 0;
    final wrongQuestions = <Question>[];
    for (var i = 0; i < questions.length; i++) {
      final ok = _results[i] ?? false;
      if (ok) {
        correct++;
      } else {
        wrongQuestions.add(questions[i]);
      }
      await db.logAnswer(questions[i].id, ok, 'review');
    }
    ref.read(progressRefreshProvider.notifier).state++;
    ref.read(mascotMoodProvider.notifier).state =
        correct >= questions.length * 0.6
            ? MascotMood.happy
            : MascotMood.neutral;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Ôn lại',
          correct: correct,
          total: questions.length,
          wrongQuestions: wrongQuestions,
          stars: null,
          subtitle: wrongQuestions.isEmpty
              ? 'Tuyệt vời! Các câu này đã nhớ chắc hơn rồi. 🎉'
              : 'Câu chưa nhớ sẽ được ôn lại vào ngày mai nhé!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _questions == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ôn lại')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final questions = _questions!;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ôn lại')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Hôm nay không có câu nào cần ôn. Giỏi lắm! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }
    final q = questions[_index];
    final isLast = _index == questions.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Ôn lại ${_index + 1}/${questions.length}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestionPlayArea(
              question: q,
              totalQuestions: questions.length,
              allowRetry: false,
              reduceEffects: ref.watch(reduceEffectsProvider),
              onCombo: (_) => ref.read(soundServiceProvider).playCombo(),
              onTapAnswer: () => ref.read(soundServiceProvider).playTap(),
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
