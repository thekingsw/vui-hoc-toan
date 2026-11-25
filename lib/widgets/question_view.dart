import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../services/scoring.dart';
import 'fraction_view.dart';

/// Trạng thái trả lời 1 câu trong Practice / Quiz.
enum AnswerState { unanswered, correct, wrongRetry, wrongFinal }

/// Widget hiển thị 1 câu hỏi theo loại (mcq / fill_number / true_false).
/// - Gọi [onAnswered] với (đúng?, đáp án bé nhập) khi chốt đáp án.
/// - Ở Practice, [allowRetry] = true: sai lần 1 hiện gợi ý và cho thử lại.
/// - [showExplanation] do màn hình cha điều khiển sau khi chốt lần cuối.
class QuestionView extends StatefulWidget {
  const QuestionView({
    super.key,
    required this.question,
    required this.onAnswered,
    this.allowRetry = false,
    this.onRetryUsed,
    this.onSettled,
  });

  final Question question;
  final void Function(bool correct, String userInput) onAnswered;
  final bool allowRetry;
  final VoidCallback? onRetryUsed;

  /// Gọi khi câu đã chốt xong (đúng, hoặc sai lần cuối).
  final VoidCallback? onSettled;

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  final _controller = TextEditingController();
  String? _selected;
  AnswerState _state = AnswerState.unanswered;
  bool _retryUsed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String input) {
    if (_state == AnswerState.correct ||
        _state == AnswerState.wrongFinal) {
      return;
    }
    final correct = checkAnswer(widget.question, input);
    setState(() {
      if (correct) {
        _state = AnswerState.correct;
      } else if (widget.allowRetry && !_retryUsed) {
        _state = AnswerState.wrongRetry;
        _retryUsed = true;
        widget.onRetryUsed?.call();
      } else {
        _state = AnswerState.wrongFinal;
      }
    });
    widget.onAnswered(correct, input);
    if (_state == AnswerState.correct || _state == AnswerState.wrongFinal) {
      widget.onSettled?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichMathText(q.prompt, fontSize: 20, fontWeight: FontWeight.w600),
        if (q.unit != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Đơn vị đáp án: ${q.unit}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 20),
        _buildInput(q),
        const SizedBox(height: 16),
        if (_state == AnswerState.wrongRetry) ...[
          _feedbackBox(
            'Chưa đúng rồi, thử lại nhé! 💡 Gợi ý: ${q.hint ?? 'Đọc kĩ đề rồi tính lại nào.'}',
            Colors.orange,
          ),
        ],
        if (_state == AnswerState.correct)
          _feedbackBox('Đúng rồi, giỏi quá! 🎉', Colors.green),
        if (_state == AnswerState.wrongFinal) ...[
          _feedbackBox(
            'Đáp án đúng là: ${q.answerText ?? ''}${q.unit != null ? ' ${q.unit}' : ''}. Đừng buồn, mình học từ câu này nhé!',
            Colors.red,
          ),
          if (q.explanation != null) ...[
            const SizedBox(height: 12),
            _feedbackBox('Lời giải: ${q.explanation}', Colors.blueGrey),
          ],
        ],
        if (_state == AnswerState.correct && q.explanation != null) ...[
          const SizedBox(height: 12),
          _feedbackBox('Lời giải: ${q.explanation}', Colors.blueGrey),
        ],
      ],
    );
  }

  Widget _feedbackBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: RichMathText(text, fontSize: 16),
    );
  }

  Widget _buildInput(Question q) {
    switch (q.type) {
      case QuestionType.mcq:
        final options = q.options ?? const [];
        return Column(
          children: options.map((opt) {
            final isSelected = _selected == opt;
            final isAnswer = q.answerText == opt;
            Color? bg;
            if (_state == AnswerState.correct && isSelected) {
              bg = Colors.green.shade100;
            } else if (_state == AnswerState.wrongFinal && isSelected) {
              bg = Colors.red.shade100;
            } else if (_state == AnswerState.wrongFinal && isAnswer) {
              bg = Colors.green.shade100;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bg,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: (_state == AnswerState.correct ||
                          _state == AnswerState.wrongFinal)
                      ? null
                      : () {
                          _selected = opt;
                          _submit(opt);
                        },
                  child: RichMathText(
                    opt,
                    fontSize: 19,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      case QuestionType.trueFalse:
        return Row(
          children: [
            Expanded(child: _boolButton('Đúng', Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _boolButton('Sai', Colors.red)),
          ],
        );
      case QuestionType.fillNumber:
        final locked = _state == AnswerState.correct ||
            _state == AnswerState.wrongFinal;
        // Đáp án là phân số (vd "1/2"): bàn phím số không gõ được '/', nên hiện thêm nút '/' để bé chèn dấu gạch phân số.
        // hiện thêm nút '/' để bé chèn dấu gạch phân số.
        final isFraction = (q.answerText ?? '').contains('/');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !locked,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9,.\s/]')),
                    ],
                    style: const TextStyle(fontSize: 22),
                    decoration: InputDecoration(
                      hintText: isFraction
                          ? 'Nhập phân số, vd 1/2'
                          : 'Nhập đáp án...',
                      suffixText: q.unit,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(_controller.text),
                  ),
                ),
                if (isFraction) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: locked
                          ? null
                          : () {
                              if (!_controller.text.contains('/')) {
                                _controller.text += '/';
                              }
                            },
                      child: const Text('/',
                          style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed:
                    locked ? null : () => _submit(_controller.text),
                child: const Text('Trả lời', style: TextStyle(fontSize: 19)),
              ),
            ),
            if (_state == AnswerState.wrongRetry)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _state = AnswerState.unanswered;
                        _controller.clear();
                      });
                    },
                    child: const Text('Thử lại',
                        style: TextStyle(fontSize: 19)),
                  ),
                ),
              ),
          ],
        );
      case QuestionType.match:
      case QuestionType.order:
      case QuestionType.dragUnit:
        return const Text(
          'Loại câu này sẽ có ở giai đoạn 2.',
          style: TextStyle(fontSize: 16),
        );
    }
  }

  Widget _boolButton(String label, Color color) {
    final locked = _state == AnswerState.correct ||
        _state == AnswerState.wrongFinal;
    final isSelected = _selected == label;
    final isAnswer = widget.question.answerText == label;
    Color? bg;
    if (_state == AnswerState.correct && isSelected) {
      bg = Colors.green.shade100;
    } else if (_state == AnswerState.wrongFinal && isSelected) {
      bg = Colors.red.shade100;
    } else if (_state == AnswerState.wrongFinal && isAnswer) {
      bg = Colors.green.shade100;
    }
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.black87,
        ),
        onPressed: locked
            ? null
            : () {
                _selected = label;
                _submit(label);
              },
        child: Text(label, style: const TextStyle(fontSize: 19)),
      ),
    );
  }
}
