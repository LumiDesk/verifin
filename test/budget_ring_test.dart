import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/chart_painters.dart';

void main() {
  testWidgets('预算环由外部图表适配层渲染并保留中心内容', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 132,
              height: 132,
              child: VeriBudgetRing(
                value: 0.72,
                trackColor: const Color(0xFFE5E7EB),
                progressColor: const Color(0xFF346EDB),
                center: const Text('72%'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VeriBudgetRing), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
