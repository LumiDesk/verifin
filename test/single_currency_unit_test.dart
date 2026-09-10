// 「单币种隐藏单位」的界面覆盖：确认单位在单币种账本里真的不出现，
// 并且**多币种账本下依然出现**（防止收口过度，把该显示的地方也隐藏掉）。
//
// 覆盖范围见 docs/reviews/2026-09-10-single-currency-unit-leak-audit.md。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/amount_format.dart' as amount_format;
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/currency_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/l10n/app_localizations.dart';
import 'package:verifin/pages/account_detail_page.dart';
import 'package:verifin/pages/assets_pages.dart';
import 'package:verifin/pages/budget_pages.dart';
import 'package:verifin/pages/home_page.dart';
import 'package:verifin/pages/profile_pages.dart';
import 'package:verifin/pages/report_analysis_page.dart';
import 'package:verifin/pages/reports_page.dart';
import 'package:verifin/pages/transactions_pages.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  final l10n = lookupAppLocalizations(const Locale('zh'));

  Future<void> pumpPage(
    WidgetTester tester,
    VeriFinController controller,
    Widget page,
  ) {
    // 部分页面（首页/资产/我的）自身不返回 Scaffold，由根壳提供；单独 pump 时补一层，
    // 否则内部 InkWell 找不到 Material 祖先。
    return tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: Scaffold(body: page)),
      ),
    );
  }

  /// 给账本加一个外币账户，使 [VeriFinController.activeBookUsesMultipleCurrencies]
  /// 为真（闸门打开）。
  void addForeignAccount(VeriFinController controller, {String code = 'USD'}) {
    controller.addAccount(
      Account(
        id: 'foreign-$code',
        bookId: controller.activeBook.id,
        name: '美元现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 100,
        iconCode: 'cash',
        note: '',
        includeInAssets: true,
        hidden: false,
        currencyCode: code,
      ),
    );
  }

  group('单位文本入口（纯函数）', () {
    tearDown(() {
      amount_format.moneyUnitStyle = MoneyUnitStyle.symbol;
      amount_format.hideUnitInSingleCurrency = true;
      amount_format.activeBookUsesMultipleCurrencies = false;
    });

    test('单币种隐藏时：有前缀只留前缀，无前缀整条省略', () {
      amount_format.hideUnitInSingleCurrency = true;
      amount_format.activeBookUsesMultipleCurrencies = false;

      expect(textCurrencyUnitHidden, isTrue);
      expect(optionalCurrencyUnit('CNY'), isNull);
      // 书名/日期范围不能被单位一起带走。
      expect(currencyUnitSubtitle(l10n, '日常账本', 'CNY'), '日常账本');
      // 只有单位时返回 null，调用方据此整条省略副标题。
      expect(currencyUnitSubtitle(l10n, null, 'CNY'), isNull);
      expect(currencyUnitSubtitle(l10n, '', 'CNY'), isNull);
    });

    test('多币种账本下单位照常显示', () {
      amount_format.hideUnitInSingleCurrency = true;
      amount_format.activeBookUsesMultipleCurrencies = true;

      expect(textCurrencyUnitHidden, isFalse);
      expect(optionalCurrencyUnit('CNY'), '¥');
      expect(currencyUnitSubtitle(l10n, '日常账本', 'CNY'), '日常账本 · 单位：¥');
      expect(currencyUnitSubtitle(l10n, null, 'CNY'), '单位：¥');
    });

    test('开关关闭时单币种账本也显示单位', () {
      amount_format.hideUnitInSingleCurrency = false;
      amount_format.activeBookUsesMultipleCurrencies = false;

      expect(textCurrencyUnitHidden, isFalse);
      expect(currencyUnitSubtitle(l10n, '日常账本', 'CNY'), '日常账本 · 单位：¥');
    });
  });

  group('单币种账本：页头副标题不出现单位', () {
    testWidgets('首页只留账本名，不带「单位：」', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller, const HomePage());

      expect(find.text('日常账本'), findsOneWidget);
      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('看板页只留区间说明', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller, const ReportsPage());

      expect(find.text('预算与统计'), findsOneWidget);
      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('资产页整条副标题省略，不留「本位币」残句', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller, const AssetsPage());

      expect(find.textContaining('本位币'), findsNothing);
    });

    testWidgets('预算页只留周期标签', (tester) async {
      final controller = await makeController();
      await pumpPage(
        tester,
        controller,
        BudgetOverviewPage(
          initialMonth: controller.budgetKeyMonthFor(DateTime.now()),
        ),
      );

      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('预算设置页只留账本名', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller, const BudgetSettingsPage());

      expect(find.text('日常账本'), findsOneWidget);
      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('统计分析页只留区间标签', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller, const ReportAnalysisPage());

      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('交易明细页（按日）只留日期', (tester) async {
      final controller = await makeController();
      await pumpPage(
        tester,
        controller,
        TransactionsPage(initialDate: DateTime(2026, 9, 10)),
      );

      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('交易明细页（普通）整条副标题省略', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller, const TransactionsPage());

      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('账户详情页只留账户类型', (tester) async {
      final controller = await makeController();
      addForeignAccount(controller, code: 'CNY');
      final account = controller.accounts.first;
      await pumpPage(tester, controller, AccountDetailPage(account: account));

      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('账户报告页只留账户名', (tester) async {
      final controller = await makeController();
      addForeignAccount(controller, code: 'CNY');
      final account = controller.accounts.first;
      await pumpPage(tester, controller, AccountReportPage(account: account));

      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('收支统计页整条副标题省略', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller, const IncomeExpenseStatsPage());

      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('首页预算卡与日历卡角标不再渲染单位', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await makeController();
      await pumpPage(tester, controller, const HomePage());

      expect(find.textContaining('单位：'), findsNothing);
    });

    testWidgets('「货币与汇率」入口副标题不再显示币种', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await makeController();
      await pumpPage(tester, controller, const ProfilePage());

      expect(find.text('CNY'), findsNothing);
    });

    testWidgets('只有一个账本时账本列表行尾不带币种', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller, const LedgerBooksPage());

      expect(find.textContaining('CNY'), findsNothing);
    });
  });

  group('多币种账本：单位必须照常显示（反向保护）', () {
    testWidgets('首页副标题保留单位', (tester) async {
      final controller = await makeController();
      addForeignAccount(controller);
      await pumpPage(tester, controller, const HomePage());

      expect(find.text('日常账本 · 单位：¥'), findsOneWidget);
    });

    testWidgets('看板页副标题保留单位', (tester) async {
      final controller = await makeController();
      addForeignAccount(controller);
      await pumpPage(tester, controller, const ReportsPage());

      expect(find.text('预算与统计 · 单位：¥'), findsOneWidget);
    });

    testWidgets('资产页保留「本位币」提示', (tester) async {
      final controller = await makeController();
      addForeignAccount(controller);
      await pumpPage(tester, controller, const AssetsPage());

      expect(find.text('本位币 ¥'), findsOneWidget);
    });

    testWidgets('账户详情页保留账户币种单位', (tester) async {
      final controller = await makeController();
      addForeignAccount(controller);
      final account = controller.accounts.firstWhere(
        (item) => item.currencyCode == 'USD',
      );
      await pumpPage(tester, controller, AccountDetailPage(account: account));

      expect(find.textContaining('单位：'), findsOneWidget);
    });

    testWidgets('多个账本时列表行尾保留币种以区分口径', (tester) async {
      final controller = await makeController();
      controller.addLedgerBook('美元账本', baseCurrencyCode: 'USD');
      await pumpPage(tester, controller, const LedgerBooksPage());

      expect(find.textContaining('CNY'), findsOneWidget);
      expect(find.textContaining('USD'), findsOneWidget);
    });
  });

  group('账目列表与退款表单', () {
    testWidgets('同币种转账不再出现「100 ¥ → 100 ¥」换算副行', (tester) async {
      final controller = await makeController();
      final bookId = controller.activeBook.id;
      controller
        ..addAccount(
          Account(
            id: 'a1',
            bookId: bookId,
            name: '招行',
            type: AccountType.debitCard,
            groupId: null,
            initialBalance: 0,
            iconCode: 'wallet',
            note: '',
            includeInAssets: true,
            hidden: false,
          ),
        )
        ..addAccount(
          Account(
            id: 'a2',
            bookId: bookId,
            name: '现金',
            type: AccountType.cash,
            groupId: null,
            initialBalance: 0,
            iconCode: 'cash',
            note: '',
            includeInAssets: true,
            hidden: false,
          ),
        )
        ..addEntry(
          LedgerEntry(
            id: 't1',
            bookId: bookId,
            type: EntryType.transfer,
            amount: 100,
            categoryId: '',
            accountId: 'a1',
            toAccountId: 'a2',
            note: '',
            occurredAt: DateTime.now(),
          ),
        );
      await pumpPage(tester, controller, const TransactionsPage());

      // 账户名标签里的「招行 → 现金」是正常信息，这里只要求不再出现带单位的换算副行。
      expect(find.textContaining('¥'), findsNothing);
      expect(find.textContaining('→'), findsWidgets);
    });

    testWidgets('退款表单两端金额不再重复单位', (tester) async {
      await tester.binding.setSurfaceSize(const Size(460, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await makeController();
      final bookId = controller.activeBook.id;
      controller
        ..addAccount(
          Account(
            id: 'a1',
            bookId: bookId,
            name: '招行',
            type: AccountType.debitCard,
            groupId: null,
            initialBalance: 1000,
            iconCode: 'wallet',
            note: '',
            includeInAssets: true,
            hidden: false,
          ),
        )
        ..addEntry(
          LedgerEntry(
            id: 'e1',
            bookId: bookId,
            type: EntryType.expense,
            amount: 100,
            categoryId: 'dining',
            accountId: 'a1',
            note: '',
            occurredAt: DateTime.now(),
          ),
        );
      await pumpPage(
        tester,
        controller,
        const TransactionDetailPage(entryId: 'e1'),
      );
      await tester.tap(find.text('添加退款'));
      await tester.pumpAndSettle();

      // 同屏顶部的退款金额与下面两端金额都不带单位。
      expect(find.textContaining('¥'), findsNothing);
    });
  });
}
