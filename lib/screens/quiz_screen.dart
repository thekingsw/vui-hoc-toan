import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../game/question_play_area.dart';
import '../game/shop/rewards.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../services/scoring.dart';
import 'result_screen.dart';

/// Thử thách cấp đảo (boss/Quiz):
/// rút phân tầng 4 mức 1 + 6 mức 2 từ kho boss 20 câu.
/// Đồng hồ cát nhỏ — hết giờ không thua (SPEC giao diện mục 6).
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
    // Lần đầu đạt ≥1 sao: mở đảo mới + thuyền chạy khi về bản đồ.
    final progressBefore = await db.allIslandProgress();
    final prevBest =
        progressBefore[widget.island.islandId]?.bestStars ?? 0;
    final firstCompletion = prevBest == 0 && stars >= 1;
    await db.saveBestStars(widget.island.islandId, stars);
    // Xu theo mức sao (mỗi mức nhận 1 lần, trả phần chênh).
    for (final (key, amount) in bossStarClaims(widget.island.islandId, stars)) {
      if (await db.claimReward(key, amount)) _coinsEarned += amount;
    }
    if (firstCompletion) {
      await db.markIslandCompleted(widget.island.islandId);
    }
    if (stars >= 1) {
      // Mở đảo kế tiếp.
      final ids = islandOrderIds;
      final idx = ids.indexOf(widget.island.islandId);
      if (idx >= 0 && idx + 1 < ids.length) {
        await db.unlockNextIsland(
            widget.island.islandId, ids[idx + 1]);
        if (firstCompletion) {
          ref.read(pendingSailProvider.notifier).state = ids[idx + 1];
        }
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
          island: widget.island,
          meta: widget.meta,
          firstCompletion: firstCompletion,
          coinsEarned: _coinsEarned,
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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Icon(Icons.hourglass_bottom, size: 22),
            ),
          ),
        ],
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
