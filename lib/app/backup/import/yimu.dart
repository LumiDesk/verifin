import 'dart:typed_data';

import '../../models.dart';
import '../xls_reader.dart';
import 'raw_import.dart';
import 'text_format.dart';

/// 一木记账 xls（老式 BIFF8 二进制 Excel）。一木把「账单导出（收支）」与「转账还款导出」
/// 做成两个不同表头的文件、且还有其他导出，故拆成两个入口 [parseYimuBill] /
/// [parseYimuTransfer]，各只认自己的表头（选错即报错、绝不跨类型猜测）。基于用户真实样例。

/// 一木「账单导出」：日期 / 收支类型 / 金额(带符号) / 类别 / 二级分类 / 账户 / 备注 / 标签 /
/// 退款。金额符号仅表方向（取绝对值）。一级「类别」→分类、二级「二级分类」→子分类，还原成
/// 父子层级；标签用「, 」分隔的多标签；备注原样导入。只认账单表头，选错文件即报错。
ParsedImport parseYimuBill(Uint8List bytes) {
  final rows = parseXls(bytes);
  final headerIndex = findHeaderRow(
    rows,
    mustHave: const <String>['日期', '收支类型', '金额'],
  );
  if (headerIndex == null) {
    throw const FormatException('未找到一木「账单导出」表头（日期/收支类型/金额），请确认选择的是一木账单导出的 xls');
  }
  final cols = columnIndex(rows[headerIndex]);
  // 子分类列名随一木版本不同：6.5.7 叫「二级分类」、5.9.1 叫「子类」（issue #12）。
  // 认这两个别名，读不到就当无子分类（只落主分类）。
  final subCategoryCol = columnOf(cols, const <String>['二级分类', '子类']);
  final records = <RawImportRecord>[];
  final errors = <ImportRowError>[];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final typeText = cellAt(row, cols['收支类型']);
    if (typeText != '支出' && typeText != '收入') {
      continue;
    }
    // 退款只对支出有意义（收入行忽略退款列，避免虚增金额）。
    final refund = typeText == '支出' ? cellAt(row, cols['退款']) : '';
    // 一木「金额」列导出的是净额 = 原价 − 优惠 − 退款。原始应付额 = |净额| + 退款：优惠是
    // 没花出去的钱不计入支出（不加回）、退款是先付后退需加回。plan_builder 语义为「金额 −
    // 退款 = 净额」，故把应付额放金额、退款单列——避免退款被减两次（issue #10），且全额退款
    // 净额=0 也不会被判非法而整单失败。
    final gross = _yimuGrossAmount(cellAt(row, cols['金额']), refund);
    // 应付额为 0（净额 0 且无退款）= 一木里的空/无效记录，直接忽略、不导入也不报错。
    if (gross <= 0) {
      continue;
    }
    final line = i + 1;
    final date = parseImportDate(cellAt(row, cols['日期']));
    if (date == null) {
      errors.add(ImportRowError(line: line, message: '日期格式无效'));
      continue;
    }
    records.add(
      RawImportRecord(
        date: date,
        type: typeText == '支出' ? EntryType.expense : EntryType.income,
        amount: gross,
        category: cellAt(row, cols['类别']),
        subCategory: cellAt(row, subCategoryCol),
        account: cellAt(row, cols['账户']),
        note: cellAt(row, cols['备注']),
        refunded: parseImportFee(refund),
        tags: splitTagLabels(cellAt(row, cols['标签'])),
        sourceLine: line,
      ),
    );
  }
  return ParsedImport(records: records, errors: errors);
}

/// 一木「转账还款导出」：日期 / 类型 / 转出账户 / 转入账户 / 金额 / 手续费 / 备注。含手续费
/// → 映射到转账 fee。只认转账表头，选错文件即报错。
ParsedImport parseYimuTransfer(Uint8List bytes) {
  final rows = parseXls(bytes);
  final headerIndex = findHeaderRow(
    rows,
    mustHave: const <String>['转出账户', '转入账户', '金额'],
  );
  if (headerIndex == null) {
    throw const FormatException(
      '未找到一木「转账还款导出」表头（转出账户/转入账户/金额），请确认选择的是一木转账还款导出的 xls',
    );
  }
  final cols = columnIndex(rows[headerIndex]);
  final records = <RawImportRecord>[];
  final errors = <ImportRowError>[];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final from = cellAt(row, cols['转出账户']);
    final to = cellAt(row, cols['转入账户']);
    if (from.isEmpty && to.isEmpty) {
      continue;
    }
    final line = i + 1;
    final record = buildRecordFromStrings(
      date: cellAt(row, cols['日期']),
      type: '转账',
      amount: cellAt(row, cols['金额']),
      account: from,
      toAccount: to,
      note: cellAt(row, cols['备注']),
      fee: cellAt(row, cols['手续费']),
      sourceLine: line,
      onError: (message) =>
          errors.add(ImportRowError(line: line, message: message)),
    );
    if (record != null) {
      records.add(record);
    }
  }
  return ParsedImport(records: records, errors: errors);
}

/// 把一木账单的净额（「金额」列 = 原价 − 优惠 − 退款）还原成原始应付额 = |净额| + 退款。
/// 修复 issue #10：退款被减两次、全额退款净额为 0 触发「金额无效」而整单失败。优惠不加回
/// （没花出去的钱）。非数字按 0 处理。
double _yimuGrossAmount(String netRaw, String refundRaw) {
  double num(String raw) =>
      double.tryParse(raw.replaceAll(RegExp(r'[¥￥,，\s]'), '')) ?? 0;
  return num(netRaw).abs() + num(refundRaw).abs();
}
