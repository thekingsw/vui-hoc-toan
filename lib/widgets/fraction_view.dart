import 'package:flutter/material.dart';

/// Hiển thị phân số dạng SGK: tử số ở trên, mẫu số ở dưới, gạch ngang ở giữa.
/// Nhận chuỗi "3/4" hoặc tử/mẫu riêng.
class FractionView extends StatelessWidget {
  const FractionView({super.key, required this.numerator, required this.denominator, this.fontSize = 18, this.color});

  final String numerator;
  final String denominator;
  final double fontSize;
  final Color? color;

  factory FractionView.parse(String text, {double fontSize = 18, Color? color}) {
    final parts = text.split('/');
    if (parts.length == 2) {
      return FractionView(
        numerator: parts[0].trim(),
        denominator: parts[1].trim(),
        fontSize: fontSize,
        color: color,
      );
    }
    return FractionView(numerator: text, denominator: '', fontSize: fontSize, color: color);
  }

  @override
  Widget build(BuildContext context) {
    if (denominator.isEmpty) {
      return Text(numerator, style: TextStyle(fontSize: fontSize, color: color));
    }
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            numerator,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: c),
          ),
          Container(height: 2, color: c),
          Text(
            denominator,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: c),
          ),
        ],
      ),
    );
  }
}

/// Hiển thị văn bản có phân số/hỗn số dạng SGK xen kẽ chữ thường:
/// - "3/4" → tử trên, mẫu dưới.
/// - "6 1/2" (hỗn số) → phần nguyên + phân số nhỏ hơn ở cạnh, đúng kiểu SGK.
class RichMathText extends StatelessWidget {
  const RichMathText(this.text, {super.key, this.fontSize = 18, this.fontWeight, this.color});

  final String text;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color? color;

  // Ưu tiên khớp hỗn số "6 1/2" trước, sau đó mới tới phân số thường "3/4".
  static final _mathPattern =
      RegExp(r'(\d+)\s+(\d+)\s*/\s*(\d+)|(\d+)\s*/\s*(\d+)');

  @override
  Widget build(BuildContext context) {
    // RichText không tự kế thừa màu chữ của Material như Text, nên khi
    // không được truyền màu phải lấy màu chữ mặc định của theme —
    // thiếu bước này chữ thường bị trắng trên nền sáng (lỗi 26/11).
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    final style = TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: effectiveColor);
    final matches = _mathPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: style);
    }
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in matches) {
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start), style: style));
      }
      if (m.group(1) != null) {
        // Hỗn số: phần nguyên + phân số thu nhỏ (kiểu SGK).
        spans.add(TextSpan(text: '${m.group(1)} ', style: style));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: FractionView(
            numerator: m.group(2)!,
            denominator: m.group(3)!,
            fontSize: fontSize * 0.8,
            color: effectiveColor,
          ),
        ));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: FractionView(
            numerator: m.group(4)!,
            denominator: m.group(5)!,
            fontSize: fontSize,
            color: effectiveColor,
          ),
        ));
      }
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos), style: style));
    }
    return RichText(text: TextSpan(children: spans, style: style));
  }
}
