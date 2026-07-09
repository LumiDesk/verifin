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
    notifyListeners();
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
