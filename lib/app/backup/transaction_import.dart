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
  });

  final List<LedgerEntry> entries;
  final List<Account> newAccounts;
  final List<Category> newCategories;
  final List<ImportRowError> errors;

  int get importedCount => entries.length;
  int get errorCount => errors.length;
  bool get isEmpty => entries.isEmpty && errors.isEmpty;
}

/// 模板/导入表头别名（中英文兼容）。
const Map<String, List<String>> _headerAliases = <String, List<String>>{
  'date': <String>['日期', 'date', '时间', 'time'],
  'type': <String>['类型', 'type', '收支', '收支类型'],
  'amount': <String>['金额', 'amount', '数额', '钱数'],
  'category': <String>['分类', 'category', '类别'],
  'account': <String>['账户', 'account', '账号', '转出账户'],
  'toAccount': <String>['转入账户', 'toaccount', 'to account', '目标账户'],
  'note': <String>['备注', 'note', 'memo', '说明', '描述'],
};

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
  if (value == null || value <= 0 || value.isNaN || value.isInfinite) {
    return null;
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
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime(year, month, day, hour, minute, second);
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
    final match = workingCategories.firstWhere(
      (category) => category.label == name && category.type == type,
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
    final accountName = cell(row, 'account');
    if (accountName.isEmpty) {
      errors.add(ImportRowError(line: line, message: '账户不能为空'));
      continue;
    }
    final note = cell(row, 'note');

    if (type == EntryType.transfer) {
      final toName = cell(row, 'toAccount');
      if (toName.isEmpty) {
        errors.add(ImportRowError(line: line, message: '转账缺少转入账户'));
        continue;
      }
      if (toName == accountName) {
        errors.add(ImportRowError(line: line, message: '转出与转入账户不能相同'));
        continue;
      }
      final fromId = resolveAccount(accountName);
      final toId = resolveAccount(toName);
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
        ),
      );
      continue;
    }

    final accountId = resolveAccount(accountName);
    final categoryId = resolveCategory(cell(row, 'category'), type);
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
      ),
    );
  }

  return ImportPlan(
    entries: entries,
    newAccounts: newAccounts,
    newCategories: newCategories,
    errors: errors,
  );
}
