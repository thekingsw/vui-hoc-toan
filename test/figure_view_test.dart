import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/widgets/figure_view.dart';

void main() {
  final figures = <Map<String, dynamic>>[
    {'kind': 'triangle', 'base': 8, 'height': 5, 'unit': 'cm'},
    {'kind': 'trapezoid', 'a': 24, 'b': 16, 'h': 10, 'unit': 'm'},
    {'kind': 'circle', 'r': 3.5, 'unit': 'cm'},
    {'kind': 'rectangle', 'l': 12, 'w': 7, 'unit': 'm'},
    {'kind': 'square', 'a': 9, 'unit': 'dm'},
    {'kind': 'box', 'l': 10, 'w': 6, 'h': 4, 'unit': 'cm'},
    {'kind': 'cube', 'a': 5, 'unit': 'cm'},
    {
      'kind': 'pie',
      'items': [
        {'label': 'Gạo', 'percent': 40},
        {'label': 'Ngô', 'percent': 35},
        {'label': 'Khoai', 'percent': 25},
      ],
    },
  ];

  for (final fig in figures) {
    testWidgets('FigureView vẽ ${fig['kind']} không lỗi', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: FigureView(figure: fig))),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(FigureView), findsOneWidget);
    });
  }
}
