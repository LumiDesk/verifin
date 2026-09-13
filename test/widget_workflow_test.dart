import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/app/widget_config.dart';
import 'package:verifin/pages/widget_design_preview.dart';
import 'package:verifin/pages/widget_gallery_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('组件页只展示固定模板，不进入用户设计编辑态', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const WidgetGalleryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('桌面小组件'), findsOneWidget);
    expect(find.byType(WidgetDesignPreview), findsNWidgets(12));
    expect(find.byTooltip('创建小组件'), findsNothing);
    expect(find.byType(UserWidgetEditorPage), findsNothing);
    expect(find.byKey(const ValueKey('widget_delete_first')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in supportedWidgetSizes) {
    for (final template in WidgetTemplate.values) {
      testWidgets('${template.name} ${size.name} 比例、对齐、圆角及大字无溢出', (
        tester,
      ) async {
        final c = await makeController();
        addTearDown(c.dispose);
        c.addEntry(
          LedgerEntry(
            id: 'real',
            bookId: c.activeBook.id,
            type: EntryType.expense,
            amount: 37,
            categoryId: c.categoriesForType(EntryType.expense).first.id,
            accountId: '',
            note: '',
            occurredAt: DateTime.now(),
          ),
        );
        final definition = UserWidgetDefinition(
          id: 'size',
          name: '用户创建的财务卡片',
          template: template,
          size: size,
          primaryMetric: WidgetMetric.todayExpense,
        );
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            VeriFinScope(
              controller: c,
              child: zhMaterialApp(
                theme: buildVeriFinTheme(brightness),
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(1.5),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: size == WidgetSize.twoByFour ? 332 : 161,
                        child: WidgetDesignPreview(
                          definition: definition,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final surface = find.byKey(const ValueKey('widget_surface_size'));
          final rect = tester.getRect(surface);
          expect(
            rect.width / rect.height,
            closeTo(size == WidgetSize.twoByTwo ? 1 : 2, .001),
          );
          final radius = tester
              .widget<ClipRRect>(surface)
              .borderRadius
              .resolve(TextDirection.ltr);
          expect(radius.topLeft, radius.bottomLeft);
          expect(radius.topRight, radius.bottomRight);
          final title = tester.getTopLeft(
            find.byKey(const ValueKey('widget_name_size')),
          );
          final amount = tester.getTopLeft(
            find.byKey(const ValueKey('widget_amount_size')),
          );
          expect(amount.dx, closeTo(title.dx, .01));
          expect(find.text('37'), findsOneWidget);
          if (template == WidgetTemplate.quickEntry) {
            final button = tester.getRect(
              find.byKey(const ValueKey('widget_entry_button_size')),
            );
            expect(button.right, lessThan(rect.right));
            expect(button.center.dy, greaterThan(rect.center.dy - 12));
          }
        }
      });
    }
  }
}
