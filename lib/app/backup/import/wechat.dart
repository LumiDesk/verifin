import 'dart:typed_data';

import '../../models.dart';
import 'raw_import.dart';
import 'text_format.dart';
import 'xlsx_reader.dart';

/// 微信「支付账单」xlsx：二进制表格，日期为 Excel 序列号，表头含「交易时间 / 交易类型 /
/// 收/支 / 金额(元) / 支付方式 / 交易对方 / 商品」。「中性交易」（提现、理财通、零钱通存取、
/// 信用卡还款等资金流转）跳过。日期由 [excelSerialToDateTime] 直接转 [DateTime]，不经字符串
/// 中转。基于用户真实导出样例。
ParsedImport parseWechat(Uint8List bytes) {
  final rows = parseXlsx(bytes);
  final headerIndex = findHeaderRow(
    rows,
    mustHave: const <String>['交易时间', '收/支'],
  );
  if (headerIndex == null) {
    throw const FormatException('未找到微信账单表头（交易时间/收/支），请确认选择的是微信导出的 xlsx');
  }
  final cols = columnIndex(rows[headerIndex]);
  final records = <RawImportRecord>[];
  final errors = <ImportRowError>[];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final direction = cellAt(row, cols['收/支']);
    if (direction != '支出' && direction != '收入') {
      continue;
    }
    final line = i + 1;
    final date = excelSerialToDateTime(cellAt(row, cols['交易时间']));
    final amount = parseImportAmount(cellAt(row, cols['金额(元)']));
    if (date == null) {
      errors.add(ImportRowError(line: line, message: '日期格式无效'));
      continue;
    }
    if (amount == null) {
      errors.add(ImportRowError(line: line, message: '金额无效'));
      continue;
    }
    final rawMethod = cellAt(row, cols['支付方式']);
    final account = (rawMethod.isEmpty || rawMethod == '/') ? '微信' : rawMethod;
    final product = cellAt(row, cols['商品']);
    // 「商品」列常是「商户订单号：…」这类无意义内容，仅在可读时并入备注。
    final usefulProduct = product.startsWith('商户订单号') || product == '/'
        ? ''
        : product;
    records.add(
      RawImportRecord(
        date: date,
        type: direction == '收入' ? EntryType.income : EntryType.expense,
        amount: amount,
        // 微信没有用户自定义分类，「交易类型」（商户消费/微信红包/转账…）是最接近
        // 分类语义的列：作为分类候选导入，交预览页映射区归到用户自己的分类体系。
        category: cellAt(row, cols['交易类型']),
        account: account,
        note: joinNote(<String>[cellAt(row, cols['交易对方']), usefulProduct]),
        sourceLine: line,
      ),
    );
  }
  return ParsedImport(records: records, errors: errors);
}
