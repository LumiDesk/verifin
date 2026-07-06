import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/main.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('shows the privacy consent dialog on first launch', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, null, false);
    await tester.pumpAndSettle();

    expect(find.text('隐私政策与用户协议'), findsOneWidget);
    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('不同意并退出'), findsOneWidget);
  });

  testWidgets('accepting the consent dialog persists and dismisses it', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await pumpApp(tester, store, false);
    await tester.pumpAndSettle();

    expect(controller.privacyConsentAccepted, isFalse);

    await tester.tap(find.byKey(const Key('privacy_consent_accept')));
    await tester.pumpAndSettle();

    expect(find.text('隐私政策与用户协议'), findsNothing);
    expect(controller.privacyConsentAccepted, isTrue);

    // 重启（同一 store 复用仓储）后不再询问。
    final reloaded = await makeController(store);
    expect(reloaded.privacyConsentAccepted, isTrue);
  });

  testWidgets('does not show consent dialog when already accepted', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('隐私政策与用户协议'), findsNothing);
  });

  testWidgets('consent keeps blocking after declining and relaunching', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    await pumpApp(tester, store, false);
    await tester.pumpAndSettle();
    expect(find.text('隐私政策与用户协议'), findsOneWidget);
    expect(find.text('不同意并退出'), findsOneWidget);

    // 模拟未同意就退出、进程未被杀而重新进入（同一 store 重建应用）：仍要求同意，
    // 不会像旧的一次性弹窗那样在热启动后漏掉。
    final relaunched = await makeController(store, false);
    await tester.pumpWidget(VeriFinApp(controller: relaunched));
    await tester.pumpAndSettle();
    expect(find.text('隐私政策与用户协议'), findsOneWidget);
    expect(relaunched.privacyConsentAccepted, isFalse);
  });

  testWidgets('can view privacy policy and user agreement from settings', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);

    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();

    expect(find.textContaining('我们不收集你的个人信息'), findsOneWidget);
  });
}
