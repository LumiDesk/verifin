import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;

import '../data/ledger_repository.dart';
import '../local_storage/local_storage.dart';
import 'ai/ai_settings.dart';
import 'app_lock.dart';
import 'backup/backup_archive.dart';
import 'backup/backup_settings.dart';
import 'backup/payment_import.dart';
import 'backup/transaction_import.dart';
import 'backup/webdav_config.dart';
import 'category_tree.dart';
import 'demo_data.dart';
import 'amount_format.dart' as amount_format;
import 'ledger_math.dart';
import 'logging/app_logger.dart';
import 'models.dart';
import 'recurring.dart';
import 'reminder/reminder_settings.dart';

/// 导入校验用的已知备份数据键：`data` 里出现其一即认定为本应用备份（配合 `app`
/// 标记）。用于拦截「格式合法却非本应用」的 JSON，避免其把数据静默覆盖为初始态。
const Set<String> _knownBackupDataKeys = <String>{
  'ledgerBooks',
  'activeBookId',
  'entries',
  'accounts',
  'accountGroups',
  'categories',
  'tags',
  'attachments',
  'recurringRules',
  'monthlyBudgets',
  'categoryBudgets',
  'dailyBudgets',
  'profile',
  'themePreference',
  'homePanels',
  'reportPanels',
};

class VeriFinController extends ChangeNotifier {
  VeriFinController._(
    this._store,
    this._repository, {
    AppLogger? logger,
    bool systemIsEnglish = false,
    // ignore: prefer_initializing_formals
  }) : _systemIsEnglish = systemIsEnglish,
       // ignore: prefer_initializing_formals
       _logger = logger {
    _loadPreferences();
    themePreferenceListenable = ValueNotifier<ThemePreference>(
      _themePreference,
    );
    localePreferenceListenable = ValueNotifier<LocalePreference>(
      _localePreference,
    );
  }

  /// 唯一的构造入口：同步载入偏好类 KV 数据后，从 SQLite 载入账目类数据
  /// （全新数据库首启动写入默认数据）。账目类数据只以 SQLite 为准。
  static Future<VeriFinController> create(
    LocalKeyValueStore store, {
    required LedgerRepository repository,
    AppLogger? logger,
    bool systemIsEnglish = false,
  }) async {
    final controller = VeriFinController._(
      store,
      repository,
      logger: logger,
      systemIsEnglish: systemIsEnglish,
    );
    await controller._loadFromRepository();
    return controller;
  }

  // 账目类数据（交易/账户/分组/账本/分类/预算）存 SQLite；以下仅为偏好类小数据的 KV 键。
  static const String _themeKey = 'verifin.theme.v1';
  static const String _localeKey = 'verifin.locale.v1';
  static const String _profileKey = 'verifin.profile.v1';
  static const String _activeBookKey = 'verifin.active_book.v1';
  static const String _assetCoverKey = 'verifin.asset_cover.v1';
  static const String _hapticsKey = 'verifin.haptics.v1';
  static const String _privacyConsentKey = 'verifin.privacy_consent.v1';
  static const String _appLockKey = 'verifin.app_lock.v1';
  static const String _assetViewModeKey = 'verifin.asset_view_mode.v1';
  static const String _assetSectionCollapsedKey =
      'verifin.asset_section_collapsed.v1';
  static const String _assetAccountOrderKey = 'verifin.asset_account_order.v1';
  static const String _assetSectionOrderKey = 'verifin.asset_section_order.v1';
  static const String _homePanelsKey = 'verifin.home_panels.v1';
  static const String _reportPanelsKey = 'verifin.report_panels.v1';
  static const String _backupSettingsKey = 'verifin.backup_settings.v1';
  static const String _backupPassphraseKey = 'verifin.backup_passphrase.v1';
  static const String _webdavKey = 'verifin.webdav.v1';
  static const String _reminderKey = 'verifin.reminder.v1';
  static const String _fabActionKey = 'verifin.fab_action.v1';
  static const String _defaultAccountKey = 'verifin.default_account.v1';
  static const String _amountFormatKey = 'verifin.amount_format.v1';
  static const String _aiSettingsKey = 'verifin.ai.v1';
  static const String _onboardingKey = 'verifin.onboarding.v1';

  static String _panelsKeyFor(PanelPageKind page) {
    switch (page) {
      case PanelPageKind.home:
        return _homePanelsKey;
      case PanelPageKind.reports:
        return _reportPanelsKey;
    }
  }

  final LocalKeyValueStore _store;

  /// 软件日志（可空，测试宿主可不注入）。落库/加载失败等会记入此处。
  final AppLogger? _logger;

  /// 软件日志入口，供「软件日志」页读取；未注入时为 null。
  AppLogger? get logger => _logger;

  /// SQLite 落库失败时回调（由 UI 层挂钩弹出「保存失败」提示）。
  void Function(Object error)? onPersistError;

  /// 应用锁开关变化时回调（由 main 挂钩，据此开关 Android FLAG_SECURE）。
  void Function(bool appLockEnabled)? onAppLockChanged;

  /// 系统语言是否为英文（由 main.dart 传入）。语言偏好为「跟随系统」时，
  /// 播种默认数据（账本名/分类/个人简介）依此选语言。
  final bool _systemIsEnglish;

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

  /// SQLite 仓储，账目类数据的唯一存储。
  final LedgerRepository _repository;

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
  bool _amountForceTwoDecimals = false;
  AiSettings _aiSettings = const AiSettings();

  List<LedgerEntry> get entries => List<LedgerEntry>.unmodifiable(
    _entries.where((entry) => entry.bookId == _activeBookId),
  );

  List<LedgerBook> get ledgerBooks => List<LedgerBook>.unmodifiable(
    _ledgerBooks.isEmpty ? _seedLedgerBooks : _ledgerBooks,
  );

  LedgerBook get activeBook => ledgerBooks.firstWhere(
    (book) => book.id == _activeBookId,
    orElse: () => ledgerBooks.first,
  );

  List<Account> get accounts => List<Account>.unmodifiable(
    _accounts.where((account) => account.bookId == _activeBookId),
  );

  List<AccountGroup> get accountGroups {
    final groups =
        _accountGroups.where((group) => group.bookId == _activeBookId).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List<AccountGroup>.unmodifiable(groups);
  }

  List<Category> get categories => List<Category>.unmodifiable(
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

  /// 为交易新增一张图片附件（[dataUrl] 为压缩后的 JPEG data URL）。
  void addAttachment(String entryId, String dataUrl) {
    if (dataUrl.isEmpty) {
      return;
    }
    _attachments.add(
      Attachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        entryId: entryId,
        dataUrl: dataUrl,
      ),
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
    for (var i = 0; i < _recurringRules.length; i++) {
      final rule = _recurringRules[i];
      final dueDates = dueDatesFor(rule, now);
      if (dueDates.isEmpty) {
        continue;
      }
      for (final due in dueDates) {
        _entries.add(
          LedgerEntry(
            id: 'entry_recur_${rule.id}_${due.millisecondsSinceEpoch}',
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
    _themePreference = preference;
    themePreferenceListenable.value = preference;
    _store.write(_themeKey, preference.name);
    notifyListeners();
  }

  LocalePreference get localePreference => _localePreference;

  /// 语言是设备本地偏好：不进 JSON 备份，初始化数据时保留。
  void setLocalePreference(LocalePreference preference) {
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

  /// 用户是否已同意隐私政策与用户协议（首启动前为 false）。
  bool get onboardingCompleted => _onboardingCompleted;

  /// 标记新用户引导已完成（只走一次，初始化数据不清除）。
  void completeOnboarding() {
    if (_onboardingCompleted) {
      return;
    }
    _onboardingCompleted = true;
    _store.write(_onboardingKey, 'true');
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
  static int _compareEntriesLatestFirst(LedgerEntry a, LedgerEntry b) {
    final byDate = b.occurredAt.compareTo(a.occurredAt);
    if (byDate != 0) {
      return byDate;
    }
    return b.id.compareTo(a.id);
  }

  /// 记账后回调（新增交易时触发），供自动备份「每次记账后」挂钩。
  /// 由应用根组件注入，控制器本身不做文件 I/O，测试宿主保持为空。
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
    );
    _applyImportPlan(plan);
    return plan;
  }

  /// 解析所选支付平台 / 记账软件导出的账单字节并导入当前账本。
  /// 支付宝(GBK CSV)、微信(xlsx)、薄荷记账(UTF-16 CSV)各自适配，其他走通用 CSV。
  /// 返回导入计划供 UI 反馈；解析失败抛 [FormatException]。
  ImportPlan importTransactionsFromPlatform(
    ImportPlatform platform,
    Uint8List bytes,
  ) {
    final plan = buildPlatformImportPlan(
      platform: platform,
      bytes: bytes,
      bookId: _activeBookId,
      existingAccounts: accounts,
      existingCategories: categories,
      now: DateTime.now(),
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
    _entries.addAll(plan.entries);
    _entries.sort(_compareEntriesLatestFirst);
    _persistAccounts();
    _persistCategories();
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

  /// 设置支出被退款 / 报销回款冲抵的金额（回到原账户）。
  /// [amount] 会被限制在 `[0, 原金额]`；设为 0 即撤销冲抵。
  void setEntryRefundedAmount(String entryId, double amount) {
    final index = _entries.indexWhere((item) => item.id == entryId);
    if (index == -1 || _entries[index].type != EntryType.expense) {
      return;
    }
    final entry = _entries[index];
    final clamped = amount.clamp(0, entry.amount).toDouble();
    _entries[index] = entry.copyWith(refundedAmount: clamped);
    _persistEntries();
    notifyListeners();
  }

  void addLedgerBook(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final book = LedgerBook(
      id: now.microsecondsSinceEpoch.toString(),
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
    if (_removeAttachmentsForEntries(removedEntryIds)) {
      _persistAttachments();
    }
    _persistLedgerBooks();
    _persistEntries();
    _persistAccounts();
    _persistAccountGroups();
    _persistRecurringRules();
    _persistAssetSectionCollapsed();
    _persistAssetAccountOrders();
    _persistAssetSectionOrders();
    _persistBudgets();
    _persistCategoryBudgets();
    _persistDailyBudgets();
    notifyListeners();
    return true;
  }

  int entryCountForBook(String bookId) {
    return _entries.where((entry) => entry.bookId == bookId).length;
  }

  void deleteEntry(String entryId) {
    _entries.removeWhere((entry) => entry.id == entryId);
    _persistEntries();
    if (_removeAttachmentsForEntries(<String>{entryId})) {
      _persistAttachments();
    }
    notifyListeners();
  }

  /// 批量删除交易（连同附件级联清理）。
  void deleteEntries(Set<String> entryIds) {
    if (entryIds.isEmpty) {
      return;
    }
    _entries.removeWhere((entry) => entryIds.contains(entry.id));
    _persistEntries();
    if (_removeAttachmentsForEntries(entryIds)) {
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

  void deleteAccount(String accountId) {
    _accounts.removeWhere((account) => account.id == accountId);
    _removeAccountFromOrders(accountId);
    _clearDefaultAccountRef(accountId);
    _persistAssetAccountOrders();
    _persistAccounts();
    notifyListeners();
  }

  void deleteAccountAndRelatedEntries(String accountId) {
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
        id: now.microsecondsSinceEpoch.toString(),
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
    _categories.add(
      Category(
        id: 'category_${DateTime.now().microsecondsSinceEpoch}',
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
    final tag = Tag(
      id: 'tag_${DateTime.now().microsecondsSinceEpoch}',
      label: trimmed,
    );
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
        id: DateTime.now().microsecondsSinceEpoch.toString(),
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
    // 把重置后的默认状态写回 SQLite。
    _persistEntries();
    _persistLedgerBooks();
    _persistAccounts();
    _persistAccountGroups();
    _persistCategories();
    _persistTags();
    _persistAttachments();
    _persistRecurringRules();
    _persistBudgets();
    _persistCategoryBudgets();
    _persistDailyBudgets();
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

    _persistLedgerBooks();
    _store.write(_activeBookKey, _activeBookId);
    _persistEntries();
    _persistAccounts();
    _persistAccountGroups();
    _persistCategories();
    _persistTags();
    _persistAttachments();
    _persistRecurringRules();
    _persistBudgets();
    _persistCategoryBudgets();
    _persistDailyBudgets();
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

  void _loadAssetSectionCollapsed() {
    final rawCollapsed = _store.read(_assetSectionCollapsedKey);
    if (rawCollapsed == null || rawCollapsed.isEmpty) {
      return;
    }
    try {
      _collapsedAssetSections
        ..clear()
        ..addAll(_decodeStringSet(jsonDecode(rawCollapsed)));
    } catch (_) {
      _store.delete(_assetSectionCollapsedKey);
    }
  }

  void _loadAssetAccountOrders() {
    final rawOrders = _store.read(_assetAccountOrderKey);
    if (rawOrders == null || rawOrders.isEmpty) {
      return;
    }
    try {
      _assetAccountOrders
        ..clear()
        ..addAll(_decodeStringListMap(jsonDecode(rawOrders)));
    } catch (_) {
      _store.delete(_assetAccountOrderKey);
    }
  }

  void _loadAssetSectionOrders() {
    final rawOrders = _store.read(_assetSectionOrderKey);
    if (rawOrders == null || rawOrders.isEmpty) {
      return;
    }
    try {
      _assetSectionOrders
        ..clear()
        ..addAll(_decodeStringListMap(jsonDecode(rawOrders)));
    } catch (_) {
      _store.delete(_assetSectionOrderKey);
    }
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

  /// 等待挂起的 SQLite 写入落库（仅测试使用）。
  @visibleForTesting
  Future<void> waitForPendingWrites() => _pendingWrite;

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

  @override
  void dispose() {
    themePreferenceListenable.dispose();
    localePreferenceListenable.dispose();
    super.dispose();
  }
}

bool _isProtectedCategory(String categoryId) {
  return categoryId == 'balance_adjust_expense' ||
      categoryId == 'balance_adjust_income';
}

String _monthKey(DateTime month) {
  return '${month.year}-${month.month.toString().padLeft(2, '0')}';
}

String _assetSectionKey(
  String bookId,
  AssetAccountViewMode mode,
  String sectionId,
) {
  return '$bookId:${mode.name}:$sectionId';
}

String _assetSectionOrderKeyForMode(String bookId, AssetAccountViewMode mode) {
  return '$bookId:${mode.name}';
}

int _defaultAccountCompare(Account a, Account b) {
  final hiddenCompare = (a.hidden ? 1 : 0).compareTo(b.hidden ? 1 : 0);
  if (hiddenCompare != 0) {
    return hiddenCompare;
  }
  final includeCompare = (b.includeInAssets ? 1 : 0).compareTo(
    a.includeInAssets ? 1 : 0,
  );
  if (includeCompare != 0) {
    return includeCompare;
  }
  final typeCompare = a.type.index.compareTo(b.type.index);
  if (typeCompare != 0) {
    return typeCompare;
  }
  return a.name.compareTo(b.name);
}

Set<String> _decodeStringSet(Object? value) {
  if (value == null) {
    return <String>{};
  }
  if (value is! List) {
    throw const FormatException('折叠数据格式不正确');
  }
  return value.whereType<String>().toSet();
}

Map<String, List<String>> _decodeStringListMap(Object? value) {
  if (value == null) {
    return <String, List<String>>{};
  }
  if (value is! Map) {
    throw const FormatException('排序数据格式不正确');
  }
  return Map<String, Object?>.from(value).map((key, rawList) {
    if (rawList is! List) {
      return MapEntry(key, <String>[]);
    }
    return MapEntry(key, rawList.whereType<String>().toList());
  });
}

String _categoryBudgetKey(String bookId, DateTime month, String categoryId) {
  return '$bookId:${_monthKey(month)}:$categoryId';
}

/// 预算键按账本隔离,格式为 `bookId:yyyy-MM[:categoryId]`。
/// 旧版本数据没有 bookId 前缀,加载/导入时归入默认账本。
Map<String, double> _bookScopedBudgets(Map<String, double> raw) {
  final legacyKey = RegExp(r'^\d{4}-\d{2}(:|$)');
  return raw.map(
    (key, value) => MapEntry(
      legacyKey.hasMatch(key) ? '$defaultLedgerBookId:$key' : key,
      value,
    ),
  );
}

List<T> _decodeModelList<T>(
  Object? value,
  T Function(Map<String, Object?> json) fromJson,
) {
  if (value == null) {
    return <T>[];
  }
  if (value is! List) {
    throw const FormatException('备份列表格式不正确');
  }
  return value.map((item) {
    if (item is! Map) {
      throw const FormatException('备份条目格式不正确');
    }
    return fromJson(Map<String, Object?>.from(item));
  }).toList();
}

List<PagePanelSetting> _defaultPanelSettings(List<PagePanelSpec> specs) {
  return specs
      .map((spec) => PagePanelSetting(id: spec.id, enabled: true))
      .toList();
}

/// 面板设置归一化:丢弃目录外的 id 并去重,目录新增的面板默认追加为开启;
/// 若结果全部关闭则强制开启第一个,保证页面至少保留一个面板。
List<PagePanelSetting> _normalizePanelSettings(
  List<PagePanelSetting> stored,
  List<PagePanelSpec> specs,
) {
  final specIds = <String>{for (final spec in specs) spec.id};
  final seen = <String>{};
  final result = <PagePanelSetting>[
    for (final item in stored)
      if (specIds.contains(item.id) && seen.add(item.id)) item,
  ];
  for (final spec in specs) {
    if (seen.add(spec.id)) {
      result.add(PagePanelSetting(id: spec.id, enabled: true));
    }
  }
  if (result.every((item) => !item.enabled)) {
    result[0] = result[0].copyWith(enabled: true);
  }
  return result;
}

Map<String, double> _decodeBudgets(Object? value) {
  if (value == null) {
    return <String, double>{};
  }
  if (value is! Map) {
    throw const FormatException('预算数据格式不正确');
  }
  return Map<String, Object?>.from(
    value,
  ).map((key, rawAmount) => MapEntry(key, (rawAmount as num? ?? 0).toDouble()));
}
