part of 'veri_fin_controller.dart';

/// 控制器的「领域操作」层：交易/账户/分组/账本/分类/标签/预算/偏好/备份/
/// 导入导出等所有对外方法。字段与持久化在 [_ControllerState]。
mixin _ControllerOps on ChangeNotifier, _ControllerState {
  List<LedgerEntry> get entries =>
      _entriesView ??= List<LedgerEntry>.unmodifiable(
        _entries.where((entry) => entry.bookId == _activeBookId),
      );

  List<LedgerBook> get ledgerBooks => List<LedgerBook>.unmodifiable(
    _ledgerBooks.isEmpty ? _seedLedgerBooks : _ledgerBooks,
  );

  LedgerBook get activeBook => ledgerBooks.firstWhere(
    (book) => book.id == _activeBookId,
    orElse: () => ledgerBooks.first,
  );

  List<Account> get accounts => _accountsView ??= List<Account>.unmodifiable(
    _accounts.where((account) => account.bookId == _activeBookId),
  );

  List<AccountGroup> get accountGroups {
    return _accountGroupsView ??= List<AccountGroup>.unmodifiable(
      _accountGroups.where((group) => group.bookId == _activeBookId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  List<Category> get categories =>
      _categoriesView ??= List<Category>.unmodifiable(
        _categories.isEmpty ? _seedCategories : _categories,
      );

  /// 全部标签（按创建/排序顺序）。标签与账本无关，全局共享。
  List<Tag> get tags => List<Tag>.unmodifiable(_tags);

  Tag? tagById(String id) => _tags.where((tag) => tag.id == id).firstOrNull;

  /// 某标签被多少笔交易使用（当前账本无关，统计全部交易）。
  int tagUsageCount(String tagId) {
    return _entries.where((entry) => entry.tagIds.contains(tagId)).length;
  }

  /// 某交易的图片附件（按加入顺序）。
  List<Attachment> attachmentsForEntry(String entryId) {
    return List<Attachment>.unmodifiable(
      _attachments.where((a) => a.entryId == entryId),
    );
  }

  int attachmentCountForEntry(String entryId) {
    return _attachments.where((a) => a.entryId == entryId).length;
  }

  // id 生成（_generateId / _idSeq）已下沉到 _ControllerState，便于载入期的
  // _syncRefundData() 等基础流程合成条目时复用。

  /// 为交易新增一张图片附件（[dataUrl] 为压缩后的 JPEG data URL）。
  void addAttachment(String entryId, String dataUrl) {
    if (dataUrl.isEmpty) {
      return;
    }
    _attachments.add(
      Attachment(id: _generateId('att'), entryId: entryId, dataUrl: dataUrl),
    );
    _persistAttachments();
    notifyListeners();
  }

  void removeAttachment(String attachmentId) {
    final before = _attachments.length;
    _attachments.removeWhere((a) => a.id == attachmentId);
    if (_attachments.length == before) {
      return;
    }
    _persistAttachments();
    notifyListeners();
  }

  /// 删除若干交易时一并清理它们的附件。返回是否有附件被移除。
  bool _removeAttachmentsForEntries(Set<String> entryIds) {
    if (entryIds.isEmpty) {
      return false;
    }
    final before = _attachments.length;
    _attachments.removeWhere((a) => entryIds.contains(a.entryId));
    return _attachments.length != before;
  }

  // ---- 周期记账 ----

  /// 当前账本下的周期记账规则（按加入顺序）。
  List<RecurringRule> get recurringRules => List<RecurringRule>.unmodifiable(
    _recurringRules.where((rule) => rule.bookId == _activeBookId),
  );

  void addRecurringRule(RecurringRule rule) {
    _recurringRules.add(rule);
    _persistRecurringRules();
    notifyListeners();
  }

  void updateRecurringRule(RecurringRule rule) {
    final index = _recurringRules.indexWhere((item) => item.id == rule.id);
    if (index == -1) {
      return;
    }
    _recurringRules[index] = rule;
    _persistRecurringRules();
    notifyListeners();
  }

  void setRecurringRuleActive(String ruleId, bool active) {
    final index = _recurringRules.indexWhere((item) => item.id == ruleId);
    if (index == -1) {
      return;
    }
    _recurringRules[index] = _recurringRules[index].copyWith(active: active);
    _persistRecurringRules();
    notifyListeners();
  }

  void deleteRecurringRule(String ruleId) {
    final before = _recurringRules.length;
    _recurringRules.removeWhere((item) => item.id == ruleId);
    if (_recurringRules.length == before) {
      return;
    }
    _persistRecurringRules();
    notifyListeners();
  }

  /// 补记所有到期的周期交易（打开应用 / 回前台时调用）。为每条到期规则按其
  /// 频率补齐从 `nextRunDate` 到 [now] 的交易，并推进规则的 `nextRunDate`。
  /// 返回新补记的交易数量。处理所有账本的规则（不限当前账本）。
  int applyDueRecurring(DateTime now) {
    var generated = 0;
    var rulesChanged = false;
    final existingIds = _entries.map((e) => e.id).toSet();
    for (var i = 0; i < _recurringRules.length; i++) {
      final rule = _recurringRules[i];
      final dueDates = dueDatesFor(rule, now);
      if (dueDates.isEmpty) {
        continue;
      }
      for (final due in dueDates) {
        // 补记 id 由 rule.id + 到期日毫秒确定。若用户把规则日期回拨重新触发补记，
        // 同一到期日会生成同 id 条目，跳过以免覆盖用户可能手改过的那条。
        final id = 'entry_recur_${rule.id}_${due.millisecondsSinceEpoch}';
        if (!existingIds.add(id)) {
          continue;
        }
        _entries.add(
          LedgerEntry(
            id: id,
            bookId: rule.bookId,
            type: rule.type,
            amount: rule.amount,
            categoryId: rule.categoryId,
            accountId: rule.accountId,
            toAccountId: rule.type == EntryType.transfer
                ? rule.toAccountId
                : null,
            note: rule.note,
            occurredAt: due,
          ),
        );
        generated += 1;
      }
      _recurringRules[i] = rule.copyWith(
        nextRunDate: advanceRecurring(
          dueDates.last,
          rule.frequency,
          anchorDay: rule.startDate.day,
        ),
      );
      rulesChanged = true;
    }
    if (generated > 0) {
      _entries.sort(_compareEntriesLatestFirst);
      _persistEntries();
    }
    if (rulesChanged) {
      _persistRecurringRules();
    }
    if (generated > 0 || rulesChanged) {
      notifyListeners();
    }
    // 注意：不在此触发 onEntryAdded。applyDueRecurring 只在 main 的开屏/回前台流程中
    // 调用，紧随其后已有 maybeBackupOnOpen + pushWidgetData，再触发会重复备份
    // （加密备份还会重复跑 PBKDF2）。
    return generated;
  }

  ThemePreference get themePreference => _themePreference;

  UserProfile get profile => _profile;

  String get assetCoverUrl => _assetCoverUrl;

  bool get hapticsEnabled => _hapticsEnabled;

  AssetAccountViewMode get assetAccountViewMode => _assetAccountViewMode;

  BackupSettings get backupSettings => _backupSettings;

  void _persistBackupSettings() {
    _store.write(_backupSettingsKey, _backupSettings.encode());
  }

  /// 保存用户选择的备份目录（Android SAF 树 URI 或桌面路径）。
  void setBackupDirectory(String uri, String label) {
    _backupSettings = _backupSettings.copyWith(
      directoryUri: uri,
      directoryLabel: label,
    );
    _persistBackupSettings();
    notifyListeners();
  }

  /// 清除备份目录，同时关闭自动备份。
  void clearBackupDirectory() {
    _backupSettings = _backupSettings.copyWith(
      clearDirectory: true,
      frequency: BackupFrequency.manual,
    );
    _persistBackupSettings();
    notifyListeners();
  }

  void setBackupFrequency(BackupFrequency frequency) {
    _backupSettings = _backupSettings.copyWith(frequency: frequency);
    _persistBackupSettings();
    notifyListeners();
  }

  void setBackupIntervalHours(int hours) {
    _backupSettings = _backupSettings.copyWith(
      intervalHours: hours < 1 ? 1 : hours,
    );
    _persistBackupSettings();
    notifyListeners();
  }

  void setBackupRetention(int retention) {
    _backupSettings = _backupSettings.copyWith(
      retention: retention < 1 ? 1 : retention,
    );
    _persistBackupSettings();
    notifyListeners();
  }

  /// 备份成功后记录时间，供自动备份频率判断与「上次备份时间」展示。
  void recordBackupTime(DateTime time) {
    _backupSettings = _backupSettings.copyWith(lastBackupAt: time);
    _persistBackupSettings();
    notifyListeners();
  }

  /// 备份加密口令（明文存本机 KV，供自动备份无人值守加密；空表示不加密）。
  /// 保护的是离开设备的备份文件，本机数据本身已在应用私有存储内。
  String get backupPassphrase => _backupPassphrase;

  bool get backupEncryptionEnabled => _backupPassphrase.isNotEmpty;

  void setBackupPassphrase(String passphrase) {
    _backupPassphrase = passphrase;
    if (passphrase.isEmpty) {
      _store.delete(_backupPassphraseKey);
    } else {
      _store.write(_backupPassphraseKey, passphrase);
    }
    notifyListeners();
  }

  /// 清除加密口令：后续备份不再加密（已加密的旧文件仍需原口令导入）。
  void clearBackupPassphrase() => setBackupPassphrase('');

  /// WebDAV 备份配置（地址/账号/密码/是否自动上传）；密码明文存本机 KV。
  WebdavConfig get webdavConfig => _webdavConfig;

  void setWebdavConfig(WebdavConfig config) {
    _webdavConfig = config;
    if (config.isConfigured) {
      _store.write(_webdavKey, config.encode());
    } else {
      _store.delete(_webdavKey);
    }
    notifyListeners();
  }

  void setWebdavAutoUpload(bool enabled) {
    setWebdavConfig(_webdavConfig.copyWith(autoUpload: enabled));
  }

  void clearWebdavConfig() {
    _webdavConfig = const WebdavConfig();
    _store.delete(_webdavKey);
    notifyListeners();
  }

  List<Category> categoriesForType(EntryType type) {
    return categoriesFor(type, categories);
  }

  Category categoryById(String id) {
    return categoryByIdFrom(categories, id);
  }

  /// 指定类型的顶级分类（多级分类树的根）。
  List<Category> rootCategoriesForType(EntryType type) {
    return rootCategories(categories, type);
  }

  /// 某分类的直接子分类。
  List<Category> childCategories(String parentId) {
    return childrenOf(categories, parentId);
  }

  /// 某分类的完整路径标签，如「餐饮 / 咖啡」。
  String categoryPathLabel(String id) {
    return pathLabel(categories, id);
  }

  /// 前序展开某类型的整棵分类树（携带层级深度），供缩进列表渲染。
  List<CategoryNode> categoryTreeForType(EntryType type) {
    return flattenTree(categories, type);
  }

  double monthlyBudget(DateTime month) {
    return _monthlyBudgets['$_activeBookId:${_monthKey(month)}'] ?? 800;
  }

  void setMonthlyBudget(DateTime month, double amount) {
    _monthlyBudgets['$_activeBookId:${_monthKey(month)}'] = amount <= 0
        ? 0
        : amount;
    _persistBudgets();
    notifyListeners();
  }

  double categoryBudget(DateTime month, String categoryId) {
    return _categoryBudgets[_categoryBudgetKey(
          _activeBookId,
          month,
          categoryId,
        )] ??
        0;
  }

  void setCategoryBudget(DateTime month, String categoryId, double amount) {
    final key = _categoryBudgetKey(_activeBookId, month, categoryId);
    if (amount <= 0) {
      _categoryBudgets.remove(key);
    } else {
      _categoryBudgets[key] = amount;
    }
    _persistCategoryBudgets();
    notifyListeners();
  }

  /// 当前账本的每日花销上限（0 表示未设置）。
  double dailyBudget() {
    return _dailyBudgets[_activeBookId] ?? 0;
  }

  void setDailyBudget(double amount) {
    if (amount <= 0) {
      _dailyBudgets.remove(_activeBookId);
    } else {
      _dailyBudgets[_activeBookId] = amount;
    }
    _persistDailyBudgets();
    notifyListeners();
  }

  void setThemePreference(ThemePreference preference) {
    if (_themePreference == preference) {
      return;
    }
    _themePreference = preference;
    themePreferenceListenable.value = preference;
    _store.write(_themeKey, preference.name);
    notifyListeners();
  }

  LocalePreference get localePreference => _localePreference;

  /// 语言是设备本地偏好：不进 JSON 备份，初始化数据时保留。
  void setLocalePreference(LocalePreference preference) {
    if (_localePreference == preference) {
      return;
    }
    _localePreference = preference;
    localePreferenceListenable.value = preference;
    _store.write(_localeKey, preference.name);
    notifyListeners();
  }

  ReminderSettings get reminderSettings => _reminderSettings;

  /// 记账提醒配置变化时的回调（由 `main.dart` 注入，用于重排本地通知）。
  ValueChanged<ReminderSettings>? onReminderChanged;

  void setReminderSettings(ReminderSettings settings) {
    if (_reminderSettings == settings) {
      return;
    }
    _reminderSettings = settings;
    _store.write(_reminderKey, settings.encode());
    notifyListeners();
    onReminderChanged?.call(settings);
  }

  void setHapticsEnabled(bool enabled) {
    if (_hapticsEnabled == enabled) {
      return;
    }
    _hapticsEnabled = enabled;
    _store.write(_hapticsKey, enabled.toString());
    notifyListeners();
  }

  /// 首页 FAB（记一笔）的行为：手动记账（默认）或 AI 对话记账。设备本地偏好，
  /// 不进 JSON 备份、初始化保留。
  FabActionMode get fabActionMode => _fabActionMode;

  void setFabActionMode(FabActionMode mode) {
    _fabActionMode = mode;
    _store.write(_fabActionKey, mode.name);
    notifyListeners();
  }

  /// 首页走势卡片的自定义配置（各槽展示的指标、曲线序列、标题）。设备本地显示偏好，
  /// 不进 JSON 备份、初始化时保留。
  HomeTrendConfig get homeTrendConfig => _homeTrendConfig;

  void setHomeTrendConfig(HomeTrendConfig config) {
    _homeTrendConfig = config;
    _store.write(_homeTrendKey, config.encode());
    notifyListeners();
  }

  void resetHomeTrendConfig() {
    _homeTrendConfig = HomeTrendConfig.defaults;
    _store.delete(_homeTrendKey);
    notifyListeners();
  }

  /// 当前账本的默认付款账户 id；未设置、或该账户已删除/隐藏时返回 null。设备本地
  /// 偏好，不进 JSON 备份、初始化时随账户一起清空。记账（手动/AI 未识别账户时）
  /// 用它作默认账户。
  String? get defaultAccountId {
    final id = _defaultAccountIds[_activeBookId];
    if (id == null || id.isEmpty) {
      return null;
    }
    final valid = _accounts.any(
      (account) =>
          account.id == id &&
          account.bookId == _activeBookId &&
          !account.hidden,
    );
    return valid ? id : null;
  }

  void setDefaultAccountId(String? accountId) {
    if (accountId == null || accountId.isEmpty) {
      _defaultAccountIds.remove(_activeBookId);
    } else {
      _defaultAccountIds[_activeBookId] = accountId;
    }
    _persistDefaultAccounts();
    notifyListeners();
  }

  void _clearDefaultAccountRef(String accountId) {
    final before = _defaultAccountIds.length;
    _defaultAccountIds.removeWhere((_, id) => id == accountId);
    if (_defaultAccountIds.length != before) {
      _persistDefaultAccounts();
    }
  }

  /// 是否强制所有金额展示两位小数（`12` → `12.00`）。设备本地偏好，不进 JSON 备份、
  /// 初始化保留。经顶层量 [amountForceTwoDecimals] 让无 context 的金额格式化纯函数
  /// （小组件、通知、`series_math` 等）同步生效。
  bool get amountForceTwoDecimals => _amountForceTwoDecimals;

  void setAmountForceTwoDecimals(bool value) {
    _amountForceTwoDecimals = value;
    amount_format.amountForceTwoDecimals = value;
    _store.write(_amountFormatKey, value.toString());
    notifyListeners();
  }

  /// AI 对话记账的连接配置（请求地址/API Key/模型）。设备本地偏好，不进 JSON
  /// 备份、初始化保留（API Key 明文存本机）。
  AiSettings get aiSettings => _aiSettings;

  void setAiSettings(AiSettings settings) {
    if (_aiSettings == settings) {
      return;
    }
    _aiSettings = settings;
    if (settings.isConfigured ||
        settings.baseUrl.isNotEmpty ||
        settings.apiKey.isNotEmpty ||
        settings.model.isNotEmpty) {
      _store.write(_aiSettingsKey, settings.encode());
    } else {
      _store.delete(_aiSettingsKey);
    }
    notifyListeners();
  }

  /// AI 对话查询的聊天记录（每条 `{role, content, displays?}`，助手消息可带序列化的
  /// 结果卡片）。设备本地、不进 JSON 备份、初始化保留。
  List<Map<String, Object?>> get aiChatHistory =>
      List<Map<String, Object?>>.unmodifiable(_aiChatHistory);

  /// 覆盖保存聊天记录。不 notifyListeners——历史无响应式依赖，只由聊天页读写，
  /// 避免每条消息触发全应用重建。
  void setAiChatHistory(List<Map<String, Object?>> history) {
    _aiChatHistory = List<Map<String, Object?>>.from(history);
    if (_aiChatHistory.isEmpty) {
      _store.delete(_aiChatHistoryKey);
    } else {
      _store.write(_aiChatHistoryKey, jsonEncode(_aiChatHistory));
    }
  }

  /// 清空聊天记录。
  void clearAiChatHistory() => setAiChatHistory(<Map<String, Object?>>[]);

  /// 用户是否已同意隐私政策与用户协议（首启动前为 false）。
  bool get onboardingCompleted => _onboardingCompleted;

  /// 标记新用户引导已完成（只走一次，初始化数据不清除）。
  void completeOnboarding() {
    if (_onboardingCompleted) {
      return;
    }
    _onboardingCompleted = true;
    _store.write(_onboardingKey, 'true');
    notifyListeners();
  }

  bool get privacyConsentAccepted => _privacyConsentAccepted;

  /// 记录用户已同意隐私政策与用户协议。一经同意即持久化，重启后不再询问。
  void acceptPrivacyConsent() {
    if (_privacyConsentAccepted) {
      return;
    }
    _privacyConsentAccepted = true;
    _store.write(_privacyConsentKey, 'true');
    notifyListeners();
  }

  /// 当前应用锁配置（含锁类型、加盐哈希、生物识别开关）。
  AppLockConfig get appLockConfig => _appLockConfig;

  /// 是否已启用应用锁（PIN 或图案）。
  bool get appLockEnabled => _appLockConfig.enabled;

  /// 当前锁类型。
  AppLockKind get appLockKind => _appLockConfig.kind;

  /// 是否开启了生物识别快捷解锁（仅在已启用应用锁时有意义）。
  bool get biometricUnlockEnabled =>
      _appLockConfig.enabled && _appLockConfig.biometricEnabled;

  /// 设置或修改应用锁密钥（PIN 数字串或图案点序列）。生成新盐并落库，不存明文。
  void setAppLock({required AppLockKind kind, required String secret}) {
    assert(kind != AppLockKind.none, 'setAppLock 不能用于关闭应用锁');
    _appLockConfig = AppLockConfig.fromSecret(
      kind: kind,
      secret: secret,
      biometricEnabled: _appLockConfig.biometricEnabled,
    );
    _persistAppLock();
    notifyListeners();
    onAppLockChanged?.call(_appLockConfig.enabled);
  }

  /// 校验输入的密钥是否匹配当前应用锁。
  bool verifyAppLock(String input) => _appLockConfig.verify(input);

  /// 关闭应用锁（同时关闭生物识别）。
  void disableAppLock() {
    if (!_appLockConfig.enabled) {
      return;
    }
    _appLockConfig = const AppLockConfig.none();
    _persistAppLock();
    notifyListeners();
    onAppLockChanged?.call(false);
  }

  /// 开关生物识别快捷解锁。仅在已启用应用锁时生效。
  void setBiometricUnlockEnabled(bool enabled) {
    if (!_appLockConfig.enabled || _appLockConfig.biometricEnabled == enabled) {
      return;
    }
    _appLockConfig = _appLockConfig.copyWith(biometricEnabled: enabled);
    _persistAppLock();
    notifyListeners();
  }

  void _persistAppLock() {
    if (_appLockConfig.enabled) {
      _store.write(_appLockKey, jsonEncode(_appLockConfig.toJson()));
    } else {
      _store.delete(_appLockKey);
    }
  }

  void toggleAssetAccountViewMode() {
    _assetAccountViewMode = _assetAccountViewMode == AssetAccountViewMode.group
        ? AssetAccountViewMode.type
        : AssetAccountViewMode.group;
    _store.write(_assetViewModeKey, _assetAccountViewMode.name);
    notifyListeners();
  }

  bool isAssetSectionCollapsed({
    required AssetAccountViewMode mode,
    required String sectionId,
  }) {
    return _collapsedAssetSections.contains(
      _assetSectionKey(_activeBookId, mode, sectionId),
    );
  }

  void toggleAssetSectionCollapsed({
    required AssetAccountViewMode mode,
    required String sectionId,
  }) {
    final key = _assetSectionKey(_activeBookId, mode, sectionId);
    if (!_collapsedAssetSections.add(key)) {
      _collapsedAssetSections.remove(key);
    }
    _persistAssetSectionCollapsed();
    notifyListeners();
  }

  List<Account> sortedAccountsForAssetSection({
    required AssetAccountViewMode mode,
    required String sectionId,
    required Iterable<Account> accounts,
  }) {
    final sorted = accounts.toList();
    final order =
        _assetAccountOrders[_assetSectionKey(_activeBookId, mode, sectionId)];
    if (order == null || order.isEmpty) {
      sorted.sort(_defaultAccountCompare);
      return sorted;
    }
    final orderIndex = <String, int>{
      for (final item in order.indexed) item.$2: item.$1,
    };
    sorted.sort((a, b) {
      final aIndex = orderIndex[a.id];
      final bIndex = orderIndex[b.id];
      if (aIndex != null && bIndex != null) {
        return aIndex.compareTo(bIndex);
      }
      if (aIndex != null) {
        return -1;
      }
      if (bIndex != null) {
        return 1;
      }
      return _defaultAccountCompare(a, b);
    });
    return sorted;
  }

  void reorderAssetAccounts({
    required AssetAccountViewMode mode,
    required String sectionId,
    required List<Account> accounts,
    required int oldIndex,
    required int newIndex,
  }) {
    if (oldIndex < 0 ||
        oldIndex >= accounts.length ||
        newIndex < 0 ||
        newIndex >= accounts.length) {
      return;
    }
    final next = accounts.toList();
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    _assetAccountOrders[_assetSectionKey(_activeBookId, mode, sectionId)] = next
        .map((account) => account.id)
        .toList();
    _persistAssetAccountOrders();
    notifyListeners();
  }

  List<T> sortedAssetSections<T>({
    required AssetAccountViewMode mode,
    required List<T> sections,
    required String Function(T section) idOf,
  }) {
    final sorted = sections.toList();
    final order =
        _assetSectionOrders[_assetSectionOrderKeyForMode(_activeBookId, mode)];
    if (order == null || order.isEmpty) {
      return sorted;
    }
    final orderIndex = <String, int>{
      for (final item in order.indexed) item.$2: item.$1,
    };
    sorted.sort((a, b) {
      final aIndex = orderIndex[idOf(a)];
      final bIndex = orderIndex[idOf(b)];
      if (aIndex != null && bIndex != null) {
        return aIndex.compareTo(bIndex);
      }
      if (aIndex != null) {
        return -1;
      }
      if (bIndex != null) {
        return 1;
      }
      return 0;
    });
    return sorted;
  }

  void reorderAssetSections<T>({
    required AssetAccountViewMode mode,
    required List<T> sections,
    required String Function(T section) idOf,
    required int oldIndex,
    required int newIndex,
  }) {
    if (oldIndex < 0 ||
        oldIndex >= sections.length ||
        newIndex < 0 ||
        newIndex > sections.length) {
      return;
    }
    final next = sections.toList();
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length).toInt(), moved);
    _assetSectionOrders[_assetSectionOrderKeyForMode(_activeBookId, mode)] =
        next.map(idOf).toList();
    _persistAssetSectionOrders();
    notifyListeners();
  }

  /// 页面的面板配置(含关闭项),顺序即渲染顺序。
  List<PagePanelSetting> panelSettings(PanelPageKind page) {
    return List<PagePanelSetting>.unmodifiable(_pagePanels[page]!);
  }

  /// 页面当前开启的面板 id,按渲染顺序返回。
  List<String> enabledPanelIds(PanelPageKind page) {
    return _pagePanels[page]!
        .where((item) => item.enabled)
        .map((item) => item.id)
        .toList(growable: false);
  }

  /// 开关面板;为避免页面变空,最后一个开启的面板不允许关闭,返回 false。
  bool setPanelEnabled(PanelPageKind page, String panelId, bool enabled) {
    final panels = _pagePanels[page]!;
    final index = panels.indexWhere((item) => item.id == panelId);
    if (index == -1 || panels[index].enabled == enabled) {
      return true;
    }
    if (!enabled && panels.where((item) => item.enabled).length <= 1) {
      return false;
    }
    panels[index] = panels[index].copyWith(enabled: enabled);
    _persistPagePanels(page);
    notifyListeners();
    return true;
  }

  /// 恢复页面面板为默认顺序并全部开启。
  void resetPanels(PanelPageKind page) {
    _pagePanels[page] = _defaultPanelSettings(page.specs);
    _persistPagePanels(page);
    notifyListeners();
  }

  void reorderPanels(PanelPageKind page, int oldIndex, int newIndex) {
    final panels = _pagePanels[page]!;
    if (oldIndex < 0 ||
        oldIndex >= panels.length ||
        newIndex < 0 ||
        newIndex > panels.length) {
      return;
    }
    final moved = panels.removeAt(oldIndex);
    panels.insert(newIndex.clamp(0, panels.length).toInt(), moved);
    _persistPagePanels(page);
    notifyListeners();
  }

  // 交易列表始终维护 occurredAt 倒序;同一时刻用 id 决出稳定顺序。
  VoidCallback? onEntryAdded;

  void addEntry(LedgerEntry entry) {
    _entries.insert(0, entry);
    _entries.sort(_compareEntriesLatestFirst);
    _persistEntries();
    notifyListeners();
    onEntryAdded?.call();
  }

  /// 解析 CSV 文本并把交易导入当前账本；匹配不到的账户/分类按名称新建。
  /// 返回导入计划（含成功笔数与逐行错误）供 UI 反馈。解析失败抛 [FormatException]。
  ImportPlan importTransactionsFromCsv(String content) {
    final rows = parseCsv(content);
    final plan = buildImportPlan(
      rows: rows,
      bookId: _activeBookId,
      existingAccounts: accounts,
      existingCategories: categories,
      now: DateTime.now(),
      existingTags: tags,
    );
    _applyImportPlan(plan);
    return plan;
  }

  void _applyImportPlan(ImportPlan plan) {
    if (plan.entries.isEmpty) {
      return;
    }
    _accounts.addAll(plan.newAccounts);
    if (plan.newCategories.isNotEmpty) {
      // 首次导入前若仍是默认分类占位，先落地为真实列表再追加。
      if (_categories.isEmpty) {
        _categories.addAll(_seedCategories);
      }
      _categories.addAll(plan.newCategories);
    }
    if (plan.newTags.isNotEmpty) {
      _tags.addAll(plan.newTags);
    }
    _entries.addAll(plan.entries);
    _entries.sort(_compareEntriesLatestFirst);
    _persistAccounts();
    _persistCategories();
    if (plan.newTags.isNotEmpty) {
      _persistTags();
    }
    _persistEntries();
    notifyListeners();
    // 导入也新增了交易：触发自动备份与小组件刷新，与手动记账一致。
    onEntryAdded?.call();
  }

  /// 仅解析所选平台账单为导入计划，**不落库**——供导入预览页展示、让用户
  /// 排除/编辑后再确认。解析失败抛 [FormatException]。
  ImportPlan parsePlatformImport(ImportPlatform platform, Uint8List bytes) {
    return buildPlatformImportPlan(
      platform: platform,
      bytes: bytes,
      bookId: _activeBookId,
      existingAccounts: accounts,
      existingCategories: categories,
      now: DateTime.now(),
      existingTags: tags,
    );
  }

  /// 落库用户在导入预览页确认（可能已筛选/编辑）的交易子集。
  /// [candidateAccounts]/[candidateCategories] 为解析计划里待新建的账户/分类，
  /// 这里只创建被保留交易**实际引用到**、且当前尚不存在的那些，避免建出用不上的
  /// 空账户/空分类。空交易列表直接返回、不写库。
  void applyImportEntries({
    required List<LedgerEntry> entries,
    required List<Account> candidateAccounts,
    required List<Category> candidateCategories,
    List<Tag> candidateTags = const <Tag>[],
    Set<String> alwaysCreateAccountIds = const <String>{},
  }) {
    if (entries.isEmpty && alwaysCreateAccountIds.isEmpty) {
      return;
    }
    final referencedAccountIds = <String>{};
    final referencedCategoryIds = <String>{};
    final referencedTagIds = <String>{};
    for (final entry in entries) {
      if (entry.accountId.isNotEmpty) {
        referencedAccountIds.add(entry.accountId);
      }
      final toAccountId = entry.toAccountId;
      if (toAccountId != null && toAccountId.isNotEmpty) {
        referencedAccountIds.add(toAccountId);
      }
      if (entry.categoryId.isNotEmpty) {
        referencedCategoryIds.add(entry.categoryId);
      }
      referencedTagIds.addAll(entry.tagIds);
    }
    final existingAccountIds = _accounts.map((account) => account.id).toSet();
    final newAccounts = candidateAccounts
        .where(
          (account) =>
              (referencedAccountIds.contains(account.id) ||
                  alwaysCreateAccountIds.contains(account.id)) &&
              !existingAccountIds.contains(account.id),
        )
        .toList();
    final existingCategoryIds = _categories
        .map((category) => category.id)
        .toSet();
    final newCategories = candidateCategories
        .where(
          (category) =>
              referencedCategoryIds.contains(category.id) &&
              !existingCategoryIds.contains(category.id),
        )
        .toList();
    // 分类映射后，子分类的 parentId 可能指向一个「被映射到现有分类、自身不再新建」的
    // 父候选。这里把这类悬空 parentId 一并保留创建，避免子分类挂到不存在的父上（由
    // _healCategoryData 兜底重挂顶级，但优先按候选补建父级更贴近用户来源层级）。
    final createdCategoryIds = newCategories.map((c) => c.id).toSet();
    for (var i = 0; i < newCategories.length; i++) {
      final parentId = newCategories[i].parentId;
      if (parentId != null &&
          !createdCategoryIds.contains(parentId) &&
          !existingCategoryIds.contains(parentId)) {
        final parent = candidateCategories
            .where((c) => c.id == parentId)
            .firstOrNull;
        if (parent != null) {
          newCategories.add(parent);
          createdCategoryIds.add(parent.id);
        }
      }
    }
    final existingTagIds = _tags.map((tag) => tag.id).toSet();
    final newTags = candidateTags
        .where(
          (tag) =>
              referencedTagIds.contains(tag.id) &&
              !existingTagIds.contains(tag.id),
        )
        .toList();

    _accounts.addAll(newAccounts);
    if (newCategories.isNotEmpty) {
      // 首次导入前若仍是默认分类占位，先落地为真实列表再追加。
      if (_categories.isEmpty) {
        _categories.addAll(_seedCategories);
      }
      _categories.addAll(newCategories);
    }
    if (newTags.isNotEmpty) {
      _tags.addAll(newTags);
    }
    _entries.addAll(entries);
    _entries.sort(_compareEntriesLatestFirst);
    // 导入数据里的旧式单标量退款（如一木账单的「退款」列）迁成关联退款条目、
    // 并重算净额缓存，使余额/统计当场即正确（不必等下次载入自愈）。
    _syncRefundData();
    _persistAccounts();
    _persistCategories();
    if (newTags.isNotEmpty) {
      _persistTags();
    }
    _persistEntries();
    notifyListeners();
    // 导入也新增了交易：触发自动备份与小组件刷新，与手动记账一致。
    onEntryAdded?.call();
  }

  void updateEntry(LedgerEntry entry) {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      return;
    }
    _entries[index] = entry;
    _entries.sort(_compareEntriesLatestFirst);
    _persistEntries();
    notifyListeners();
  }

  /// 标记 / 取消标记支出为「待报销」。仅支出有效。
  void setEntryReimbursable(String entryId, bool reimbursable) {
    final index = _entries.indexWhere((item) => item.id == entryId);
    if (index == -1 || _entries[index].type != EntryType.expense) {
      return;
    }
    _entries[index] = _entries[index].copyWith(reimbursable: reimbursable);
    _persistEntries();
    notifyListeners();
  }

  LedgerEntry? _entryOrNull(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// 某笔支出下的退款条目（到账优先、发起其次的时间倒序）。含待到账。
  List<LedgerEntry> refundsForEntry(String expenseId) {
    final list = _entries
        .where((e) => e.type == EntryType.refund && e.refundOf == expenseId)
        .toList();
    list.sort((a, b) {
      final ad = a.settledAt ?? a.occurredAt;
      final bd = b.settledAt ?? b.occurredAt;
      return bd.compareTo(ad);
    });
    return List<LedgerEntry>.unmodifiable(list);
  }

  /// 当前账本所有「待到账」退款（发起日倒序），用于「待退款」清单页。
  List<LedgerEntry> get pendingRefunds {
    final list = _entries
        .where((e) => e.bookId == _activeBookId && e.isPendingRefund)
        .toList();
    list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List<LedgerEntry>.unmodifiable(list);
  }

  /// 某笔支出已挂的退款总额（含待到账），用于「剩余可退」与超额拦截。
  double refundedTotalFor(String expenseId) {
    var sum = 0.0;
    for (final e in _entries) {
      if (e.type == EntryType.refund && e.refundOf == expenseId) {
        sum += e.amount;
      }
    }
    return sum;
  }

  /// 某笔支出「剩余可退」额 = 原金额 − 已挂退款（含待到账），钳到 `[0, amount]`。
  /// 决策 D：禁止超额，退款上限为原金额。
  double remainingRefundable(String expenseId) {
    final expense = _entryOrNull(expenseId);
    if (expense == null || expense.type != EntryType.expense) return 0;
    return (expense.amount - refundedTotalFor(expenseId))
        .clamp(0.0, expense.amount)
        .toDouble();
  }

  /// 给某笔支出添加一笔退款。金额自动截到「剩余可退」（决策 D：禁止超额）。
  /// [settledAt] 为 null 表示「待到账」（不进余额 / 净额，只进待退款清单）。
  /// 返回实际记入的退款条目；金额 ≤ 0 或支出不存在时返回 null。
  LedgerEntry? addRefund({
    required String expenseId,
    required double amount,
    required String accountId,
    required DateTime initiatedAt,
    DateTime? settledAt,
    String note = '',
  }) {
    final expense = _entryOrNull(expenseId);
    if (expense == null || expense.type != EntryType.expense) return null;
    final capped = amount.clamp(0.0, remainingRefundable(expenseId)).toDouble();
    if (capped <= 0) return null;
    final refund = LedgerEntry(
      id: _generateId('entry'),
      bookId: expense.bookId,
      type: EntryType.refund,
      amount: capped,
      categoryId: expense.categoryId,
      accountId: accountId,
      note: note,
      occurredAt: initiatedAt,
      refundOf: expenseId,
      settledAt: settledAt,
    );
    _entries.add(refund);
    _entries.sort(_compareEntriesLatestFirst);
    _syncRefundCache(); // 重算原支出净额缓存
    _persistEntries();
    notifyListeners();
    onEntryAdded?.call();
    return refund;
  }

  /// 更新一笔退款（金额/到账账户/发起日期/备注/到账状态）。
  /// 金额自动截到「剩余可退（不含本笔旧值）」，防止超额。
  void updateRefund(LedgerEntry refund) {
    final index = _entries.indexWhere(
      (e) => e.id == refund.id && e.type == EntryType.refund,
    );
    if (index == -1) return;
    final expenseId = refund.refundOf ?? _entries[index].refundOf;
    final expense = expenseId == null ? null : _entryOrNull(expenseId);
    var otherSum = 0.0;
    for (final e in _entries) {
      if (e.id != refund.id &&
          e.type == EntryType.refund &&
          e.refundOf == expenseId) {
        otherSum += e.amount;
      }
    }
    final cap = expense == null
        ? refund.amount
        : (expense.amount - otherSum).clamp(0.0, expense.amount).toDouble();
    _entries[index] = refund.copyWith(
      amount: refund.amount.clamp(0.0, cap).toDouble(),
    );
    _entries.sort(_compareEntriesLatestFirst);
    _syncRefundCache();
    _persistEntries();
    notifyListeners();
  }

  /// 标记退款「已到账」（传到账日期）或改回「待到账」（传 null）。
  void setRefundSettled(String refundId, DateTime? settledAt) {
    final index = _entries.indexWhere(
      (e) => e.id == refundId && e.type == EntryType.refund,
    );
    if (index == -1) return;
    _entries[index] = _entries[index].copyWith(
      settledAt: settledAt,
      clearSettledAt: settledAt == null,
    );
    _syncRefundCache();
    _persistEntries();
    notifyListeners();
  }

  /// 删除一笔退款条目（原支出净额缓存随之恢复）。
  void deleteRefund(String refundId) {
    final index = _entries.indexWhere(
      (e) => e.id == refundId && e.type == EntryType.refund,
    );
    if (index == -1) return;
    _entries.removeAt(index);
    _syncRefundCache();
    _persistEntries();
    if (_removeAttachmentsForEntries(<String>{refundId})) {
      _persistAttachments();
    }
    notifyListeners();
  }

  void addLedgerBook(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final book = LedgerBook(
      id: _generateId('book'),
      name: trimmedName,
      createdAt: now,
      isDefault: false,
    );
    _ledgerBooks.add(book);
    _activeBookId = book.id;
    _persistLedgerBooks();
    _store.write(_activeBookKey, _activeBookId);
    notifyListeners();
  }

  void renameLedgerBook(String bookId, String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    final index = _ledgerBooks.indexWhere((book) => book.id == bookId);
    if (index == -1) {
      return;
    }
    _ledgerBooks[index] = _ledgerBooks[index].copyWith(name: trimmedName);
    _persistLedgerBooks();
    notifyListeners();
  }

  void switchLedgerBook(String bookId) {
    if (!_ledgerBooks.any((book) => book.id == bookId)) {
      return;
    }
    _activeBookId = bookId;
    _store.write(_activeBookKey, _activeBookId);
    notifyListeners();
  }

  bool deleteLedgerBook(String bookId) {
    final book = _ledgerBooks.where((item) => item.id == bookId).firstOrNull;
    if (book == null || book.isDefault) {
      return false;
    }
    _ledgerBooks.removeWhere((item) => item.id == bookId);
    final removedEntryIds = _entries
        .where((entry) => entry.bookId == bookId)
        .map((entry) => entry.id)
        .toSet();
    _entries.removeWhere((entry) => entry.bookId == bookId);
    _accounts.removeWhere((account) => account.bookId == bookId);
    _accountGroups.removeWhere((group) => group.bookId == bookId);
    _recurringRules.removeWhere((rule) => rule.bookId == bookId);
    _collapsedAssetSections.removeWhere((key) => key.startsWith('$bookId:'));
    _assetAccountOrders.removeWhere((key, _) => key.startsWith('$bookId:'));
    _assetSectionOrders.removeWhere((key, _) => key.startsWith('$bookId:'));
    _monthlyBudgets.removeWhere((key, _) => key.startsWith('$bookId:'));
    _categoryBudgets.removeWhere((key, _) => key.startsWith('$bookId:'));
    _dailyBudgets.remove(bookId);
    _defaultAccountIds.remove(bookId);
    _persistDefaultAccounts();
    if (_activeBookId == bookId) {
      _activeBookId = defaultLedgerBookId;
      _store.write(_activeBookKey, _activeBookId);
    }
    // 内存里剥离该账本的附件，落库交给下方整体写入（附件已含在快照里）。
    _removeAttachmentsForEntries(removedEntryIds);
    _persistAllLedgerData();
    // 以下为 KV 偏好类，不在账目事务内。
    _persistAssetSectionCollapsed();
    _persistAssetAccountOrders();
    _persistAssetSectionOrders();
    notifyListeners();
    return true;
  }

  int entryCountForBook(String bookId) {
    return _entries.where((entry) => entry.bookId == bookId).length;
  }

  void deleteEntry(String entryId) {
    // 删支出时级联删除挂它的退款条目；删退款时由 _syncRefundData 恢复原支出净额缓存。
    final refundIds = _entries
        .where((e) => e.type == EntryType.refund && e.refundOf == entryId)
        .map((e) => e.id)
        .toSet();
    final removeIds = <String>{entryId, ...refundIds};
    _entries.removeWhere((entry) => removeIds.contains(entry.id));
    _syncRefundCache();
    _persistEntries();
    if (_removeAttachmentsForEntries(removeIds)) {
      _persistAttachments();
    }
    notifyListeners();
  }

  /// 批量删除交易（连同关联退款条目与附件级联清理）。
  void deleteEntries(Set<String> entryIds) {
    if (entryIds.isEmpty) {
      return;
    }
    final refundIds = _entries
        .where(
          (e) =>
              e.type == EntryType.refund &&
              e.refundOf != null &&
              entryIds.contains(e.refundOf),
        )
        .map((e) => e.id)
        .toSet();
    final removeIds = <String>{...entryIds, ...refundIds};
    _entries.removeWhere((entry) => removeIds.contains(entry.id));
    _syncRefundCache();
    _persistEntries();
    if (_removeAttachmentsForEntries(removeIds)) {
      _persistAttachments();
    }
    notifyListeners();
  }

  /// 批量改分类：只改与目标分类同类型的交易（类型不符的跳过）。返回改动数量。
  int setEntriesCategory(Set<String> entryIds, String categoryId) {
    final category = _categories.where((c) => c.id == categoryId).firstOrNull;
    if (category == null || entryIds.isEmpty) {
      return 0;
    }
    var changed = 0;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entryIds.contains(entry.id) && entry.type == category.type) {
        _entries[i] = entry.copyWith(categoryId: categoryId);
        changed += 1;
      }
    }
    if (changed > 0) {
      _persistEntries();
      notifyListeners();
    }
    return changed;
  }

  /// 批量改账户：设置选中交易的（转出）账户。返回改动数量。
  int setEntriesAccount(Set<String> entryIds, String accountId) {
    if (entryIds.isEmpty) {
      return 0;
    }
    var changed = 0;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      // 转账时目标账户不能与转出账户相同。
      if (entryIds.contains(entry.id) &&
          entry.accountId != accountId &&
          !(entry.type == EntryType.transfer &&
              entry.toAccountId == accountId)) {
        _entries[i] = entry.copyWith(accountId: accountId);
        changed += 1;
      }
    }
    if (changed > 0) {
      _persistEntries();
      notifyListeners();
    }
    return changed;
  }

  void addAccount(Account account) {
    _accounts.add(account);
    _persistAccounts();
    notifyListeners();
  }

  void updateAccount(Account account) {
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      return;
    }
    _accounts[index] = account;
    _persistAccounts();
    notifyListeners();
  }

  /// 停用引用 [accountId] 的周期规则并清掉其账户引用（转出改为「无账户」、
  /// 转入清空），避免删账户后规则继续往已不存在的账户补记。返回受影响的规则数，
  /// 供 UI 提示用户前往复查。
  int _detachAccountFromRecurringRules(String accountId) {
    var affected = 0;
    for (var i = 0; i < _recurringRules.length; i++) {
      final rule = _recurringRules[i];
      final hitsFrom = rule.accountId == accountId;
      final hitsTo = rule.toAccountId == accountId;
      if (!hitsFrom && !hitsTo) {
        continue;
      }
      _recurringRules[i] = rule.copyWith(
        active: false,
        accountId: hitsFrom ? '' : null,
        clearToAccountId: hitsTo,
      );
      affected++;
    }
    if (affected > 0) {
      _persistRecurringRules();
    }
    return affected;
  }

  /// 删除账户。返回被停用的周期规则数（0 表示没有规则引用它）。
  int deleteAccount(String accountId) {
    final affectedRules = _detachAccountFromRecurringRules(accountId);
    _accounts.removeWhere((account) => account.id == accountId);
    _removeAccountFromOrders(accountId);
    _clearDefaultAccountRef(accountId);
    _persistAssetAccountOrders();
    _persistAccounts();
    notifyListeners();
    return affectedRules;
  }

  /// 删除账户及其相关交易。返回被停用的周期规则数。
  int deleteAccountAndRelatedEntries(String accountId) {
    final affectedRules = _detachAccountFromRecurringRules(accountId);
    final removedEntryIds = _entries
        .where((entry) => entryTouchesAccount(entry, accountId))
        .map((entry) => entry.id)
        .toSet();
    _entries.removeWhere((entry) => entryTouchesAccount(entry, accountId));
    _accounts.removeWhere((account) => account.id == accountId);
    _removeAccountFromOrders(accountId);
    _clearDefaultAccountRef(accountId);
    _persistEntries();
    if (_removeAttachmentsForEntries(removedEntryIds)) {
      _persistAttachments();
    }
    _persistAssetAccountOrders();
    _persistAccounts();
    notifyListeners();
    return affectedRules;
  }

  void adjustAccountBalance(
    Account account,
    double targetBalance, {
    String note = '余额调整',
  }) {
    final currentBalance = accountBalance(account);
    final difference = targetBalance - currentBalance;
    if (difference.abs() < 0.005) {
      return;
    }
    final now = DateTime.now();
    _entries.insert(
      0,
      LedgerEntry(
        id: _generateId('entry'),
        bookId: account.bookId,
        type: difference > 0 ? EntryType.income : EntryType.expense,
        amount: difference.abs(),
        categoryId: difference > 0
            ? 'balance_adjust_income'
            : 'balance_adjust_expense',
        accountId: account.id,
        note: note,
        occurredAt: now,
      ),
    );
    _entries.sort(_compareEntriesLatestFirst);
    _persistEntries();
    notifyListeners();
    // 余额调整也生成了一笔交易：触发自动备份与小组件刷新。
    onEntryAdded?.call();
  }

  /// 不生成交易,直接调整初始余额,使当前余额等于目标值。
  void rebaseAccountBalance(Account account, double targetBalance) {
    final currentBalance = accountBalance(account);
    final difference = targetBalance - currentBalance;
    if (difference.abs() < 0.005) {
      return;
    }
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      return;
    }
    _accounts[index] = _accounts[index].copyWith(
      initialBalance: _accounts[index].initialBalance + difference,
    );
    _persistAccounts();
    notifyListeners();
  }

  /// 新增分类。传入 [parentId] 则创建为该分类的子分类（多级分类）；
  /// 子分类的类型强制继承父分类，[type] 仅在创建顶级分类时生效。
  void addCategory({
    required EntryType type,
    required String label,
    required String iconCode,
    String? parentId,
  }) {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      return;
    }
    var resolvedType = type;
    if (parentId != null) {
      final parent = _categories
          .where((category) => category.id == parentId)
          .firstOrNull;
      if (parent == null) {
        return;
      }
      // 子分类类型必须与父分类一致。
      resolvedType = parent.type;
    }
    // 同一父级下已存在同名同类型分类则不重复创建（避免增殖出重复同名分类，
    // 也避免触犯分类唯一约束；名称按归一化比较，容忍大小写/空白/全半角差异）。
    final normalized = normalizedCategoryLabel(trimmedLabel);
    final duplicate = _categories.any(
      (category) =>
          category.type == resolvedType &&
          category.parentId == parentId &&
          normalizedCategoryLabel(category.label) == normalized,
    );
    if (duplicate) {
      return;
    }
    _categories.add(
      Category(
        id: _generateId('category'),
        label: trimmedLabel,
        type: resolvedType,
        iconCode: iconCode,
        parentId: parentId,
      ),
    );
    _persistCategories();
    notifyListeners();
  }

  /// 移动分类到新的父分类下（[newParentId] 为 null 表示移到顶级）。
  /// 拦截：系统分类、指向自身、成环（移到自己的后代下）、跨类型。
  bool moveCategory(String categoryId, String? newParentId) {
    if (_isProtectedCategory(categoryId) || categoryId == newParentId) {
      return false;
    }
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index == -1) {
      return false;
    }
    final category = _categories[index];
    if (category.parentId == newParentId) {
      return false;
    }
    if (newParentId != null) {
      final parent = _categories.where((c) => c.id == newParentId).firstOrNull;
      if (parent == null || parent.type != category.type) {
        return false;
      }
      // 不能移动到自己的后代之下，否则会成环。
      if (isDescendantOf(_categories, newParentId, categoryId)) {
        return false;
      }
    }
    // 从原位置摘出并追加到末尾，成为新父级下的最后一个同级。
    _categories.removeAt(index);
    _categories.add(category.copyWith(parentId: newParentId));
    _persistCategories();
    notifyListeners();
    return true;
  }

  void renameCategory(String categoryId, String label) {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      return;
    }
    final index = _categories.indexWhere(
      (category) => category.id == categoryId,
    );
    if (index == -1) {
      return;
    }
    _categories[index] = _categories[index].copyWith(label: trimmedLabel);
    _persistCategories();
    notifyListeners();
  }

  void updateCategoryIcon(String categoryId, String iconCode) {
    final index = _categories.indexWhere(
      (category) => category.id == categoryId,
    );
    if (index == -1) {
      return;
    }
    _categories[index] = _categories[index].copyWith(iconCode: iconCode);
    _persistCategories();
    notifyListeners();
  }

  /// 在同一父级（[parentId] 为 null 即顶级）的兄弟分类间重排。
  /// 仅在这些兄弟节点占据的全局位置上做置换，不影响其余分类与各自子树。
  void reorderCategories(
    EntryType type,
    String? parentId,
    int oldIndex,
    int newIndex,
  ) {
    final positions = <int>[];
    for (var i = 0; i < _categories.length; i++) {
      final category = _categories[i];
      if (category.type == type && category.parentId == parentId) {
        positions.add(i);
      }
    }
    if (oldIndex < 0 ||
        oldIndex >= positions.length ||
        newIndex < 0 ||
        newIndex > positions.length) {
      return;
    }
    final siblings = <Category>[for (final p in positions) _categories[p]];
    final moved = siblings.removeAt(oldIndex);
    siblings.insert(newIndex.clamp(0, siblings.length), moved);
    for (var k = 0; k < positions.length; k++) {
      _categories[positions[k]] = siblings[k];
    }
    _persistCategories();
    notifyListeners();
  }

  bool deleteCategory(String categoryId) {
    if (_isProtectedCategory(categoryId)) {
      return false;
    }
    final category = _categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    if (category == null || categoryUsageCount(categoryId) > 0) {
      return false;
    }
    // 仍被周期规则引用时不能删除，否则规则到期会生成悬空分类的交易。
    if (categoryUsedByRecurringRule(categoryId)) {
      return false;
    }
    // 有子分类时不能直接删除，需先移动或删除子分类。
    if (hasChildren(_categories, categoryId)) {
      return false;
    }
    if (categoriesForType(category.type).length <= 1) {
      return false;
    }
    _categories.removeWhere((item) => item.id == categoryId);
    // 清理该分类在各账本/月份下的分类预算，避免残留孤儿键。
    _categoryBudgets.removeWhere((key, _) => key.endsWith(':$categoryId'));
    _persistCategories();
    _persistCategoryBudgets();
    notifyListeners();
    return true;
  }

  int categoryUsageCount(String categoryId) {
    return _entries.where((entry) => entry.categoryId == categoryId).length;
  }

  /// 是否有周期规则正引用该分类（含尚未生成过任何交易的规则）。
  bool categoryUsedByRecurringRule(String categoryId) {
    return _recurringRules.any((rule) => rule.categoryId == categoryId);
  }

  /// 引用该分类的周期规则数（用于 UI 提示）。
  int categoryRecurringRuleCount(String categoryId) {
    return _recurringRules
        .where((rule) => rule.categoryId == categoryId)
        .length;
  }

  /// 把 [sourceId] 分类合并到 [targetId]：其全部交易与周期规则改指向 [targetId]，
  /// 随后删除 [sourceId]（连同其分类预算）。用于统一同义分类（如「交通出行」并入「交通」）。
  ///
  /// 返回被改动的交易笔数；无法合并时返回 -1（源受保护 / 源或目标不存在 / 类型不一致 /
  /// 源与目标相同 / 源仍有子分类 / 目标是源的后代）。源有子分类时应先移动或删除子分类。
  int mergeCategoryInto(String sourceId, String targetId) {
    if (sourceId == targetId || _isProtectedCategory(sourceId)) {
      return -1;
    }
    final source = _categories.where((c) => c.id == sourceId).firstOrNull;
    final target = _categories.where((c) => c.id == targetId).firstOrNull;
    if (source == null || target == null || source.type != target.type) {
      return -1;
    }
    // 源有子分类无法整体合并（会孤立子树）；目标是源的后代同理不允许。
    if (hasChildren(_categories, sourceId) ||
        isDescendantOf(_categories, targetId, sourceId)) {
      return -1;
    }
    var changed = 0;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].categoryId == sourceId) {
        _entries[i] = _entries[i].copyWith(categoryId: targetId);
        changed += 1;
      }
    }
    var rulesChanged = false;
    for (var i = 0; i < _recurringRules.length; i++) {
      if (_recurringRules[i].categoryId == sourceId) {
        _recurringRules[i] = _recurringRules[i].copyWith(categoryId: targetId);
        rulesChanged = true;
      }
    }
    _categories.removeWhere((c) => c.id == sourceId);
    // 清理源分类的分类预算，避免残留孤儿键。
    _categoryBudgets.removeWhere((key, _) => key.endsWith(':$sourceId'));
    if (changed > 0) {
      _persistEntries();
    }
    if (rulesChanged) {
      _persistRecurringRules();
    }
    _persistCategories();
    _persistCategoryBudgets();
    notifyListeners();
    return changed;
  }

  // ---- 标签 ----

  /// 新增标签。名称去重（忽略首尾空白，区分大小写），已存在则返回其 id。
  String? addTag(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final existing = _tags.where((tag) => tag.label == trimmed).firstOrNull;
    if (existing != null) {
      return existing.id;
    }
    final tag = Tag(id: _generateId('tag'), label: trimmed);
    _tags.add(tag);
    _persistTags();
    notifyListeners();
    return tag.id;
  }

  void renameTag(String tagId, String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final index = _tags.indexWhere((tag) => tag.id == tagId);
    if (index == -1) {
      return;
    }
    _tags[index] = _tags[index].copyWith(label: trimmed);
    _persistTags();
    notifyListeners();
  }

  void reorderTags(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _tags.length ||
        newIndex < 0 ||
        newIndex > _tags.length) {
      return;
    }
    final moved = _tags.removeAt(oldIndex);
    _tags.insert(newIndex.clamp(0, _tags.length), moved);
    _persistTags();
    notifyListeners();
  }

  /// 删除标签，并从所有交易的 tagIds 中移除该标签的引用。
  void deleteTag(String tagId) {
    final index = _tags.indexWhere((tag) => tag.id == tagId);
    if (index == -1) {
      return;
    }
    _tags.removeAt(index);
    var touchedEntries = false;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.tagIds.contains(tagId)) {
        _entries[i] = entry.copyWith(
          tagIds: entry.tagIds.where((id) => id != tagId).toList(),
        );
        touchedEntries = true;
      }
    }
    _persistTags();
    if (touchedEntries) {
      _persistEntries();
    }
    notifyListeners();
  }

  void addAccountGroup(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    _accountGroups.add(
      AccountGroup(
        id: _generateId('group'),
        bookId: _activeBookId,
        name: trimmedName,
        iconCode: 'folder',
        sortOrder: accountGroups.length,
      ),
    );
    _persistAccountGroups();
    notifyListeners();
  }

  void renameAccountGroup(String groupId, String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    final index = _accountGroups.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      return;
    }
    _accountGroups[index] = _accountGroups[index].copyWith(name: trimmedName);
    _persistAccountGroups();
    notifyListeners();
  }

  void updateAccountGroupIcon(String groupId, String iconCode) {
    final index = _accountGroups.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      return;
    }
    _accountGroups[index] = _accountGroups[index].copyWith(iconCode: iconCode);
    _persistAccountGroups();
    notifyListeners();
  }

  void deleteAccountGroup(String groupId) {
    _accountGroups.removeWhere((group) => group.id == groupId);
    for (var i = 0; i < _accounts.length; i += 1) {
      if (_accounts[i].groupId == groupId) {
        _accounts[i] = _accounts[i].copyWith(groupId: 'ungrouped');
      }
    }
    _normalizeGroupOrder();
    _persistAccountGroups();
    _persistAccounts();
    notifyListeners();
  }

  void reorderAccountGroup(int oldIndex, int newIndex) {
    final groups = accountGroups.toList();
    final otherGroups = _accountGroups
        .where((group) => group.bookId != _activeBookId)
        .toList();
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = groups.removeAt(oldIndex);
    groups.insert(newIndex, moved);
    _accountGroups
      ..clear()
      ..addAll(otherGroups)
      ..addAll(
        groups.indexed.map((item) => item.$2.copyWith(sortOrder: item.$1)),
      );
    _persistAccountGroups();
    notifyListeners();
  }

  void updateProfile(UserProfile profile) {
    _profile = profile;
    _store.write(_profileKey, jsonEncode(profile.toJson()));
    notifyListeners();
  }

  void setAssetCoverUrl(String value) {
    _assetCoverUrl = value.trim();
    if (_assetCoverUrl.isEmpty) {
      _store.delete(_assetCoverKey);
    } else {
      _store.write(_assetCoverKey, _assetCoverUrl);
    }
    notifyListeners();
  }

  void resetAllData() {
    // 偏好类 KV 键清空；账目类数据在下方以默认状态写回 SQLite。
    for (final key in <String>[
      _themeKey,
      _profileKey,
      _activeBookKey,
      _assetCoverKey,
      _hapticsKey,
      _assetViewModeKey,
      _assetSectionCollapsedKey,
      _assetAccountOrderKey,
      _assetSectionOrderKey,
      _homePanelsKey,
      _reportPanelsKey,
    ]) {
      _store.delete(key);
    }
    _entries.clear();
    _accounts
      ..clear()
      ..addAll(defaultAccounts);
    _accountGroups
      ..clear()
      ..addAll(defaultAccountGroups);
    _ledgerBooks
      ..clear()
      ..addAll(_seedLedgerBooks);
    _categories
      ..clear()
      ..addAll(_seedCategories);
    _tags.clear();
    _attachments.clear();
    _recurringRules.clear();
    _monthlyBudgets.clear();
    _categoryBudgets.clear();
    _dailyBudgets.clear();
    _profile = _seedProfile;
    _themePreference = ThemePreference.system;
    _activeBookId = defaultLedgerBookId;
    _assetCoverUrl = '';
    _hapticsEnabled = true;
    _assetAccountViewMode = AssetAccountViewMode.type;
    _collapsedAssetSections.clear();
    _assetAccountOrders.clear();
    _assetSectionOrders.clear();
    // 账户被清空，默认付款账户随之失效。
    _defaultAccountIds.clear();
    _persistDefaultAccounts();
    for (final page in PanelPageKind.values) {
      _pagePanels[page] = _defaultPanelSettings(page.specs);
    }
    // 把重置后的默认状态写回 SQLite（单事务原子替换全部表）。
    _persistAllLedgerData();
    themePreferenceListenable.value = _themePreference;
    notifyListeners();
  }

  String exportDataJson() {
    final payload = <String, Object?>{
      'app': 'verifin',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': <String, Object?>{
        'ledgerBooks': _ledgerBooks.map((book) => book.toJson()).toList(),
        'activeBookId': _activeBookId,
        'entries': _entries.map((entry) => entry.toJson()).toList(),
        'accounts': _accounts.map((account) => account.toJson()).toList(),
        'accountGroups': _accountGroups.map((group) => group.toJson()).toList(),
        'categories': _categories.map((category) => category.toJson()).toList(),
        'tags': _tags.map((tag) => tag.toJson()).toList(),
        'attachments': _attachments.map((a) => a.toJson()).toList(),
        'recurringRules': _recurringRules.map((r) => r.toJson()).toList(),
        'monthlyBudgets': Map<String, double>.from(_monthlyBudgets),
        'categoryBudgets': Map<String, double>.from(_categoryBudgets),
        'dailyBudgets': Map<String, double>.from(_dailyBudgets),
        'profile': _profile.toJson(),
        'themePreference': _themePreference.name,
        'assetCoverUrl': _assetCoverUrl,
        'hapticsEnabled': _hapticsEnabled,
        'assetAccountViewMode': _assetAccountViewMode.name,
        'collapsedAssetSections': _collapsedAssetSections.toList(),
        'assetAccountOrders': _assetAccountOrders,
        'assetSectionOrders': _assetSectionOrders,
        'homePanels': _pagePanels[PanelPageKind.home]!
            .map((item) => item.toJson())
            .toList(),
        'reportPanels': _pagePanels[PanelPageKind.reports]!
            .map((item) => item.toJson())
            .toList(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 导出为压缩包（zip）字节：把图片附件从 JSON 里剥离、单独存 `attachments/<id>`，
  /// 控制备份体积（详见 `backup_archive.dart`）。加密备份仍走文本信封路径、不打包，
  /// 以复用现有加密逻辑；未加密备份用本方法产出精简 zip。
  Uint8List exportBackupArchiveBytes() {
    return packBackupArchive(exportDataJson());
  }

  /// 从备份字节导入：zip（新版精简备份）先解包还原内嵌 JSON，否则按 UTF-8 文本
  /// （旧版纯 JSON 备份）解析。加密备份需调用方先解密成明文再传入。
  void importBackupBytes(List<int> bytes) {
    if (looksLikeZipBytes(bytes)) {
      importDataJson(unpackBackupArchive(bytes));
    } else {
      importDataJson(utf8.decode(bytes));
    }
  }

  void importDataJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('备份文件格式不正确');
    }
    final root = Map<String, Object?>.from(decoded);

    // 防御性拦截加密信封：它带 `app:'verifin'` 但只有密文、无任何数据键，若直接
    // 往下走会被当成「空备份」用默认数据覆盖并清库。加密备份必须先解密再导入。
    if (root['enc'] != null || root.containsKey('cipher')) {
      throw const FormatException('这是加密备份，请先输入口令解密后再导入');
    }

    final dataValue = root['data'] ?? root;
    if (dataValue is! Map) {
      throw const FormatException('备份文件缺少数据内容');
    }
    final data = Map<String, Object?>.from(dataValue);

    // 只接受本应用的备份：必须至少含一个已知数据键。仅有 `app` 标记而无任何数据键
    // 的 JSON（如残缺/异常文件）一律拒绝，绝不在导入前清空/覆盖现有数据。
    final looksLikeVeriFinBackup = data.keys.any(_knownBackupDataKeys.contains);
    if (!looksLikeVeriFinBackup) {
      throw const FormatException('不是本应用的备份文件');
    }

    final importedBooks = _decodeModelList<LedgerBook>(
      data['ledgerBooks'],
      LedgerBook.fromJson,
    );
    final nextLedgerBooks = <LedgerBook>[
      ...(importedBooks.isEmpty ? _seedLedgerBooks : importedBooks),
    ];
    if (!nextLedgerBooks.any((book) => book.id == defaultLedgerBookId)) {
      nextLedgerBooks.insert(0, _seedLedgerBooks.first);
    }

    final importedActiveBookId = data['activeBookId'] as String?;
    final nextActiveBookId =
        importedActiveBookId != null &&
            nextLedgerBooks.any((book) => book.id == importedActiveBookId)
        ? importedActiveBookId
        : defaultLedgerBookId;

    final nextEntries = _decodeModelList<LedgerEntry>(
      data['entries'],
      LedgerEntry.fromJson,
    )..sort(_compareEntriesLatestFirst);
    final nextAccounts = _decodeModelList<Account>(
      data['accounts'],
      Account.fromJson,
    );
    final nextAccountGroups = _decodeModelList<AccountGroup>(
      data['accountGroups'],
      AccountGroup.fromJson,
    );
    final importedCategories = _decodeModelList<Category>(
      data['categories'],
      Category.fromJson,
    );
    final nextCategories = <Category>[
      ...(importedCategories.isEmpty ? _seedCategories : importedCategories),
    ];
    final nextTags = _decodeModelList<Tag>(data['tags'], Tag.fromJson);
    final nextAttachments = _decodeModelList<Attachment>(
      data['attachments'],
      Attachment.fromJson,
    );
    final nextRecurringRules = _decodeModelList<RecurringRule>(
      data['recurringRules'],
      RecurringRule.fromJson,
    );
    final nextMonthlyBudgets = _bookScopedBudgets(
      _decodeBudgets(data['monthlyBudgets']),
    );
    final nextCategoryBudgets = _bookScopedBudgets(
      _decodeBudgets(data['categoryBudgets']),
    );
    // 按日预算键是纯 bookId（无日期前缀），无需 _bookScopedBudgets 迁移。
    final nextDailyBudgets = _decodeBudgets(data['dailyBudgets']);

    final profileValue = data['profile'];
    final nextProfile = profileValue is Map
        ? UserProfile.fromJson(Map<String, Object?>.from(profileValue))
        : _seedProfile;
    final nextThemePreference = ThemePreference.fromStorage(
      data['themePreference'] as String?,
    );
    final nextAssetCoverUrl = data['assetCoverUrl'] as String? ?? '';
    final nextHapticsEnabled = data['hapticsEnabled'] as bool? ?? true;
    final nextAssetAccountViewMode = AssetAccountViewMode.fromStorage(
      data['assetAccountViewMode'] as String?,
    );
    final nextCollapsedAssetSections = _decodeStringSet(
      data['collapsedAssetSections'],
    );
    final nextAssetAccountOrders = _decodeStringListMap(
      data['assetAccountOrders'],
    );
    final nextAssetSectionOrders = _decodeStringListMap(
      data['assetSectionOrders'],
    );
    // 旧备份没有面板字段,归一化会补全默认开启的面板。
    final nextHomePanels = _normalizePanelSettings(
      _decodeModelList<PagePanelSetting>(
        data['homePanels'],
        PagePanelSetting.fromJson,
      ),
      homePanelSpecs,
    );
    final nextReportPanels = _normalizePanelSettings(
      _decodeModelList<PagePanelSetting>(
        data['reportPanels'],
        PagePanelSetting.fromJson,
      ),
      reportPanelSpecs,
    );

    _ledgerBooks
      ..clear()
      ..addAll(nextLedgerBooks);
    _activeBookId = nextActiveBookId;
    _entries
      ..clear()
      ..addAll(nextEntries);
    _accounts
      ..clear()
      ..addAll(nextAccounts);
    _accountGroups
      ..clear()
      ..addAll(nextAccountGroups);
    _normalizeGroupOrder();
    _categories
      ..clear()
      ..addAll(nextCategories);
    _tags
      ..clear()
      ..addAll(nextTags);
    _attachments
      ..clear()
      ..addAll(nextAttachments);
    _recurringRules
      ..clear()
      ..addAll(nextRecurringRules);
    _monthlyBudgets
      ..clear()
      ..addAll(nextMonthlyBudgets);
    _categoryBudgets
      ..clear()
      ..addAll(nextCategoryBudgets);
    _dailyBudgets
      ..clear()
      ..addAll(nextDailyBudgets);
    _profile = nextProfile;
    _themePreference = nextThemePreference;
    _assetCoverUrl = nextAssetCoverUrl;
    _hapticsEnabled = nextHapticsEnabled;
    _assetAccountViewMode = nextAssetAccountViewMode;
    _collapsedAssetSections
      ..clear()
      ..addAll(nextCollapsedAssetSections);
    _assetAccountOrders
      ..clear()
      ..addAll(nextAssetAccountOrders);
    _assetSectionOrders
      ..clear()
      ..addAll(nextAssetSectionOrders);
    _pagePanels[PanelPageKind.home] = nextHomePanels;
    _pagePanels[PanelPageKind.reports] = nextReportPanels;

    // 备份恢复零参照完整性校验，是「幽灵同名分类」的唯一现实入口（内部不一致的外部/
    // 异构/手改备份）；覆盖后跑一遍自愈，堵住这个入口。落库统一由下方 _persistAllLedgerData。
    _healCategoryData();
    // 退款自愈：把导入数据里的旧标量退款迁成关联退款条目并重算净额缓存。
    _syncRefundData();
    _persistAllLedgerData();
    _store.write(_activeBookKey, _activeBookId);
    _store.write(_profileKey, jsonEncode(_profile.toJson()));
    _store.write(_themeKey, _themePreference.name);
    _store.write(_hapticsKey, _hapticsEnabled.toString());
    _store.write(_assetViewModeKey, _assetAccountViewMode.name);
    _persistAssetSectionCollapsed();
    _persistAssetAccountOrders();
    _persistAssetSectionOrders();
    for (final page in PanelPageKind.values) {
      _persistPagePanels(page);
    }
    if (_assetCoverUrl.isEmpty) {
      _store.delete(_assetCoverKey);
    } else {
      _store.write(_assetCoverKey, _assetCoverUrl);
    }
    themePreferenceListenable.value = _themePreference;
    notifyListeners();
  }

  double accountBalance(Account account) {
    var balance = account.initialBalance;
    for (final entry in _entries.where(
      (item) =>
          item.bookId == account.bookId &&
          entryTouchesAccount(item, account.id),
    )) {
      balance += accountDeltaForEntry(entry, account.id);
    }
    return balance;
  }

  /// 载入偏好类小数据（KV）。账目类数据由 [_loadFromRepository] 从 SQLite 载入。
}
