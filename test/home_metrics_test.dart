import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/home_metrics.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/home_metrics_settings_page.dart';

import 'support/test_harness.dart';

LedgerEntry _entry({
  required String id,
  required EntryType type,
  required double amount,
  required DateTime occurredAt,
  String accountId = 'a',
  bool reimbursable = false,
  double refundedAmount = 0,
}) {
  return LedgerEntry(
    id: id,
    bookId: 'book',
    type: type,
    amount: amount,
    categoryId: type == EntryType.transfer ? '' : 'c',
    accountId: accountId,
    note: '',
    occurredAt: occurredAt,
    reimbursable: reimbursable,
    refundedAmount: refundedAmount,
  );
}

Account _account({
  required String id,
  bool includeInAssets = true,
  bool hidden = false,
}) {
  return Account(
    id: id,
    bookId: 'book',
    name: id,
    type: AccountType.cash,
    groupId: null,
    initialBalance: 0,
    iconCode: 'wallet',
    note: '',
    includeInAssets: includeInAssets,
    hidden: hidden,
  );
}

void main() {
  group('cumulativeWeekWindowFor（累积展开窗口）', () {
    test('起点恒为 1 号，终点按 7 天步进', () {
      // 7 月有 31 天。
      expect(cumulativeWeekWindowFor(DateTime(2026, 7, 1)).end.day, 7);
      expect(cumulativeWeekWindowFor(DateTime(2026, 7, 7)).end.day, 7);
      expect(cumulativeWeekWindowFor(DateTime(2026, 7, 8)).end.day, 14);
      expect(cumulativeWeekWindowFor(DateTime(2026, 7, 14)).end.day, 14);
      expect(cumulativeWeekWindowFor(DateTime(2026, 7, 15)).end.day, 21);
      // 起点始终是 1 号。
      expect(cumulativeWeekWindowFor(DateTime(2026, 7, 15)).start.day, 1);
    });

    test('终点不超过当月最后一天', () {
      expect(cumulativeWeekWindowFor(DateTime(2026, 7, 30)).end.day, 31);
      // 2 月 28 天：29~31 号不存在，取 2026-02，末段封顶 28。
      expect(cumulativeWeekWindowFor(DateTime(2026, 2, 26)).end.day, 28);
    });
  });

  group('monthWindowFor（整月窗口）', () {
    test('1 号至当月最后一天', () {
      final w = monthWindowFor(DateTime(2026, 7, 15));
      expect(w.start.day, 1);
      expect(w.end.day, 31);
    });
  });

  group('sparseLabelsForWindow（稀疏日期标签）', () {
    test('天数少（≤8）时全部展示', () {
      final w = cumulativeWeekWindowFor(DateTime(2026, 7, 3)); // 1–7
      expect(sparseLabelsForWindow(w).where((s) => s.isNotEmpty).length, 7);
    });

    test('整月只在 1 号与每 5 天标注', () {
      final labels = sparseLabelsForWindow(
        monthWindowFor(DateTime(2026, 7, 1)),
      );
      expect(labels.length, 31);
      final labeledDays = <int>[
        for (var i = 0; i < labels.length; i++)
          if (labels[i].isNotEmpty) i + 1,
      ];
      expect(labeledDays, <int>[1, 5, 10, 15, 20, 25, 30]);
    });
  });

  group('computeHomeMetric', () {
    final now = DateTime(2026, 7, 15, 12);
    final entries = <LedgerEntry>[
      _entry(id: 'e1', type: EntryType.expense, amount: 100, occurredAt: now),
      _entry(
        id: 'e2',
        type: EntryType.income,
        amount: 300,
        occurredAt: DateTime(2026, 7, 10),
      ),
      _entry(
        id: 'e3',
        type: EntryType.expense,
        amount: 40,
        occurredAt: DateTime(2026, 6, 20),
      ),
      _entry(
        id: 'e4',
        type: EntryType.expense,
        amount: 200,
        occurredAt: DateTime(2026, 7, 5),
        reimbursable: true,
        refundedAmount: 50,
      ),
    ];
    final balances = <String, double>{'asset': 1000, 'debt': -300, 'x': 500};
    final accounts = <Account>[
      _account(id: 'asset'),
      _account(id: 'debt'),
      _account(id: 'x', includeInAssets: false),
    ];
    final ctx = HomeMetricContext(
      entries: entries,
      accounts: accounts,
      balanceOf: (account) => balances[account.id] ?? 0,
      now: now,
    );

    test('本月/今日/本年 收支结余按净额计算', () {
      // 本月支出：e1(100) + e4 净额(200-50=150) = 250。
      expect(computeHomeMetric(HomeMetric.monthExpense, ctx), 250);
      expect(computeHomeMetric(HomeMetric.monthIncome, ctx), 300);
      expect(computeHomeMetric(HomeMetric.monthNet, ctx), 50);
      expect(computeHomeMetric(HomeMetric.todayExpense, ctx), 100);
      expect(computeHomeMetric(HomeMetric.todayNet, ctx), -100);
      // 本年支出：100 + 40 + 150 = 290。
      expect(computeHomeMetric(HomeMetric.yearExpense, ctx), 290);
    });

    test('日均消费以本月已过天数为分母', () {
      expect(computeHomeMetric(HomeMetric.dailyAvgExpense, ctx), 250 / 15);
    });

    test('资产/负债/净资产只计入资产账户且负债取绝对值', () {
      expect(computeHomeMetric(HomeMetric.totalAssets, ctx), 1000);
      expect(computeHomeMetric(HomeMetric.totalLiabilities, ctx), 300);
      expect(computeHomeMetric(HomeMetric.netAssets, ctx), 700);
    });

    test('待报销 / 已报销', () {
      expect(computeHomeMetric(HomeMetric.reimbursablePending, ctx), 150);
      expect(computeHomeMetric(HomeMetric.reimbursed, ctx), 50);
    });
  });

  group('HomeTrendConfig 编解码', () {
    test('encode→decode 往返一致', () {
      const config = HomeTrendConfig(
        title: '我的概览',
        big: HomeMetric.netAssets,
        pill: HomeMetric.todayNet,
        card1: HomeMetric.weekExpense,
        card2: HomeMetric.yearIncome,
        card3: HomeMetric.reimbursablePending,
        series: HomeTrendSeries.net,
      );
      expect(HomeTrendConfig.decode(config.encode()), config);
    });

    test('空 / 损坏数据回落默认', () {
      expect(HomeTrendConfig.decode(null), HomeTrendConfig.defaults);
      expect(HomeTrendConfig.decode(''), HomeTrendConfig.defaults);
      expect(HomeTrendConfig.decode('not json'), HomeTrendConfig.defaults);
    });
  });

  group('controller 持久化', () {
    testWidgets('设置持久化、复位恢复默认', (tester) async {
      final controller = await makeController();
      expect(controller.homeTrendConfig, HomeTrendConfig.defaults);
      const custom = HomeTrendConfig(
        title: '资产视角',
        big: HomeMetric.netAssets,
        pill: HomeMetric.monthNet,
        card1: HomeMetric.totalAssets,
        card2: HomeMetric.totalLiabilities,
        card3: HomeMetric.todayExpense,
        series: HomeTrendSeries.income,
      );
      controller.setHomeTrendConfig(custom);
      expect(controller.homeTrendConfig, custom);
      controller.resetHomeTrendConfig();
      expect(controller.homeTrendConfig, HomeTrendConfig.defaults);
    });
  });

  group('HomeMetricsSettingsPage', () {
    Future<void> pumpPage(WidgetTester tester, dynamic controller) async {
      await tester.pumpWidget(
        VeriFinScope(
          controller: controller,
          child: zhMaterialApp(home: const HomeMetricsSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('点槽位选新指标即时保存', (tester) async {
      final controller = await makeController();
      await pumpPage(tester, controller);

      // 点「大数字」槽位打开选择弹窗（先滚到可见）。
      await tester.ensureVisible(find.text('大数字'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('大数字'));
      await tester.pumpAndSettle();
      // 选「日均收入」（默认各槽未使用它，弹窗内唯一）。
      await tester.ensureVisible(find.text('日均收入'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日均收入'));
      await tester.pumpAndSettle();

      expect(controller.homeTrendConfig.big, HomeMetric.dailyAvgIncome);
    });

    testWidgets('复位按钮恢复默认', (tester) async {
      final controller = await makeController();
      controller.setHomeTrendConfig(
        HomeTrendConfig.defaults.copyWith(big: HomeMetric.netAssets),
      );
      await pumpPage(tester, controller);

      await tester.tap(find.byKey(const Key('trend_reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();

      expect(controller.homeTrendConfig, HomeTrendConfig.defaults);
    });
  });
}
