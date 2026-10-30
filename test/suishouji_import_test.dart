import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/import/plan_builder.dart';
import 'package:verifin/app/backup/import/suishouji.dart';
import 'package:verifin/app/backup/payment_import.dart';
import 'package:verifin/app/models.dart';

String _columnLetters(int index) {
  var value = index + 1;
  final letters = StringBuffer();
  while (value > 0) {
    final remainder = (value - 1) % 26;
    letters.writeCharCode(65 + remainder);
    value = (value - 1) ~/ 26;
  }
  return letters.toString().split('').reversed.join();
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _inlineCell(int row, int column, String value) {
  final ref = '${_columnLetters(column)}$row';
  if (value.isEmpty) {
    return '<c r="$ref"/>';
  }
  return '<c r="$ref" t="inlineStr"><is><t>${_escapeXml(value)}</t></is></c>';
}

String _sheetXml(List<List<String>> rows) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<sheetData>',
  );
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    buffer.write('<row r="${rowIndex + 1}">');
    for (var column = 0; column < rows[rowIndex].length; column++) {
      buffer.write(_inlineCell(rowIndex + 1, column, rows[rowIndex][column]));
    }
    buffer.write('</row>');
  }
  buffer.write('</sheetData></worksheet>');
  return buffer.toString();
}

/// 构造只含工作表、无 sharedStrings 的最小 xlsx；用于错误路径，避免测试依赖
/// 二进制 fixture 的某一行。
Uint8List _buildWorkbook(Map<String, List<List<String>>> sheets) {
  final workbook = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets>',
  );
  final rels = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );
  final archive = Archive();
  var index = 0;
  for (final entry in sheets.entries) {
    index++;
    workbook.write(
      '<sheet name="${_escapeXml(entry.key)}" sheetId="$index" r:id="rId$index"/>',
    );
    rels.write(
      '<Relationship Id="rId$index" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet$index.xml"/>',
    );
    archive.addFile(
      ArchiveFile.string(
        'xl/worksheets/sheet$index.xml',
        _sheetXml(entry.value),
      ),
    );
  }
  workbook.write('</sheets></workbook>');
  rels.write('</Relationships>');
  archive
    ..addFile(ArchiveFile.string('xl/workbook.xml', workbook.toString()))
    ..addFile(
      ArchiveFile.string('xl/_rels/workbook.xml.rels', rels.toString()),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  ImportPlan run(List<int> bytes) {
    return buildImportPlanFromRecords(
      parsed: parseSuishouji(Uint8List.fromList(bytes)),
      bookId: 'book_default',
      existingAccounts: const <Account>[],
      existingCategories: const <Category>[],
      now: DateTime(2026, 9, 1, 12),
    );
  }

  group('随手记多工作表 xlsx（真实结构脱敏 fixture）', () {
    late ImportPlan plan;
    late Map<String, String> accountNames;
    late Map<String, Category> categories;

    setUp(() {
      final bytes = File(
        'test/fixtures/suishouji_sample.xlsx',
      ).readAsBytesSync();
      plan = run(bytes);
      accountNames = <String, String>{
        for (final account in plan.newAccounts) account.id: account.name,
      };
      categories = <String, Category>{
        for (final category in plan.newCategories) category.id: category,
      };
    });

    test('导入支出/收入/转账/退款/余额变更，债务与负债变更跳过', () {
      expect(plan.errorCount, 0);
      expect(plan.importedCount, 7);
      expect(
        plan.entries.where((entry) => entry.type == EntryType.expense).length,
        3,
      );
      expect(
        plan.entries.where((entry) => entry.type == EntryType.income).length,
        3,
      );
      expect(
        plan.entries.where((entry) => entry.type == EntryType.transfer).length,
        1,
      );
      expect(
        plan.entries.where((entry) => entry.type == EntryType.refund),
        isEmpty,
      );
      expect(plan.newAccounts.map((account) => account.name).toSet(), <String>{
        '现金',
        '银行卡',
      });
    });

    test('账户统一建为同币种现金账户，不创建应收/应付/信用卡账户', () {
      expect(
        plan.newAccounts.every(
          (account) =>
              account.type == AccountType.cash && account.currencyCode == 'CNY',
        ),
        isTrue,
      );
      expect(
        plan.newAccounts.map((account) => account.name).toSet().intersection(
          <String>{'应收款项', '应付款项', '信用卡'},
        ),
        isEmpty,
      );
    });

    test('一级/二级分类还原父子层级并去掉尾部空格', () {
      final lunch = plan.newCategories.firstWhere(
        (category) => category.label == '午餐',
      );
      expect(categories[lunch.parentId]?.label, '餐饮');
      final salary = plan.newCategories.firstWhere(
        (category) => category.label == '月薪',
      );
      expect(categories[salary.parentId]?.label, '工资');
      final refund = plan.newCategories.firstWhere(
        (category) => category.label == '退货',
      );
      expect(refund.type, EntryType.income);
      expect(categories[refund.parentId]?.label, '购物');
      expect(
        plan.newCategories.any(
          (category) =>
              category.label.endsWith(' ') || category.label.startsWith(' '),
        ),
        isFalse,
      );
    });

    test('退款按收入兜底并回到原账户，备注保留', () {
      final refund = plan.entries.firstWhere((entry) => entry.note == '#退款#');
      expect(refund.type, EntryType.income);
      expect(refund.amount, 20);
      expect(accountNames[refund.accountId], '现金');
    });

    test('转账映射转出/转入账户且不计收支', () {
      final transfer = plan.entries.singleWhere(
        (entry) => entry.type == EntryType.transfer,
      );
      expect(transfer.amount, 100);
      expect(accountNames[transfer.accountId], '银行卡');
      expect(accountNames[transfer.toAccountId], '现金');
    });

    test('余额变更按符号落到余额调整系统分类', () {
      final increase = plan.entries.singleWhere((entry) => entry.amount == 30);
      expect(increase.type, EntryType.income);
      expect(categories[increase.categoryId]?.key, balanceAdjustIncomeKey);
      final decrease = plan.entries.singleWhere((entry) => entry.amount == 10);
      expect(decrease.type, EntryType.expense);
      expect(categories[decrease.categoryId]?.key, balanceAdjustExpenseKey);
    });

    test('商家并入备注，成员/项目/记账人不进入账目', () {
      final lunch = plan.entries.firstWhere((entry) => entry.amount == 25.5);
      expect(lunch.note, '午饭 商家A');
      expect(plan.entries.any((entry) => entry.note.contains('成员A')), isFalse);
      expect(plan.entries.any((entry) => entry.note.contains('日常消费')), isFalse);
    });
  });

  test('平台注册表按 suishouji 解析，文件过滤只接受 xlsx', () {
    final bytes = File('test/fixtures/suishouji_sample.xlsx').readAsBytesSync();
    final plan = buildPlatformImportPlan(
      platform: ImportPlatform.suishouji,
      bytes: Uint8List.fromList(bytes),
      bookId: 'book_default',
      existingAccounts: const <Account>[],
      existingCategories: const <Category>[],
      now: DateTime(2026, 9, 1, 12),
    );

    expect(plan.importedCount, 7);
    expect(ImportPlatform.suishouji.fileExtensions, <String>['xlsx']);
  });

  test('单行日期非法时按工作表给出逐行错误，不产生交易', () {
    final header = <String>[
      '交易类型',
      '日期',
      '一级分类',
      '二级分类',
      '支出账户',
      '账户币种',
      '金额',
      '成员',
      '商家',
      '项目分类',
      '项目',
      '记账人',
      '备注',
    ];
    final bytes = _buildWorkbook(<String, List<List<String>>>{
      '支出': <List<String>>[
        header,
        <String>[
          '支出',
          'not-a-date',
          '餐饮',
          '午餐',
          '现金',
          'CNY',
          '10',
          '',
          '',
          '',
          '',
          '',
          '',
        ],
      ],
    });

    final parsed = parseSuishouji(bytes);
    expect(parsed.records, isEmpty);
    expect(parsed.errors, hasLength(1));
    expect(parsed.errors.single.message, contains('支出'));
    expect(parsed.errors.single.message, contains('日期格式无效'));
  });

  test('只有债务工作表时明确报格式错误', () {
    final bytes = _buildWorkbook(<String, List<List<String>>>{
      '收债': <List<String>>[
        <String>['交易类型', '日期', '账户1', '账户2', '账户币种', '金额'],
        <String>['收债', '2026-08-10', '应收款项', '支付宝', 'CNY', '100'],
      ],
    });

    expect(() => parseSuishouji(bytes), throwsA(isA<FormatException>()));
  });

  test('非 xlsx 字节给出随手记专用格式错误', () {
    expect(
      () => parseSuishouji(Uint8List.fromList(utf8.encode('not an xlsx'))),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('随手记导出的 xlsx'),
        ),
      ),
    );
  });
}
