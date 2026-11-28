import 'dart:math';

import '../models/question.dart';
import 'scoring.dart';
import 'validator.dart';

/// Sinh câu biến thể từ câu gốc bằng cách thay số trong biểu thức
/// kiểm chứng (calc) rồi tính lại đáp án.
///
/// Nguyên tắc an toàn (thà không sinh còn hơn sinh câu sai):
/// - Chỉ áp dụng cho mcq / fill_number / column_calc có calc.
/// - Chỉ thay số nào xuất hiện trong đề bài (dữ kiện bé nhìn thấy);
///   hằng số đổi đơn vị (100, 1000...) không có trong đề thì giữ nguyên.
/// - Đáp án mới phải tính được chính xác bằng phân số, không âm,
///   khác đáp án cũ, định dạng theo đáp án cũ.
/// - Câu biến thể phải qua validator của app; không qua thì bỏ,
///   dùng nguyên câu gốc.
/// Câu biến thể giữ nguyên id của câu gốc để hộp ôn cập nhật đúng.

class CalcValue {
  CalcValue(BigInt n, BigInt d) {
    if (d == BigInt.zero) throw const FormatException('chia cho 0');
    if (d < BigInt.zero) {
      n = -n;
      d = -d;
    }
    final g = _gcd(n.abs(), d);
    num = n ~/ g;
    den = d ~/ g;
  }

  late final BigInt num;
  late final BigInt den;

  static BigInt _gcd(BigInt a, BigInt b) {
    while (b != BigInt.zero) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a == BigInt.zero ? BigInt.one : a;
  }

  factory CalcValue.fromDecimal(String s) {
    final t = s.trim().replaceAll(',', '.');
    final neg = t.startsWith('-');
    final body = neg ? t.substring(1) : t;
    final parts = body.split('.');
    if (parts.length == 1) {
      return CalcValue(BigInt.parse(body) * (neg ? -BigInt.one : BigInt.one),
          BigInt.one);
    }
    final digits = parts[0] + parts[1];
    var n = BigInt.parse(digits);
    if (neg) n = -n;
    return CalcValue(n, BigInt.from(10).pow(parts[1].length));
  }

  CalcValue operator +(CalcValue o) => CalcValue(num * o.den + o.num * den, den * o.den);
  CalcValue operator -(CalcValue o) => CalcValue(num * o.den - o.num * den, den * o.den);
  CalcValue operator *(CalcValue o) => CalcValue(num * o.num, den * o.den);
  CalcValue operator /(CalcValue o) => CalcValue(num * o.den, den * o.num);
  CalcValue operator -() => CalcValue(-num, den);

  bool get isNegative => num < BigInt.zero;
  bool get isInteger => den == BigInt.one;

  /// Làm tròn tới [places] chữ số thập phân (nửa lên).
  CalcValue roundTo(int places) {
    final scale = BigInt.from(10).pow(places);
    final scaled = num * scale;
    var q = scaled ~/ den;
    final r = scaled - q * den;
    if ((r.abs() * BigInt.two) >= den) {
      q += scaled < BigInt.zero ? -BigInt.one : BigInt.one;
    }
    return CalcValue(q, scale);
  }

  @override
  bool operator ==(Object other) =>
      other is CalcValue && num == other.num && den == other.den;

  @override
  int get hashCode => Object.hash(num, den);
}

/// Tính biểu thức calc (Fraction/Decimal/round/int + số + toán tử).
/// Trả null nếu không tính được.
CalcValue? evalCalc(String expr) {
  try {
    final p = _Parser(expr);
    final v = p.parseExpr();
    p.expectEnd();
    return v;
  } catch (_) {
    return null;
  }
}

class _Parser {
  _Parser(this.s);
  final String s;
  int i = 0;

  void _skip() {
    while (i < s.length && (s[i] == ' ' || s[i] == '\t')) {
      i++;
    }
  }

  bool _eat(String c) {
    _skip();
    if (i < s.length && s[i] == c) {
      i++;
      return true;
    }
    return false;
  }

  void expectEnd() {
    _skip();
    if (i != s.length) throw const FormatException('thừa ký tự');
  }

  CalcValue parseExpr() {
    var v = _parseTerm();
    while (true) {
      if (_eat('+')) {
        v = v + _parseTerm();
      } else if (_eat('-')) {
        v = v - _parseTerm();
      } else {
        return v;
      }
    }
  }

  CalcValue _parseTerm() {
    var v = _parseFactor();
    while (true) {
      if (_eat('*')) {
        v = v * _parseFactor();
      } else if (_eat('/')) {
        v = v / _parseFactor();
      } else {
        return v;
      }
    }
  }

  CalcValue _parseFactor() {
    _skip();
    if (_eat('-')) return -_parseFactor();
    if (_eat('(')) {
      final v = parseExpr();
      if (!_eat(')')) throw const FormatException('thiếu )');
      return v;
    }
    // Số
    final m = RegExp(r'\d+(\.\d+)?').matchAsPrefix(s, i);
    if (m != null) {
      i = m.end;
      return CalcValue.fromDecimal(m.group(0)!);
    }
    // Hàm
    final idm = RegExp(r'[A-Za-z]+').matchAsPrefix(s, i);
    if (idm != null) {
      final name = idm.group(0)!;
      i = idm.end;
      if (!_eat('(')) throw const FormatException('thiếu (');
      switch (name) {
        case 'Fraction':
          final a = parseExpr();
          if (!_eat(',')) throw const FormatException('Fraction thiếu ,');
          final b = parseExpr();
          if (!_eat(')')) throw const FormatException('thiếu )');
          return a / b;
        case 'Decimal':
          _skip();
          String str;
          if (i < s.length && (s[i] == "'" || s[i] == '"')) {
            final q = s[i];
            final end = s.indexOf(q, i + 1);
            if (end < 0) throw const FormatException('thiếu dấu nháy');
            str = s.substring(i + 1, end);
            i = end + 1;
          } else {
            final nm = RegExp(r'-?\d+(\.\d+)?').matchAsPrefix(s, i);
            if (nm == null) throw const FormatException('Decimal lạ');
            str = nm.group(0)!;
            i = nm.end;
          }
          if (!_eat(')')) throw const FormatException('thiếu )');
          return CalcValue.fromDecimal(str);
        case 'round':
          final v = parseExpr();
          var places = 0;
          if (_eat(',')) {
            final p = parseExpr();
            if (!p.isInteger) throw const FormatException('round places');
            places = p.num.toInt();
          }
          if (!_eat(')')) throw const FormatException('thiếu )');
          return v.roundTo(places);
        case 'int':
          final v = parseExpr();
          if (!_eat(')')) throw const FormatException('thiếu )');
          return CalcValue(v.num ~/ v.den, BigInt.one);
      }
    }
    throw const FormatException('không đọc được');
  }
}

/// Định dạng giá trị theo mẫu đáp án cũ (phân số / thập phân / nguyên).
/// Trả null nếu không biểu diễn đúng được theo mẫu.
String? _formatLike(CalcValue v, String sample) {
  final s = sample.trim();
  if (s.contains('/')) {
    if (v.isNegative) return null;
    return '${v.num}/${v.den}';
  }
  if (s.contains(',') || s.contains('.')) {
    final decPart = s.split(RegExp(r'[,.]')).last;
    final places = decPart.length;
    final r = v.roundTo(places);
    if (r != v) return null; // làm tròn làm đổi giá trị → không chắc chắn
    final scale = BigInt.from(10).pow(places);
    final scaled = (r.num * scale) ~/ r.den;
    final neg = scaled < BigInt.zero;
    final abs = scaled.abs().toString().padLeft(places + 1, '0');
    final intPart = abs.substring(0, abs.length - places);
    final fracPart = abs.substring(abs.length - places);
    return '${neg ? '-' : ''}$intPart,$fracPart';
  }
  // Số nguyên
  if (!v.isInteger) return null;
  return '${v.num}';
}

/// Sinh số thay thế cùng dạng với số cũ (giữ số chữ số / chữ số thập phân).
String? _replacementFor(String old, Random rnd) {
  if (old.contains('.')) {
    final parts = old.split('.');
    final intLen = parts[0].length;
    final fracLen = parts[1].length;
    for (var t = 0; t < 8; t++) {
      final ip = intLen == 1
          ? rnd.nextInt(9) + 1
          : rnd.nextInt(9 * pow(10, intLen - 1).toInt()) +
              pow(10, intLen - 1).toInt();
      final fp = rnd.nextInt(pow(10, fracLen).toInt());
      final cand = '$ip.${fp.toString().padLeft(fracLen, '0')}';
      if (cand != old) return cand;
    }
    return null;
  }
  final v = int.tryParse(old);
  if (v == null || v <= 0) return null;
  final digits = old.length;
  for (var t = 0; t < 8; t++) {
    final cand = digits == 1
        ? rnd.nextInt(8) + 2
        : rnd.nextInt(9 * pow(10, digits - 1).toInt()) +
            pow(10, digits - 1).toInt();
    if (cand != v) return '$cand';
  }
  return null;
}

/// Thử sinh 1 câu biến thể từ [q]. Không sinh được thì trả null
/// (nơi gọi dùng nguyên câu gốc).
Question? makeVariant(Question q, {Random? random}) {
  final rnd = random ?? Random();
  if (q.type != QuestionType.mcq &&
      q.type != QuestionType.fillNumber &&
      q.type != QuestionType.columnCalc) {
    return null;
  }
  final calc = q.calc;
  final answer = q.answerText;
  if (calc == null || calc.isEmpty || answer == null) return null;
  final oldValue = evalCalc(calc);
  if (oldValue == null) return null;

  // Các số trong calc; chỉ thay số xuất hiện trong đề (dữ kiện).
  final numRe = RegExp(r'\d+(\.\d+)?');
  final inCalc = <String>{};
  for (final m in numRe.allMatches(calc)) {
    inCalc.add(m.group(0)!);
  }
  final replaceMap = <String, String>{}; // số trong calc -> số mới (dạng calc)
  for (final old in inCalc) {
    final vn = old.replaceAll('.', ',');
    if (!q.prompt.contains(vn) && !q.prompt.contains(old)) continue;
    final rep = _replacementFor(old, rnd);
    if (rep != null) replaceMap[old] = rep;
  }
  if (replaceMap.isEmpty) return null;

  // Thay trong calc (theo ranh giới số, dài trước để tránh thay lồng)
  var newCalc = calc;
  final olds = replaceMap.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final old in olds) {
    newCalc = newCalc.replaceAllMapped(
      RegExp(r'(?<![\d.])' + RegExp.escape(old) + r'(?![\d.])'),
      (_) => replaceMap[old]!,
    );
  }
  final newValue = evalCalc(newCalc);
  if (newValue == null || newValue.isNegative || newValue == oldValue) {
    return null;
  }
  // Tránh đáp án quá lớn
  if (newValue.num.abs() > BigInt.from(10000000) * newValue.den) return null;
  final newAnswer = _formatLike(newValue, answer);
  if (newAnswer == null) return null;
  // Kiểm chứng: đáp án mới phải bằng giá trị tính được
  if (!numbersEqual(newAnswer, _formatLike(newValue, newAnswer) ?? '')) {
    // _formatLike(newValue, newAnswer) phải cho lại chính newAnswer
    if (_formatLike(newValue, newAnswer) != newAnswer) return null;
  }

  // Thay số trong đề theo dạng hiển thị VN
  var newPrompt = q.prompt;
  for (final old in olds) {
    final rep = replaceMap[old]!;
    final oldVn = old.replaceAll('.', ',');
    final repVn = rep.replaceAll('.', ',');
    if (newPrompt.contains(oldVn)) {
      newPrompt = newPrompt.replaceAllMapped(
        RegExp(r'(?<![\d.,])' + RegExp.escape(oldVn) + r'(?![\d.,])'),
        (_) => repVn,
      );
    }
  }
  if (newPrompt == q.prompt) return null;

  // Lựa chọn cho mcq: đáp án mới + 3 nhiễu quanh nó
  List<String>? newOptions;
  if (q.type == QuestionType.mcq) {
    final opts = <String>{newAnswer};
    final steps = [
      CalcValue(BigInt.one, BigInt.one),
      CalcValue(-BigInt.one, BigInt.one),
      CalcValue(BigInt.two, BigInt.one),
      CalcValue(-BigInt.two, BigInt.one),
      CalcValue(BigInt.from(10), BigInt.one),
      CalcValue(BigInt.from(-10), BigInt.one),
      CalcValue(BigInt.one, BigInt.from(10)),
      CalcValue(-BigInt.one, BigInt.from(10)),
      CalcValue(BigInt.one, BigInt.from(100)),
      CalcValue(-BigInt.one, BigInt.from(100)),
    ]..shuffle(rnd);
    for (final st in steps) {
      if (opts.length >= 4) break;
      final cand = newValue + st;
      if (cand.isNegative) continue;
      final f = _formatLike(cand, answer);
      if (f != null) opts.add(f);
    }
    if (opts.length < 4) return null;
    newOptions = opts.toList()..shuffle(rnd);
  }

  final variant = Question(
    id: q.id,
    lessonId: q.lessonId,
    type: q.type,
    difficulty: q.difficulty,
    prompt: newPrompt,
    options: newOptions ?? q.options,
    answerRaw: newAnswer,
    pairs: q.pairs,
    items: q.items,
    bank: q.bank,
    column: q.type == QuestionType.columnCalc
        ? _variantColumn(q, replaceMap)
        : q.column,
    unit: q.unit,
    hint: q.hint,
    explanation: null, // lời giải cũ gắn với số cũ — bỏ để tránh sai
    calc: newCalc,
    tags: q.tags,
    figure: null, // hình cũ gắn với số cũ — bỏ
  );

  // Kiểm chứng cuối bằng validator của app (đảo giả lập 1 câu)
  final errors = validateIslandJson({
    'island_id': 'variant_check',
    'title': 'Kiểm tra biến thể',
    'order': 0,
    'lessons': [
      {'lesson_id': q.lessonId, 'kind': 'lesson', 'title': 'Bài'},
    ],
    'questions': [
      {
        'id': variant.id,
        'lesson_id': variant.lessonId,
        'type': _typeName(variant.type),
        'difficulty': variant.difficulty,
        'prompt': variant.prompt,
        'options': variant.options,
        'answer': variant.answerRaw,
        'column': variant.column,
      },
    ],
  });
  if (errors.isNotEmpty) return null;
  return variant;
}

String _typeName(QuestionType t) {
  switch (t) {
    case QuestionType.mcq:
      return 'mcq';
    case QuestionType.fillNumber:
      return 'fill_number';
    case QuestionType.trueFalse:
      return 'true_false';
    case QuestionType.match:
      return 'match';
    case QuestionType.order:
      return 'order';
    case QuestionType.dragUnit:
      return 'drag_unit';
    case QuestionType.columnCalc:
      return 'column_calc';
  }
}

Map<String, dynamic>? _variantColumn(
    Question q, Map<String, String> replaceMap) {
  final col = q.column;
  if (col == null) return null;
  String swap(dynamic v) {
    var s = '$v';
    for (final e in replaceMap.entries) {
      final oldVn = e.key.replaceAll('.', ',');
      final repVn = e.value.replaceAll('.', ',');
      if (s == oldVn || s == e.key) s = repVn;
    }
    return s;
  }

  return {'a': swap(col['a']), 'op': col['op'], 'b': swap(col['b'])};
}
