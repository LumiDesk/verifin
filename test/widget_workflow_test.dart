import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/app/widget_config.dart';
import 'package:verifin/pages/widget_design_preview.dart';
import 'package:verifin/pages/widget_gallery_page.dart';

import 'support/test_harness.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is SelectField && widget.label == label,
);

void main() {
  useTestDatabases();

  testWidgets('创建保存编辑菜单和桌面添加走完整流程', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await makeController();
    addTearDown(controller.dispose);
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('verifin/app'),
      (call) async {
        calls.add(call);
        return call.method == 'pinUserWidget' ? true : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('verifin/app'),
        null,
      ),
    );
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.dark),
          home: const WidgetGalleryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已保存的小组件'), findsNothing);
    expect(find.textContaining('从下方'), findsNothing);
    expect(find.text('点击右上角加号，创建你的第一个财务小组件'), findsOneWidget);
    expect(find.text('编辑'), findsNothing);

    await tester.tap(find.byTooltip('创建小组件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('基于模板创建').first);
    await tester.pumpAndSettle();
    expect(find.byType(UserWidgetEditorPage), findsOneWidget);
    expect(find.text('保存到我的小组件'), findsNothing);
    expect(find.byTooltip('保存'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '我的日常');
    await tester.pump();
    final preview = tester.getSize(
      find.byKey(
        ValueKey(
          'widget_surface_${tester.widget<WidgetDesignPreview>(find.byType(WidgetDesignPreview)).definition.id}',
        ),
      ),
    );
    expect(preview.width, closeTo(preview.height, .01));

    await tester.ensureVisible(field('桌面尺寸'));
    await tester.tap(field('桌面尺寸'));
    await tester.pumpAndSettle();
    expect(find.text('1 × 1'), findsNothing);
    expect(find.text('4 × 1'), findsNothing);
    expect(find.text('4 × 2'), findsNothing);
    await tester.tap(find.text('1 × 2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.userWidgetDefinitions.single.name, '我的日常');
    expect(controller.userWidgetDefinitions.single.chartMetric, isNull);
    final id = controller.userWidgetDefinitions.single.id;
    await tester.tap(find.byKey(ValueKey('widget_tile_$id')));
    await tester.pumpAndSettle();
    expect(find.byType(UserWidgetEditorPage), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('背景'),
      220,
      scrollable: firstVerticalScrollable(),
    );
    await tester.tap(find.text('背景'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('veri_menu_item_widget_background_local')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(4, 420));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('添加到桌面'),
      200,
      scrollable: firstVerticalScrollable(),
    );
    await tester.tap(find.text('添加到桌面'));
    await tester.pumpAndSettle();
    expect(
      calls.where((call) => call.method == 'pinUserWidget').single.arguments,
      {'definitionId': id},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('有数据时长按删除不递归并支持取消确认和自动补位', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await makeController();
    addTearDown(c.dispose);
    await c.saveUserWidgetDefinitions(const [
      UserWidgetDefinition(
        id: 'first',
        name: '日常支出',
        template: WidgetTemplate.quickEntry,
      ),
      UserWidgetDefinition(
        id: 'second',
        name: '资产概览',
        template: WidgetTemplate.netWorth,
      ),
    ]);
    await tester.pumpWidget(
      VeriFinScope(
        controller: c,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.dark),
          home: const WidgetGalleryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final firstPosition = tester.getTopLeft(
      find.byKey(const ValueKey('widget_tile_first')),
    );
    await tester.longPress(find.byKey(const ValueKey('widget_tile_first')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('widget_delete_first')), findsOneWidget);
    expect(find.byKey(const ValueKey('widget_delete_second')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('widget_delete_first')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(c.userWidgetDefinitions, hasLength(2));
    await tester.tap(find.byKey(const ValueKey('widget_delete_first')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(c.userWidgetDefinitions.single.id, 'second');
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('widget_tile_second'))),
      firstPosition,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('编辑态点击画布空白退出，长按组件只显示当前删除入口', (tester) async {
    final c = await makeController();
    addTearDown(c.dispose);
    await c.saveUserWidgetDefinitions(const [
      UserWidgetDefinition(
        id: 'only',
        name: '唯一组件',
        template: WidgetTemplate.quickEntry,
      ),
    ]);
    await tester.pumpWidget(
      VeriFinScope(
        controller: c,
        child: zhMaterialApp(home: const WidgetGalleryPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('widget_tile_only')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('widget_delete_only')), findsOneWidget);
    // The right half of a one-column tile is intentionally empty canvas.
    final tileRect = tester.getRect(
      find.byKey(const ValueKey('widget_tile_only')),
    );
    await tester.tapAt(Offset(tileRect.right + 20, tileRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('widget_delete_only')), findsNothing);
  });

  testWidgets('拖动重新排序后保存顺序', (tester) async {
    final c = await makeController();
    addTearDown(c.dispose);
    await c.saveUserWidgetDefinitions(const [
      UserWidgetDefinition(
        id: 'a',
        name: 'A',
        template: WidgetTemplate.quickEntry,
      ),
      UserWidgetDefinition(
        id: 'b',
        name: 'B',
        template: WidgetTemplate.quickEntry,
      ),
    ]);
    await tester.pumpWidget(
      VeriFinScope(
        controller: c,
        child: zhMaterialApp(home: const WidgetGalleryPage()),
      ),
    );
    await tester.pumpAndSettle();
    final a = find.byKey(const ValueKey('widget_tile_a'));
    final b = find.byKey(const ValueKey('widget_tile_b'));
    await tester.longPress(a);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(a));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(b));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.userWidgetDefinitions.map((item) => item.id), ['b', 'a']);
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
