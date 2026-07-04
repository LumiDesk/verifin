import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/series_math.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

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
    expect(bookkeepingDurationStat(20), ('20', '记账天数'));
    expect(bookkeepingDurationStat(365), ('365', '记账天数'));
    expect(bookkeepingDurationStat(438), ('1.2', '记账年数'));
    expect(bookkeepingDurationStat(730), ('2', '记账年数'));
  });
}
