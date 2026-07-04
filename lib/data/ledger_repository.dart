import 'package:sqflite_common/sqlite_api.dart';

import '../app/models.dart';
import 'app_database.dart';

/// 账目类数据仓储接口。生产实现为 [SqliteLedgerRepository]；测试可注入内存实现，
/// 避免真实异步 I/O 与 widget 测试的 fake-async 冲突。
///
/// 语义为「整表覆盖」：每次 saveX 以传入列表整体替换该类数据。
abstract interface class LedgerRepository {
  Future<List<LedgerEntry>> loadEntries();
  Future<void> saveEntries(List<LedgerEntry> entries);

  Future<List<LedgerBook>> loadBooks();
  Future<void> saveBooks(List<LedgerBook> books);

  Future<List<Account>> loadAccounts();
  Future<void> saveAccounts(List<Account> accounts);

  Future<List<AccountGroup>> loadAccountGroups();
  Future<void> saveAccountGroups(List<AccountGroup> groups);

  Future<List<Category>> loadCategories();
  Future<void> saveCategories(List<Category> categories);

  Future<Map<String, double>> loadMonthlyBudgets();
  Future<void> saveMonthlyBudgets(Map<String, double> budgets);

  Future<Map<String, double>> loadCategoryBudgets();
  Future<void> saveCategoryBudgets(Map<String, double> budgets);

  Future<bool> hasAnyData();
}

/// 基于 SQLite 的仓储实现。每次写入以事务批量清空并重建对应表；列表顺序通过
/// sort_order 列保留（entries 除外，其顺序由 occurred_at 决定）。
class SqliteLedgerRepository implements LedgerRepository {
  SqliteLedgerRepository(this._database);

  final AppDatabase _database;
  Database get _db => _database.db;

  // ---- 交易 ----

  @override
  Future<List<LedgerEntry>> loadEntries() async {
    final rows = await _db.query(
      'entries',
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(_entryFromRow).toList();
  }

  @override
  Future<void> saveEntries(List<LedgerEntry> entries) async {
    await _replaceAll('entries', entries.map(_entryToRow));
  }

  // ---- 账本 ----

  @override
  Future<List<LedgerBook>> loadBooks() async {
    final rows = await _db.query('ledger_books', orderBy: 'sort_order ASC');
    return rows.map(_bookFromRow).toList();
  }

  @override
  Future<void> saveBooks(List<LedgerBook> books) async {
    await _replaceAll('ledger_books', _indexed(books, _bookToRow));
  }

  // ---- 账户 ----

  @override
  Future<List<Account>> loadAccounts() async {
    final rows = await _db.query('accounts', orderBy: 'sort_order ASC');
    return rows.map(_accountFromRow).toList();
  }

  @override
  Future<void> saveAccounts(List<Account> accounts) async {
    await _replaceAll('accounts', _indexed(accounts, _accountToRow));
  }

  // ---- 账户分组 ----

  @override
  Future<List<AccountGroup>> loadAccountGroups() async {
    final rows = await _db.query('account_groups', orderBy: 'sort_order ASC');
    return rows.map(_groupFromRow).toList();
  }

  @override
  Future<void> saveAccountGroups(List<AccountGroup> groups) async {
    await _replaceAll('account_groups', groups.map(_groupToRow));
  }

  // ---- 分类 ----

  @override
  Future<List<Category>> loadCategories() async {
    final rows = await _db.query('categories', orderBy: 'sort_order ASC');
    return rows.map(_categoryFromRow).toList();
  }

  @override
  Future<void> saveCategories(List<Category> categories) async {
    await _replaceAll('categories', _indexed(categories, _categoryToRow));
  }

  // ---- 预算（键值对：月度 / 分类）----

  @override
  Future<Map<String, double>> loadMonthlyBudgets() =>
      _loadBudgetMap('monthly_budgets');

  @override
  Future<void> saveMonthlyBudgets(Map<String, double> budgets) =>
      _saveBudgetMap('monthly_budgets', budgets);

  @override
  Future<Map<String, double>> loadCategoryBudgets() =>
      _loadBudgetMap('category_budgets');

  @override
  Future<void> saveCategoryBudgets(Map<String, double> budgets) =>
      _saveBudgetMap('category_budgets', budgets);

  /// 是否已存在任何账目数据（用于判断迁移是否有内容写入）。
  @override
  Future<bool> hasAnyData() async {
    for (final table in const <String>[
      'entries',
      'ledger_books',
      'accounts',
      'account_groups',
      'categories',
    ]) {
      final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      final count = (rows.first['c'] as int?) ?? 0;
      if (count > 0) {
        return true;
      }
    }
    return false;
  }

  // ---- 内部工具 ----

  Future<void> _replaceAll(
    String table,
    Iterable<Map<String, Object?>> rows,
  ) async {
    final rowList = rows.toList();
    await _db.transaction((txn) async {
      await txn.delete(table);
      final batch = txn.batch();
      for (final row in rowList) {
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, double>> _loadBudgetMap(String table) async {
    final rows = await _db.query(table);
    return <String, double>{
      for (final row in rows)
        row['scope_key'] as String: (row['amount'] as num).toDouble(),
    };
  }

  Future<void> _saveBudgetMap(String table, Map<String, double> budgets) async {
    await _replaceAll(
      table,
      budgets.entries.map(
        (entry) => <String, Object?>{
          'scope_key': entry.key,
          'amount': entry.value,
        },
      ),
    );
  }

  /// 为有序列表补充 sort_order 列（值为列表下标）。
  static Iterable<Map<String, Object?>> _indexed<T>(
    List<T> items,
    Map<String, Object?> Function(T item, int index) toRow,
  ) {
    return items.indexed.map((item) => toRow(item.$2, item.$1));
  }

  // ---- 行映射 ----

  static Map<String, Object?> _entryToRow(LedgerEntry e) => <String, Object?>{
    'id': e.id,
    'book_id': e.bookId,
    'type': e.type.storageValue,
    'amount': e.amount,
    'category_id': e.categoryId,
    'account_id': e.accountId,
    'to_account_id': e.toAccountId,
    'note': e.note,
    'occurred_at': e.occurredAt.millisecondsSinceEpoch,
  };

  static LedgerEntry _entryFromRow(Map<String, Object?> row) => LedgerEntry(
    id: row['id'] as String,
    bookId: row['book_id'] as String,
    type: EntryType.fromStorage(row['type'] as String),
    amount: (row['amount'] as num).toDouble(),
    categoryId: row['category_id'] as String,
    accountId: row['account_id'] as String,
    toAccountId: row['to_account_id'] as String?,
    note: row['note'] as String? ?? '',
    occurredAt: DateTime.fromMillisecondsSinceEpoch(row['occurred_at'] as int),
  );

  static Map<String, Object?> _bookToRow(LedgerBook b, int index) =>
      <String, Object?>{
        'id': b.id,
        'name': b.name,
        'created_at': b.createdAt.millisecondsSinceEpoch,
        'is_default': b.isDefault ? 1 : 0,
        'sort_order': index,
      };

  static LedgerBook _bookFromRow(Map<String, Object?> row) => LedgerBook(
    id: row['id'] as String,
    name: row['name'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    isDefault: (row['is_default'] as int) != 0,
  );

  static Map<String, Object?> _accountToRow(Account a, int index) =>
      <String, Object?>{
        'id': a.id,
        'book_id': a.bookId,
        'name': a.name,
        'type': a.type.name,
        'group_id': a.groupId,
        'initial_balance': a.initialBalance,
        'icon_code': a.iconCode,
        'note': a.note,
        'include_in_assets': a.includeInAssets ? 1 : 0,
        'hidden': a.hidden ? 1 : 0,
        'card_last4': a.cardLast4,
        'sort_order': index,
      };

  static Account _accountFromRow(Map<String, Object?> row) => Account(
    id: row['id'] as String,
    bookId: row['book_id'] as String,
    name: row['name'] as String,
    type: AccountType.fromStorage(row['type'] as String?),
    groupId: row['group_id'] as String?,
    initialBalance: (row['initial_balance'] as num).toDouble(),
    iconCode: row['icon_code'] as String,
    note: row['note'] as String? ?? '',
    includeInAssets: (row['include_in_assets'] as int) != 0,
    hidden: (row['hidden'] as int) != 0,
    cardLast4: row['card_last4'] as String? ?? '',
  );

  static Map<String, Object?> _groupToRow(AccountGroup g) => <String, Object?>{
    'id': g.id,
    'book_id': g.bookId,
    'name': g.name,
    'icon_code': g.iconCode,
    'sort_order': g.sortOrder,
  };

  static AccountGroup _groupFromRow(Map<String, Object?> row) => AccountGroup(
    id: row['id'] as String,
    bookId: row['book_id'] as String,
    name: row['name'] as String,
    iconCode: row['icon_code'] as String,
    sortOrder: row['sort_order'] as int,
  );

  static Map<String, Object?> _categoryToRow(Category c, int index) =>
      <String, Object?>{
        'id': c.id,
        'label': c.label,
        'type': c.type.storageValue,
        'icon_code': c.iconCode,
        'sort_order': index,
      };

  static Category _categoryFromRow(Map<String, Object?> row) => Category(
    id: row['id'] as String,
    label: row['label'] as String,
    type: EntryType.fromStorage(row['type'] as String),
    iconCode: row['icon_code'] as String,
  );
}
