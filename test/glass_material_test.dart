import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final highContrast in [false, true]) {
      testWidgets(
        '玻璃 $brightness 高对比度=$highContrast 保持内容清楚且可点击',
        (tester) async {
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildVeriFinTheme(brightness),
              home: MediaQuery(
                data: MediaQueryData(highContrast: highContrast),
                child: VeriGlassBackdrop(
                  child: Scaffold(
                    body: VeriPage(
                      child: ListView(
                        children: [
                          VeriCard(
                            onTap: () => taps++,
                            quietTap: true,
                            child: const Text('查看账目'),
                          ),
                          const VeriCard(child: Text('第二张卡片')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BackdropGroup), findsOneWidget);
          expect(
            find.byType(BackdropFilter),
            highContrast ? findsNothing : findsNWidgets(2),
          );
          expect(find.byType(ImageFiltered), findsNothing);
          final surfaces = tester
              .widgetList<DecoratedBox>(find.byType(DecoratedBox))
              .map((box) => box.decoration)
              .whereType<BoxDecoration>()
              .where(
                (decoration) =>
                    decoration.color != null && decoration.borderRadius != null,
              );
          expect(surfaces.length, 2);
          for (final surface in surfaces) {
            expect(surface.gradient, isNull);
            expect(surface.border, highContrast ? isNotNull : isNull);
            expect(surface.color!.a, highContrast ? 1 : lessThan(1));
          }
          await tester.tap(find.text('查看账目'));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        },
        skip: !veriGlassDesignPreview,
      );
    }
  }
}
