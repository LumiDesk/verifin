import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/l10n/app_localizations_zh.dart';
import 'package:verifin/app/amount_format.dart' as amount_format;
import 'package:verifin/app/credit_card.dart';
import 'package:verifin/app/image_cropper.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/series_math.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('DateWindow.days 正常区间含首尾，逆序区间返回空不崩溃', () {
    final normal = DateWindow(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 3),
    ).days;
    expect(normal.length, 3);
    expect(normal.first, DateTime(2026, 7, 1));
    expect(normal.last, DateTime(2026, 7, 3));

    // end 早于 start：不再抛异常，返回空列表。
    final reversed = DateWindow(
      start: DateTime(2026, 7, 3),
      end: DateTime(2026, 7, 1),
    ).days;
    expect(reversed, isEmpty);
  });

  test('weekWindowFor 覆盖周一至周日（含跨月的周）', () {
    // 2026-07-10 是周五，本周为 07-06(周一)~07-12(周日)。
    final w = weekWindowFor(DateTime(2026, 7, 10, 15));
    expect(w.start, DateTime(2026, 7, 6));
    expect(w.end, DateTime(2026, 7, 12));
    expect(w.days.length, 7);

    // 跨月：2026-08-01 是周六，本周应从 07-27 起。
    final cross = weekWindowFor(DateTime(2026, 8, 1));
    expect(cross.start, DateTime(2026, 7, 27));
    expect(cross.end, DateTime(2026, 8, 2));
  });

  test('quarterWindowFor / quarterOfMonth 覆盖整季', () {
    expect(quarterOfMonth(7), 3);
    final q3 = quarterWindowFor(DateTime(2026, 8, 15));
    expect(q3.start, DateTime(2026, 7, 1));
    expect(q3.end, DateTime(2026, 9, 30));

    final q1 = quarterWindowFor(DateTime(2026, 2, 3));
    expect(q1.start, DateTime(2026, 1, 1));
    expect(q1.end, DateTime(2026, 3, 31));
  });

  test('monthlyNetValuesForType 按月聚合指定类型、只算当年、用净额', () {
    LedgerEntry expense(
      String id,
      DateTime at,
      double amount, {
      double refunded = 0,
    }) => LedgerEntry(
      id: id,
      bookId: 'b',
      type: EntryType.expense,
      amount: amount,
      categoryId: 'c',
      accountId: 'a',
      note: '',
      occurredAt: at,
      refundedAmount: refunded,
    );
    final entries = <LedgerEntry>[
      expense('a', DateTime(2026, 1, 5), 100),
      expense('b', DateTime(2026, 1, 20), 50, refunded: 20), // 净 30
      expense('c', DateTime(2026, 3, 8), 200),
      expense('d', DateTime(2025, 3, 8), 999), // 去年，不计
      LedgerEntry(
        id: 'inc',
        bookId: 'b',
        type: EntryType.income,
        amount: 300,
        categoryId: 'c',
        accountId: 'a',
        note: '',
        occurredAt: DateTime(2026, 1, 9),
      ),
    ];
    final values = monthlyNetValuesForType(entries, 2026, EntryType.expense);
    expect(values.length, 12);
    expect(values[0], 130); // 1 月：100 + 30
    expect(values[2], 200); // 3 月
    expect(values[5], 0); // 6 月无数据
  });

  test('android package name is not the Flutter template package', () async {
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/top/talyra42/verifin/MainActivity.kt',
    ).readAsStringSync();

    expect(buildGradle, contains('applicationId = "top.talyra42.verifin"'));
    expect(buildGradle, isNot(contains('com.example.verifin')));
    expect(mainActivity, contains('package top.talyra42.verifin'));
  });

  test('account balance series keeps history baseline and sign', () async {
    final now = DateTime.now();
    final account = Account(
      id: 'acc-series',
      bookId: 'default',
      name: '测试卡',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 100,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    final lastMonth = DateTime(
      now.year,
      now.month,
    ).subtract(const Duration(days: 1));
    final entries = <LedgerEntry>[
      LedgerEntry(
        id: 'prior',
        bookId: 'default',
        type: EntryType.expense,
        amount: 300,
        categoryId: 'dining',
        accountId: account.id,
        note: '',
        occurredAt: lastMonth,
      ),
      LedgerEntry(
        id: 'current',
        bookId: 'default',
        type: EntryType.expense,
        amount: 50,
        categoryId: 'dining',
        accountId: account.id,
        note: '',
        occurredAt: DateTime(now.year, now.month, 1, 10),
      ),
    ];

    final values = accountBalanceSeries(account, entries);

    expect(values.first, -250);
    expect(values.last, -250);
  });

  test('monthly net asset series includes prior year history', () async {
    final now = DateTime.now();
    final account = Account(
      id: 'acc-net',
      bookId: 'default',
      name: '测试卡',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 100,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    final entries = <LedgerEntry>[
      LedgerEntry(
        id: 'last-year',
        bookId: 'default',
        type: EntryType.expense,
        amount: 300,
        categoryId: 'dining',
        accountId: account.id,
        note: '',
        occurredAt: DateTime(now.year - 1, 12, 31, 12),
      ),
    ];

    final values = monthlyNetAssetSeries(<Account>[account], entries);

    expect(values.first, -200);
    expect(values.last, -200);
  });

  test('bookkeeping duration switches to years after one year', () async {
    final l10n = AppLocalizationsZh();
    expect(bookkeepingDurationStat(l10n, 20), ('20', '记账天数'));
    expect(bookkeepingDurationStat(l10n, 365), ('365', '记账天数'));
    expect(bookkeepingDurationStat(l10n, 438), ('1.2', '记账年数'));
    expect(bookkeepingDurationStat(l10n, 730), ('2', '记账年数'));
  });

  test('cropper pan shift maps offset=±1 exactly to the image edge', () async {
    // 200x100 横图放进 100x100 取景框：cover 缩放为 1，
    // zoom=1 时可视区为源图中央 100x100，
    // 水平最大平移 = (200-100)/2 = 50 显示像素，垂直无可平移空间。
    const source = Size(200, 100);
    const box = Size(100, 100);

    final atZoom1 = cropperPanShift(sourceSize: source, boxSize: box, zoom: 1);
    expect(atZoom1.dx, closeTo(50, 0.001));
    expect(atZoom1.dy, closeTo(0, 0.001));

    // zoom=2 时可视区 50x50（源像素），显示比例变为 2：
    // 水平 (200-50)/2=75 源像素 × 2 = 150；垂直 (100-50)/2=25 × 2 = 50。
    // 该映射与实际裁剪(cropImageDataUrl)一致：offset=±1 恰好把裁剪窗口
    // 推到图片边缘，预览不会露出图片外的区域。
    final atZoom2 = cropperPanShift(sourceSize: source, boxSize: box, zoom: 2);
    expect(atZoom2.dx, closeTo(150, 0.001));
    expect(atZoom2.dy, closeTo(50, 0.001));

    // 竖图：只有垂直方向可平移。
    final tall = cropperPanShift(
      sourceSize: const Size(100, 300),
      boxSize: box,
      zoom: 1,
    );
    expect(tall.dx, closeTo(0, 0.001));
    expect(tall.dy, closeTo(100, 0.001));

    // 尺寸未知/非法时不平移。
    expect(
      cropperPanShift(sourceSize: Size.zero, boxSize: box, zoom: 1),
      Offset.zero,
    );
  });

  test('formatAmount respects the global two-decimals preference', () {
    addTearDown(() => amount_format.amountForceTwoDecimals = false);

    // 默认：去掉多余尾随零。
    amount_format.amountForceTwoDecimals = false;
    expect(formatAmount(12), '12');
    expect(formatAmount(12.5), '12.5');
    expect(formatAmount(12.34), '12.34');
    expect(formatAmount(0), '0');

    // 强制两位小数。
    amount_format.amountForceTwoDecimals = true;
    expect(formatAmount(12), '12.00');
    expect(formatAmount(12.5), '12.50');
    expect(formatAmount(12.34), '12.34');
    expect(formatAmount(0), '0.00');
    // 派生格式化同步生效。
    expect(formatExpenseAmount(12), '-12.00');
    expect(formatIncomeAmount(12.5), '12.50');
    expect(formatSignedAmount(12), '+12.00');
  });

  test('cardLast4Of 取完整卡号末四位数字', () {
    expect(cardLast4Of('6222 0000 0000 1234'), '1234');
    expect(cardLast4Of('621226123456'), '3456');
    expect(cardLast4Of('12'), '12');
    expect(cardLast4Of(''), '');
    expect(cardLast4Of('卡号1234'), '1234');
  });

  test('initialCardLast4Follows 由数据反推跟随开关初始态', () {
    // 新账户：两者皆空 → 跟随（默认打开）。
    expect(initialCardLast4Follows('', ''), isTrue);
    // 仅手填后四位、无完整卡号 → 不跟随（保留手填值）。
    expect(initialCardLast4Follows('', '8888'), isFalse);
    // 完整卡号存在且后四位正是其末四位 → 跟随。
    expect(initialCardLast4Follows('6222000000001234', '1234'), isTrue);
    // 完整卡号存在但后四位是另设的值 → 不跟随。
    expect(initialCardLast4Follows('6222000000001234', '9999'), isFalse);
  });

  test('信用额度：已用与可用', () {
    // 欠款 = 负余额绝对值。
    expect(usedCredit(-3200), 3200);
    // 余额为正（存入/超额还款）时已用为 0。
    expect(usedCredit(500), 0);
    // 可用 = 额度 − 已用。
    expect(availableCredit(5000, -3200), 1800);
    expect(availableCredit(5000, 0), 5000);
    // 未设额度返回 null。
    expect(availableCredit(null, -3200), isNull);
  });

  test('账单周期：下一账单日与当前周期窗口', () {
    // 今天在账单日之前 → 下一账单日为本月账单日。
    final before = nextStatementDate(20, DateTime(2026, 7, 10));
    expect(before, DateTime(2026, 7, 20));
    // 今天已过本月账单日 → 顺延到下月。
    final after = nextStatementDate(5, DateTime(2026, 7, 10));
    expect(after, DateTime(2026, 8, 5));
    // 当前周期：上一账单日次日 至 下一账单日当天。
    final cycle = currentBillingCycle(5, DateTime(2026, 7, 10));
    expect(cycle.start, DateTime(2026, 7, 6));
    expect(cycle.end, DateTime(2026, 8, 5));
  });

  test('本期账单：只统计周期内本账户支出净额，退款冲抵、还款不计', () {
    LedgerEntry expense(String id, double amount, DateTime at, {double refund = 0}) {
      return LedgerEntry(
        id: id,
        bookId: 'default',
        type: EntryType.expense,
        amount: amount,
        categoryId: 'c',
        accountId: 'card',
        note: '',
        occurredAt: at,
        refundedAmount: refund,
      );
    }

    final cycle = currentBillingCycle(5, DateTime(2026, 7, 10));
    final entries = <LedgerEntry>[
      expense('a', 100, DateTime(2026, 7, 8)), // 周期内
      expense('b', 200, DateTime(2026, 7, 8), refund: 50), // 周期内，净额 150
      expense('c', 999, DateTime(2026, 6, 30)), // 周期外（上个周期）
      // 还款：转账进本卡，不计入支出。
      LedgerEntry(
        id: 'r',
        bookId: 'default',
        type: EntryType.transfer,
        amount: 500,
        categoryId: '',
        accountId: 'bank',
        toAccountId: 'card',
        note: '',
        occurredAt: DateTime(2026, 7, 9),
      ),
    ];
    expect(billingCycleExpense(entries, 'card', cycle), 250);
  });
}
