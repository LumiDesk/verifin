import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/payment_import.dart';
import 'package:verifin/app/backup/transaction_import.dart';
import 'package:verifin/app/ledger_math.dart';
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

/// 构造 Tally「备份」zip：zip 内含 backup_data.json（Gson 全量数据的最小子集）。
Uint8List _buildTallyBackup(Map<String, Object?> data) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('backup_data.json', jsonEncode(data)));
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

  group('一木记账 账单 xls（BIFF8 二进制，带符号金额，二级分类）', () {
    // 真实样例（用户提供，7 条收支记录），验证 OLE2/BIFF8 读取 + 归一化端到端。
    late ImportPlan plan;
    setUp(() {
      final bytes = File(
        'test/fixtures/yimu_transactions.xls',
      ).readAsBytesSync();
      plan = run(ImportPlatform.yimuBill, Uint8List.fromList(bytes));
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
      final category = plan.newCategories.firstWhere(
        (c) => c.id == income.categoryId,
      );
      expect(category.label, '其他'); // 二级分类，而非一级「收入」。
      expect(category.type, EntryType.income);
    });

    test('支出按二级分类、金额取绝对值', () {
      final expense = plan.entries.firstWhere((e) => e.amount == 500);
      expect(expense.type, EntryType.expense);
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

  group('一木记账 转账 xls（独立文件，转出/转入账户 + 手续费）', () {
    late ImportPlan plan;
    setUp(() {
      final bytes = File('test/fixtures/yimu_transfers.xls').readAsBytesSync();
      plan = run(ImportPlatform.yimuTransfer, Uint8List.fromList(bytes));
    });

    test('识别为转账并建立转出/转入账户', () {
      expect(plan.importedCount, 1);
      expect(plan.errorCount, 0);
      final transfer = plan.entries.single;
      expect(transfer.type, EntryType.transfer);
      expect(transfer.amount, 20);
      expect(transfer.fee, 0);
      final from = plan.newAccounts.firstWhere(
        (a) => a.id == transfer.accountId,
      );
      final to = plan.newAccounts.firstWhere(
        (a) => a.id == transfer.toAccountId,
      );
      expect(from.name, '微信钱包');
      expect(to.name, '支付宝');
    });

    test('选错文件即报错（不跨类型猜测）', () {
      final billBytes = File(
        'test/fixtures/yimu_transactions.xls',
      ).readAsBytesSync();
      final transferBytes = File(
        'test/fixtures/yimu_transfers.xls',
      ).readAsBytesSync();
      // 账单入口选到转账文件 → 表头不匹配，报错。
      expect(
        () => run(ImportPlatform.yimuBill, Uint8List.fromList(transferBytes)),
        throwsFormatException,
      );
      // 转账入口选到账单文件 → 同样报错。
      expect(
        () => run(ImportPlatform.yimuTransfer, Uint8List.fromList(billBytes)),
        throwsFormatException,
      );
    });
  });

  group('Tally 备份 zip（backup_data.json，精确时间戳）', () {
    final expenseAt = DateTime(2026, 7, 5, 18, 4, 49);
    final incomeAt = DateTime(2026, 7, 4, 9, 30);
    final transferAt = DateTime(2026, 7, 3, 12);
    final discountTransferAt = DateTime(2026, 7, 2, 8);

    late ImportPlan plan;
    setUp(() {
      final bytes = _buildTallyBackup(<String, Object?>{
        'assets': <Object?>[
          <String, Object?>{'id': 1, 'name': '招商储蓄卡'},
          <String, Object?>{'id': 2, 'name': '现金'},
        ],
        'records': <Object?>[
          <String, Object?>{
            'date': expenseAt.millisecondsSinceEpoch,
            'type': 0,
            'amount': 23.5,
            'category': '餐饮',
            'subCategory': '午餐',
            'assetId': 1,
            'note': '午饭',
            'remark': '',
          },
          <String, Object?>{
            'date': incomeAt.millisecondsSinceEpoch,
            'type': 1,
            'amount': 8000.0,
            'category': '工资',
            'subCategory': '',
            'assetId': 1,
            'note': '月薪',
            'remark': '',
          },
          <String, Object?>{
            'date': transferAt.millisecondsSinceEpoch,
            'type': 2,
            'amount': 500.0,
            'category': '资产互转',
            'assetId': 1,
            'note': '招商储蓄卡 -> 现金 | 备注: 取现',
            'remark': '',
          },
          <String, Object?>{
            'date': discountTransferAt.millisecondsSinceEpoch,
            'type': 2,
            'amount': 500.0,
            'category': '资产互转',
            'assetId': 2,
            'note': '现金 -> 招商储蓄卡 (账单:600 优惠:100)',
            'remark': '',
          },
          // 金额为 0 的记录应被跳过。
          <String, Object?>{
            'date': transferAt.millisecondsSinceEpoch,
            'type': 0,
            'amount': 0,
            'category': '其它',
            'assetId': 1,
            'note': '',
          },
        ],
      });
      plan = run(ImportPlatform.tally, bytes);
    });

    test('导入 4 笔（跳过金额为 0），无错误行', () {
      expect(plan.importedCount, 4);
      expect(plan.errorCount, 0);
    });

    test('支出：二级分类作分类、精确时间戳、账户映射', () {
      final expense = plan.entries.firstWhere(
        (e) => e.type == EntryType.expense,
      );
      expect(expense.amount, 23.5);
      expect(expense.occurredAt, expenseAt);
      expect(expense.note, '午饭');
      final category = plan.newCategories.firstWhere(
        (c) => c.id == expense.categoryId,
      );
      expect(category.label, '午餐');
      final account = plan.newAccounts.firstWhere(
        (a) => a.id == expense.accountId,
      );
      expect(account.name, '招商储蓄卡');
    });

    test('收入：无二级分类时回退一级分类', () {
      final income = plan.entries.firstWhere((e) => e.type == EntryType.income);
      expect(income.amount, 8000);
      final category = plan.newCategories.firstWhere(
        (c) => c.id == income.categoryId,
      );
      expect(category.label, '工资');
    });

    test('转账：从 note 拆出转出/转入账户，剥离用户备注', () {
      final transfer = plan.entries.firstWhere(
        (e) => e.type == EntryType.transfer && e.occurredAt == transferAt,
      );
      final from = plan.newAccounts.firstWhere(
        (a) => a.id == transfer.accountId,
      );
      final to = plan.newAccounts.firstWhere(
        (a) => a.id == transfer.toAccountId,
      );
      expect(from.name, '招商储蓄卡');
      expect(to.name, '现金');
      expect(transfer.note, '取现');
      expect(transfer.amount, 500);
    });

    test('转账：剥离「(账单:X 优惠:Y)」尾注', () {
      final transfer = plan.entries.firstWhere(
        (e) =>
            e.type == EntryType.transfer && e.occurredAt == discountTransferAt,
      );
      final from = plan.newAccounts.firstWhere(
        (a) => a.id == transfer.accountId,
      );
      final to = plan.newAccounts.firstWhere(
        (a) => a.id == transfer.toAccountId,
      );
      expect(from.name, '现金');
      expect(to.name, '招商储蓄卡');
    });

    test('非 zip 字节报错', () {
      expect(
        () => run(
          ImportPlatform.tally,
          Uint8List.fromList(utf8.encode('not a zip')),
        ),
        throwsFormatException,
      );
    });
  });

  group('Tally 资产账户：余额与类型导入', () {
    final at = DateTime(2026, 7, 5, 12);

    // 某账户导入后的显示余额 = 初始余额 + 该账户在导入交易中的增量合计。
    double displayedBalance(ImportPlan plan, Account account) {
      var balance = account.initialBalance;
      for (final entry in plan.entries) {
        balance += accountDeltaForEntry(entry, account.id);
      }
      return balance;
    }

    late ImportPlan plan;
    setUp(() {
      final bytes = _buildTallyBackup(<String, Object?>{
        'assets': <Object?>[
          // 有流水的资产：当前余额 1035.18。
          <String, Object?>{
            'id': 1,
            'name': '微信余额',
            'amount': 1035.18,
            'type': 0,
          },
          // 无流水的零余额钱包。
          <String, Object?>{'id': 2, 'name': 'qq钱包', 'amount': 0, 'type': 0},
          // 借出（type 2）：正值资产。
          <String, Object?>{'id': 3, 'name': '妈妈', 'amount': 2000.0, 'type': 2},
          // 负债（type 1）：Veri Fin 里记为负余额。
          <String, Object?>{'id': 4, 'name': '花呗', 'amount': 300.0, 'type': 1},
          // 不计入总资产的资产。
          <String, Object?>{
            'id': 5,
            'name': '公积金',
            'amount': 500.0,
            'type': 0,
            'isIncludedInTotal': false,
          },
        ],
        'records': <Object?>[
          <String, Object?>{
            'date': at.millisecondsSinceEpoch,
            'type': 1,
            'amount': 2996.17,
            'category': '工资',
            'assetId': 1,
            'note': '',
          },
          <String, Object?>{
            'date': at.millisecondsSinceEpoch,
            'type': 0,
            'amount': 1960.99,
            'category': '购物',
            'assetId': 1,
            'note': '',
          },
        ],
      });
      plan = run(ImportPlatform.tally, bytes);
    });

    test('有流水账户回推初始余额，显示余额对齐 Tally 当前余额', () {
      final wechat = plan.newAccounts.firstWhere((a) => a.name == '微信余额');
      expect(displayedBalance(plan, wechat), closeTo(1035.18, 0.001));
    });

    test('无流水账户按当前余额补建，且标记为独立账户', () {
      final qq = plan.newAccounts.firstWhere((a) => a.name == 'qq钱包');
      expect(qq.initialBalance, 0);
      expect(plan.standaloneAccountIds, contains(qq.id));
      final mama = plan.newAccounts.firstWhere((a) => a.name == '妈妈');
      expect(mama.initialBalance, 2000);
      expect(displayedBalance(plan, mama), 2000);
    });

    test('负债账户记为负余额', () {
      final huabei = plan.newAccounts.firstWhere((a) => a.name == '花呗');
      expect(huabei.initialBalance, -300);
    });

    test('isIncludedInTotal=false 映射到 includeInAssets=false', () {
      final fund = plan.newAccounts.firstWhere((a) => a.name == '公积金');
      expect(fund.includeInAssets, isFalse);
      final wechat = plan.newAccounts.firstWhere((a) => a.name == '微信余额');
      expect(wechat.includeInAssets, isTrue);
    });

    test('所有资产账户均被补齐（含无流水的）', () {
      final names = plan.newAccounts.map((a) => a.name).toSet();
      expect(names, containsAll(<String>['微信余额', 'qq钱包', '妈妈', '花呗', '公积金']));
    });
  });
}
