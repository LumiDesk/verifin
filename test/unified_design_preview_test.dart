import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

/// 同一业务路径同时用于默认外观和显式设计预览构建，避免为候选设计复制页面。
void main() {
  useTestDatabases();
  for (final width in [360.0, 393.0]) {
    for (final theme in [ThemePreference.light, ThemePreference.dark]) {
      testWidgets('真实页面 $width ${theme.name} 导航、菜单和保存可用', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 852);
        addTearDown(tester.view.reset);
        final controller = await pumpApp(tester);
        controller.setThemePreference(theme);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await addTestAccount(tester, '预览账户');
        expect(controller.accounts.single.name, '预览账户');
        for (final tab in [2, 3, 0]) {
          await tapBottomTab(tester, tab);
          expect(tester.takeException(), isNull);
        }
        await createQuickEntry(tester);
        expect(tester.takeException(), isNull);
        final save = find.byKey(const Key('save_entry_button'));
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(852));
        await tester.tap(save);
        await tester.pumpAndSettle();
        await controller.waitForPendingWrites();
        expect(controller.entries.single.amount, 45);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
