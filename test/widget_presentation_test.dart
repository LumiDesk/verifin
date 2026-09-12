import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/widget_config.dart';
import 'package:verifin/app/widget_presentation.dart';

void main() {
  final now = DateTime(2026, 9, 12);
  final book = LedgerBook(
    id: 'book',
    name: '个人',
    createdAt: DateTime(2026),
    isDefault: true,
  );
  LedgerEntry expense(String id, double amount, DateTime date) => LedgerEntry(
    id: id,
    bookId: book.id,
    type: EntryType.expense,
    amount: amount,
    categoryId: 'food',
    accountId: 'cash',
    note: '',
    occurredAt: date,
  );
  final snapshot = WidgetLedgerSnapshot(
    book: book,
    entries: [
      expense('old', 80, DateTime(2026, 8, 26)),
      expense('today', 37, now),
    ],
    accounts: [
      Account(
        id: 'cash',
        bookId: book.id,
        name: '现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 1000,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      ),
    ],
    rates: const [],
    budgetWindow: DateWindow(
      start: DateTime(2026, 9),
      end: DateTime(2026, 9, 30),
    ),
    budget: 100,
  );

  test('主值与曲线使用所选日期内真实数据', () {
    final week = buildWidgetPresentation(
      definition: const UserWidgetDefinition(
        id: 'week',
        name: '本周',
        template: WidgetTemplate.trend,
        chartMetric: WidgetChartMetric.expense,
        dateRange: WidgetDateRange.sevenDays,
      ),
      snapshot: snapshot,
      now: now,
    );
    final month = buildWidgetPresentation(
      definition: const UserWidgetDefinition(
        id: 'month',
        name: '本月',
        template: WidgetTemplate.trend,
        chartMetric: WidgetChartMetric.expense,
      ),
      snapshot: snapshot,
      now: now,
    );
    expect(week.primary.value, 37);
    expect(week.series, [0, 0, 0, 0, 0, 0, 37]);
    expect(month.primary.value, 117);
    expect(month.series.whereType<double>().reduce((a, b) => a + b), 117);
  });

  test('预算进度与净资产没有假百分比或错误支出回退', () {
    final budget = buildWidgetPresentation(
      definition: const UserWidgetDefinition(
        id: 'budget',
        name: '预算',
        template: WidgetTemplate.budget,
      ),
      snapshot: snapshot,
      now: now,
    );
    final assets = buildWidgetPresentation(
      definition: const UserWidgetDefinition(
        id: 'assets',
        name: '资产',
        template: WidgetTemplate.netWorth,
      ),
      snapshot: snapshot,
      now: now,
    );
    expect(budget.primary.value, 63);
    expect(budget.budgetUsage, .37);
    expect(assets.primary.value, 883);
  });

  test('旧尺寸迁移与行列命名保持一致', () {
    expect(widgetSizeAspect(WidgetSize.twoByTwo), 1);
    expect(widgetSizeAspect(WidgetSize.oneByTwo), 2);
    expect(widgetSizeAspect(WidgetSize.twoByFour), 2);
    expect(supportedWidgetSize(WidgetSize.oneByOne), WidgetSize.oneByTwo);
    expect(supportedWidgetSize(WidgetSize.fourByTwo), WidgetSize.twoByFour);
  });
}
