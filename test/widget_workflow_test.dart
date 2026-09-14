import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/widget_gallery_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();
  testWidgets(
    'native preview failure shows a message without a fabricated replacement',
    (tester) async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('verifin/app'),
        (call) async {
          if (call.method == 'renderWidgetPreview') {
            throw PlatformException(code: 'WIDGET_PREVIEW_FAILED');
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
      expect(find.text('打开应用刷新'), findsNWidgets(4));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byTooltip('创建小组件'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
