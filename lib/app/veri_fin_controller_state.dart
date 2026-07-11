part of 'veri_fin_controller.dart';

/// 控制器的「状态与持久化」层：集中所有内存字段、KV/SQLite 载入与落库、
/// 以及少量被载入流程调用的基础方法。领域操作在 [_ControllerOps]。
mixin _ControllerState on ChangeNotifier {
  // 依赖由具体类 VeriFinController 注入（构造参数）。
  LocalKeyValueStore get _store;
  LedgerRepository get _repository;
  AppLogger? get _logger;
  bool get _systemIsEnglish;

  /// SQLite 落库失败时回调（由 UI 层挂钩弹出「保存失败」提示）。
  void Function(Object error)? onPersistError;

  /// 应用锁开关变化时回调（由 main 挂钩，据此开关 Android FLAG_SECURE）。
  void Function(bool appLockEnabled)? onAppLockChanged;

  /// 播种/初始化默认数据时是否用英文（数据只在播种时定语言，之后随用户编辑）。
  bool get _seedEnglish {
    switch (_localePreference) {
      case LocalePreference.zh:
        return false;
      case LocalePreference.en:
        return true;
      case LocalePreference.system:
        return _systemIsEnglish;
    }
  }

  List<LedgerBook> get _seedLedgerBooks =>
      defaultLedgerBooksFor(english: _seedEnglish);
  List<Category> get _seedCategories =>
      defaultCategoriesFor(english: _seedEnglish);
  UserProfile get _seedProfile => defaultUserProfileFor(english: _seedEnglish);

  final List<LedgerEntry> _entries = <LedgerEntry>[];
  final List<LedgerBook> _ledgerBooks = <LedgerBook>[];
  final List<Account> _accounts = <Account>[];
  final List<AccountGroup> _accountGroups = <AccountGroup>[];
  final List<Category> _categories = <Category>[];
  final List<Tag> _tags = <Tag>[];
  final List<Attachment> _attachments = <Attachment>[];
  final List<RecurringRule> _recurringRules = <RecurringRule>[];
  final Map<String, double> _monthlyBudgets = <String, double>{};
  final Map<String, double> _categoryBudgets = <String, double>{};
  // 按日预算：每个账本一条「每日花销上限」，键为 bookId、值为金额（适用于每一天）。
  final Map<String, double> _dailyBudgets = <String, double>{};
  // 默认付款账户：每个账本各存一个账户 id（键为 bookId）。设备本地偏好。
  final Map<String, String> _defaultAccountIds = <String, String>{};
  final Set<String> _collapsedAssetSections = <String>{};
  final Map<String, List<String>> _assetAccountOrders =
      <String, List<String>>{};
  final Map<String, List<String>> _assetSectionOrders =
      <String, List<String>>{};
  final Map<PanelPageKind, List<PagePanelSetting>> _pagePanels =
      <PanelPageKind, List<PagePanelSetting>>{
        for (final page in PanelPageKind.values)
          page: _defaultPanelSettings(page.specs),
      };

  late final ValueNotifier<ThemePreference> themePreferenceListenable;

  /// 语言偏好通知器：驱动 `MaterialApp.locale` 即时切换。
  late final ValueNotifier<LocalePreference> localePreferenceListenable;

  ThemePreference _themePreference = ThemePreference.system;
  LocalePreference _localePreference = LocalePreference.system;
  UserProfile _profile = defaultUserProfile;
  String _activeBookId = defaultLedgerBookId;
  String _assetCoverUrl = '';
  bool _hapticsEnabled = true;
  bool _privacyConsentAccepted = false;
  bool _onboardingCompleted = false;
  AppLockConfig _appLockConfig = const AppLockConfig.none();
  AssetAccountViewMode _assetAccountViewMode = AssetAccountViewMode.type;
  BackupSettings _backupSettings = const BackupSettings();
  String _backupPassphrase = '';
  WebdavConfig _webdavConfig = const WebdavConfig();
  ReminderSettings _reminderSettings = ReminderSettings.disabled;
  FabActionMode _fabActionMode = FabActionMode.manual;
  HomeTrendConfig _homeTrendConfig = HomeTrendConfig.defaults;
  bool _amountForceTwoDecimals = false;
  AiSettings _aiSettings = const AiSettings();

  /// AI 对话查询的聊天记录：每条 `{role, content, displays?}`——助手消息可带序列化的
  /// 结果卡片（`displays` 为 [AiResultDisplay] 的 JSON），重开时连同图表一起还原。
  /// 设备本地偏好，不进 JSON 备份、初始化保留。
  List<Map<String, Object?>> _aiChatHistory = <Map<String, Object?>>[];

  void _loadDefaultAccounts() {
    final raw = _store.read(_defaultAccountKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<dynamic, dynamic>;
      _defaultAccountIds
        ..clear()
        ..addAll(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
    } catch (_) {
      _store.delete(_defaultAccountKey);
    }
  }

  void _persistDefaultAccounts() {
    _store.write(_defaultAccountKey, jsonEncode(_defaultAccountIds));
  }

  /// 删除账户时，清掉任何指向它的默认付款账户设置。

  void _loadPreferences() {
    _themePreference = ThemePreference.fromStorage(_store.read(_themeKey));
    _localePreference = LocalePreference.fromStorage(_store.read(_localeKey));
    _loadProfile();
    _activeBookId = _store.read(_activeBookKey) ?? defaultLedgerBookId;
    _assetCoverUrl = _store.read(_assetCoverKey) ?? '';
    _hapticsEnabled = _store.read(_hapticsKey) != 'false';
    _privacyConsentAccepted = _store.read(_privacyConsentKey) == 'true';
    _onboardingCompleted = _store.read(_onboardingKey) == 'true';
    _loadAppLock();
    _assetAccountViewMode = AssetAccountViewMode.fromStorage(
      _store.read(_assetViewModeKey),
    );
    _loadAssetSectionCollapsed();
    _loadAssetAccountOrders();
    _loadAssetSectionOrders();
    _loadPagePanels();
    _backupSettings = BackupSettings.decode(_store.read(_backupSettingsKey));
    _backupPassphrase = _store.read(_backupPassphraseKey) ?? '';
    _webdavConfig = WebdavConfig.decode(_store.read(_webdavKey));
    _reminderSettings = ReminderSettings.decode(_store.read(_reminderKey));
    _fabActionMode = FabActionMode.fromStorage(_store.read(_fabActionKey));
    _loadDefaultAccounts();
    _amountForceTwoDecimals = _store.read(_amountFormatKey) == 'true';
    amount_format.amountForceTwoDecimals = _amountForceTwoDecimals;
    _aiSettings = AiSettings.decode(_store.read(_aiSettingsKey));
    _aiChatHistory = _decodeChatHistory(_store.read(_aiChatHistoryKey));
    _homeTrendConfig = HomeTrendConfig.decode(_store.read(_homeTrendKey));
  }

  /// 从 SQLite 载入账目类数据；全新数据库首启动写入默认账本/账户/分组/分类。
  Future<void> _loadFromRepository() async {
    final books = await _repository.loadBooks();
    if (books.isEmpty) {
      _ledgerBooks
        ..clear()
        ..addAll(_seedLedgerBooks);
      _accounts
        ..clear()
        ..addAll(defaultAccounts);
      _accountGroups
        ..clear()
        ..addAll(defaultAccountGroups);
      _categories
        ..clear()
        ..addAll(_seedCategories);
      _normalizeGroupOrder();
      await _repository.saveBooks(_ledgerBooks);
      await _repository.saveAccounts(_accounts);
      await _repository.saveAccountGroups(_accountGroups);
      await _repository.saveCategories(_categories);
    } else {
      _ledgerBooks
        ..clear()
        ..addAll(books);
      if (!_ledgerBooks.any((book) => book.id == defaultLedgerBookId)) {
        _ledgerBooks.insert(0, _seedLedgerBooks.first);
      }
      _accounts
        ..clear()
        ..addAll(await _repository.loadAccounts());
      _accountGroups
        ..clear()
        ..addAll(await _repository.loadAccountGroups());
      _normalizeGroupOrder();
      final categories = await _repository.loadCategories();
      _categories
        ..clear()
        ..addAll(categories.isEmpty ? _seedCategories : categories);
    }
    if (!_ledgerBooks.any((book) => book.id == _activeBookId)) {
      _activeBookId = defaultLedgerBookId;
      _store.write(_activeBookKey, _activeBookId);
    }
    final entries = await _repository.loadEntries();
    entries.sort(_compareEntriesLatestFirst);
    _entries
      ..clear()
      ..addAll(entries);
    _tags
      ..clear()
      ..addAll(await _repository.loadTags());
    _attachments
      ..clear()
      ..addAll(await _repository.loadAttachments());
    _recurringRules
      ..clear()
      ..addAll(await _repository.loadRecurringRules());
    _monthlyBudgets
      ..clear()
      ..addAll(_bookScopedBudgets(await _repository.loadMonthlyBudgets()));
    _categoryBudgets
      ..clear()
      ..addAll(_bookScopedBudgets(await _repository.loadCategoryBudgets()));
    _dailyBudgets
      ..clear()
      ..addAll(await _repository.loadDailyBudgets());
    // 一次性分类参照完整性自愈：修复历史/异构备份带入的孤儿 parentId、悬空分类引用、
    // 重复同名分类（消除「幽灵同名分类」的数据根因）。改动了才落库。
    // 退款数据自愈：迁移旧标量退款为关联退款条目并重算净额缓存。
    final categoryHealed = _healCategoryData();
    final refundHealed = _syncRefundData();
    if (categoryHealed || refundHealed) {
      _persistAllLedgerData();
    }
    notifyListeners();
  }

  /// 分类参照完整性自愈：在内存列表（[_categories]/[_entries]/[_recurringRules]）上就地
  /// 修复脏分类数据，返回是否有改动（调用方据此决定落库）。**幂等**：数据已干净时零改动。
  ///
  /// 反复运行到不再变化（重挂孤儿会催生新的重复、合并重复会改变子分类归属，需收敛到稳定），
  /// 循环有上限兜底防止异常数据下的死循环。修复三类问题：
  /// 1) 孤儿 / 空串 parentId（指向不存在的父分类）→ 重挂为顶级（parentId=null）；
  /// 2) 重复分类（同 type+parentId+label 的多条）→ 保留一条（系统分类优先），其余的交易 /
  ///    周期规则 / 子分类 parentId 改指向保留者后删除；
  /// 3) 悬空交易 / 周期规则引用（categoryId 指向不存在的分类）→ 归入按类型惰性创建的
  ///    「未分类」分类（固定 id，保证幂等、重跑复用同一条）。
  bool _healCategoryData() {
    var everChanged = false;
    // 8 次足以让「重挂→合并→再合并」收敛；纯防御上限，正常一两轮即稳定。
    for (var round = 0; round < 8; round++) {
      if (!_healCategoryDataOnce()) {
        break;
      }
      everChanged = true;
    }
    return everChanged;
  }

  bool _healCategoryDataOnce() {
    var changed = false;
    final ids = <String>{for (final c in _categories) c.id};

    // ---- 1) 孤儿 / 空串 parentId → 顶级 ----
    for (var i = 0; i < _categories.length; i++) {
      final parentId = _categories[i].parentId;
      if (parentId != null && (parentId.isEmpty || !ids.contains(parentId))) {
        _categories[i] = _categories[i].copyWith(parentId: null);
        changed = true;
      }
    }

    // ---- 2) 合并重复分类（同 type + parentId + label）----
    String dedupeKey(Category c) =>
        '${c.type.storageValue} ${c.parentId ?? ''} ${c.label}';
    final canonical = <String, String>{}; // key -> 保留的 id
    final remap = <String, String>{}; // 被并入的 id -> 保留的 id
    for (final c in _categories) {
      final key = dedupeKey(c);
      final keep = canonical[key];
      if (keep == null) {
        canonical[key] = c.id;
      } else if (_isProtectedCategory(c.id) && !_isProtectedCategory(keep)) {
        // 当前是系统分类而已选保留者不是：改用系统分类为保留者，旧的并入。
        canonical[key] = c.id;
        remap[keep] = c.id;
      } else {
        remap[c.id] = keep;
      }
    }
    if (remap.isNotEmpty) {
      String resolve(String id) {
        var cur = id;
        final seen = <String>{};
        while (remap.containsKey(cur) && seen.add(cur)) {
          cur = remap[cur]!;
        }
        return cur;
      }

      final dupIds = remap.keys.toSet();
      for (var i = 0; i < _entries.length; i++) {
        if (dupIds.contains(_entries[i].categoryId)) {
          _entries[i] = _entries[i].copyWith(
            categoryId: resolve(_entries[i].categoryId),
          );
        }
      }
      for (var i = 0; i < _recurringRules.length; i++) {
        if (dupIds.contains(_recurringRules[i].categoryId)) {
          _recurringRules[i] = _recurringRules[i].copyWith(
            categoryId: resolve(_recurringRules[i].categoryId),
          );
        }
      }
      for (var i = 0; i < _categories.length; i++) {
        final parentId = _categories[i].parentId;
        if (parentId != null && dupIds.contains(parentId)) {
          _categories[i] = _categories[i].copyWith(parentId: resolve(parentId));
        }
      }
      _categories.removeWhere((c) => dupIds.contains(c.id));
      for (final dup in dupIds) {
        _categoryBudgets.removeWhere((key, _) => key.endsWith(':$dup'));
      }
      changed = true;
    }

    // ---- 3) 悬空交易 / 周期规则引用 → 「未分类」（按类型惰性创建，固定 id 幂等）----
    final liveIds = <String>{for (final c in _categories) c.id};
    String uncategorizedIdFor(EntryType type) {
      final id = 'uncategorized_${type.storageValue}';
      if (!liveIds.contains(id)) {
        _categories.add(
          Category(
            id: id,
            label: _seedEnglish ? 'Uncategorized' : '未分类',
            type: type,
            iconCode: 'category',
          ),
        );
        liveIds.add(id);
        changed = true;
      }
      return id;
    }

    bool isDangling(String categoryId) =>
        categoryId.isNotEmpty &&
        !_isProtectedCategory(categoryId) &&
        !liveIds.contains(categoryId);

    for (var i = 0; i < _entries.length; i++) {
      final categoryId = _entries[i].categoryId;
      if (isDangling(categoryId)) {
        _entries[i] = _entries[i].copyWith(
          categoryId: uncategorizedIdFor(_entries[i].type),
        );
        changed = true;
      }
    }
    for (var i = 0; i < _recurringRules.length; i++) {
      final categoryId = _recurringRules[i].categoryId;
      if (isDangling(categoryId)) {
        _recurringRules[i] = _recurringRules[i].copyWith(
          categoryId: uncategorizedIdFor(_recurringRules[i].type),
        );
        changed = true;
      }
    }

    return changed;
  }

  /// 历史迁移：把旧版单标量退款（支出 `refundedAmount > 0` 却没有任何关联退款条目）
  /// 合成为一条「已到账」退款条目（金额=标量、日期/账户取原支出、备注空），让旧数据
  /// 平滑升级到新模型并使历史退款可见。迁移后余额与净额恒等不变（支出改扣全额、退款
  /// 条目补回同额），只是把「一个数」变成「一条可见事件」。返回是否合成了条目。
  ///
  /// **只在载入/导入时调用一次**——绝不在退款增删改后调用：删掉最后一笔退款时缓存尚未
  /// 清零，若在此判「有标量却无条目」会把退款又合成回来（曾导致删退款后余额不减）。
  bool _migrateLegacyRefunds() {
    final expensesWithRefundEntry = <String>{
      for (final e in _entries)
        if (e.type == EntryType.refund && e.refundOf != null) e.refundOf!,
    };
    final synthesized = <LedgerEntry>[];
    for (final e in _entries) {
      if (e.type == EntryType.expense &&
          e.refundedAmount > 0 &&
          !expensesWithRefundEntry.contains(e.id)) {
        final amount = e.refundedAmount.clamp(0.0, e.amount).toDouble();
        if (amount <= 0) continue;
        synthesized.add(
          LedgerEntry(
            id: _generateId('entry'),
            bookId: e.bookId,
            type: EntryType.refund,
            amount: amount,
            categoryId: e.categoryId,
            accountId: e.accountId,
            note: '',
            occurredAt: e.occurredAt, // 发起日期沿用原支出日
            refundOf: e.id,
            settledAt: e.occurredAt, // 历史退款视为已到账
          ),
        );
      }
    }
    if (synthesized.isEmpty) return false;
    _entries.addAll(synthesized);
    return true;
  }

  /// 重算每笔支出的净额缓存 [LedgerEntry.refundedAmount] = 「挂它的·已到账·退款金额之和」
  /// （钳到 `[0, amount]`）；无到账退款则归零。该缓存只驱动统计净额（[LedgerEntry.netAmount]），
  /// 账户余额不读它。**待到账**退款（`settledAt == null`）不计入（cash basis）。
  /// 每次退款增删改后调用；返回是否有改动。
  bool _syncRefundCache() {
    final settledByExpense = <String, double>{};
    for (final e in _entries) {
      if (e.type == EntryType.refund &&
          e.settledAt != null &&
          e.refundOf != null) {
        settledByExpense[e.refundOf!] =
            (settledByExpense[e.refundOf!] ?? 0) + e.amount;
      }
    }
    var changed = false;
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (e.type != EntryType.expense) continue;
      final target = (settledByExpense[e.id] ?? 0)
          .clamp(0.0, e.amount)
          .toDouble();
      if ((e.refundedAmount - target).abs() > 0.0001) {
        _entries[i] = e.copyWith(refundedAmount: target);
        changed = true;
      }
    }
    return changed;
  }

  /// 载入/导入时的退款自愈（幂等）：先迁移旧标量为退款条目，再重算净额缓存并排序。
  /// 返回是否有改动（调用方据此决定落库）。
  bool _syncRefundData() {
    final migrated = _migrateLegacyRefunds();
    final cached = _syncRefundCache();
    final changed = migrated || cached;
    if (changed) {
      _entries.sort(_compareEntriesLatestFirst);
    }
    return changed;
  }

  void _removeAccountFromOrders(String accountId) {
    for (final order in _assetAccountOrders.values) {
      order.remove(accountId);
    }
  }

  void _loadProfile() {
    final rawProfile = _store.read(_profileKey);
    if (rawProfile == null || rawProfile.isEmpty) {
      _profile = _seedProfile;
      return;
    }

    try {
      _profile = UserProfile.fromJson(
        Map<String, Object?>.from(
          jsonDecode(rawProfile) as Map<dynamic, dynamic>,
        ),
      );
    } catch (_) {
      _store.delete(_profileKey);
      _profile = _seedProfile;
    }
  }

  void _loadAppLock() {
    final raw = _store.read(_appLockKey);
    if (raw == null || raw.isEmpty) {
      _appLockConfig = const AppLockConfig.none();
      return;
    }
    try {
      _appLockConfig = AppLockConfig.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
      );
    } catch (_) {
      _store.delete(_appLockKey);
      _appLockConfig = const AppLockConfig.none();
    }
  }

  /// 读取 KV 中的 JSON 并应用；空则跳过，解码失败则删掉坏值。用于「读→try decode→
  /// catch 则 delete」这一重复骨架。
  void _loadJson(String key, void Function(Object decoded) apply) {
    final raw = _store.read(key);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      apply(jsonDecode(raw) as Object);
    } catch (_) {
      _store.delete(key);
    }
  }

  void _loadAssetSectionCollapsed() {
    _loadJson(_assetSectionCollapsedKey, (decoded) {
      _collapsedAssetSections
        ..clear()
        ..addAll(_decodeStringSet(decoded));
    });
  }

  void _loadAssetAccountOrders() {
    _loadJson(_assetAccountOrderKey, (decoded) {
      _assetAccountOrders
        ..clear()
        ..addAll(_decodeStringListMap(decoded));
    });
  }

  void _loadAssetSectionOrders() {
    _loadJson(_assetSectionOrderKey, (decoded) {
      _assetSectionOrders
        ..clear()
        ..addAll(_decodeStringListMap(decoded));
    });
  }

  /// 进程内单调自增序号，配合微秒时间戳生成不会碰撞的 id：连续两次生成可能落在
  /// 同一微秒，单靠 microsecondsSinceEpoch 会得到相同 id（删一个会连带删同 id 的）。
  int _idSeq = 0;

  /// 生成唯一 id：`前缀_微秒时间戳_单调序号`。即便同一微秒批量生成也各不相同。
  /// 放在状态层，供 [_syncRefundData] 等载入期基础流程与 [_ControllerOps] 共用。
  String _generateId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}';

  void _persistEntries() {
    _trackWrite(_repository.saveEntries(List<LedgerEntry>.of(_entries)));
  }

  // 记录最近一次 SQLite 写入，供测试等待其落库。写入按连接串行，等待最新即可。
  Future<void> _pendingWrite = Future<void>.value();

  void _trackWrite(Future<void> write) {
    // 挂 catchError：落库失败时记录日志并回调 UI 提示，避免「内存已改但库未写」
    // 的静默不一致——用户以为已保存、重启后却丢失。
    final tracked = write.catchError(_handlePersistError);
    _pendingWrite = tracked;
    unawaited(tracked);
  }

  void _handlePersistError(Object error, StackTrace stackTrace) {
    _logger?.error('数据保存失败', source: 'persist', error: error);
    onPersistError?.call(error);
  }

  /// 等待挂起的 SQLite 写入落库。
  Future<void> waitForPendingWrites() => _pendingWrite;

  /// 刷盘所有挂起写入：偏好类 KV **与** 账目类 SQLite。应用切到后台时调用，
  /// 确保应用锁 / 隐私同意等关键偏好，以及用户刚记下的交易，在进程可能被系统
  /// 回收前落盘（此前只刷 KV，SQLite 写入是 fire-and-forget，极端情况下会丢账）。
  Future<void> flushPendingWrites() {
    return Future.wait(<Future<void>>[_store.flush(), _pendingWrite]);
  }

  void _persistLedgerBooks() {
    _trackWrite(_repository.saveBooks(List<LedgerBook>.of(_ledgerBooks)));
  }

  void _persistAccounts() {
    _trackWrite(_repository.saveAccounts(List<Account>.of(_accounts)));
  }

  void _persistAccountGroups() {
    _trackWrite(
      _repository.saveAccountGroups(List<AccountGroup>.of(_accountGroups)),
    );
  }

  void _persistCategories() {
    _trackWrite(_repository.saveCategories(List<Category>.of(_categories)));
  }

  void _persistTags() {
    _trackWrite(_repository.saveTags(List<Tag>.of(_tags)));
  }

  void _persistAttachments() {
    _trackWrite(_repository.saveAttachments(List<Attachment>.of(_attachments)));
  }

  void _persistRecurringRules() {
    _trackWrite(
      _repository.saveRecurringRules(List<RecurringRule>.of(_recurringRules)),
    );
  }

  void _persistBudgets() {
    _trackWrite(
      _repository.saveMonthlyBudgets(Map<String, double>.of(_monthlyBudgets)),
    );
  }

  void _persistCategoryBudgets() {
    _trackWrite(
      _repository.saveCategoryBudgets(Map<String, double>.of(_categoryBudgets)),
    );
  }

  void _persistDailyBudgets() {
    _trackWrite(
      _repository.saveDailyBudgets(Map<String, double>.of(_dailyBudgets)),
    );
  }

  /// 一次性原子替换全部账目类表（导入/恢复/重置/删账本用）。相比逐表 `_persistX`，
  /// 这些跨多表的整体操作若中途失败会整体回滚，不留孤儿引用（如 entries 已换但
  /// accounts 还是旧的）。KV 偏好类写入不在事务内，另行处理。
  void _persistAllLedgerData() {
    _trackWrite(
      _repository.replaceAllLedgerData(
        LedgerDataSnapshot(
          books: List<LedgerBook>.of(_ledgerBooks),
          accounts: List<Account>.of(_accounts),
          accountGroups: List<AccountGroup>.of(_accountGroups),
          categories: List<Category>.of(_categories),
          tags: List<Tag>.of(_tags),
          attachments: List<Attachment>.of(_attachments),
          entries: List<LedgerEntry>.of(_entries),
          recurringRules: List<RecurringRule>.of(_recurringRules),
          monthlyBudgets: Map<String, double>.of(_monthlyBudgets),
          categoryBudgets: Map<String, double>.of(_categoryBudgets),
          dailyBudgets: Map<String, double>.of(_dailyBudgets),
        ),
      ),
    );
  }

  void _persistAssetSectionCollapsed() {
    _store.write(
      _assetSectionCollapsedKey,
      jsonEncode(_collapsedAssetSections.toList()),
    );
  }

  void _persistAssetAccountOrders() {
    _store.write(_assetAccountOrderKey, jsonEncode(_assetAccountOrders));
  }

  void _persistAssetSectionOrders() {
    _store.write(_assetSectionOrderKey, jsonEncode(_assetSectionOrders));
  }

  void _loadPagePanels() {
    for (final page in PanelPageKind.values) {
      final key = _panelsKeyFor(page);
      final raw = _store.read(key);
      if (raw == null || raw.isEmpty) {
        _pagePanels[page] = _defaultPanelSettings(page.specs);
        continue;
      }
      try {
        _pagePanels[page] = _normalizePanelSettings(
          _decodeModelList<PagePanelSetting>(
            jsonDecode(raw),
            PagePanelSetting.fromJson,
          ),
          page.specs,
        );
      } catch (_) {
        _store.delete(key);
        _pagePanels[page] = _defaultPanelSettings(page.specs);
      }
    }
  }

  void _persistPagePanels(PanelPageKind page) {
    _store.write(
      _panelsKeyFor(page),
      jsonEncode(_pagePanels[page]!.map((item) => item.toJson()).toList()),
    );
  }

  void _normalizeGroupOrder() {
    final grouped = <String, List<AccountGroup>>{};
    for (final group in _accountGroups) {
      grouped.putIfAbsent(group.bookId, () => <AccountGroup>[]).add(group);
    }
    _accountGroups.clear();
    for (final groups in grouped.values) {
      groups.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _accountGroups.addAll(
        groups.indexed.map((item) => item.$2.copyWith(sortOrder: item.$1)),
      );
    }
  }
}
