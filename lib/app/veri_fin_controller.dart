import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;

import '../data/ledger_repository.dart';
import '../local_storage/local_storage.dart';
import 'ai/ai_settings.dart';
import 'app_lock.dart';
import 'backup/backup_settings.dart';
import 'backup/payment_import.dart';
import 'backup/transaction_import.dart';
import 'backup/webdav_config.dart';
import 'budget_cycle.dart';
import 'category_tree.dart';
import 'demo_data.dart';
import 'model_lookup.dart';
import 'amount_format.dart' as amount_format;
import 'home_metrics.dart';
import 'ledger_math.dart';
import 'logging/app_logger.dart';
import 'models.dart';
import 'recurring.dart';
import 'reminder/reminder_settings.dart';

part 'veri_fin_controller_state.dart';
part 'veri_fin_controller_ops.dart';

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

// 偏好类 KV 键（库级私有以便各 part 共享）。全部 `verifin.*.v1` 键集中在此，
// 仅两处例外：软件日志 `verifin.logs.v1`（logging/app_logger.dart，自管读写）；
// 应用锁 `verifin.app_lock.v1` 的哈希格式在 app_lock.dart、键仍在下表。
// 新增偏好键一律加进本表，并确认「初始化清除/备份豁免」清单是否需要覆盖它。
const String _themeKey = 'verifin.theme.v1';
const String _localeKey = 'verifin.locale.v1';
const String _profileKey = 'verifin.profile.v1';
const String _activeBookKey = 'verifin.active_book.v1';
const String _assetCoverKey = 'verifin.asset_cover.v1';
const String _hapticsKey = 'verifin.haptics.v1';
const String _privacyConsentKey = 'verifin.privacy_consent.v1';
const String _appLockKey = 'verifin.app_lock.v1';
const String _assetViewModeKey = 'verifin.asset_view_mode.v1';
const String _assetSectionCollapsedKey = 'verifin.asset_section_collapsed.v1';
const String _assetAccountOrderKey = 'verifin.asset_account_order.v1';
const String _assetSectionOrderKey = 'verifin.asset_section_order.v1';
const String _homePanelsKey = 'verifin.home_panels.v1';
const String _reportPanelsKey = 'verifin.report_panels.v1';
const String _backupSettingsKey = 'verifin.backup_settings.v1';
const String _backupPassphraseKey = 'verifin.backup_passphrase.v1';
const String _webdavKey = 'verifin.webdav.v1';
const String _reminderKey = 'verifin.reminder.v1';
const String _fabActionKey = 'verifin.fab_action.v1';
const String _defaultAccountKey = 'verifin.default_account.v1';
const String _budgetCycleKey = 'verifin.budget_cycle.v1';
const String _amountFormatKey = 'verifin.amount_format.v1';
const String _aiSettingsKey = 'verifin.ai.v1';
const String _aiChatHistoryKey = 'verifin.ai_chat.v1';
const String _homeTrendKey = 'verifin.home_metrics.v1';
const String _onboardingKey = 'verifin.onboarding.v1';

String _panelsKeyFor(PanelPageKind page) {
  switch (page) {
    case PanelPageKind.home:
      return _homePanelsKey;
    case PanelPageKind.reports:
      return _reportPanelsKey;
  }
}

/// 交易列表排序：时间倒序（原为类静态方法，改为库级以便 part 共享）。
int _compareEntriesLatestFirst(LedgerEntry a, LedgerEntry b) {
  final byDate = b.occurredAt.compareTo(a.occurredAt);
  if (byDate != 0) {
    return byDate;
  }
  return b.id.compareTo(a.id);
}

/// 记账后回调（新增交易时触发），供自动备份「每次记账后」挂钩。
/// 由应用根组件注入，控制器本身不做文件 I/O，测试宿主保持为空。

class VeriFinController extends ChangeNotifier
    with _ControllerState, _ControllerOps {
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

  @override
  final LocalKeyValueStore _store;
  @override
  final LedgerRepository _repository;
  @override
  final AppLogger? _logger;
  @override
  final bool _systemIsEnglish;

  /// 软件日志入口，供「软件日志」页读取；未注入时为 null。
  AppLogger? get logger => _logger;

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

/// 解码 AI 聊天记录（`[{role, content, displays?}, …]`）；损坏数据回退空列表。
/// `displays` 为结果卡片的 JSON 列表（[AiResultDisplay] 序列化），原样保留供聊天页还原。
List<Map<String, Object?>> _decodeChatHistory(String? raw) {
  if (raw == null || raw.isEmpty) {
    return <Map<String, Object?>>[];
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) {
            final displays = item['displays'];
            return <String, Object?>{
              'role': item['role']?.toString() ?? 'user',
              'content': item['content']?.toString() ?? '',
              if (displays is List)
                'displays': displays
                    .whereType<Map>()
                    .map((d) => Map<String, Object?>.from(d))
                    .toList(),
            };
          })
          .where(
            (m) =>
                (m['content']! as String).isNotEmpty ||
                (m['displays'] as List?)?.isNotEmpty == true,
          )
          .toList();
    }
  } catch (_) {
    // 损坏记录忽略。
  }
  return <Map<String, Object?>>[];
}

String _categoryBudgetKey(String bookId, DateTime month, String categoryId) {
  return '$bookId:${_monthKey(month)}:$categoryId';
}

/// 「默认预算」的哨兵月段：默认月/分类预算存在预算表的 `bookId:default[:catId]`
/// 键上。逐月键恒为 `yyyy-MM`（纯数字），故 `default` 与任何真实月份天然不冲突，
/// 也无需改表结构或迁移；账本删除（`startsWith('bookId:')`）与分类删除/合并
/// （`endsWith(':catId')`）的清理规则对默认键同样生效。
const String _budgetDefaultMonthSegment = 'default';

String _defaultMonthlyBudgetKey(String bookId) =>
    '$bookId:$_budgetDefaultMonthSegment';

String _defaultCategoryBudgetKey(String bookId, String categoryId) =>
    '$bookId:$_budgetDefaultMonthSegment:$categoryId';

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
