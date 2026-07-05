import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/image_cropper.dart';
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
}
