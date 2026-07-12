import 'dart:typed_data';

import 'raw_import.dart';
import 'text_format.dart';

/// 钱迹「CSV」导出：UTF-8（含 BOM）逗号 CSV，18 列（ID/时间/分类/二级分类/类型/金额/币种/
/// 账户1/账户2/备注/已报销/手续费/优惠券/记账者/账单标记/标签/账单图片/关联账单）。金额恒为
/// 正、方向由「类型」列定。基于用户真实完整导出样例，覆盖全部记账类型：
///
/// | 钱迹类型 | Veri Fin | 说明 |
/// |---|---|---|
/// | 支出 / 报销 | 支出 | 一级「分类」+二级「二级分类」还原层级；「退款」按「关联账单」折叠进原支出退款额 |
/// | 收入 / 报销记录 / 债务-利息收入 | 收入 | 报销记录=报销款到账；债务利息=利息收入 |
/// | 转账 / 还款 | 转账 | 账户1→账户2，手续费；还款=信用卡还款（资金账户→信用卡） |
/// | 退款 | （折叠进原支出，净额=金额−退款）| 原单不在文件里的孤立退款回落记为收入，避免丢钱 |
/// | 债务-借出/收款/借入/还款 | 转账 | 账户1「A->B」箭头拆 from→to（把「人」当账户，正=对方欠我）；无箭头按借贷方向补空账户 |
///
/// 币种（均 CNY）、优惠券（仅少量、金额已是实付净额故不加回）、账单图片、记账者不导入。
ParsedImport parseQianji(Uint8List bytes) {
  final rows = parseCsv(decodeUtf8Bytes(bytes));
  final headerIndex = findHeaderRow(
    rows,
    mustHave: const <String>['时间', '类型', '金额', '账户1'],
  );
  if (headerIndex == null) {
    throw const FormatException('未找到钱迹账单表头（时间/类型/金额/账户1），请确认选择的是钱迹导出的 CSV');
  }
  final cols = columnIndex(rows[headerIndex]);
  String cell(List<String> row, String name) => cellAt(row, cols[name]);

  final data = rows.sublist(headerIndex + 1);

  // 第一遍：收集「支出/报销」的 ID，以及「退款」按原单 ID 的折叠额。退款与原支出同账户、
  // 金额 ≤ 原额（用户样例验证），故折叠进 refundedAmount 与 App 内退款冲抵语义一致。
  final expenseIds = <String>{};
  for (final row in data) {
    final type = cell(row, '类型');
    if (type == '支出' || type == '报销') {
      final id = cell(row, 'ID');
      if (id.isNotEmpty) {
        expenseIds.add(id);
      }
    }
  }
  final refundByOriginal = <String, double>{};
  for (final row in data) {
    if (cell(row, '类型') != '退款') {
      continue;
    }
    final link = cell(row, '关联账单');
    final amount = parseImportAmount(cell(row, '金额'));
    if (link.isNotEmpty && amount != null && expenseIds.contains(link)) {
      refundByOriginal[link] = (refundByOriginal[link] ?? 0) + amount;
    }
  }

  final records = <RawImportRecord>[];
  final errors = <ImportRowError>[];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final line = i + 1;
    final type = cell(row, '类型');
    // 0 元 / 空金额行（钱迹「心愿单」「收藏想买」等占位记录，金额恒为 0）静默跳过：
    // 不是真实交易，钱迹自身也不计入收支，避免在导入预览里塞一堆「金额无效」噪音。
    if (parseImportAmount(cell(row, '金额')) == null) {
      continue;
    }
    void onError(String message) =>
        errors.add(ImportRowError(line: line, message: message));

    final RawImportRecord? record;
    switch (type) {
      case '支出' || '报销':
        final refund = refundByOriginal[cell(row, 'ID')];
        record = buildRecordFromStrings(
          date: cell(row, '时间'),
          type: '支出',
          amount: cell(row, '金额'),
          category: cell(row, '分类'),
          subCategory: cell(row, '二级分类'),
          account: cell(row, '账户1'),
          note: cell(row, '备注'),
          refunded: refund == null ? '' : refund.toStringAsFixed(2),
          tags: splitTagLabels(cell(row, '标签')),
          sourceLine: line,
          onError: onError,
        );
      case '收入' || '报销记录' || '债务-利息收入':
        record = buildRecordFromStrings(
          date: cell(row, '时间'),
          type: '收入',
          amount: cell(row, '金额'),
          category: cell(row, '分类'),
          subCategory: cell(row, '二级分类'),
          account: cell(row, '账户1'),
          note: cell(row, '备注'),
          tags: splitTagLabels(cell(row, '标签')),
          sourceLine: line,
          onError: onError,
        );
      case '转账' || '还款':
        record = buildRecordFromStrings(
          date: cell(row, '时间'),
          type: '转账',
          amount: cell(row, '金额'),
          account: cell(row, '账户1'),
          toAccount: cell(row, '账户2'),
          note: cell(row, '备注'),
          fee: cell(row, '手续费'),
          sourceLine: line,
          onError: onError,
        );
      case '退款':
        final link = cell(row, '关联账单');
        if (link.isNotEmpty && expenseIds.contains(link)) {
          // 已折叠进原支出的退款额，不再单独成条。
          continue;
        }
        // 孤立退款（原单不在本次导出）：记为收入，避免丢钱。
        record = buildRecordFromStrings(
          date: cell(row, '时间'),
          type: '收入',
          amount: cell(row, '金额'),
          category: cell(row, '分类'),
          subCategory: cell(row, '二级分类'),
          account: cell(row, '账户1'),
          note: cell(row, '备注'),
          sourceLine: line,
          onError: onError,
        );
      case '债务-借出' || '债务-收款' || '债务-借入' || '债务-还款':
        final (from, to) = _debtAccounts(type, cell(row, '账户1'));
        record = buildRecordFromStrings(
          date: cell(row, '时间'),
          type: '转账',
          amount: cell(row, '金额'),
          account: from,
          toAccount: to,
          note: cell(row, '备注'),
          sourceLine: line,
          onError: onError,
        );
      default:
        // 未知类型：跳过，不猜测（宁可漏、不记错）。
        continue;
    }
    if (record != null) {
      records.add(record);
    }
  }
  return ParsedImport(records: records, errors: errors);
}

/// 拆解债务行的「账户1」为转账的 (转出, 转入)。钱迹债务用「转出->转入」编码方向：借出
/// 「我的账户->对方」、收款「对方->我的账户」、还款「我的账户->对方」。无箭头时只给了对方
/// 名字（钱迹未记真实资金账户），按借贷方向补一个空账户（不动真实余额），使「对方」账户余额
/// 仍表净欠款：借出→对方 +（对方欠我）；收款/借入/还款→对方 −。
(String, String) _debtAccounts(String type, String account1) {
  final arrow = account1.indexOf('->');
  if (arrow >= 0) {
    return (
      account1.substring(0, arrow).trim(),
      account1.substring(arrow + 2).trim(),
    );
  }
  return switch (type) {
    '债务-借出' => ('', account1),
    _ => (account1, ''),
  };
}
