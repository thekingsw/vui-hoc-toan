import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/question_play_area.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/scoring.dart';
import 'result_screen.dart';

/// Màn Thi thử (Đợt B): rút 20 câu trộn từ mọi đảo đã có dữ liệu
/// (10 mức 1 + 10 mức 2), không cho thử lại, chấm thang 10.
/// Câu sai tự vào Hộp ôn lại qua logAnswer như các chế độ khác.
class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
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
    final islands = await ref.read(islandsProvider.future);
    final pool = <Question>[
      for (final island in islands.values) ...island.questions,
    ];
    setState(() {
      _questions =
          selectQuizQuestions(pool, easyCount: 10, mediumCount: 10);
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
      await db.logAnswer(questions[i].id, ok, 'exam');
    }
    ref.read(progressRefreshProvider.notifier).state++;
    final score = examScore(correct, questions.length);
    ref.read(mascotMoodProvider.notifier).state =
        score >= 5 ? MascotMood.happy : MascotMood.neutral;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Thi thử',
          correct: correct,
          total: questions.length,
          wrongQuestions: wrongQuestions,
          stars: null,
          subtitle:
              'Điểm của bé: ${score.toString().replaceAll('.', ',')} / 10'
              '${wrongQuestions.isEmpty ? ' — Xuất sắc! 🎉' : '. Câu sai đã được đưa vào hộp ôn lại nhé!'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _questions == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thi thử')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final questions = _questions!;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thi thử')),
        body: const Center(
          child: Text('Chưa có câu hỏi nào để thi thử.'),
        ),
      );
    }
    final q = questions[_index];
    final isLast = _index == questions.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Thi thử ${_index + 1}/${questions.length}'),
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
                  isLast ? 'Nộp bài' : 'Câu tiếp theo',
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
