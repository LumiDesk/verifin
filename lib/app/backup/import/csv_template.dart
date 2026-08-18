import 'dart:typed_data';

import '../../currency_catalog.dart';
import '../../currency_math.dart';
import '../../models.dart';
import 'raw_import.dart';
import 'text_format.dart';

/// Veri Fin「CSV 模板」导入入口。**只认本应用模板**：白名单校验表头只允许模板列，
/// 严格拒绝第三方软件的原生表头——第三方账单各走自己的 parser。

/// Veri Fin CSV 模板列：既是「下载 CSV 模板」的表头，也是 [validateCsvTemplateHeader]
/// 严格校验的唯一真源。改这里即同时改模板与校验。
const List<String> csvTemplateColumns = <String>[
  '日期',
  '类型',
  '金额',
  '分类',
  '账户',
  '转入账户',
  '备注',
  '币种',
  '账户金额',
  '本位币金额',
  '转入金额',
  '汇率（1原币=X本位币）',
  '账户币种',
  '转入账户币种',
];

/// 表头列名 → 列键的别名。CSV 模板列 + 可选的 子分类/标签/手续费/退款（规范中文列名）。
/// **不兼容第三方软件的原生表头**（钱迹「账户1/账户2」、随手记「交易类型」等通用识别
/// 已下线，各软件走各自 parser）。
const Map<String, List<String>> _headerAliases = <String, List<String>>{
  'date': <String>['日期'],
  'type': <String>['类型'],
  'amount': <String>['金额'],
  'category': <String>['分类'],
  'subcategory': <String>['子分类'],
  'account': <String>['账户'],
  'toAccount': <String>['转入账户'],
  'note': <String>['备注'],
  'fee': <String>['手续费'],
  'refunded': <String>['退款'],
  'tags': <String>['标签'],
  'currency': <String>['币种'],
  'accountAmount': <String>['账户金额'],
  'baseAmount': <String>['本位币金额'],
  'toAccountAmount': <String>['转入金额'],
  'rateToBase': <String>['汇率（1原币=x本位币）'],
  'accountCurrency': <String>['账户币种'],
  'toAccountCurrency': <String>['转入账户币种'],
};

/// CSV 模板内容（带表头与示例行），用户下载后填写再导入。
String transactionCsvTemplate() {
  return '${csvTemplateColumns.join(',')}\n'
      '2026-01-05,支出,23.50,餐饮,现金,,午饭,CNY,23.50,23.50,,,CNY,\n'
      '2026-01-05,收入,100,工资,美元账户,,奖金,USD,100,720,,7.2,USD,\n'
      '2026-01-06,转账,500,,现金,美元账户,换汇,CNY,500,0,70,,CNY,USD\n';
}

const List<String> transactionCsvExportColumns = <String>[
  '日期',
  '类型',
  '金额',
  '分类',
  '子分类',
  '账户',
  '转入账户',
  '备注',
  '手续费',
  '退款',
  '标签',
  '币种',
  '账户金额',
  '本位币金额',
  '转入金额',
  '汇率（1原币=X本位币）',
  '账户币种',
  '转入账户币种',
];

/// 导出可重新识别币种语义的交易 CSV。退款子条目折叠回原支出的退款列，避免重复；
/// 完整备份/恢复仍以 JSON v2 为准。
String transactionCsvExport({
  required List<LedgerEntry> entries,
  required List<Account> accounts,
  required List<Category> categories,
  required List<Tag> tags,
  required String baseCurrencyCode,
}) {
  final accountsById = <String, Account>{
    for (final account in accounts) account.id: account,
  };
  final categoriesById = <String, Category>{
    for (final category in categories) category.id: category,
  };
  final tagsById = <String, Tag>{for (final tag in tags) tag.id: tag};
  final rows = <List<String>>[transactionCsvExportColumns];
  for (final entry in entries.where(
    (entry) => entry.type != EntryType.refund,
  )) {
    final category = categoriesById[entry.categoryId];
    final parent = category?.parentId == null
        ? null
        : categoriesById[category!.parentId];
    final refundedOriginal =
        entry.type == EntryType.expense && entry.baseAmount > 0
        ? normalizeCurrencyAmount(
            entry.refundedBaseAmount / entry.baseAmount * entry.amount,
            entry.currencyCode,
          )
        : 0.0;
    final derivedRate =
        entry.type != EntryType.transfer &&
            entry.currencyCode != baseCurrencyCode &&
            entry.amount > 0
        ? entry.baseAmount / entry.amount
        : null;
    rows.add(<String>[
      _csvDate(entry.occurredAt),
      switch (entry.type) {
        EntryType.expense => '支出',
        EntryType.income => '收入',
        EntryType.transfer => '转账',
        EntryType.refund => '退款',
      },
      formatCurrencyNumber(entry.amount, entry.currencyCode),
      parent?.label ?? category?.label ?? '',
      parent == null ? '' : category?.label ?? '',
      accountsById[entry.accountId]?.name ?? '',
      accountsById[entry.toAccountId]?.name ?? '',
      entry.note,
      entry.fee == 0
          ? ''
          : formatCurrencyNumber(
              entry.fee,
              accountsById[entry.accountId]?.currencyCode ?? entry.currencyCode,
            ),
      refundedOriginal == 0
          ? ''
          : formatCurrencyNumber(refundedOriginal, entry.currencyCode),
      entry.tagIds
          .map((id) => tagsById[id]?.label)
          .whereType<String>()
          .join('，'),
      entry.currencyCode,
      entry.accountAmount == null
          ? ''
          : formatCurrencyNumber(
              entry.accountAmount!,
              accountsById[entry.accountId]?.currencyCode ?? entry.currencyCode,
            ),
      formatCurrencyNumber(entry.baseAmount, baseCurrencyCode),
      entry.toAccountAmount == null
          ? ''
          : formatCurrencyNumber(
              entry.toAccountAmount!,
              accountsById[entry.toAccountId]?.currencyCode ??
                  entry.currencyCode,
            ),
      derivedRate == null ? '' : formatRateValue(derivedRate),
      accountsById[entry.accountId]?.currencyCode ?? '',
      accountsById[entry.toAccountId]?.currencyCode ?? '',
    ]);
  }
  return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
}

String _csvDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}

String _csvCell(String value) {
  if (!value.contains(RegExp('[,"\\r\\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// 校验 CSV 是否为 Veri Fin 模板：首行每一列（去空白、忽略空列）都必须是模板认识的列名
/// （[_headerAliases] 的规范列——模板列加可选 子分类/标签/手续费/退款）。出现任何**外来列**
/// （如钱迹「账户1/账户2/一级分类」、随手记「交易类型」）即抛 [FormatException]，引导用户
/// 使用本应用下载的模板。必需列是否齐全交由 [parseCsvTemplateRows] 统一报错，不在此重复。
///
/// 用白名单而非「表头必须完全等于模板列」，是为了在严格拒绝第三方文件的同时，仍允许模板
/// 省略可选列、或补上 子分类/标签 列（issue #11 的层级分类与多标签导入）。
void validateCsvTemplateHeader(List<List<String>> rows) {
  if (rows.isEmpty) {
    throw const FormatException('文件为空');
  }
  final allowed = _headerAliases.values
      .expand((names) => names)
      .map(_normalizeHeader)
      .toSet();
  final unknown = rows.first
      .map((cell) => cell.trim())
      .where(
        (cell) => cell.isNotEmpty && !allowed.contains(_normalizeHeader(cell)),
      )
      .toList();
  if (unknown.isNotEmpty) {
    throw FormatException(
      '表头包含非模板列：${unknown.join('、')}。'
      '请使用本应用「下载 CSV 模板」的表头（日期、类型、金额、分类、账户、转入账户、备注，'
      '可选 子分类、标签、币种、账户金额、本位币金额、转入金额、汇率、账户币种），'
      '其他记账软件请用对应的导入入口',
    );
  }
}

String _normalizeHeader(String raw) => raw.trim().toLowerCase();

/// 根据表头构建列索引；缺少必需列时返回 null。
Map<String, int>? _resolveColumns(List<String> header) {
  final normalized = header.map(_normalizeHeader).toList();
  final columns = <String, int>{};
  for (final entry in _headerAliases.entries) {
    for (var i = 0; i < normalized.length; i++) {
      if (entry.value.map((a) => a.toLowerCase()).contains(normalized[i])) {
        columns[entry.key] = i;
        break;
      }
    }
  }
  for (final required in <String>['date', 'type', 'amount', 'account']) {
    if (!columns.containsKey(required)) {
      return null;
    }
  }
  return columns;
}

/// 解析「CSV 模板」字节为 [ParsedImport]：UTF-8 解码 → 分词 → 白名单校验表头 → 逐行成
/// 强类型记录（type/amount/date 无法解析的行记入错误、不产记录）。缺必需列抛
/// [FormatException]。
ParsedImport parseCsvTemplate(Uint8List bytes) {
  final rows = parseCsv(decodeUtf8Bytes(bytes));
  validateCsvTemplateHeader(rows);
  return parseCsvTemplateRows(rows);
}

/// 由已分词的 CSV 行（首行为表头）构建 [ParsedImport]。供 [parseCsvTemplate] 与
/// 兼容入口 `buildImportPlan(rows:)` 共用。缺必需列抛 [FormatException]。
ParsedImport parseCsvTemplateRows(List<List<String>> rows) {
  if (rows.isEmpty) {
    throw const FormatException('文件为空');
  }
  final columns = _resolveColumns(rows.first);
  if (columns == null) {
    throw const FormatException('缺少必需的列：日期、类型、金额、账户');
  }

  String cell(List<String> row, String key) {
    final index = columns[key];
    if (index == null || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  final records = <RawImportRecord>[];
  final errors = <ImportRowError>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final line = i + 1;
    final rawCurrencyCode = cell(row, 'currency').toUpperCase();
    final rawAccountCurrency = cell(row, 'accountCurrency').toUpperCase();
    final rawToAccountCurrency = cell(row, 'toAccountCurrency').toUpperCase();
    final invalidCurrencyCodes = <String>[
      rawCurrencyCode,
      rawAccountCurrency,
      rawToAccountCurrency,
    ].where((code) => code.isNotEmpty && !CurrencyCatalog.isSupported(code));
    if (invalidCurrencyCodes.isNotEmpty) {
      errors.add(
        ImportRowError(
          line: line,
          message: '币种代码无法识别：${invalidCurrencyCodes.join('、')}',
        ),
      );
      continue;
    }
    final invalidOptionalAmounts =
        <String, String>{
              '账户金额': cell(row, 'accountAmount'),
              '本位币金额': cell(row, 'baseAmount'),
              '转入金额': cell(row, 'toAccountAmount'),
              '汇率': cell(row, 'rateToBase'),
            }.entries
            .where(
              (entry) =>
                  entry.value.isNotEmpty &&
                  (entry.key == '本位币金额'
                          ? parseImportAmountAllowZero(entry.value)
                          : parseImportAmount(entry.value)) ==
                      null,
            )
            .map((entry) => entry.key)
            .toList();
    if (invalidOptionalAmounts.isNotEmpty) {
      errors.add(
        ImportRowError(
          line: line,
          message: '${invalidOptionalAmounts.join('、')}无效（应为大于 0 的数字）',
        ),
      );
      continue;
    }
    final record = buildRecordFromStrings(
      date: cell(row, 'date'),
      type: cell(row, 'type'),
      amount: cell(row, 'amount'),
      category: cell(row, 'category'),
      subCategory: cell(row, 'subcategory'),
      account: cell(row, 'account'),
      toAccount: cell(row, 'toAccount'),
      note: cell(row, 'note'),
      fee: cell(row, 'fee'),
      refunded: cell(row, 'refunded'),
      currencyCode: rawCurrencyCode,
      accountCurrencyCode: rawAccountCurrency,
      toAccountCurrencyCode: rawToAccountCurrency,
      accountAmount: cell(row, 'accountAmount'),
      baseAmount: cell(row, 'baseAmount'),
      toAccountAmount: cell(row, 'toAccountAmount'),
      rateToBase: cell(row, 'rateToBase'),
      tags: splitTagLabels(cell(row, 'tags')),
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
