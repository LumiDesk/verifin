import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/widget_gallery_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('verifin/app'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('verifin/app'), null);
  });

  testWidgets(
    'gallery displays provider pixels and requests the correct native sizes',
    (tester) async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      final bytes = File(
        'android/app/src/main/res/drawable-nodpi/widget_preview_quick_entry.png',
      ).readAsBytesSync();
      final calls = <Map<dynamic, dynamic>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('verifin/app'),
        (call) async {
          if (call.method == 'renderWidgetPreview') {
            calls.add(call.arguments as Map);
            return bytes;
          }
          return null;
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
          child: zhMaterialApp(home: const WidgetGalleryPage()),
        ),
      );
      await tester.pumpAndSettle();
      final byTemplate = {for (final call in calls) call['template']: call};
      expect(byTemplate.keys.toSet(), {
        'quick_entry',
        'budget',
        'net_worth',
        'trend',
      });
      expect(byTemplate['quick_entry']!['heightDp'], 72);
      expect(
        byTemplate['budget']!['heightDp'],
        byTemplate['budget']!['widthDp'],
      );
      expect(
        byTemplate['net_worth']!['heightDp'],
        byTemplate['net_worth']!['widthDp'],
      );
      expect(
        byTemplate['trend']!['widthDp'],
        (byTemplate['budget']!['widthDp'] as int) * 2 + 12,
      );
      for (final template in byTemplate.keys) {
        final image = tester.widget<Image>(
          find.byKey(ValueKey('native_widget_preview_$template')),
        );
        expect((image.image as MemoryImage).bytes, orderedEquals(bytes));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop widget page is a read-only template gallery', (
    tester,
  ) async {
    await pumpApp(tester);
    // 入口在「我的 → 数据与工具」宫格里。
    await tapBottomTab(tester, 3);
    await tester.scrollUntilVisible(
      find.text('桌面小组件'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('桌面小组件'));
    await tester.pumpAndSettle();

    expect(find.text('桌面小组件'), findsOneWidget);
    expect(find.text('查看 VeriFin 提供的固定组件样式'), findsOneWidget);
    expect(find.text('我的小组件'), findsNothing);
    expect(find.byTooltip('创建小组件'), findsNothing);
    expect(find.text('保存到我的小组件'), findsNothing);
  });
}
