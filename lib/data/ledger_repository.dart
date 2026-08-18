import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../app/models.dart';
import 'app_database.dart';

/// 账目类全量数据快照。用于「导入/恢复/重置/删账本」这类需要一次性原子替换
/// 多张表的场景——见 [LedgerRepository.replaceAllLedgerData]。
class LedgerDataSnapshot {
  const LedgerDataSnapshot({
    required this.books,
    required this.accounts,
    required this.accountGroups,
    required this.categories,
    required this.tags,
    required this.attachments,
    required this.entries,
    required this.recurringRules,
    required this.monthlyBudgets,
    required this.categoryBudgets,
    required this.dailyBudgets,
    this.exchangeRates = const <ExchangeRate>[],
  });

  final List<LedgerBook> books;
  final List<Account> accounts;
  final List<AccountGroup> accountGroups;
  final List<Category> categories;
  final List<Tag> tags;
  final List<Attachment> attachments;
  final List<LedgerEntry> entries;
  final List<RecurringRule> recurringRules;
  final Map<String, double> monthlyBudgets;
  final Map<String, double> categoryBudgets;
  final Map<String, double> dailyBudgets;
  final List<ExchangeRate> exchangeRates;
}

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

  Future<List<Tag>> loadTags();
  Future<void> saveTags(List<Tag> tags);

  Future<List<Attachment>> loadAttachments();
  Future<void> saveAttachments(List<Attachment> attachments);

  /// Replaces entries, attachments and optional exchange rates in one transaction.
  Future<void> saveEntryAggregate({
    required List<LedgerEntry> entries,
    required List<Attachment> attachments,
    List<ExchangeRate>? exchangeRates,
  });

  Future<List<RecurringRule>> loadRecurringRules();
  Future<void> saveRecurringRules(List<RecurringRule> rules);

  /// Persists generated recurring entries and advanced rules atomically.
  Future<void> saveRecurringGeneration({
    required List<LedgerEntry> entries,
    required List<RecurringRule> recurringRules,
  });

  Future<List<ExchangeRate>> loadExchangeRates();
  Future<void> saveExchangeRates(List<ExchangeRate> rates);

  Future<Map<String, double>> loadMonthlyBudgets();
  Future<void> saveMonthlyBudgets(Map<String, double> budgets);

  Future<Map<String, double>> loadCategoryBudgets();
  Future<void> saveCategoryBudgets(Map<String, double> budgets);

  Future<Map<String, double>> loadDailyBudgets();
  Future<void> saveDailyBudgets(Map<String, double> budgets);

  /// 在单个事务中保存三张预算表，供预算设置页一次性提交草稿。
  Future<void> saveBudgetSettings({
    required Map<String, double> monthlyBudgets,
    required Map<String, double> categoryBudgets,
    required Map<String, double> dailyBudgets,
  });

  /// 在单个数据库事务中整体替换全部账目类表。用于导入/恢复/重置/删账本：
  /// 保证跨表一致——中途失败会整体回滚，不会留下「entries 已换、accounts 还是旧的」
  /// 这类孤儿引用状态。
  Future<void> replaceAllLedgerData(LedgerDataSnapshot snapshot);

  Future<bool> hasAnyData();
}

/// 基于 SQLite 的仓储实现。列表顺序通过 sort_order 列保留（entries 除外，其顺序
/// 由 occurred_at 决定）。
///
/// 写入策略：交易/账本/账户/分组/分类/标签/周期规则/汇率走**行级差分**（[_incrementalReplace]）
/// ——只写与内存基线快照不同的行，避免单条改动就重写整表（entries 随交易量无限增长，
/// 是写放大主因）。附件（含大 blob）与预算（极小）仍整表覆盖。saveX 的对外语义不变：
/// 落库后该表内容 == 传入列表。导入/恢复/重置走 [replaceAllLedgerData] 多表原子整替。
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
    final entries = rows.map(_entryFromRow).toList();
    _seedSnapshot('entries', entries.map(_entryToRow));
    return entries;
  }

  @override
  Future<void> saveEntries(List<LedgerEntry> entries) async {
    await _incrementalReplace('entries', entries.map(_entryToRow));
  }

  // ---- 账本 ----

  @override
  Future<List<LedgerBook>> loadBooks() async {
    final rows = await _db.query('ledger_books', orderBy: 'sort_order ASC');
    final books = rows.map(_bookFromRow).toList();
    _seedSnapshot('ledger_books', _indexed(books, _bookToRow));
    return books;
  }

  @override
  Future<void> saveBooks(List<LedgerBook> books) async {
    await _incrementalReplace('ledger_books', _indexed(books, _bookToRow));
  }

  // ---- 账户 ----

  @override
  Future<List<Account>> loadAccounts() async {
    final rows = await _db.query('accounts', orderBy: 'sort_order ASC');
    final accounts = rows.map(_accountFromRow).toList();
    _seedSnapshot('accounts', _indexed(accounts, _accountToRow));
    return accounts;
  }

  @override
  Future<void> saveAccounts(List<Account> accounts) async {
    await _incrementalReplace('accounts', _indexed(accounts, _accountToRow));
  }

  // ---- 账户分组 ----

  @override
  Future<List<AccountGroup>> loadAccountGroups() async {
    final rows = await _db.query('account_groups', orderBy: 'sort_order ASC');
    final groups = rows.map(_groupFromRow).toList();
    _seedSnapshot('account_groups', groups.map(_groupToRow));
    return groups;
  }

  @override
  Future<void> saveAccountGroups(List<AccountGroup> groups) async {
    await _incrementalReplace('account_groups', groups.map(_groupToRow));
  }

  // ---- 分类 ----

  @override
  Future<List<Category>> loadCategories() async {
    final rows = await _db.query('categories', orderBy: 'sort_order ASC');
    final categories = rows.map(_categoryFromRow).toList();
    _seedSnapshot('categories', _indexed(categories, _categoryToRow));
    return categories;
  }

  @override
  Future<void> saveCategories(List<Category> categories) async {
    await _incrementalReplace(
      'categories',
      _indexed(categories, _categoryToRow),
    );
  }

  // ---- 标签 ----

  @override
  Future<List<Tag>> loadTags() async {
    final rows = await _db.query('tags', orderBy: 'sort_order ASC');
    final tags = rows.map(_tagFromRow).toList();
    _seedSnapshot('tags', _indexed(tags, _tagToRow));
    return tags;
  }

  @override
  Future<void> saveTags(List<Tag> tags) async {
    await _incrementalReplace('tags', _indexed(tags, _tagToRow));
  }

  // ---- 图片附件 ----

  @override
  Future<List<Attachment>> loadAttachments() async {
    final rows = await _db.query('attachments', orderBy: 'sort_order ASC');
    return rows.map(_attachmentFromRow).toList();
  }

  @override
  Future<void> saveAttachments(List<Attachment> attachments) async {
    await _replaceAll('attachments', _indexed(attachments, _attachmentToRow));
  }

  @override
  Future<void> saveEntryAggregate({
    required List<LedgerEntry> entries,
    required List<Attachment> attachments,
    List<ExchangeRate>? exchangeRates,
  }) async {
    await _db.transaction((txn) async {
      await _replaceInTxn(txn, 'entries', entries.map(_entryToRow));
      await _replaceInTxn(
        txn,
        'attachments',
        _indexed(attachments, _attachmentToRow),
      );
      if (exchangeRates != null) {
        await _replaceInTxn(
          txn,
          'exchange_rates',
          exchangeRates.map(_exchangeRateToRow),
        );
      }
    });
    _seedSnapshot('entries', entries.map(_entryToRow));
    if (exchangeRates != null) {
      _seedSnapshot('exchange_rates', exchangeRates.map(_exchangeRateToRow));
    }
  }

  // ---- 周期记账规则 ----

  @override
  Future<List<RecurringRule>> loadRecurringRules() async {
    final rows = await _db.query('recurring_rules', orderBy: 'sort_order ASC');
    final rules = rows.map(_recurringFromRow).toList();
    _seedSnapshot('recurring_rules', _indexed(rules, _recurringToRow));
    return rules;
  }

  @override
  Future<void> saveRecurringRules(List<RecurringRule> rules) async {
    await _incrementalReplace(
      'recurring_rules',
      _indexed(rules, _recurringToRow),
    );
  }

  @override
  Future<void> saveRecurringGeneration({
    required List<LedgerEntry> entries,
    required List<RecurringRule> recurringRules,
  }) async {
    await _db.transaction((txn) async {
      await _replaceInTxn(txn, 'entries', entries.map(_entryToRow));
      await _replaceInTxn(
        txn,
        'recurring_rules',
        _indexed(recurringRules, _recurringToRow),
      );
    });
    _seedSnapshot('entries', entries.map(_entryToRow));
    _seedSnapshot('recurring_rules', _indexed(recurringRules, _recurringToRow));
  }

  // ---- 本地汇率 ----

  @override
  Future<List<ExchangeRate>> loadExchangeRates() async {
    final rows = await _db.query(
      'exchange_rates',
      orderBy: 'currency_code ASC, effective_date DESC, id DESC',
    );
    final rates = rows.map(_exchangeRateFromRow).toList();
    _seedSnapshot('exchange_rates', rates.map(_exchangeRateToRow));
    return rates;
  }

  @override
  Future<void> saveExchangeRates(List<ExchangeRate> rates) async {
    await _incrementalReplace('exchange_rates', rates.map(_exchangeRateToRow));
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

  @override
  Future<Map<String, double>> loadDailyBudgets() =>
      _loadBudgetMap('daily_budgets');

  @override
  Future<void> saveDailyBudgets(Map<String, double> budgets) =>
      _saveBudgetMap('daily_budgets', budgets);

  @override
  Future<void> saveBudgetSettings({
    required Map<String, double> monthlyBudgets,
    required Map<String, double> categoryBudgets,
    required Map<String, double> dailyBudgets,
  }) async {
    await _db.transaction((txn) async {
      await _replaceInTxn(txn, 'monthly_budgets', _budgetRows(monthlyBudgets));
      await _replaceInTxn(
        txn,
        'category_budgets',
        _budgetRows(categoryBudgets),
      );
      await _replaceInTxn(txn, 'daily_budgets', _budgetRows(dailyBudgets));
    });
  }

  @override
  Future<void> replaceAllLedgerData(LedgerDataSnapshot snapshot) async {
    // 全部表在同一事务内清空重建：任一步失败即整体回滚，绝不留半新半旧状态。
    await _db.transaction((txn) async {
      await _replaceInTxn(
        txn,
        'ledger_books',
        _indexed(snapshot.books, _bookToRow),
      );
      await _replaceInTxn(
        txn,
        'accounts',
        _indexed(snapshot.accounts, _accountToRow),
      );
      await _replaceInTxn(
        txn,
        'account_groups',
        snapshot.accountGroups.map(_groupToRow),
      );
      await _replaceInTxn(
        txn,
        'categories',
        _indexed(snapshot.categories, _categoryToRow),
      );
      await _replaceInTxn(txn, 'tags', _indexed(snapshot.tags, _tagToRow));
      await _replaceInTxn(
        txn,
        'attachments',
        _indexed(snapshot.attachments, _attachmentToRow),
      );
      await _replaceInTxn(txn, 'entries', snapshot.entries.map(_entryToRow));
      await _replaceInTxn(
        txn,
        'recurring_rules',
        _indexed(snapshot.recurringRules, _recurringToRow),
      );
      await _replaceInTxn(
        txn,
        'monthly_budgets',
        _budgetRows(snapshot.monthlyBudgets),
      );
      await _replaceInTxn(
        txn,
        'category_budgets',
        _budgetRows(snapshot.categoryBudgets),
      );
      await _replaceInTxn(
        txn,
        'daily_budgets',
        _budgetRows(snapshot.dailyBudgets),
      );
      await _replaceInTxn(
        txn,
        'exchange_rates',
        snapshot.exchangeRates.map(_exchangeRateToRow),
      );
    });
    // 整替后重建各增量表基线，使后续单条 saveX 的差分有正确起点（否则会拿导入前
    // 的旧快照去 diff、误删或漏写）。附件/预算不走增量、无需重置。
    _seedSnapshot('ledger_books', _indexed(snapshot.books, _bookToRow));
    _seedSnapshot('accounts', _indexed(snapshot.accounts, _accountToRow));
    _seedSnapshot('account_groups', snapshot.accountGroups.map(_groupToRow));
    _seedSnapshot('categories', _indexed(snapshot.categories, _categoryToRow));
    _seedSnapshot('tags', _indexed(snapshot.tags, _tagToRow));
    _seedSnapshot('entries', snapshot.entries.map(_entryToRow));
    _seedSnapshot(
      'recurring_rules',
      _indexed(snapshot.recurringRules, _recurringToRow),
    );
    _seedSnapshot(
      'exchange_rates',
      snapshot.exchangeRates.map(_exchangeRateToRow),
    );
  }

  /// 是否已存在任何账目数据（用于判断迁移是否有内容写入）。
  @override
  Future<bool> hasAnyData() async {
    for (final table in const <String>[
      'entries',
      'ledger_books',
      'accounts',
      'account_groups',
      'categories',
      'exchange_rates',
    ]) {
      final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      final count = (rows.first['c'] as int?) ?? 0;
      if (count > 0) {
        return true;
      }
    }
    return false;
  }

  // ---- 增量写：按主键 id 的行级差分 ----

  /// 每张「增量表」在内存里保留上次落库的行快照（id → 规范化行）。saveX 时据此
  /// 算出真正变化的行（新增/改动/删除），只写这些行，避免每次单条改动就 DELETE
  /// 整表再全量 INSERT（entries 表随交易量无限增长，是写放大的主因）。
  ///
  /// 语义与整表覆盖完全一致——落库后 DB 内容 == 传入列表；只是实现为「差分应用」。
  /// 附件表（含大 JPEG blob，缓存整行会成倍占内存）与预算表（极小、少写）不走此路，
  /// 仍用整表覆盖。导入/恢复/重置走 [replaceAllLedgerData]（多表原子整替）。
  final Map<String, Map<Object, Map<String, Object?>>> _rowSnapshots =
      <String, Map<Object, Map<String, Object?>>>{};

  /// 记录某表当前 DB 内容为基线快照（键为行的 id 列）。loadX 载入后、
  /// replaceAllLedgerData 整替后调用，使后续差分有正确基线。
  void _seedSnapshot(String table, Iterable<Map<String, Object?>> rows) {
    _rowSnapshots[table] = <Object, Map<String, Object?>>{
      for (final row in rows) row['id'] as Object: row,
    };
  }

  /// 以 [rows] 差分更新 [table]：只写与基线快照不同的行。无基线（未 load 过）时
  /// 退化为一次整表覆盖并建立基线；无任何变化则不发生写入。
  Future<void> _incrementalReplace(
    String table,
    Iterable<Map<String, Object?>> rows,
  ) async {
    final next = <Object, Map<String, Object?>>{
      for (final row in rows) row['id'] as Object: row,
    };
    final prev = _rowSnapshots[table];
    if (prev == null) {
      await _replaceAll(table, next.values);
      _rowSnapshots[table] = next;
      return;
    }
    final toUpsert = <Map<String, Object?>>[];
    next.forEach((id, row) {
      final old = prev[id];
      if (old == null || !_sameRow(old, row)) {
        toUpsert.add(row);
      }
    });
    final toDelete = <Object>[
      for (final id in prev.keys)
        if (!next.containsKey(id)) id,
    ];
    if (toUpsert.isEmpty && toDelete.isEmpty) {
      return;
    }
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in toUpsert) {
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final id in toDelete) {
        batch.delete(table, where: 'id = ?', whereArgs: <Object>[id]);
      }
      await batch.commit(noResult: true);
    });
    _rowSnapshots[table] = next;
  }

  /// 行相等：列数与每列值都相等（列值均为 String/int/double/null，`!=` 即可）。
  static bool _sameRow(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  // ---- 内部工具 ----

  Future<void> _replaceAll(
    String table,
    Iterable<Map<String, Object?>> rows,
  ) async {
    await _db.transaction((txn) async {
      await _replaceInTxn(txn, table, rows);
    });
  }

  /// 在给定事务执行器内清空并重建单表。供 [_replaceAll]（单表）与
  /// [replaceAllLedgerData]（多表共享一个事务）复用。
  Future<void> _replaceInTxn(
    Transaction txn,
    String table,
    Iterable<Map<String, Object?>> rows,
  ) async {
    final rowList = rows.toList();
    await txn.delete(table);
    final batch = txn.batch();
    for (final row in rowList) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Iterable<Map<String, Object?>> _budgetRows(
    Map<String, double> budgets,
  ) => budgets.entries.map(
    (entry) => <String, Object?>{'scope_key': entry.key, 'amount': entry.value},
  );

  Future<Map<String, double>> _loadBudgetMap(String table) async {
    final rows = await _db.query(table);
    return <String, double>{
      for (final row in rows)
        row['scope_key'] as String: (row['amount'] as num).toDouble(),
    };
  }

  Future<void> _saveBudgetMap(String table, Map<String, double> budgets) async {
    await _replaceAll(table, _budgetRows(budgets));
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
    'currency_code': e.currencyCode,
    'account_amount': e.accountAmount,
    'to_account_amount': e.toAccountAmount,
    'base_amount': e.baseAmount,
    'conversion_source': e.conversionSource.name,
    'category_id': e.categoryId,
    'account_id': e.accountId,
    'to_account_id': e.toAccountId,
    'note': e.note,
    'occurred_at': e.occurredAt.millisecondsSinceEpoch,
    // 标签 id 列表以 JSON 数组存单列（整表覆盖式读写，无需关联表）。
    'tag_ids': e.tagIds.isEmpty ? null : jsonEncode(e.tagIds),
    'fee': e.fee,
    'reimbursable': e.reimbursable ? 1 : 0,
    'refunded_amount': e.refundedBaseAmount,
    'refund_of': e.refundOf,
    'settled_at': e.settledAt?.millisecondsSinceEpoch,
  };

  static LedgerEntry _entryFromRow(Map<String, Object?> row) => LedgerEntry(
    id: row['id'] as String,
    bookId: row['book_id'] as String,
    type: EntryType.fromStorage(row['type'] as String),
    amount: (row['amount'] as num).toDouble(),
    currencyCode: row['currency_code'] as String? ?? defaultCurrencyCode,
    accountAmount: (row['account_amount'] as num?)?.toDouble(),
    toAccountAmount: (row['to_account_amount'] as num?)?.toDouble(),
    baseAmount: (row['base_amount'] as num?)?.toDouble() ?? 0,
    conversionSource: ConversionSource.fromStorage(
      row['conversion_source'] as String?,
    ),
    categoryId: row['category_id'] as String,
    accountId: row['account_id'] as String,
    toAccountId: row['to_account_id'] as String?,
    note: row['note'] as String? ?? '',
    occurredAt: DateTime.fromMillisecondsSinceEpoch(row['occurred_at'] as int),
    tagIds: _decodeTagIds(row['tag_ids']),
    fee: (row['fee'] as num?)?.toDouble() ?? 0,
    reimbursable: ((row['reimbursable'] as int?) ?? 0) != 0,
    refundedBaseAmount: (row['refunded_amount'] as num?)?.toDouble() ?? 0,
    refundOf: row['refund_of'] as String?,
    settledAt: row['settled_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['settled_at'] as int),
  );

  static List<String> _decodeTagIds(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
    }
    return const <String>[];
  }

  static Map<String, Object?> _tagToRow(Tag t, int index) => <String, Object?>{
    'id': t.id,
    'label': t.label,
    'sort_order': index,
  };

  static Tag _tagFromRow(Map<String, Object?> row) =>
      Tag(id: row['id'] as String, label: row['label'] as String);

  static Map<String, Object?> _attachmentToRow(Attachment a, int index) =>
      <String, Object?>{
        'id': a.id,
        'entry_id': a.entryId,
        'data_url': a.dataUrl,
        'sort_order': index,
      };

  static Attachment _attachmentFromRow(Map<String, Object?> row) => Attachment(
    id: row['id'] as String,
    entryId: row['entry_id'] as String,
    dataUrl: row['data_url'] as String,
  );

  static Map<String, Object?> _recurringToRow(RecurringRule r, int index) =>
      <String, Object?>{
        'id': r.id,
        'book_id': r.bookId,
        'type': r.type.storageValue,
        'amount': r.amount,
        'currency_code': r.currencyCode,
        'account_amount': r.accountAmount,
        'to_account_amount': r.toAccountAmount,
        'base_amount': r.baseAmount,
        'rate_policy': r.ratePolicy.name,
        'category_id': r.categoryId,
        'account_id': r.accountId,
        'to_account_id': r.toAccountId,
        'note': r.note,
        'frequency': r.frequency.storageValue,
        'start_date': r.startDate.millisecondsSinceEpoch,
        'next_run_date': r.nextRunDate.millisecondsSinceEpoch,
        'active': r.active ? 1 : 0,
        'sort_order': index,
      };

  static RecurringRule _recurringFromRow(
    Map<String, Object?> row,
  ) => RecurringRule(
    id: row['id'] as String,
    bookId: row['book_id'] as String,
    type: EntryType.fromStorage(row['type'] as String),
    amount: (row['amount'] as num).toDouble(),
    currencyCode: row['currency_code'] as String? ?? defaultCurrencyCode,
    accountAmount: (row['account_amount'] as num?)?.toDouble(),
    toAccountAmount: (row['to_account_amount'] as num?)?.toDouble(),
    baseAmount: (row['base_amount'] as num?)?.toDouble() ?? 0,
    ratePolicy: RecurringRatePolicy.fromStorage(row['rate_policy'] as String?),
    categoryId: row['category_id'] as String,
    accountId: row['account_id'] as String,
    toAccountId: row['to_account_id'] as String?,
    note: row['note'] as String? ?? '',
    frequency: RecurringFrequency.fromStorage(row['frequency'] as String?),
    startDate: DateTime.fromMillisecondsSinceEpoch(row['start_date'] as int),
    nextRunDate: DateTime.fromMillisecondsSinceEpoch(
      row['next_run_date'] as int,
    ),
    active: ((row['active'] as int?) ?? 1) != 0,
  );

  static Map<String, Object?> _exchangeRateToRow(ExchangeRate rate) =>
      <String, Object?>{
        'id': rate.id,
        'book_id': rate.bookId,
        'base_currency_code': rate.baseCurrencyCode,
        'currency_code': rate.currencyCode,
        'effective_date': currencyDateKey(rate.effectiveDate),
        'rate_to_base': rate.rateToBase,
        'source': rate.source.name,
        'created_at': rate.createdAt.millisecondsSinceEpoch,
        'updated_at': rate.updatedAt.millisecondsSinceEpoch,
      };

  static ExchangeRate _exchangeRateFromRow(Map<String, Object?> row) {
    final effectiveDate = parseCurrencyDateKey(row['effective_date']);
    if (effectiveDate == null) {
      throw FormatException(
        'Invalid exchange rate effective_date: ${row['effective_date']}',
      );
    }
    return ExchangeRate(
      id: row['id'] as String,
      bookId: row['book_id'] as String,
      baseCurrencyCode: row['base_currency_code'] as String,
      currencyCode: row['currency_code'] as String,
      effectiveDate: effectiveDate,
      rateToBase: (row['rate_to_base'] as num).toDouble(),
      source: ExchangeRateSource.fromStorage(row['source'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  static Map<String, Object?> _bookToRow(LedgerBook b, int index) =>
      <String, Object?>{
        'id': b.id,
        'name': b.name,
        'created_at': b.createdAt.millisecondsSinceEpoch,
        'is_default': b.isDefault ? 1 : 0,
        'base_currency_code': b.baseCurrencyCode,
        'currency_setup_status': b.currencySetupStatus.name,
        'sort_order': index,
      };

  static LedgerBook _bookFromRow(Map<String, Object?> row) => LedgerBook(
    id: row['id'] as String,
    name: row['name'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    isDefault: (row['is_default'] as int) != 0,
    baseCurrencyCode:
        row['base_currency_code'] as String? ?? defaultCurrencyCode,
    currencySetupStatus: CurrencySetupStatus.fromStorage(
      row['currency_setup_status'] as String?,
    ),
  );

  static Map<String, Object?> _accountToRow(Account a, int index) =>
      <String, Object?>{
        'id': a.id,
        'book_id': a.bookId,
        'name': a.name,
        'type': a.type.name,
        'group_id': a.groupId,
        'initial_balance': a.initialBalance,
        'currency_code': a.currencyCode,
        'icon_code': a.iconCode,
        'note': a.note,
        'include_in_assets': a.includeInAssets ? 1 : 0,
        'hidden': a.hidden ? 1 : 0,
        'card_last4': a.cardLast4,
        'card_number': a.cardNumber,
        'card_last4_follows': a.cardLast4Follows ? 1 : 0,
        'credit_limit': a.creditLimit,
        'sort_order': index,
        'statement_day': a.statementDay,
        'due_day': a.dueDay,
      };

  static Account _accountFromRow(Map<String, Object?> row) => Account(
    id: row['id'] as String,
    bookId: row['book_id'] as String,
    name: row['name'] as String,
    type: AccountType.fromStorage(row['type'] as String?),
    groupId: row['group_id'] as String?,
    initialBalance: (row['initial_balance'] as num).toDouble(),
    currencyCode: row['currency_code'] as String? ?? defaultCurrencyCode,
    iconCode: row['icon_code'] as String,
    note: row['note'] as String? ?? '',
    includeInAssets: (row['include_in_assets'] as int) != 0,
    hidden: (row['hidden'] as int) != 0,
    cardLast4: row['card_last4'] as String? ?? '',
    cardNumber: row['card_number'] as String? ?? '',
    cardLast4Follows: (row['card_last4_follows'] as int? ?? 0) != 0,
    creditLimit: (row['credit_limit'] as num?)?.toDouble(),
    statementDay: (row['statement_day'] as num?)?.toInt(),
    dueDay: (row['due_day'] as num?)?.toInt(),
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
        'parent_id': c.parentId,
      };

  static Category _categoryFromRow(Map<String, Object?> row) {
    return Category(
      id: row['id'] as String,
      label: row['label'] as String,
      type: EntryType.fromStorage(row['type'] as String),
      iconCode: row['icon_code'] as String,
      parentId: Category.normalizeParentId(row['parent_id'] as String?),
    );
  }
}
