import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/assets_pages.dart';
import 'package:verifin/pages/currency_rates_page.dart';
import 'package:verifin/pages/ledger_books_page.dart';
import 'package:verifin/pages/sheets.dart';

import 'support/in_memory_ledger_repository.dart';
import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Future<void> pumpPage(
    WidgetTester tester,
    VeriFinController controller,
    Widget page,
  ) {
    return tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: page),
      ),
    );
  }

  testWidgets('货币选择器支持按代码和名称搜索', (tester) async {
    CurrencyDefinition? selected;
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showCurrencyPickerSheet(
                  context: context,
                  title: '选择货币',
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('currency_search_field')),
      'US Dollar',
    );
    await tester.pump();
    expect(find.text('USD'), findsOneWidget);
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    expect(selected?.code, 'USD');
  });

  testWidgets('新建账本同时选择本位币', (tester) async {
    final controller = await makeController();
    expect(
      controller.activeBook.currencySetupStatus,
      CurrencySetupStatus.confirmed,
    );
    await pumpPage(tester, controller, const LedgerBooksPage());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ledger_book_name_field')),
      '美元账本',
    );
    await tester.tap(find.textContaining('CNY ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger_book_save_button')));
    await tester.pumpAndSettle();

    expect(controller.activeBook.name, '美元账本');
    expect(controller.activeBook.baseCurrencyCode, 'USD');
    expect(find.textContaining('0 笔交易 · USD'), findsOneWidget);
  });

  testWidgets('新增账户可选择币种并按 minor unit 保存余额', (tester) async {
    final controller = await makeController();
    await pumpPage(tester, controller, const AddAccountPage());

    await tester.enterText(find.byType(TextFormField).first, '日元现金');
    await tester.tap(find.byKey(const Key('account_currency_select_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_JPY')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '12.7');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(controller.accounts.single.currencyCode, 'JPY');
    expect(controller.accounts.single.initialBalance, 13);
  });

  testWidgets('汇率管理页可保存十位精度的本地汇率', (tester) async {
    final controller = await makeController();
    await pumpPage(tester, controller, const CurrencyRatesPage());

    await tester.tap(find.byTooltip('添加汇率'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    for (final key in <String>['7', '.', '1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('number_key_$key')));
    }
    await tester.pump();
    expect(find.text('7.123456'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('number_pad_ok')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('汇率已保存'), findsOneWidget);
    expect(controller.exchangeRates.single.currencyCode, 'USD');
    expect(controller.exchangeRates.single.rateToBase, 7.123456);
    await tester.pumpAndSettle();
    expect(find.text('1 USD = 7.123456 CNY'), findsOneWidget);
    expect(find.textContaining('应用不会联网'), findsOneWidget);
  });

  testWidgets('旧账本从货币页完成一次性无换算重解释', (tester) async {
    final repository = InMemoryLedgerRepository();
    await repository.saveBooks(<LedgerBook>[
      LedgerBook(
        id: defaultLedgerBookId,
        name: '旧账本',
        createdAt: DateTime(2024),
        isDefault: true,
        currencySetupStatus: CurrencySetupStatus.legacyUnconfirmed,
      ),
    ]);
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repository,
    );
    await pumpPage(tester, controller, const CurrencyRatesPage());
    await tester.pumpAndSettle();

    expect(find.text('确认现有金额的币种'), findsWidgets);
    await tester.tap(find.text('现有金额其实是其他币种'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    expect(find.textContaining('所有数值保持不变'), findsOneWidget);
    await tester.tap(find.text('确认并应用'));
    await tester.pumpAndSettle();

    expect(controller.activeBook.baseCurrencyCode, 'USD');
    expect(
      controller.activeBook.currencySetupStatus,
      CurrencySetupStatus.confirmed,
    );
  });
}
