import '../category_tree.dart';
import '../models.dart';

/// 单行导入错误（行号从 1 计，含表头）。
class ImportRowError {
  const ImportRowError({required this.line, required this.message});

  final int line;
  final String message;
}

/// 导入计划：待新增的交易，以及为匹配名称需要新建的账户/分类，和逐行错误。
class ImportPlan {
  const ImportPlan({
    required this.entries,
    required this.newAccounts,
    required this.newCategories,
    required this.errors,
    this.source,
    this.standaloneAccountIds = const <String>{},
  });

  final List<LedgerEntry> entries;
  final List<Account> newAccounts;
  final List<Category> newCategories;
  final List<ImportRowError> errors;

  /// 识别到的导入来源（钱迹 / 随手记 / 模板），未识别为 null。
  final ImportSource? source;

  /// 待新建账户中「即使没有交易引用也要创建」的 id 集合。默认空——普通 CSV 导入的
  /// 账户都由交易派生、被排除后不应留下空账户；仅 Tally 这类携带账户余额/类型的来源，
  /// 会把源账本里的资产账户（含零余额、无流水的账户）标记为独立账户一并落库。
  final Set<String> standaloneAccountIds;

  int get importedCount => entries.length;
  int get errorCount => errors.length;
  bool get isEmpty => entries.isEmpty && errors.isEmpty;
}

/// 模板/导入表头别名（中英文兼容，含钱迹 / 随手记等常见导出列名）。
const Map<String, List<String>> _headerAliases = <String, List<String>>{
  'date': <String>['日期', 'date', '时间', 'time', '交易时间', '记账时间'],
  'type': <String>['类型', 'type', '收支', '收支类型', '交易类型'],
  'amount': <String>['金额', 'amount', '数额', '钱数', '金额（元）'],
  'category': <String>['分类', 'category', '类别', '一级分类', '分类名称'],
  'account': <String>['账户', 'account', '账号', '转出账户', '账户1', '支付账户'],
  'toAccount': <String>['转入账户', 'toaccount', 'to account', '目标账户', '账户2'],
  'note': <String>['备注', 'note', 'memo', '说明', '描述', '备注信息'],
  'fee': <String>['手续费', 'fee', '服务费'],
  'refunded': <String>['退款', 'refund', '退款金额', 'refunded'],
};

/// 可识别的导入来源，用于给用户友好提示。
enum ImportSource {
  veriFin('Veri Fin 模板'),
  qianji('钱迹'),
  suishouji('随手记');

  const ImportSource(this.label);

  final String label;
}

/// 根据表头识别导入来源；无法识别返回 null（仍可能按通用别名解析）。
ImportSource? detectImportSource(List<String> header) {
  final cells = header.map((cell) => cell.trim()).toSet();
  bool has(String name) => cells.contains(name);
  final hasForeignAccounts = has('账户1') || has('账户2');
  // 随手记导出以「交易类型」为列名。
  if (has('交易类型') && (hasForeignAccounts || has('账户'))) {
    return ImportSource.suishouji;
  }
  // 钱迹导出含「类型」+「账户1/账户2」+「一级分类/分类」。
  if (has('类型') && hasForeignAccounts && (has('一级分类') || has('分类'))) {
    return ImportSource.qianji;
  }
  if (has('类型') && has('账户') && has('金额') && has('日期')) {
    return ImportSource.veriFin;
  }
  return null;
}

/// CSV 模板内容（带表头与示例行），用户下载后填写再导入。
String transactionCsvTemplate() {
  return '日期,类型,金额,分类,账户,转入账户,备注\n'
      '2026-01-05,支出,23.50,餐饮,现金,,午饭\n'
      '2026-01-05,收入,8000,工资,储蓄卡,,月薪\n'
      '2026-01-06,转账,500,,现金,储蓄卡,取现\n';
}

/// 解析 CSV（兼容引号包裹、字段内逗号与换行、双引号转义、CRLF）。
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  var fieldStarted = false;
  var rowHasContent = false;

  void endField() {
    row.add(field.toString());
    field = StringBuffer();
    fieldStarted = false;
  }

  void endRow() {
    endField();
    // 忽略完全空白的行。
    if (rowHasContent) {
      rows.add(row);
    }
    row = <String>[];
    rowHasContent = false;
  }

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(char);
        rowHasContent = true;
      }
      continue;
    }
    switch (char) {
      case '"':
        inQuotes = true;
        fieldStarted = true;
        rowHasContent = true;
        break;
      case ',':
        endField();
        break;
      case '\r':
        break;
      case '\n':
        endRow();
        break;
      default:
        field.write(char);
        if (char.trim().isNotEmpty) {
          rowHasContent = true;
        }
        fieldStarted = true;
        break;
    }
  }
  // 处理最后一行（无结尾换行）。
  if (fieldStarted || row.isNotEmpty || rowHasContent) {
    endRow();
  }
  return rows;
}

EntryType? _parseType(String raw) {
  final value = raw.trim().toLowerCase();
  switch (value) {
    case '支出':
    case 'expense':
    case '支':
      return EntryType.expense;
    case '收入':
    case 'income':
    case '收':
      return EntryType.income;
    case '转账':
    case 'transfer':
    case '转':
      return EntryType.transfer;
  }
  return null;
}

double? _parseAmount(String raw) {
  final cleaned = raw
      .trim()
      .replaceAll(RegExp(r'[¥$,\s]'), '')
      .replaceAll('，', '');
  if (cleaned.isEmpty) {
    return null;
  }
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value.isInfinite) {
    return null;
  }
  // 部分导出（如钱迹）支出金额为负，方向由「类型」列决定，这里取绝对值。
  final magnitude = value.abs();
  return magnitude == 0 ? null : magnitude;
}

/// 转账手续费：可空/可为 0，非法或负数按 0 处理（不像金额那样使整行失败）。
double _parseFee(String raw) {
  final cleaned = raw
      .trim()
      .replaceAll(RegExp(r'[¥$,\s]'), '')
      .replaceAll('，', '');
  if (cleaned.isEmpty) {
    return 0;
  }
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value.isInfinite || value < 0) {
    return 0;
  }
  return value;
}

DateTime? _parseDate(String raw) {
  final value = raw.trim().replaceAll('/', '-').replaceAll('.', '-');
  if (value.isEmpty) {
    return null;
  }
  // 支持 "YYYY-MM-DD" 或 "YYYY-MM-DD HH:MM(:SS)"。
  final match = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.tryParse(match.group(4) ?? '') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '') ?? 0;
  final second = int.tryParse(match.group(6) ?? '') ?? 0;
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  final result = DateTime(year, month, day, hour, minute, second);
  // DateTime 会把越界的日静默归一化（如 2-30 → 3-2）。回读校验，宁可判为无效日期
  // 让该行报错，也不要静默记成错误的日期。
  if (result.year != year || result.month != month || result.day != day) {
    return null;
  }
  return result;
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

/// 由解析后的 CSV 单元格构建导入计划。纯函数：不修改传入集合，id 由
/// [now] 与行序派生（保证同输入可复现）。缺必需列抛 [FormatException]。
ImportPlan buildImportPlan({
  required List<List<String>> rows,
  required String bookId,
  required List<Account> existingAccounts,
  required List<Category> existingCategories,
  required DateTime now,
}) {
  if (rows.isEmpty) {
    throw const FormatException('文件为空');
  }
  final columns = _resolveColumns(rows.first);
  if (columns == null) {
    throw const FormatException('缺少必需的列：日期、类型、金额、账户');
  }
  final source = detectImportSource(rows.first);

  final workingAccounts = List<Account>.from(existingAccounts);
  final workingCategories = List<Category>.from(existingCategories);
  final newAccounts = <Account>[];
  final newCategories = <Category>[];
  final entries = <LedgerEntry>[];
  final errors = <ImportRowError>[];
  var idCounter = 0;

  String nextId(String prefix) {
    idCounter++;
    return '${prefix}_${now.microsecondsSinceEpoch}_$idCounter';
  }

  String cell(List<String> row, String key) {
    final index = columns[key];
    if (index == null || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  String resolveAccount(String name) {
    final match = workingAccounts.firstWhere(
      (account) => account.name == name,
      orElse: () => const Account(
        id: '',
        bookId: '',
        name: '',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 0,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      ),
    );
    if (match.id.isNotEmpty) {
      return match.id;
    }
    final account = Account(
      id: nextId('account'),
      bookId: bookId,
      name: name,
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    workingAccounts.add(account);
    newAccounts.add(account);
    return account.id;
  }

  String resolveCategory(String name, EntryType type) {
    if (name.isEmpty) {
      return '';
    }
    // 名称按归一化比较（容忍大小写/首尾空白/全半角差异），命中即复用现有分类，
    // 不因近似同名而增殖出重复分类。
    final normalized = normalizedCategoryLabel(name);
    final match = workingCategories.firstWhere(
      (category) =>
          category.type == type &&
          normalizedCategoryLabel(category.label) == normalized,
      orElse: () => const Category(
        id: '',
        label: '',
        type: EntryType.expense,
        iconCode: '',
      ),
    );
    if (match.id.isNotEmpty) {
      return match.id;
    }
    final category = Category(
      id: nextId('category'),
      label: name,
      type: type,
      iconCode: 'category',
    );
    workingCategories.add(category);
    newCategories.add(category);
    return category.id;
  }

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final line = i + 1;
    final type = _parseType(cell(row, 'type'));
    if (type == null) {
      errors.add(ImportRowError(line: line, message: '类型无法识别（应为 支出/收入/转账）'));
      continue;
    }
    final amount = _parseAmount(cell(row, 'amount'));
    if (amount == null) {
      errors.add(ImportRowError(line: line, message: '金额无效（应为大于 0 的数字）'));
      continue;
    }
    final date = _parseDate(cell(row, 'date'));
    if (date == null) {
      errors.add(ImportRowError(line: line, message: '日期格式无效（应为 2026-01-05）'));
      continue;
    }
    // 账户可空：留空表示「无账户」（只记金额、不计入任何账户余额）。
    final accountName = cell(row, 'account');
    final note = cell(row, 'note');

    if (type == EntryType.transfer) {
      final toName = cell(row, 'toAccount');
      if (accountName.isEmpty && toName.isEmpty) {
        errors.add(ImportRowError(line: line, message: '转账缺少账户'));
        continue;
      }
      if (accountName.isNotEmpty && toName == accountName) {
        errors.add(ImportRowError(line: line, message: '转出与转入账户不能相同'));
        continue;
      }
      // 单边为空（如源账本转入/转出到未跟踪账户）仍按转账记，空的一端不计余额。
      final fromId = accountName.isEmpty ? '' : resolveAccount(accountName);
      final toId = toName.isEmpty ? null : resolveAccount(toName);
      entries.add(
        LedgerEntry(
          id: nextId('entry'),
          bookId: bookId,
          type: type,
          amount: amount,
          categoryId: '',
          accountId: fromId,
          toAccountId: toId,
          note: note,
          occurredAt: date,
          fee: _parseFee(cell(row, 'fee')),
        ),
      );
      continue;
    }

    final accountId = accountName.isEmpty ? '' : resolveAccount(accountName);
    final categoryId = resolveCategory(cell(row, 'category'), type);
    // 支出可带「退款」列（部分/全额退回）：映射到 refundedAmount，钳制在 [0, 金额]，
    // 使净额=金额−退款、退款回到原账户（与 App 内退款冲抵语义一致）。收入行忽略。
    final refunded = type == EntryType.expense
        ? _parseFee(cell(row, 'refunded')).clamp(0, amount).toDouble()
        : 0.0;
    entries.add(
      LedgerEntry(
        id: nextId('entry'),
        bookId: bookId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: null,
        note: note,
        occurredAt: date,
        refundedAmount: refunded,
      ),
    );
  }

  return ImportPlan(
    entries: entries,
    newAccounts: newAccounts,
    newCategories: newCategories,
    errors: errors,
    source: source,
  );
}
