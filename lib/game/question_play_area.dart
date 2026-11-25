import 'package:flutter/material.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../theme/game_theme.dart';
import '../widgets/question_view.dart';
import '../widgets/speech_bubble.dart';
import 'effects/boat_progress.dart';
import 'effects/coin_fly.dart';
import 'effects/combo_badge.dart';
import 'effects/confetti_burst.dart';
import 'effects/shake_widget.dart';

/// Khu vực chơi 1 câu hỏi với đầy đủ hiệu ứng (SPEC giao diện mục 6):
/// đường thuyền, combo, pháo giấy, rung khi sai, khung thoại linh vật.
/// Dùng chung cho Luyện tập và Thử thách; màn cha lo chọn câu + kết thúc.
class QuestionPlayArea extends StatefulWidget {
  const QuestionPlayArea({
    super.key,
    required this.question,
    required this.totalQuestions,
    required this.allowRetry,
    required this.reduceEffects,
    required this.onAnswered,
    required this.onSettled,
    this.coins = 0,
    this.coinFlyKey = 0,
  });

  final Question question;
  final int totalQuestions;
  final bool allowRetry;
  final bool reduceEffects;
  final void Function(bool correct, String userInput) onAnswered;
  final VoidCallback onSettled;

  /// Số xu hiện có (hiện ở góc) và khóa kích hoạt hiệu ứng xu bay.
  final int coins;
  final int coinFlyKey;

  @override
  State<QuestionPlayArea> createState() => _QuestionPlayAreaState();
}

class _QuestionPlayAreaState extends State<QuestionPlayArea> {
  static const _praises = ['Giỏi quá!', 'Đúng rồi, giỏi quá! 🎉', 'Tuyệt vời!'];

  int _boatDone = 0;
  int _combo = 0;
  int _shakeKey = 0;
  int _confettiKey = 0;
  int _praiseIndex = 0;
  int _wrongCount = 0;
  bool _settled = false;
  bool _lastCorrect = false;
  String _bubble = 'Cố lên nào!';
  MascotMood _mood = MascotMood.neutral;

  @override
  void didUpdateWidget(QuestionPlayArea old) {
    super.didUpdateWidget(old);
    if (old.question.id != widget.question.id) {
      _wrongCount = 0;
      _settled = false;
      _lastCorrect = false;
      _bubble = 'Cố lên nào!';
      _mood = MascotMood.neutral;
    }
  }

  void _handleAnswered(bool correct, String input) {
    final q = widget.question;
    setState(() {
      if (correct) {
        _combo++;
        _boatDone++;
        _confettiKey++;
        _settled = true;
        _lastCorrect = true;
        _bubble = _praises[_praiseIndex++ % _praises.length];
        _mood = MascotMood.happy;
      } else {
        _combo = 0;
        _shakeKey++;
        _mood = MascotMood.sad;
        if (widget.allowRetry && _wrongCount == 0) {
          _bubble =
              'Gần đúng rồi! Gợi ý: ${q.hint ?? 'Đọc kĩ đề rồi tính lại nào.'}';
        } else {
          _settled = true;
          _lastCorrect = false;
          _bubble = 'Mình cùng xem nhé…';
        }
        _wrongCount++;
      }
    });
    widget.onAnswered(correct, input);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: BoatProgress(
                      total: widget.totalQuestions, done: _boatDone),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GameColors.accent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CoinWidget(size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.coins}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ComboBadge(combo: _combo),
            SpeechBubble(mood: _mood, text: _bubble),
            const SizedBox(height: 12),
            ShakeWidget(
              shakeKey: _shakeKey,
              enabled: !widget.reduceEffects,
              child: QuestionView(
                key: ValueKey(q.id),
                question: q,
                allowRetry: widget.allowRetry,
                hideFeedback: true,
                onAnswered: _handleAnswered,
                onSettled: widget.onSettled,
              ),
            ),
            if (_settled && !_lastCorrect) ...[
              const SizedBox(height: 12),
              _infoBox(
                'Đáp án đúng là: ${q.answerText ?? ''}${q.unit != null ? ' ${q.unit}' : ''}. Đừng buồn, mình học từ câu này nhé!',
                GameColors.wrongSoft,
              ),
            ],
            if (_settled && q.explanation != null) ...[
              const SizedBox(height: 12),
              _infoBox('Lời giải: ${q.explanation}', Colors.blueGrey),
            ],
          ],
        ),
        if (_confettiKey > 0)
          Positioned.fill(
            child: ConfettiBurst(
              key: ValueKey(_confettiKey),
              enabled: !widget.reduceEffects,
            ),
          ),
        if (widget.coinFlyKey > 0)
          Positioned.fill(
            child: CoinFly(
              key: ValueKey(widget.coinFlyKey),
              enabled: !widget.reduceEffects,
            ),
          ),
      ],
    );
  }

  Widget _infoBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }
}
