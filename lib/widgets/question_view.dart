import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../services/scoring.dart';
import 'figure_view.dart';
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
    this.onSelect,
    this.hideFeedback = false,
  });

  final Question question;
  final void Function(bool correct, String userInput) onAnswered;
  final bool allowRetry;
  final VoidCallback? onRetryUsed;

  /// Gọi khi bé chạm chọn một đáp án (để phát tiếng chạm).
  final VoidCallback? onSelect;

  /// Gọi khi câu đã chốt xong (đúng, hoặc sai lần cuối).
  final VoidCallback? onSettled;

  /// true: màn hình cha tự hiện phản hồi (khung thoại linh vật),
  /// widget không hiện hộp phản hồi của nó nữa.
  final bool hideFeedback;

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  final _controller = TextEditingController();
  String? _selected;
  AnswerState _state = AnswerState.unanswered;
  bool _retryUsed = false;

  /// Thứ tự lựa chọn hiển thị cho câu mcq: xáo 1 lần lúc mở câu
  /// (màn hình cha dùng ValueKey(question.id) nên mỗi câu là 1 State
  /// mới) và giữ nguyên trong suốt câu, kể cả khi thử lại.
  late final List<String> _displayOptions;

  // --- Đợt C: trạng thái các loại câu mới ---
  /// match: cột phải hiển thị xáo trộn (chỉ số vào pairs).
  late final List<int> _matchRightOrder;
  int? _matchLeftSel;
  final Map<int, int> _matched = {}; // trái -> phải (chỉ số pairs)

  /// order: thứ tự hiển thị xáo trộn + các mục bé đã chọn theo thứ tự.
  late final List<int> _orderDisplay;
  final List<int> _orderPicked = [];

  /// drag_unit: đơn vị đã chọn cho từng chỗ trống + ô đang chọn.
  late final List<String?> _unitPicks;
  int? _unitFocus;

  @override
  void initState() {
    super.initState();
    _displayOptions = shuffledOptions(widget.question);
    final q = widget.question;
    _matchRightOrder = [
      for (var i = 0; i < (q.pairs?.length ?? 0); i++) i,
    ]..shuffle();
    _orderDisplay = [
      for (var i = 0; i < (q.items?.length ?? 0); i++) i,
    ]..shuffle();
    final blanks = q.prompt.split('___').length - 1;
    _unitPicks = List<String?>.filled(blanks, null);
  }

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
        if (q.type != QuestionType.dragUnit)
          RichMathText(q.prompt, fontSize: 20, fontWeight: FontWeight.w600),
        if (q.figure != null) FigureView(figure: q.figure!),
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
        if (!widget.hideFeedback && _state == AnswerState.wrongRetry) ...[
          _feedbackBox(
            'Chưa đúng rồi, thử lại nhé! 💡 Gợi ý: ${q.hint ?? 'Đọc kĩ đề rồi tính lại nào.'}',
            Colors.orange,
          ),
        ],
        if (!widget.hideFeedback && _state == AnswerState.correct)
          _feedbackBox('Đúng rồi, giỏi quá! 🎉', Colors.green),
        if (!widget.hideFeedback && _state == AnswerState.wrongFinal) ...[
          _feedbackBox(
            'Đáp án đúng là: ${q.answerText ?? ''}${q.unit != null ? ' ${q.unit}' : ''}. Đừng buồn, mình học từ câu này nhé!',
            Colors.orange,
          ),
          if (q.explanation != null) ...[
            const SizedBox(height: 12),
            _feedbackBox('Lời giải: ${q.explanation}', Colors.blueGrey),
          ],
        ],
        if (!widget.hideFeedback &&
            _state == AnswerState.correct &&
            q.explanation != null) ...[
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
        final options = _displayOptions;
        return Column(
          children: options.map((opt) {
            final isSelected = _selected == opt;
            final isAnswer = q.answerText == opt;
            Color? bg;
            if (_state == AnswerState.correct && isSelected) {
              bg = Colors.green.shade100;
            } else if (_state == AnswerState.wrongFinal && isSelected) {
              bg = Colors.orange.shade100;
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
                          widget.onSelect?.call();
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
            Expanded(child: _boolButton('Sai', Colors.deepOrange)),
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
        return _buildMatch(q);
      case QuestionType.order:
        return _buildOrder(q);
      case QuestionType.dragUnit:
        return _buildDragUnit(q);
      case QuestionType.columnCalc:
        return _buildColumnCalc(q);
    }
  }

  bool get _locked =>
      _state == AnswerState.correct || _state == AnswerState.wrongFinal;

  Widget _submitButton(String? input) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: (_locked || input == null) ? null : () => _submit(input),
        child: const Text('Trả lời', style: TextStyle(fontSize: 19)),
      ),
    );
  }

  Widget _retryButton(VoidCallback onRetry) {
    if (_state != AnswerState.wrongRetry) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 56,
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _state = AnswerState.unanswered;
              onRetry();
            });
          },
          child: const Text('Thử lại', style: TextStyle(fontSize: 19)),
        ),
      ),
    );
  }

  /// Nối cặp: chạm cột trái rồi chạm cột phải. Cặp đã nối hiện số thứ tự.
  Widget _buildMatch(Question q) {
    final pairs = q.pairs ?? const [];
    final complete = _matched.length == pairs.length && pairs.isNotEmpty;
    final input = complete
        ? [
            for (var i = 0; i < pairs.length; i++)
              '${pairs[i][0]}=${pairs[_matched[i]!][1]}',
          ].join('|')
        : null;
    Widget cell(String text, bool selected, int? badge, VoidCallback? onTap) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selected ? Colors.blue.shade100 : Colors.white,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: selected ? Colors.blue : Colors.grey.shade400,
                  width: selected ? 2.5 : 1,
                ),
              ),
            ),
            onPressed: _locked ? null : onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (badge != null)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                Flexible(child: RichMathText(text, fontSize: 18)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < pairs.length; i++)
                    cell(
                      pairs[i][0],
                      _matchLeftSel == i || _matched.containsKey(i),
                      _matched.containsKey(i)
                          ? _matched.keys.toList().indexOf(i) + 1
                          : null,
                      () {
                        widget.onSelect?.call();
                        setState(() {
                          if (_matched.containsKey(i)) {
                            _matched.remove(i);
                            _matchLeftSel = null;
                          } else {
                            _matchLeftSel = i;
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  for (final j in _matchRightOrder)
                    cell(
                      pairs[j][1],
                      _matched.containsValue(j),
                      _matched.containsValue(j)
                          ? _matched.values.toList().indexOf(j) + 1
                          : null,
                      () {
                        widget.onSelect?.call();
                        setState(() {
                          final left = _matchLeftSel;
                          if (left != null && !_matched.containsValue(j)) {
                            _matched[left] = j;
                            _matchLeftSel = null;
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _submitButton(input),
        _retryButton(() {
          _matched.clear();
          _matchLeftSel = null;
        }),
      ],
    );
  }

  /// Sắp xếp: chạm các mục theo thứ tự đúng, hiện số 1, 2, 3...
  Widget _buildOrder(Question q) {
    final items = q.items ?? const [];
    final complete = _orderPicked.length == items.length && items.isNotEmpty;
    final input = complete
        ? _orderPicked.map((i) => items[i]).join('|')
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in _orderDisplay)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orderPicked.contains(i)
                      ? Colors.blue.shade100
                      : Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _orderPicked.contains(i)
                          ? Colors.blue
                          : Colors.grey.shade400,
                      width: _orderPicked.contains(i) ? 2.5 : 1,
                    ),
                  ),
                ),
                onPressed: _locked
                    ? null
                    : () {
                        widget.onSelect?.call();
                        setState(() {
                          if (_orderPicked.contains(i)) {
                            _orderPicked.remove(i);
                          } else {
                            _orderPicked.add(i);
                          }
                        });
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_orderPicked.contains(i))
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('${_orderPicked.indexOf(i) + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                    Flexible(child: RichMathText(items[i], fontSize: 18)),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        _submitButton(input),
        _retryButton(() => _orderPicked.clear()),
      ],
    );
  }

  /// Kéo thả đơn vị (bản chạm chọn): chạm ô trống rồi chạm đơn vị.
  Widget _buildDragUnit(Question q) {
    final parts = q.prompt.split('___');
    final complete =
        _unitPicks.isNotEmpty && _unitPicks.every((u) => u != null);
    final input = complete ? _unitPicks.join('|') : null;
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(text: parts[i]));
      if (i < _unitPicks.length) {
        final picked = _unitPicks[i];
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: _locked
                ? null
                : () {
                    widget.onSelect?.call();
                    setState(() => _unitFocus = i);
                  },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _unitFocus == i
                    ? Colors.blue.shade100
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _unitFocus == i ? Colors.blue : Colors.amber.shade700,
                  width: _unitFocus == i ? 2.5 : 1.5,
                ),
              ),
              child: Text(
                picked ?? ' ? ',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
            children: spans,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final u in q.bank ?? const <String>[])
              ChoiceChip(
                label: Text(u, style: const TextStyle(fontSize: 18)),
                selected: _unitFocus != null &&
                    _unitPicks[_unitFocus!] == u,
                onSelected: _locked || _unitFocus == null
                    ? null
                    : (_) {
                        widget.onSelect?.call();
                        setState(() => _unitPicks[_unitFocus!] = u);
                      },
              ),
          ],
        ),
        const SizedBox(height: 16),
        _submitButton(input),
        _retryButton(() {
          for (var i = 0; i < _unitPicks.length; i++) {
            _unitPicks[i] = null;
          }
          _unitFocus = null;
        }),
      ],
    );
  }

  /// Đặt tính cột dọc: hiện phép tính hàng dọc + ô nhập kết quả.
  Widget _buildColumnCalc(Question q) {
    final col = q.column ?? const {};
    final a = '${col['a'] ?? ''}';
    final b = '${col['b'] ?? ''}';
    final op = '${col['op'] ?? '+'}';
    const style = TextStyle(fontSize: 30, fontWeight: FontWeight.bold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a, style: style),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(op, style: style),
                    const SizedBox(width: 14),
                    Text(b, style: style),
                  ],
                ),
                const SizedBox(height: 6),
                Container(height: 3, width: 130, color: Colors.black87),
                const SizedBox(height: 6),
                const Text('?', style: style),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          enabled: !_locked,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s/]')),
          ],
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            hintText: 'Nhập kết quả...',
            suffixText: q.unit,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(_controller.text),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _submitButton(_controller.text.isEmpty ? null : _controller.text),
        _retryButton(() => _controller.clear()),
      ],
    );
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
      bg = Colors.orange.shade100;
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
                widget.onSelect?.call();
                _selected = label;
                _submit(label);
              },
        child: Text(label, style: const TextStyle(fontSize: 19)),
      ),
    );
  }
}
