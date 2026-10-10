import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/chart_painters.dart';

void main() {
  testWidgets('环形图分段点击回传正确索引且中心空区不越界', (tester) async {
    int? selected = -99;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: VeriDonutChart(
                segments: const <VeriDonutSegment>[
                  VeriDonutSegment(
                    label: 'A',
                    value: 1,
                    color: Color(0xFF346EDB),
                  ),
                  VeriDonutSegment(
                    label: 'B',
                    value: 1,
                    color: Color(0xFF2AA198),
                  ),
                ],
                center: const Text('center'),
                onSelected: (index) => selected = index,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(VeriDonutChart));
    // 起始角 -90°，右半圆属于第一段。
    await tester.tapAt(center + const Offset(87, 0));
    await tester.pumpAndSettle();
    expect(selected, 0);

    // 中心空区应回传 null，且不能把 -1 索引交给上层。
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });
}
