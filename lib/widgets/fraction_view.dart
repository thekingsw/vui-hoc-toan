import 'package:flutter/material.dart';

/// Hiển thị phân số dạng tử số / mẫu số rõ ràng (vd. 3/4).
/// Nhận chuỗi "3/4" hoặc tử/mẫu riêng.
class FractionView extends StatelessWidget {
  const FractionView({super.key, required this.numerator, required this.denominator, this.fontSize = 18});

  final String numerator;
  final String denominator;
  final double fontSize;

  factory FractionView.parse(String text, {double fontSize = 18}) {
    final parts = text.split('/');
    if (parts.length == 2) {
      return FractionView(
        numerator: parts[0].trim(),
        denominator: parts[1].trim(),
        fontSize: fontSize,
      );
    }
    return FractionView(numerator: text, denominator: '', fontSize: fontSize);
  }

  @override
  Widget build(BuildContext context) {
    if (denominator.isEmpty) {
      return Text(numerator, style: TextStyle(fontSize: fontSize));
    }
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            numerator,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
          Container(
            height: 2,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          Text(
            denominator,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Hiển thị văn bản có phân số dạng "a/b" xen kẽ chữ thường.
/// Cách dùng đơn giản ở MVP: tách chuỗi theo khoảng trắng, từ nào chứa
/// '/' và 2 phía đều là số thì vẽ bằng [FractionView].
class RichMathText extends StatelessWidget {
  const RichMathText(this.text, {super.key, this.fontSize = 18, this.fontWeight});

  final String text;
  final double fontSize;
  final FontWeight? fontWeight;

  static final _fractionPattern = RegExp(r'\d+\s*/\s*\d+');

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: fontSize, fontWeight: fontWeight);
    final matches = _fractionPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: style);
    }
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in matches) {
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start), style: style));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: FractionView.parse(m.group(0)!, fontSize: fontSize),
      ));
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos), style: style));
    }
    return RichText(text: TextSpan(children: spans, style: style));
  }
}
