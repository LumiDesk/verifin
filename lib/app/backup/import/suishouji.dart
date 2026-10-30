import 'dart:typed_data';

import '../../currency_catalog.dart';
import '../../models.dart';
import 'raw_import.dart';
import 'text_format.dart';
import 'xlsx_reader.dart';

/// 随手记导出的 Excel 账单：同一个 `.xlsx` 里按交易类型分成多张工作表。
///
/// | 随手记工作表 | Veri Fin | 说明 |
/// |---|---|---|
/// | 支出 / 收入 | 支出 / 收入 | 一级分类 + 二级分类还原父子层级 |
/// | 转账 | 转账 | 转出账户 → 转入账户；不记收支 |
/// | 退款 | 收入（兜底）| 导出没有原支出编号，无法关联原支出；按收入导入保证账户余额正确 |
/// | 余额变更 | 收入 / 支出 | 正数记收入、负数记支出，落到本账本「余额调整」系统分类 |
/// | 负债变更 | （跳过）| 正数可能表示欠款增加或余额增加，导出没有账户类型，方向无法确定 |
/// | 收债 / 借出 / 还债 / 借入 | （跳过）| Veri Fin 无债务/借贷功能，硬记会污染统计并凭空造应收/应付账户 |
///
/// 账户列名在不同工作表里不同（支出账户 / 收入账户 / 账户1 / 转出账户 / 转入账户），
/// 因此按表头名取列而不是按固定位置。账户统一建为现金账户并保留来源币种——导出没有
/// 账户类型与当前余额，不猜品牌类型，余额由导入交易重建。成员、项目、记账人不导入；
/// 商家并入备注。基于 Issue 52 用户真实导出样例。
ParsedImport parseSuishouji(Uint8List bytes) {
  final List<XlsxSheet> sheets;
  try {
    sheets = parseXlsxSheets(bytes);
  } on FormatException catch (error) {
    throw FormatException('${error.message}（请确认选择的是随手记导出的 xlsx）');
  }

  final records = <RawImportRecord>[];
  final errors = <ImportRowError>[];
  var supportedSheets = 0;

  for (final sheet in sheets) {
    switch (sheet.name) {
      case '支出':
        supportedSheets++;
        _parseExpenseLike(
          sheet,
          type: EntryType.expense,
          accountHeaders: const <String>['支出账户', '账户1'],
          records: records,
          errors: errors,
        );
        break;
      case '收入':
        supportedSheets++;
        _parseExpenseLike(
          sheet,
          type: EntryType.income,
          accountHeaders: const <String>['收入账户', '账户1'],
          records: records,
          errors: errors,
        );
        break;
      case '退款':
        supportedSheets++;
        _parseRefund(sheet, records: records, errors: errors);
        break;
      case '转账':
        supportedSheets++;
        _parseTransfer(sheet, records: records, errors: errors);
        break;
      case '余额变更':
        supportedSheets++;
        _parseBalanceChange(sheet, records: records, errors: errors);
        break;
      case '收债' || '借出' || '还债' || '借入' || '负债变更':
        // 债务/借贷与负债变更一律跳过：Veri Fin 没有这些领域模型，凭空造账户或按
        // 猜测的方向记收支都会破坏统计与资产列表。与钱迹 parser 的既有约定一致。
        break;
      default:
        // 未知工作表不猜，宁可漏也不记错。
        break;
    }
  }

  if (supportedSheets == 0) {
    throw const FormatException(
      '未找到随手记账单工作表（支出/收入/转账/退款/余额变更），请确认选择的是随手记导出的 xlsx',
    );
  }
  return ParsedImport(records: records, errors: errors);
}

/// 单张工作表的表头与列索引。`cell` 按列名取值，越界/缺失列返回空串。
class _SheetTable {
  const _SheetTable({
    required this.sheet,
    required this.headerIndex,
    required this.columns,
  });

  final XlsxSheet sheet;
  final int headerIndex;
  final Map<String, int> columns;

  String cell(List<String> row, String name) => cellAt(row, columns[name]);

  int? column(List<String> names) => columnOf(columns, names);
}

/// 空表（没有任何非空行）直接跳过；表头缺失或必需列缺失属于格式错误，抛
/// [FormatException] 让用户知道选错了文件，而不是静默导入半套数据。
_SheetTable? _openTable(
  XlsxSheet sheet, {
  required List<String> mustHave,
  List<List<String>> requiredColumns = const <List<String>>[],
}) {
  if (sheet.rows.every(_isBlankRow)) {
    return null;
  }
  final headerIndex = findHeaderRow(sheet.rows, mustHave: mustHave);
  if (headerIndex == null) {
    throw FormatException(
      '未找到随手记「${sheet.name}」表头（${mustHave.join('/')}），'
      '请确认选择的是随手记导出的 xlsx',
    );
  }
  final columns = columnIndex(sheet.rows[headerIndex]);
  for (final aliases in requiredColumns) {
    if (aliases.isNotEmpty && columnOf(columns, aliases) == null) {
      throw FormatException('随手记「${sheet.name}」缺少${aliases.first}列，请确认导出文件完整');
    }
  }
  return _SheetTable(sheet: sheet, headerIndex: headerIndex, columns: columns);
}

bool _isBlankRow(List<String> row) => row.every((cell) => cell.trim().isEmpty);

void _addError(
  List<ImportRowError> errors,
  XlsxSheet sheet,
  int line,
  String message,
) {
  errors.add(ImportRowError(line: line, message: '${sheet.name}：$message'));
}

double? _readAmount(
  _SheetTable table,
  List<String> row,
  int line,
  List<ImportRowError> errors,
) {
  final amount = parseImportAmountAllowZero(table.cell(row, '金额'));
  if (amount == null) {
    _addError(errors, table.sheet, line, '金额无效（应为数字）');
  }
  return amount;
}

DateTime? _readDate(
  _SheetTable table,
  List<String> row,
  int line,
  List<ImportRowError> errors,
) {
  final date = parseImportDate(table.cell(row, '日期'));
  if (date == null) {
    _addError(
      errors,
      table.sheet,
      line,
      '日期格式无效（应为 2026-01-05 或 2026-01-05 12:30:00）',
    );
  }
  return date;
}

/// 读取币种；空串返回 null（由 plan builder 回退当前账本本位币）。
String? _currency(List<String> row, _SheetTable table) {
  final value = table.cell(row, '账户币种').trim().toUpperCase();
  return value.isEmpty ? null : value;
}

bool _currencyIsInvalid(String? code) {
  return code != null && !CurrencyCatalog.isSupported(code);
}

String _note(_SheetTable table, List<String> row) {
  return joinNote(<String>[table.cell(row, '备注'), table.cell(row, '商家')]);
}

void _parseExpenseLike(
  XlsxSheet sheet, {
  required EntryType type,
  required List<String> accountHeaders,
  required List<RawImportRecord> records,
  required List<ImportRowError> errors,
}) {
  final table = _openTable(
    sheet,
    mustHave: const <String>['交易类型', '日期', '一级分类', '二级分类', '账户币种', '金额'],
    requiredColumns: <List<String>>[accountHeaders],
  );
  if (table == null) {
    return;
  }
  final accountIndex = table.column(accountHeaders)!;
  final expectedType = switch (type) {
    EntryType.expense => '支出',
    EntryType.income => '收入',
    EntryType.transfer => '转账',
    EntryType.refund => '退款',
  };
  for (var i = table.headerIndex + 1; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    if (_isBlankRow(row)) {
      continue;
    }
    final line = i + 1;
    final rawType = table.cell(row, '交易类型');
    if (rawType.isNotEmpty && rawType != expectedType) {
      _addError(errors, sheet, line, '交易类型「$rawType」与工作表不一致');
      continue;
    }
    final amount = _readAmount(table, row, line, errors);
    if (amount == null) {
      continue;
    }
    if (amount == 0) {
      continue;
    }
    final date = _readDate(table, row, line, errors);
    if (date == null) {
      continue;
    }
    final currency = _currency(row, table);
    if (_currencyIsInvalid(currency)) {
      _addError(errors, sheet, line, '币种代码无法识别：$currency');
      continue;
    }
    records.add(
      RawImportRecord(
        date: date,
        type: type,
        amount: amount,
        currencyCode: currency,
        accountCurrencyCode: currency,
        category: table.cell(row, '一级分类'),
        subCategory: table.cell(row, '二级分类'),
        account: cellAt(row, accountIndex),
        note: _note(table, row),
        sourceLine: line,
      ),
    );
  }
}

void _parseRefund(
  XlsxSheet sheet, {
  required List<RawImportRecord> records,
  required List<ImportRowError> errors,
}) {
  final table = _openTable(
    sheet,
    mustHave: const <String>['交易类型', '日期', '一级分类', '二级分类', '账户1', '账户币种', '金额'],
    requiredColumns: const <List<String>>[
      <String>['账户1'],
    ],
  );
  if (table == null) {
    return;
  }
  final accountIndex = table.column(const <String>['账户1'])!;
  for (var i = table.headerIndex + 1; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    if (_isBlankRow(row)) {
      continue;
    }
    final line = i + 1;
    final rawType = table.cell(row, '交易类型');
    if (rawType.isNotEmpty && rawType != '退款') {
      _addError(errors, sheet, line, '交易类型「$rawType」与工作表不一致');
      continue;
    }
    final amount = _readAmount(table, row, line, errors);
    if (amount == null) {
      continue;
    }
    if (amount == 0) {
      continue;
    }
    final date = _readDate(table, row, line, errors);
    if (date == null) {
      continue;
    }
    final currency = _currency(row, table);
    if (_currencyIsInvalid(currency)) {
      _addError(errors, sheet, line, '币种代码无法识别：$currency');
      continue;
    }
    // 导出没有原支出编号，无法生成 refundOf 关联；按收入兜底，至少保证退款回到
    // 对应账户，账户余额不会凭空少一笔。原支出净额不回冲是随手记导出的已知限制。
    records.add(
      RawImportRecord(
        date: date,
        type: EntryType.income,
        amount: amount,
        currencyCode: currency,
        accountCurrencyCode: currency,
        category: table.cell(row, '一级分类'),
        subCategory: table.cell(row, '二级分类'),
        account: cellAt(row, accountIndex),
        note: _note(table, row),
        sourceLine: line,
      ),
    );
  }
}

void _parseTransfer(
  XlsxSheet sheet, {
  required List<RawImportRecord> records,
  required List<ImportRowError> errors,
}) {
  final table = _openTable(
    sheet,
    mustHave: const <String>['交易类型', '日期', '转出账户', '转入账户', '账户币种', '金额'],
  );
  if (table == null) {
    return;
  }
  for (var i = table.headerIndex + 1; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    if (_isBlankRow(row)) {
      continue;
    }
    final line = i + 1;
    final rawType = table.cell(row, '交易类型');
    if (rawType.isNotEmpty && rawType != '转账') {
      _addError(errors, sheet, line, '交易类型「$rawType」与工作表不一致');
      continue;
    }
    final amount = _readAmount(table, row, line, errors);
    if (amount == null) {
      continue;
    }
    if (amount == 0) {
      continue;
    }
    final date = _readDate(table, row, line, errors);
    if (date == null) {
      continue;
    }
    final from = table.cell(row, '转出账户');
    final to = table.cell(row, '转入账户');
    if (from.isEmpty && to.isEmpty) {
      _addError(errors, sheet, line, '转账缺少账户');
      continue;
    }
    if (from.isNotEmpty && from == to) {
      _addError(errors, sheet, line, '转出与转入账户不能相同');
      continue;
    }
    final currency = _currency(row, table);
    if (_currencyIsInvalid(currency)) {
      _addError(errors, sheet, line, '币种代码无法识别：$currency');
      continue;
    }
    records.add(
      RawImportRecord(
        date: date,
        type: EntryType.transfer,
        amount: amount,
        currencyCode: currency,
        accountCurrencyCode: currency,
        toAccountCurrencyCode: currency,
        account: from,
        toAccount: to,
        note: _note(table, row),
        sourceLine: line,
      ),
    );
  }
}

void _parseBalanceChange(
  XlsxSheet sheet, {
  required List<RawImportRecord> records,
  required List<ImportRowError> errors,
}) {
  final table = _openTable(
    sheet,
    mustHave: const <String>['交易类型', '日期', '账户1', '账户币种', '金额'],
    requiredColumns: const <List<String>>[
      <String>['账户1'],
    ],
  );
  if (table == null) {
    return;
  }
  final accountIndex = table.column(const <String>['账户1'])!;
  for (var i = table.headerIndex + 1; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    if (_isBlankRow(row)) {
      continue;
    }
    final line = i + 1;
    final rawType = table.cell(row, '交易类型');
    if (rawType.isNotEmpty && rawType != '余额变更') {
      _addError(errors, sheet, line, '交易类型「$rawType」与工作表不一致');
      continue;
    }
    final rawAmount = table.cell(row, '金额');
    final signed = parseImportSignedAmount(rawAmount);
    if (signed == null) {
      _addError(errors, sheet, line, '金额无效（应为数字）');
      continue;
    }
    if (signed == 0) {
      continue;
    }
    final account = cellAt(row, accountIndex);
    if (account.isEmpty) {
      _addError(errors, sheet, line, '余额变更缺少账户');
      continue;
    }
    final date = _readDate(table, row, line, errors);
    if (date == null) {
      continue;
    }
    final currency = _currency(row, table);
    if (_currencyIsInvalid(currency)) {
      _addError(errors, sheet, line, '币种代码无法识别：$currency');
      continue;
    }
    final type = signed > 0 ? EntryType.income : EntryType.expense;
    records.add(
      RawImportRecord(
        date: date,
        type: type,
        amount: signed.abs(),
        currencyCode: currency,
        accountCurrencyCode: currency,
        categoryKey: balanceAdjustCategoryKey(type),
        account: account,
        note: _note(table, row),
        sourceLine: line,
      ),
    );
  }
}
