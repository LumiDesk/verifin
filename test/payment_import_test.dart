import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/payment_import.dart';
import 'package:verifin/app/backup/transaction_import.dart';
import 'package:verifin/app/models.dart';

/// 构造最小 xlsx（仅 sharedStrings + sheet1），供微信解析测试。
/// 结构与真实微信导出一致：字符串走 sharedStrings、日期/金额为数字单元格。
Uint8List _buildXlsx(List<List<String>> shared, String sheetRowsXml) {
  final sb = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
  for (final si in shared) {
    sb.write('<si><t>${si.join()}</t></si>');
  }
  sb.write('</sst>');
  final sheet = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
    )
    ..write(sheetRowsXml)
    ..write('</sheetData></worksheet>');

  final archive = Archive()
    ..addFile(ArchiveFile.string('xl/sharedStrings.xml', sb.toString()))
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet.toString()));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  ImportPlan run(ImportPlatform platform, Uint8List bytes) =>
      buildPlatformImportPlan(
        platform: platform,
        bytes: bytes,
        bookId: 'book_default',
        existingAccounts: const <Account>[],
        existingCategories: const <Category>[],
        now: DateTime(2026, 7, 5, 12),
      );

  group('支付宝 CSV（GBK，前置说明行，含不计收支）', () {
    // 真实结构：表头前有多行说明，收/支 含 支出/收入/不计收支，收/付款方式可能带 &。
    const content =
        '导出信息：\n姓名：某某\n共3笔记录\n'
        '------------------------支付宝电子客户回单------------------------\n'
        '交易时间,交易分类,交易对方,对方账号,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号,商家订单号,备注,\n'
        '2026-07-05 18:04:49,商业服务,某商家,a***@qq.com,收钱码收款,支出,2.00,花呗,交易成功,111,222,,\n'
        '2026-07-05 11:37:42,信用借还,花呗,/,花呗主动还款,不计收支,121.00,余额宝,还款成功,333,,,\n'
        '2026-07-04 09:50:05,餐饮美食,某店,b***@z.cn,午饭,支出,10.90,招商银行储蓄卡(0966)&红包,交易成功,444,,,\n';

    late ImportPlan plan;
    setUp(() {
      plan = run(
        ImportPlatform.alipay,
        Uint8List.fromList(gbk.encode(content)),
      );
    });

    test('跳过「不计收支」，只导入收支两笔', () {
      expect(plan.importedCount, 2);
      expect(plan.errorCount, 0);
      expect(plan.entries.every((e) => e.type == EntryType.expense), isTrue);
    });

    test('收/付款方式取 & 前一段作账户名', () {
      final names = plan.newAccounts.map((a) => a.name).toSet();
      expect(names, containsAll(<String>['花呗', '招商银行储蓄卡(0966)']));
    });

    test('金额与分类正确解析', () {
      final amounts = plan.entries.map((e) => e.amount).toList()..sort();
      expect(amounts, <double>[2.00, 10.90]);
      final cats = plan.newCategories.map((c) => c.label).toSet();
      expect(cats, containsAll(<String>['商业服务', '餐饮美食']));
    });
  });

  group('微信 xlsx（Excel 序列号日期，含中性交易）', () {
    late ImportPlan plan;
    setUp(() {
      final shared = <List<String>>[
        <String>['交易时间'], // 0
        <String>['交易类型'], // 1
        <String>['交易对方'], // 2
        <String>['商品'], // 3
        <String>['收/支'], // 4
        <String>['金额(元)'], // 5
        <String>['支付方式'], // 6
        <String>['当前状态'], // 7
        <String>['商户消费'], // 8
        <String>['深圳某校'], // 9
        <String>['商户订单号：2026'], // 10 —— 无意义，应从备注剔除
        <String>['支出'], // 11
        <String>['招商银行储蓄卡(0966)'], // 12
        <String>['支付成功'], // 13
        <String>['微信红包'], // 14
        <String>['某人'], // 15
        <String>['/'], // 16
        <String>['收入'], // 17
        <String>['已存入零钱'], // 18
        <String>['零钱提现'], // 19
        <String>['招商银行(0966)'], // 20
        <String>['提现已到账'], // 21
      ];
      String s(int i) => '<c t="s"><v>$i</v></c>';
      String n(String v) => '<c><v>$v</v></c>';
      final rows = StringBuffer()
        // 表头（前面还有说明行，这里只放一行说明 + 表头验证定位能力）
        ..write('<row><c t="s"><v>0</v></c></row>') // 混淆行（仅一个「交易时间」不足以误判表头）
        ..write(
          '<row>'
          '${s(0)}${s(1)}${s(2)}${s(3)}${s(4)}${s(5)}${s(6)}${s(7)}'
          '</row>',
        )
        // 支出：序列号 46206.494≈2026-07-03 11:51
        ..write(
          '<row>'
          '${n('46206.49423611111')}${s(8)}${s(9)}${s(10)}${s(11)}${n('15')}${s(12)}${s(13)}'
          '</row>',
        )
        // 收入：支付方式为 /（应回落为「微信」）
        ..write(
          '<row>'
          '${n('46206.76704861111')}${s(14)}${s(15)}${s(16)}${s(17)}${n('20')}${s(16)}${s(18)}'
          '</row>',
        )
        // 中性交易：收/支 为 /（应跳过）
        ..write(
          '<row>'
          '${n('46203.79090277778')}${s(19)}${s(20)}${s(16)}${s(16)}${n('5.55')}${s(20)}${s(21)}'
          '</row>',
        );
      plan = run(ImportPlatform.wechat, _buildXlsx(shared, rows.toString()));
    });

    test('跳过中性交易，导入收入与支出各一笔', () {
      expect(plan.importedCount, 2);
      expect(plan.errorCount, 0);
    });

    test('Excel 序列号转成正确日期', () {
      final expense = plan.entries.firstWhere(
        (e) => e.type == EntryType.expense,
      );
      expect(expense.occurredAt.year, 2026);
      expect(expense.occurredAt.month, 7);
      expect(expense.occurredAt.day, 3);
      expect(expense.amount, 15);
    });

    test('支付方式为 / 时账户回落为微信；备注剔除商户订单号', () {
      final income = plan.entries.firstWhere((e) => e.type == EntryType.income);
      final account = plan.newAccounts.firstWhere(
        (a) => a.id == income.accountId,
      );
      expect(account.name, '微信');
      final expense = plan.entries.firstWhere(
        (e) => e.type == EntryType.expense,
      );
      expect(expense.note.contains('商户订单号'), isFalse);
      expect(expense.note.contains('深圳某校'), isTrue);
    });
  });

  group('薄荷记账 CSV（UTF-16LE，制表符分隔，支出为负，转账）', () {
    late ImportPlan plan;
    setUp(() {
      const header =
          '类型\t货币\t金额\t汇率（相对本位币）\t项目\t分类\t父类\t账户\t付款\t收款\t商家\t地址\t日期\t标签\t作者\t备注\t图一\t图二\t图三';
      const rows = <String>[
        '收入\tCNY\t0.03\t1.0000\t\t利息\t\t支付宝\t\t\t\t\t2026-07-03 11:12\t\tA\t',
        '支出\tCNY\t-3\t1.0000\t\t餐饮\t\t花呗\t\t\t\t\t2026-07-02 19:08\t\tA\t晚饭',
        '转账\tCNY\t12.48\t1.0000\t\t账户互转\t\t\t微信\t支付宝\t\t\t2026-06-30 18:59\t\tA\t',
        // 账户为空：薄荷允许「不计资产」的记录 → 导入为无账户交易。
        '支出\tCNY\t-49\t1.0000\t\t餐饮\t\t\t\t\t\t\t2026-01-07 17:56\t\tA\t',
        // 单边转账：仅收款 → 转出端为无账户，仍按转账记。
        '转账\tCNY\t243\t1.0000\t\t账户互转\t\t\t\t支付宝\t\t\t2026-06-01 17:54\t\tA\t',
      ];
      final content = '﻿$header\n${rows.join('\n')}\n';
      plan = run(
        ImportPlatform.mint,
        Uint8List.fromList(utf16.encode(content)),
      );
    });

    test('导入五笔（含无账户与单边转账），无报错', () {
      expect(plan.importedCount, 5);
      expect(plan.errorCount, 0);
    });

    test('账户为空的行导入为无账户交易（accountId 为空）', () {
      final noAccount = plan.entries
          .where((e) => e.type == EntryType.expense && e.amount == 49)
          .single;
      expect(noAccount.accountId, isEmpty);
    });

    test('单边转账：转出端为空、转入端为支付宝', () {
      final oneSided = plan.entries
          .where((e) => e.type == EntryType.transfer && e.amount == 243)
          .single;
      expect(oneSided.accountId, isEmpty);
      final to = plan.newAccounts.firstWhere(
        (a) => a.id == oneSided.toAccountId,
      );
      expect(to.name, '支付宝');
    });

    test('支出金额取绝对值', () {
      final expense = plan.entries.firstWhere(
        (e) => e.type == EntryType.expense,
      );
      expect(expense.amount, 3);
      expect(expense.note, '晚饭');
    });

    test('转账映射付款→账户、收款→转入账户', () {
      final transfer = plan.entries.firstWhere(
        (e) => e.type == EntryType.transfer,
      );
      final from = plan.newAccounts.firstWhere(
        (a) => a.id == transfer.accountId,
      );
      final to = plan.newAccounts.firstWhere(
        (a) => a.id == transfer.toAccountId,
      );
      expect(from.name, '微信');
      expect(to.name, '支付宝');
      expect(transfer.amount, 12.48);
    });
  });

  group('通用 CSV（钱迹/随手记/模板，UTF-8 逗号）', () {
    test('走别名识别导入', () {
      const content = '日期,类型,金额,分类,账户,转入账户,备注\n2026-07-01,支出,23.5,餐饮,现金,,午饭\n';
      final plan = run(
        ImportPlatform.genericCsv,
        Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)]),
      );
      expect(plan.importedCount, 1);
      expect(plan.entries.first.amount, 23.5);
    });
  });

  group('一木记账 xls（BIFF8 二进制，带符号金额，二级分类）', () {
    // 真实样例（用户提供，7 条记录），验证 OLE2/BIFF8 读取 + 归一化端到端。
    late ImportPlan plan;
    setUp(() {
      final bytes = File('test/fixtures/yimu_sample.xls').readAsBytesSync();
      plan = run(ImportPlatform.yimu, Uint8List.fromList(bytes));
    });

    test('全部 7 条导入、无错误', () {
      expect(plan.importedCount, 7);
      expect(plan.errorCount, 0);
    });

    test('收入按二级分类映射、金额取绝对值、日期正确', () {
      final income = plan.entries.firstWhere(
        (e) => e.type == EntryType.income && e.amount == 200,
      );
      expect(income.occurredAt.year, 2026);
      expect(income.occurredAt.month, 7);
      final category = plan.newCategories.firstWhere(
        (c) => c.id == income.categoryId,
      );
      expect(category.label, '工资'); // 二级分类，而非一级「收入」。
      expect(category.type, EntryType.income);
    });

    test('支出金额取绝对值、账户按名建立', () {
      final expense = plan.entries.firstWhere((e) => e.amount == 500);
      expect(expense.type, EntryType.expense);
      final account = plan.newAccounts.firstWhere(
        (a) => a.id == expense.accountId,
      );
      expect(account.name, '微信钱包');
      final category = plan.newCategories.firstWhere(
        (c) => c.id == expense.categoryId,
      );
      expect(category.label, '饮料酒水');
    });

    test('账户为空记为「无账户」', () {
      final noAccount = plan.entries.firstWhere((e) => e.amount == 3);
      expect(noAccount.accountId, isEmpty);
    });
  });
}
