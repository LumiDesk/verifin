import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/l10n/app_localizations.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/onboarding_page.dart';

import 'support/test_harness.dart';

Future<void> _pumpOnboarding(
  WidgetTester tester,
  dynamic controller, {
  Locale locale = const Locale('zh'),
}) async {
  await tester.pumpWidget(
    VeriFinScope(
      controller: controller,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Navigator(
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  useTestDatabases();

  testWidgets('引导走完创建账户与预算并标记完成', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    // acceptConsent=false：不预置 onboarding 标记，模拟新用户。
    final controller = await makeController(store, false);

    await _pumpOnboarding(tester, controller);

    expect(find.text('欢迎使用 Veri Fin'), findsOneWidget);

    // 第 1 步 → 账户步骤。
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('CNY'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_base_currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    expect(find.text('USD'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('onboarding_account_name')),
      '现金',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding_account_balance')),
      '500',
    );

    // → 预算步骤。
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboarding_budget')), '3000');

    // → 完成步骤。
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('一切就绪'), findsOneWidget);

    // 完成。
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    expect(controller.onboardingCompleted, isTrue);
    expect(controller.accounts.any((a) => a.name == '现金'), isTrue);
    expect(controller.activeBook.baseCurrencyCode, 'USD');
    expect(
      controller.accounts.firstWhere((a) => a.name == '现金').currencyCode,
      'USD',
    );
    expect(controller.monthlyBudget(DateTime.now()), 3000);

    controller.dispose();
  });

  testWidgets('非中文引导默认选择 USD 本位币', (WidgetTester tester) async {
    final controller = await makeController(LocalKeyValueStore(), false);

    await _pumpOnboarding(tester, controller, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('跳过引导只标记完成不建数据', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store, false);

    await _pumpOnboarding(tester, controller);

    final accountsBefore = controller.accounts.length;
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();

    expect(controller.onboardingCompleted, isTrue);
    expect(controller.accounts.length, accountsBefore);

    controller.dispose();
  });
}
