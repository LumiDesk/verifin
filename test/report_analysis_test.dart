import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/demo_data.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/report_analysis.dart';

LedgerEntry entry({
  required String id,
  required EntryType type,
  required double amount,
  required String categoryId,
  required DateTime occurredAt,
  double refundedAmount = 0,
}) {
  return LedgerEntry(
    id: id,
    bookId: 'default',
    type: type,
    amount: amount,
    categoryId: categoryId,
    accountId: 'cash',
    note: '',
    occurredAt: occurredAt,
    refundedAmount: refundedAmount,
  );
}

void main() {
  final categories = defaultCategories;

  group('ReportRange', () {
    test('month range covers whole natural month', () {
      final range = ReportRange.month(DateTime(2026, 2, 15));
      expect(range.start, DateTime(2026, 2, 1));
      expect(range.end, DateTime(2026, 2, 28));
      expect(range.dayCount, 28);
      expect(range.mode, ReportRangeMode.month);
    });

    test('year range covers whole year', () {
      final range = ReportRange.year(2026);
      expect(range.start, DateTime(2026, 1, 1));
      expect(range.end, DateTime(2026, 12, 31));
      expect(range.dayCount, 365);
    });

    test('custom range normalizes reversed bounds and strips time', () {
      final range = ReportRange.custom(
        DateTime(2026, 3, 10, 23, 59),
        DateTime(2026, 3, 1, 8),
      );
      expect(range.start, DateTime(2026, 3, 1));
      expect(range.end, DateTime(2026, 3, 10));
      expect(range.dayCount, 10);
    });
  });

  test('reportSummary nets income and expense, ignores transfer', () {
    final entries = <LedgerEntry>[
      entry(
        id: 'a',
        type: EntryType.income,
        amount: 1000,
        categoryId: 'salary',
        occurredAt: DateTime(2026, 5, 1),
      ),
      entry(
        id: 'b',
        type: EntryType.expense,
        amount: 300,
        categoryId: 'dining',
        occurredAt: DateTime(2026, 5, 2),
        refundedAmount: 100,
      ),
      LedgerEntry(
        id: 'c',
        bookId: 'default',
        type: EntryType.transfer,
        amount: 500,
        categoryId: 'transfer_out',
        accountId: 'cash',
        toAccountId: 'bank',
        note: '',
        occurredAt: DateTime(2026, 5, 3),
      ),
    ];
    final summary = reportSummary(entries);
    expect(summary.income, 1000);
    expect(summary.expense, 200); // 300 - 100 refunded
    expect(summary.net, 800);
    expect(summary.incomeCount, 1);
    expect(summary.expenseCount, 1);
    expect(summary.entryCount, 2);
  });

  test('reportCategoryStats aggregates by type and sorts desc', () {
    final entries = <LedgerEntry>[
      entry(
        id: 'e1',
        type: EntryType.expense,
        amount: 100,
        categoryId: 'dining',
        occurredAt: DateTime(2026, 5, 1),
      ),
      entry(
        id: 'e2',
        type: EntryType.expense,
        amount: 300,
        categoryId: 'transport',
        occurredAt: DateTime(2026, 5, 2),
      ),
      entry(
        id: 'i1',
        type: EntryType.income,
        amount: 5000,
        categoryId: 'salary',
        occurredAt: DateTime(2026, 5, 3),
      ),
    ];
    final expenseStats = reportCategoryStats(
      entries,
      categories,
      EntryType.expense,
    );
    expect(expenseStats.length, 2);
    expect(expenseStats.first.category.id, 'transport');
    expect(expenseStats.first.amount, 300);
    expect(expenseStats.first.percent, closeTo(0.75, 1e-9));

    final incomeStats = reportCategoryStats(
      entries,
      categories,
      EntryType.income,
    );
    expect(incomeStats.length, 1);
    expect(incomeStats.first.category.id, 'salary');
    expect(incomeStats.first.percent, closeTo(1.0, 1e-9));
  });

  group('reportTrend', () {
    test('short custom range is daily and buckets by day', () {
      final range = ReportRange.custom(
        DateTime(2026, 5, 1),
        DateTime(2026, 5, 5),
      );
      final entries = <LedgerEntry>[
        entry(
          id: 'e1',
          type: EntryType.expense,
          amount: 40,
          categoryId: 'dining',
          occurredAt: DateTime(2026, 5, 2, 10),
        ),
        entry(
          id: 'e2',
          type: EntryType.expense,
          amount: 60,
          categoryId: 'dining',
          occurredAt: DateTime(2026, 5, 2, 20),
        ),
        entry(
          id: 'skip',
          type: EntryType.income,
          amount: 999,
          categoryId: 'salary',
          occurredAt: DateTime(2026, 5, 2),
        ),
      ];
      final trend = reportTrend(entries, range, EntryType.expense);
      expect(trend.granularity, ReportTrendGranularity.daily);
      expect(trend.points.length, 5);
      expect(trend.values[1], 100); // May 2 = 40 + 60
      expect(trend.maxValue, 100);
    });

    test('year range is monthly with 12 buckets', () {
      final range = ReportRange.year(2026);
      final entries = <LedgerEntry>[
        entry(
          id: 'jan',
          type: EntryType.expense,
          amount: 200,
          categoryId: 'dining',
          occurredAt: DateTime(2026, 1, 15),
        ),
        entry(
          id: 'dec',
          type: EntryType.expense,
          amount: 500,
          categoryId: 'dining',
          occurredAt: DateTime(2026, 12, 31),
        ),
        entry(
          id: 'other-year',
          type: EntryType.expense,
          amount: 999,
          categoryId: 'dining',
          occurredAt: DateTime(2025, 12, 31),
        ),
      ];
      final trend = reportTrend(entries, range, EntryType.expense);
      expect(trend.granularity, ReportTrendGranularity.monthly);
      expect(trend.points.length, 12);
      expect(trend.values.first, 200);
      expect(trend.values.last, 500);
    });

    test('range spanning several months aggregates monthly', () {
      final range = ReportRange.custom(
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 30),
      );
      final entries = <LedgerEntry>[
        entry(
          id: 'feb',
          type: EntryType.expense,
          amount: 80,
          categoryId: 'dining',
          occurredAt: DateTime(2026, 2, 10),
        ),
      ];
      final trend = reportTrend(entries, range, EntryType.expense);
      expect(trend.granularity, ReportTrendGranularity.monthly);
      expect(trend.points.length, 4);
      expect(trend.values[1], 80);
    });
  });
}
