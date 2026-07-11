import 'package:sqflite_common/sqlite_api.dart';

import 'database_factory.dart';

/// Veri Fin 本地 SQLite 数据库。负责建表、版本迁移与连接持有。
///
/// 具体的按类型读写在 [LedgerRepository]。数据库只承载「账目」类核心数据；
/// 偏好类小数据（主题、触感、面板配置、资产排序等）仍保留在 KV。
class AppDatabase {
  AppDatabase._(this.db);

  /// 底层 sqflite 连接，供仓储层执行 SQL。
  final Database db;

  static const String defaultDatabaseName = 'verifin.db';
  static const int schemaVersion = 11;

  /// 打开（或创建）数据库。测试通过 [factory]/[path] 注入 ffi 与内存路径；
  /// 真实平台留空则由 [resolveDatabaseFactory]/[resolveDatabasePath] 决定。
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final resolvedFactory = factory ?? await resolveDatabaseFactory();
    final resolvedPath = path ?? await resolveDatabasePath(defaultDatabaseName);
    final database = await resolvedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(database);
  }

  Future<void> close() => db.close();

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final statement in _schemaCurrent) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 → v2：分类支持多级树形结构，新增可空的 parent_id 列（顶级为 NULL）。
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE categories ADD COLUMN parent_id TEXT');
    }
    // v2 → v3：标签系统。新增 tags 表；交易新增可空 tag_ids 列（JSON 数组）。
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE entries ADD COLUMN tag_ids TEXT');
      await db.execute('''
        CREATE TABLE tags (
          id TEXT PRIMARY KEY,
          label TEXT NOT NULL,
          sort_order INTEGER NOT NULL
        )
      ''');
    }
    // v3 → v4：图片附件。独立表，按 entry_id 关联，data_url 存压缩 JPEG。
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE attachments (
          id TEXT PRIMARY KEY,
          entry_id TEXT NOT NULL,
          data_url TEXT NOT NULL,
          sort_order INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_attachments_entry ON attachments (entry_id)',
      );
    }
    // v4 → v5：转账手续费。交易新增 fee 列，默认 0。
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE entries ADD COLUMN fee REAL NOT NULL DEFAULT 0',
      );
    }
    // v5 → v6：报销/退款。交易新增待报销标记与已冲抵金额。
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE entries ADD COLUMN reimbursable INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE entries ADD COLUMN refunded_amount REAL NOT NULL DEFAULT 0',
      );
    }
    // v6 → v7：周期记账规则表。
    if (oldVersion < 7) {
      await db.execute(_recurringRulesTable);
    }
    // v7 → v8：信用卡账单日/还款日（可选）。
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE accounts ADD COLUMN statement_day INTEGER');
      await db.execute('ALTER TABLE accounts ADD COLUMN due_day INTEGER');
    }
    // v8 → v9：按日预算维度。键为 `bookId:yyyy-MM-dd`。
    if (oldVersion < 9) {
      await db.execute(_dailyBudgetsTable);
    }
    // v9 → v10：分类唯一性约束。历史/异构备份可能带入重复同名分类（「幽灵分类」根因），
    // 先按 (label,type,IFNULL(parent_id,'')) 去重（交易/周期规则/子分类引用改指向保留者、
    // 删掉重复），再建唯一索引。**必须先去重再建索引**，否则 CREATE UNIQUE INDEX 会因已有
    // 重复行失败。悬空引用/孤儿 parentId 不违反唯一性、由 controller 载入时的 _healCategoryData
    // 处理，此处只管重复行。
    if (oldVersion < 10) {
      // 真实库自 v1 起必有 categories/entries；recurring_rules 由上面 v7 块保证在前。
      // 判存在只为兼容迁移测试的最小桩库，并顺带抵御异常损坏的安装。
      if (await _tableExists(db, 'categories')) {
        await _dedupeCategories(db);
        await db.execute(_categoriesUniqueIndex);
      }
    }
    // v10 → v11：完整卡号（信用卡/储蓄卡）与信用额度（信用卡/信用账户，可空）。
    // 判 accounts 存在只为兼容迁移测试的最小桩库（真实库自 v1 起必有 accounts）。
    if (oldVersion < 11 && await _tableExists(db, 'accounts')) {
      await db.execute(
        "ALTER TABLE accounts ADD COLUMN card_number TEXT NOT NULL DEFAULT ''",
      );
      await db.execute('ALTER TABLE accounts ADD COLUMN credit_limit REAL');
    }
  }

  static Future<bool> _tableExists(Database db, String name) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      <Object?>[name],
    );
    return rows.isNotEmpty;
  }

  /// 合并重复分类：保留每个 (label,type,IFNULL(parent_id,'')) 组内 rowid 最小的一条，
  /// 其余的交易/周期规则/子分类 parent_id 引用改指向保留者后删除。仅在对应表存在时改写引用
  /// （真实库都在，判存在是为兼容最小桩库）。
  static Future<void> _dedupeCategories(Database db) async {
    await db.execute('''
      CREATE TEMP TABLE _cat_keep AS
        SELECT id AS keep_id, label, type, IFNULL(parent_id, '') AS pkey
        FROM categories
        WHERE rowid IN (
          SELECT MIN(rowid) FROM categories
          GROUP BY label, type, IFNULL(parent_id, '')
        )
    ''');
    await db.execute('''
      CREATE TEMP TABLE _cat_map AS
        SELECT c.id AS old_id, k.keep_id AS keep_id
        FROM categories c
        JOIN _cat_keep k
          ON c.label = k.label AND c.type = k.type
          AND IFNULL(c.parent_id, '') = k.pkey
    ''');
    if (await _tableExists(db, 'entries')) {
      await db.execute('''
        UPDATE entries
          SET category_id =
            (SELECT keep_id FROM _cat_map WHERE old_id = entries.category_id)
          WHERE category_id IN
            (SELECT old_id FROM _cat_map WHERE old_id <> keep_id)
      ''');
    }
    if (await _tableExists(db, 'recurring_rules')) {
      await db.execute('''
        UPDATE recurring_rules
          SET category_id =
            (SELECT keep_id FROM _cat_map WHERE old_id = recurring_rules.category_id)
          WHERE category_id IN
            (SELECT old_id FROM _cat_map WHERE old_id <> keep_id)
      ''');
    }
    await db.execute('''
      UPDATE categories
        SET parent_id =
          (SELECT keep_id FROM _cat_map WHERE old_id = categories.parent_id)
        WHERE parent_id IN (SELECT old_id FROM _cat_map WHERE old_id <> keep_id)
    ''');
    await db.execute('''
      DELETE FROM categories
        WHERE id IN (SELECT old_id FROM _cat_map WHERE old_id <> keep_id)
    ''');
    await db.execute('DROP TABLE _cat_map');
    await db.execute('DROP TABLE _cat_keep');
  }

  /// 分类唯一约束：同一父级（顶级按空串归一）下不允许同 label+type 的重复分类。
  static const String _categoriesUniqueIndex =
      "CREATE UNIQUE INDEX idx_categories_unique "
      "ON categories (label, type, IFNULL(parent_id, ''))";

  static const String _dailyBudgetsTable = '''
    CREATE TABLE daily_budgets (
      scope_key TEXT PRIMARY KEY,
      amount REAL NOT NULL
    )
  ''';

  static const String _recurringRulesTable = '''
    CREATE TABLE recurring_rules (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      category_id TEXT NOT NULL,
      account_id TEXT NOT NULL,
      to_account_id TEXT,
      note TEXT NOT NULL,
      frequency TEXT NOT NULL,
      start_date INTEGER NOT NULL,
      next_run_date INTEGER NOT NULL,
      active INTEGER NOT NULL,
      sort_order INTEGER NOT NULL
    )
  ''';

  /// 当前完整建表语句（供全新数据库 onCreate 用）。字段命名用 snake_case；
  /// 布尔存 0/1；时间存毫秒时间戳。已含历次迁移引入的列/表（parent_id、tags 等）。
  static const List<String> _schemaCurrent = <String>[
    '''
    CREATE TABLE ledger_books (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      is_default INTEGER NOT NULL,
      sort_order INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE entries (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      category_id TEXT NOT NULL,
      account_id TEXT NOT NULL,
      to_account_id TEXT,
      note TEXT NOT NULL,
      occurred_at INTEGER NOT NULL,
      tag_ids TEXT,
      fee REAL NOT NULL DEFAULT 0,
      reimbursable INTEGER NOT NULL DEFAULT 0,
      refunded_amount REAL NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX idx_entries_book ON entries (book_id)',
    'CREATE INDEX idx_entries_occurred ON entries (occurred_at)',
    '''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      group_id TEXT,
      initial_balance REAL NOT NULL,
      icon_code TEXT NOT NULL,
      note TEXT NOT NULL,
      include_in_assets INTEGER NOT NULL,
      hidden INTEGER NOT NULL,
      card_last4 TEXT NOT NULL,
      card_number TEXT NOT NULL DEFAULT '',
      credit_limit REAL,
      sort_order INTEGER NOT NULL,
      statement_day INTEGER,
      due_day INTEGER
    )
    ''',
    'CREATE INDEX idx_accounts_book ON accounts (book_id)',
    '''
    CREATE TABLE account_groups (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      name TEXT NOT NULL,
      icon_code TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_account_groups_book ON account_groups (book_id)',
    '''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      type TEXT NOT NULL,
      icon_code TEXT NOT NULL,
      sort_order INTEGER NOT NULL,
      parent_id TEXT
    )
    ''',
    _categoriesUniqueIndex,
    '''
    CREATE TABLE monthly_budgets (
      scope_key TEXT PRIMARY KEY,
      amount REAL NOT NULL
    )
    ''',
    '''
    CREATE TABLE category_budgets (
      scope_key TEXT PRIMARY KEY,
      amount REAL NOT NULL
    )
    ''',
    _dailyBudgetsTable,
    '''
    CREATE TABLE tags (
      id TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE attachments (
      id TEXT PRIMARY KEY,
      entry_id TEXT NOT NULL,
      data_url TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_attachments_entry ON attachments (entry_id)',
    _recurringRulesTable,
  ];
}
