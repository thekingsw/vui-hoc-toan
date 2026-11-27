import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vẽ hình minh họa từ trường `figure` của thẻ học / câu hỏi.
///
/// figure là object tham số, vd {"kind": "trapezoid", "a": 24, "b": 16,
/// "h": 10, "unit": "m"}. Các kind: triangle{base,height},
/// trapezoid{a,b,h}, circle{r}, rectangle{l,w}, square{a}, box{l,w,h},
/// cube{a}, pie{items:[{label,percent}]}.
class FigureView extends StatelessWidget {
  const FigureView({super.key, required this.figure, this.color});

  final Map<String, dynamic> figure;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    if (figure['kind'] == 'pie') {
      return _PieFigure(figure: figure);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(280, 190),
        painter: _FigurePainter(figure, c),
      ),
    );
  }
}

String _fmtNum(num v) {
  final s = v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString().replaceAll('.', ',');
  // Nhóm nghìn bằng khoảng trắng cho phần nguyên.
  final parts = s.split(',');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(' ');
    buf.write(intPart[i]);
  }
  return parts.length > 1 ? '$buf,${parts[1]}' : '$buf';
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.fig, this.color);

  final Map<String, dynamic> fig;
  final Color color;

  double _n(String k) => (fig[k] as num?)?.toDouble() ?? 0;
  String get _unit => (fig['unit'] as String?) ?? '';

  String _label(num v) => _unit.isEmpty ? _fmtNum(v) : '${_fmtNum(v)} $_unit';

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final dash = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    switch (fig['kind']) {
      case 'triangle':
        _triangle(canvas, size, stroke, fill, dash);
      case 'trapezoid':
        _trapezoid(canvas, size, stroke, fill, dash);
      case 'circle':
        _circle(canvas, size, stroke, fill, dash);
      case 'rectangle':
        _rect(canvas, size, stroke, fill, _n('l'), _n('w'));
      case 'square':
        _rect(canvas, size, stroke, fill, _n('a'), _n('a'), square: true);
      case 'box':
        _box(canvas, size, stroke, fill, _n('l'), _n('w'), _n('h'));
      case 'cube':
        _box(canvas, size, stroke, fill, _n('a'), _n('a'), _n('a'), cube: true);
    }
  }

  void _text(Canvas canvas, String s, Offset at, {bool center = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 6.0, gap = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = math.min(d + dashLen, total);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d = end + gap;
    }
  }

  void _triangle(Canvas canvas, Size size, Paint stroke, Paint fill, Paint dash) {
    final base = _n('base'), height = _n('height');
    final w = size.width - 90, h = size.height - 60;
    final scale = math.min(w / base, h / height);
    final bw = base * scale, bh = height * scale;
    final left = (size.width - bw) / 2, bottom = size.height - 35;
    final apex = Offset(left + bw / 2, bottom - bh);
    final path = Path()
      ..moveTo(left, bottom)
      ..lineTo(left + bw, bottom)
      ..lineTo(apex.dx, apex.dy)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    // Đường cao nét đứt.
    _dashedLine(canvas, apex, Offset(apex.dx, bottom), dash);
    // Góc vuông ở chân đường cao.
    const sq = 10.0;
    canvas.drawPath(
      Path()
        ..moveTo(apex.dx, bottom - sq)
        ..lineTo(apex.dx + sq, bottom - sq)
        ..lineTo(apex.dx + sq, bottom),
      dash,
    );
    _text(canvas, _label(base), Offset(left + bw / 2, bottom + 18));
    _text(canvas, _label(height), Offset(apex.dx + 26, bottom - bh / 2));
  }

  void _trapezoid(Canvas canvas, Size size, Paint stroke, Paint fill, Paint dash) {
    final a = _n('a'), b = _n('b'), h = _n('h');
    final w = size.width - 90, hh = size.height - 70;
    final scale = math.min(w / a, hh / h);
    final aw = a * scale, bw = b * scale, bh = h * scale;
    final left = (size.width - aw) / 2, bottom = size.height - 35;
    final topLeft = left + (aw - bw) / 2, top = bottom - bh;
    final path = Path()
      ..moveTo(left, bottom)
      ..lineTo(left + aw, bottom)
      ..lineTo(topLeft + bw, top)
      ..lineTo(topLeft, top)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    _dashedLine(canvas, Offset(topLeft, top), Offset(topLeft, bottom), dash);
    _text(canvas, _label(a), Offset(left + aw / 2, bottom + 18));
    _text(canvas, _label(b), Offset(topLeft + bw / 2, top - 16));
    _text(canvas, _label(h), Offset(topLeft - 24, bottom - bh / 2));
  }

  void _circle(Canvas canvas, Size size, Paint stroke, Paint fill, Paint dash) {
    final r = _n('r');
    final center = Offset(size.width / 2, size.height / 2);
    final rad = math.min(size.width, size.height) / 2 - 30;
    canvas.drawCircle(center, rad, fill);
    canvas.drawCircle(center, rad, stroke);
    final edge = center + Offset(rad * 0.7071, -rad * 0.7071);
    canvas.drawLine(center, edge, dash);
    canvas.drawCircle(center, 3, Paint()..color = color);
    _text(canvas, _label(r), (center + edge) / 2 + const Offset(16, -12));
  }

  void _rect(Canvas canvas, Size size, Paint stroke, Paint fill, double l, double w,
      {bool square = false}) {
    final availW = size.width - 90, availH = size.height - 60;
    final scale = math.min(availW / l, availH / w);
    final rw = l * scale, rh = w * scale;
    final left = (size.width - rw) / 2, top = (size.height - rh) / 2 - 8;
    final rect = Rect.fromLTWH(left, top, rw, rh);
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
    _text(canvas, _label(l), Offset(left + rw / 2, top + rh + 18));
    if (!square) {
      _text(canvas, _label(w), Offset(left - 26, top + rh / 2));
    }
  }

  void _box(Canvas canvas, Size size, Paint stroke, Paint fill, double l, double w,
      double h, {bool cube = false}) {
    final availW = size.width - 110, availH = size.height - 70;
    final scale = math.min(availW / (l + w * 0.45), availH / (h + w * 0.45));
    final fw = l * scale, fh = h * scale;
    final dx = w * scale * 0.45, dy = -w * scale * 0.45;
    final left = (size.width - fw - dx) / 2;
    final bottom = size.height - 35;
    final top = bottom - fh;
    // Mặt sau.
    final back = Rect.fromLTWH(left + dx, top + dy, fw, fh);
    canvas.drawRect(back, stroke);
    // Mặt trước.
    final front = Rect.fromLTWH(left, top, fw, fh);
    canvas.drawRect(front, fill);
    canvas.drawRect(front, stroke);
    // Các cạnh nối.
    for (final (fx, fy) in [(left, top), (left + fw, top), (left + fw, bottom), (left, bottom)]) {
      canvas.drawLine(Offset(fx, fy), Offset(fx + dx, fy + dy), stroke);
    }
    _text(canvas, _label(l), Offset(left + fw / 2, bottom + 18));
    _text(canvas, _label(h), Offset(left - 24, top + fh / 2));
    _text(canvas, _label(w), Offset(left + fw + dx / 2 + 14, bottom + dy / 2));
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.fig != fig || old.color != color;
}

class _PieFigure extends StatelessWidget {
  const _PieFigure({required this.figure});

  final Map<String, dynamic> figure;

  static const _palette = [
    Color(0xFF42A5F5),
    Color(0xFFFFA726),
    Color(0xFF66BB6A),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF26C6DA),
    Color(0xFFFFCA28),
    Color(0xFF8D6E63),
  ];

  @override
  Widget build(BuildContext context) {
    final items = (figure['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(150, 150),
            painter: _PiePainter(items, _palette),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${items[i]['label']}: ${_fmtNum((items[i]['percent'] as num?) ?? 0)}%',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.items, this.palette);

  final List<Map<String, dynamic>> items;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var i = 0; i < items.length; i++) {
      final pct = ((items[i]['percent'] as num?) ?? 0).toDouble();
      final sweep = pct / 100 * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = palette[i % palette.length],
      );
      start += sweep;
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PiePainter old) => old.items != items;
}
