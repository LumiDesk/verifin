import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum EntryType {
  expense,
  income,
  transfer;

  String label(AppLocalizations l10n) {
    switch (this) {
      case EntryType.expense:
        return l10n.entryTypeExpense;
      case EntryType.income:
        return l10n.entryTypeIncome;
      case EntryType.transfer:
        return l10n.entryTypeTransfer;
    }
  }

  String get storageValue {
    switch (this) {
      case EntryType.expense:
        return 'expense';
      case EntryType.income:
        return 'income';
      case EntryType.transfer:
        return 'transfer';
    }
  }

  static EntryType fromStorage(String value) {
    return EntryType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => EntryType.expense,
    );
  }
}

enum ThemePreference {
  system,
  light,
  dark;

  String label(AppLocalizations l10n) {
    switch (this) {
      case ThemePreference.system:
        return l10n.themeSystem;
      case ThemePreference.light:
        return l10n.themeLight;
      case ThemePreference.dark:
        return l10n.themeDark;
    }
  }

  ThemeMode get themeMode {
    switch (this) {
      case ThemePreference.system:
        return ThemeMode.system;
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  static ThemePreference fromStorage(String? value) {
    return ThemePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => ThemePreference.system,
    );
  }
}

/// 应用语言偏好：跟随系统或固定某一语言。设备本地偏好（存 KV），
/// 不进 JSON 备份，初始化数据时保留。
enum LocalePreference {
  system,
  zh,
  en;

  /// 固定语言时返回对应 locale；跟随系统返回 null（交给系统解析）。
  Locale? get locale {
    switch (this) {
      case LocalePreference.system:
        return null;
      case LocalePreference.zh:
        return const Locale('zh');
      case LocalePreference.en:
        return const Locale('en');
    }
  }

  /// 语言选项显示名：具体语言恒用其母语名，跟随系统随当前语言。
  String label(AppLocalizations l10n) {
    switch (this) {
      case LocalePreference.system:
        return l10n.localeFollowSystem;
      case LocalePreference.zh:
        return '简体中文';
      case LocalePreference.en:
        return 'English';
    }
  }

  static LocalePreference fromStorage(String? value) {
    return LocalePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => LocalePreference.system,
    );
  }
}

enum AccountType {
  onlinePayment,
  creditCard,
  debitCard,
  investment,
  cash;

  String label(AppLocalizations l10n) {
    switch (this) {
      case AccountType.onlinePayment:
        return l10n.accountTypeOnlinePayment;
      case AccountType.creditCard:
        return l10n.accountTypeCreditCard;
      case AccountType.debitCard:
        return l10n.accountTypeDebitCard;
      case AccountType.investment:
        return l10n.accountTypeInvestment;
      case AccountType.cash:
        return l10n.accountTypeCash;
    }
  }

  static AccountType fromStorage(String? value) {
    return AccountType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => AccountType.onlinePayment,
    );
  }

  bool get supportsCardLast4 {
    return this == AccountType.creditCard || this == AccountType.debitCard;
  }
}

enum AssetAccountViewMode {
  group,
  type;

  String label(AppLocalizations l10n) {
    switch (this) {
      case AssetAccountViewMode.group:
        return l10n.assetViewGroup;
      case AssetAccountViewMode.type:
        return l10n.assetViewType;
    }
  }

  String toggleLabel(AppLocalizations l10n) {
    switch (this) {
      case AssetAccountViewMode.group:
        return l10n.assetViewToggleToType;
      case AssetAccountViewMode.type:
        return l10n.assetViewToggleToGroup;
    }
  }

  static AssetAccountViewMode fromStorage(String? value) {
    return AssetAccountViewMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AssetAccountViewMode.type,
    );
  }
}

/// 首页 FAB（记一笔）点击后的行为：手动记账（默认）或 AI 对话记账。
enum FabActionMode {
  manual,
  ai;

  String label(AppLocalizations l10n) {
    switch (this) {
      case FabActionMode.manual:
        return l10n.fabModeManual;
      case FabActionMode.ai:
        return l10n.fabModeAi;
    }
  }

  static FabActionMode fromStorage(String? value) {
    return FabActionMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => FabActionMode.manual,
    );
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.bookId,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    required this.note,
    required this.occurredAt,
    this.tagIds = const <String>[],
    this.fee = 0,
    this.reimbursable = false,
    this.refundedAmount = 0,
  });

  final String id;
  final String bookId;
  final EntryType type;
  final double amount;
  final String categoryId;
  final String accountId;
  final String? toAccountId;
  final String note;
  final DateTime occurredAt;

  /// 该交易关联的标签 id 列表（多对多，可为空）。
  final List<String> tagIds;

  /// 转账手续费（仅 [EntryType.transfer] 有意义），由转出账户承担；
  /// 转出账户余额额外减少该金额，转入账户不变。
  final double fee;

  /// 是否标记为「待报销」（仅支出有意义）。仅作标记，不影响金额；
  /// 报销/退款到账通过 [refundedAmount] 冲抵原交易。
  final bool reimbursable;

  /// 已被退款 / 报销回款冲抵的金额（仅支出有意义，回到原账户）。
  /// 统计与账户余额都按「金额 − 已冲抵」的净额计算。
  final double refundedAmount;

  /// 净支出额（原金额减去已退款/报销回款）。非支出返回原金额。
  double get netAmount =>
      type == EntryType.expense ? amount - refundedAmount : amount;

  LedgerEntry copyWith({
    String? id,
    String? bookId,
    EntryType? type,
    double? amount,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    bool clearToAccountId = false,
    String? note,
    DateTime? occurredAt,
    List<String>? tagIds,
    double? fee,
    bool? reimbursable,
    double? refundedAmount,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: clearToAccountId ? null : toAccountId ?? this.toAccountId,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      tagIds: tagIds ?? this.tagIds,
      fee: fee ?? this.fee,
      reimbursable: reimbursable ?? this.reimbursable,
      refundedAmount: refundedAmount ?? this.refundedAmount,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'type': type.storageValue,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'note': note,
      'occurredAt': occurredAt.toIso8601String(),
      if (tagIds.isNotEmpty) 'tagIds': tagIds,
      if (fee != 0) 'fee': fee,
      if (reimbursable) 'reimbursable': true,
      if (refundedAmount != 0) 'refundedAmount': refundedAmount,
    };
  }

  static LedgerEntry fromJson(Map<String, Object?> json) {
    return LedgerEntry(
      id: json['id'] as String,
      bookId: json['bookId'] as String? ?? defaultLedgerBookId,
      type: EntryType.fromStorage(json['type'] as String? ?? 'expense'),
      amount: (json['amount'] as num).toDouble(),
      categoryId: json['categoryId'] as String? ?? 'dining',
      accountId: json['accountId'] as String? ?? 'alipay',
      toAccountId: json['toAccountId'] as String?,
      note: json['note'] as String? ?? '',
      occurredAt:
          DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
          DateTime.now(),
      tagIds: _stringList(json['tagIds']),
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      reimbursable: json['reimbursable'] as bool? ?? false,
      refundedAmount: (json['refundedAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList(growable: false);
  }
  return const <String>[];
}

/// 周期记账频率。
enum RecurringFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurringFrequency(this.storageValue);

  final String storageValue;

  String label(AppLocalizations l10n) {
    switch (this) {
      case RecurringFrequency.daily:
        return l10n.recurringDaily;
      case RecurringFrequency.weekly:
        return l10n.recurringWeekly;
      case RecurringFrequency.monthly:
        return l10n.recurringMonthly;
      case RecurringFrequency.yearly:
        return l10n.recurringYearly;
    }
  }

  static RecurringFrequency fromStorage(String? value) {
    return RecurringFrequency.values.firstWhere(
      (f) => f.storageValue == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }
}

/// 周期记账规则：按频率自动补记交易（如房租、工资）。规则本身带 [bookId]，
/// 生成的交易落入同一账本；[nextRunDate] 为下一次应生成的日期。
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.bookId,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    required this.note,
    required this.frequency,
    required this.startDate,
    required this.nextRunDate,
    this.active = true,
  });

  final String id;
  final String bookId;
  final EntryType type;
  final double amount;
  final String categoryId;
  final String accountId;
  final String? toAccountId;
  final String note;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextRunDate;
  final bool active;

  RecurringRule copyWith({
    String? note,
    double? amount,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    bool clearToAccountId = false,
    EntryType? type,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? nextRunDate,
    bool? active,
  }) {
    return RecurringRule(
      id: id,
      bookId: bookId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: clearToAccountId ? null : toAccountId ?? this.toAccountId,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextRunDate: nextRunDate ?? this.nextRunDate,
      active: active ?? this.active,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'type': type.storageValue,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'note': note,
      'frequency': frequency.storageValue,
      'startDate': startDate.toIso8601String(),
      'nextRunDate': nextRunDate.toIso8601String(),
      'active': active,
    };
  }

  static RecurringRule fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return RecurringRule(
      id: json['id'] as String,
      bookId: json['bookId'] as String? ?? defaultLedgerBookId,
      type: EntryType.fromStorage(json['type'] as String? ?? 'expense'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      categoryId: json['categoryId'] as String? ?? 'dining',
      accountId: json['accountId'] as String? ?? '',
      toAccountId: json['toAccountId'] as String?,
      note: json['note'] as String? ?? '',
      frequency: RecurringFrequency.fromStorage(json['frequency'] as String?),
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ?? now,
      nextRunDate:
          DateTime.tryParse(json['nextRunDate'] as String? ?? '') ?? now,
      active: json['active'] as bool? ?? true,
    );
  }
}

/// 交易的图片附件（如票据）。以压缩后的 JPEG data URL 存储在独立表中，
/// 不放进 entries 表，避免整表覆盖式写入放大；数据落在应用私有的 SQLite 内。
class Attachment {
  const Attachment({
    required this.id,
    required this.entryId,
    required this.dataUrl,
  });

  final String id;
  final String entryId;

  /// `data:image/jpeg;base64,...` 形式的图片，移动端用内存图片渲染。
  final String dataUrl;

  Attachment copyWith({String? id, String? entryId, String? dataUrl}) {
    return Attachment(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      dataUrl: dataUrl ?? this.dataUrl,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'entryId': entryId, 'dataUrl': dataUrl};
  }

  static Attachment fromJson(Map<String, Object?> json) {
    return Attachment(
      id: json['id'] as String,
      entryId: json['entryId'] as String? ?? '',
      dataUrl: json['dataUrl'] as String? ?? '',
    );
  }
}

/// 标签：与交易多对多关联，用于跨分类的横向归类与统计。
class Tag {
  const Tag({required this.id, required this.label});

  final String id;
  final String label;

  Tag copyWith({String? id, String? label}) {
    return Tag(id: id ?? this.id, label: label ?? this.label);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'label': label};
  }

  static Tag fromJson(Map<String, Object?> json) {
    return Tag(
      id: json['id'] as String,
      label: json['label'] as String? ?? '未命名标签',
    );
  }
}

const String defaultLedgerBookId = 'default';

class LedgerBook {
  const LedgerBook({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isDefault,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isDefault;

  LedgerBook copyWith({String? id, String? name, DateTime? createdAt}) {
    return LedgerBook(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isDefault': isDefault,
    };
  }

  static LedgerBook fromJson(Map<String, Object?> json) {
    final id = json['id'] as String? ?? defaultLedgerBookId;
    return LedgerBook(
      id: id,
      name: json['name'] as String? ?? '日常账本',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isDefault: json['isDefault'] as bool? ?? id == defaultLedgerBookId,
    );
  }
}

class Account {
  const Account({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.groupId,
    required this.initialBalance,
    required this.iconCode,
    required this.note,
    required this.includeInAssets,
    required this.hidden,
    this.cardLast4 = '',
    this.statementDay,
    this.dueDay,
  });

  final String id;
  final String bookId;
  final String name;
  final AccountType type;
  final String? groupId;
  final double initialBalance;
  final String iconCode;
  final String note;
  final bool includeInAssets;
  final bool hidden;
  final String cardLast4;

  /// 信用卡账单日（每月 1–28，可选）。花呗类用户可不设置。
  final int? statementDay;

  /// 信用卡还款日（每月 1–28，可选）。设置后展示还款提醒。
  final int? dueDay;

  Account copyWith({
    String? id,
    String? bookId,
    String? name,
    AccountType? type,
    String? groupId,
    double? initialBalance,
    String? iconCode,
    String? note,
    bool? includeInAssets,
    bool? hidden,
    String? cardLast4,
    int? statementDay,
    bool clearStatementDay = false,
    int? dueDay,
    bool clearDueDay = false,
  }) {
    return Account(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      groupId: groupId ?? this.groupId,
      initialBalance: initialBalance ?? this.initialBalance,
      iconCode: iconCode ?? this.iconCode,
      note: note ?? this.note,
      includeInAssets: includeInAssets ?? this.includeInAssets,
      hidden: hidden ?? this.hidden,
      cardLast4: cardLast4 ?? this.cardLast4,
      statementDay: clearStatementDay
          ? null
          : statementDay ?? this.statementDay,
      dueDay: clearDueDay ? null : dueDay ?? this.dueDay,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'name': name,
      'type': type.name,
      'groupId': groupId,
      'initialBalance': initialBalance,
      'iconCode': iconCode,
      'note': note,
      'includeInAssets': includeInAssets,
      'hidden': hidden,
      'cardLast4': cardLast4,
      if (statementDay != null) 'statementDay': statementDay,
      if (dueDay != null) 'dueDay': dueDay,
    };
  }

  static Account fromJson(Map<String, Object?> json) {
    return Account(
      id: json['id'] as String,
      bookId: json['bookId'] as String? ?? defaultLedgerBookId,
      name: json['name'] as String? ?? '未命名账户',
      type: AccountType.fromStorage(json['type'] as String?),
      groupId: json['groupId'] as String?,
      initialBalance: (json['initialBalance'] as num? ?? 0).toDouble(),
      iconCode: json['iconCode'] as String? ?? 'wallet',
      note: json['note'] as String? ?? '',
      includeInAssets: json['includeInAssets'] as bool? ?? true,
      hidden: json['hidden'] as bool? ?? false,
      cardLast4: json['cardLast4'] as String? ?? '',
      statementDay: (json['statementDay'] as num?)?.toInt(),
      dueDay: (json['dueDay'] as num?)?.toInt(),
    );
  }
}

class AccountGroup {
  const AccountGroup({
    required this.id,
    required this.bookId,
    required this.name,
    required this.iconCode,
    required this.sortOrder,
  });

  final String id;
  final String bookId;
  final String name;
  final String iconCode;
  final int sortOrder;

  AccountGroup copyWith({
    String? id,
    String? bookId,
    String? name,
    String? iconCode,
    int? sortOrder,
  }) {
    return AccountGroup(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'name': name,
      'iconCode': iconCode,
      'sortOrder': sortOrder,
    };
  }

  static AccountGroup fromJson(Map<String, Object?> json) {
    return AccountGroup(
      id: json['id'] as String,
      bookId: json['bookId'] as String? ?? defaultLedgerBookId,
      name: json['name'] as String? ?? '未命名分组',
      iconCode: json['iconCode'] as String? ?? 'folder',
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

enum ProfileGender {
  unset,
  male,
  female;

  String label(AppLocalizations l10n) {
    switch (this) {
      case ProfileGender.unset:
        return l10n.genderUnset;
      case ProfileGender.male:
        return l10n.genderMale;
      case ProfileGender.female:
        return l10n.genderFemale;
    }
  }

  static ProfileGender fromStorage(String? value) {
    return ProfileGender.values.firstWhere(
      (gender) => gender.name == value,
      orElse: () => ProfileGender.unset,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.nickname,
    required this.bio,
    required this.avatarDataUrl,
    this.gender = ProfileGender.unset,
    this.birthday = '',
    this.city = '',
    this.occupation = '',
  });

  final String nickname;
  final String bio;
  final String avatarDataUrl;
  final ProfileGender gender;
  final String birthday;
  final String city;
  final String occupation;

  UserProfile copyWith({
    String? nickname,
    String? bio,
    String? avatarDataUrl,
    ProfileGender? gender,
    String? birthday,
    String? city,
    String? occupation,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      avatarDataUrl: avatarDataUrl ?? this.avatarDataUrl,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      city: city ?? this.city,
      occupation: occupation ?? this.occupation,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nickname': nickname,
      'bio': bio,
      'avatarDataUrl': avatarDataUrl,
      'gender': gender.name,
      'birthday': birthday,
      'city': city,
      'occupation': occupation,
    };
  }

  static UserProfile fromJson(Map<String, Object?> json) {
    return UserProfile(
      nickname: json['nickname'] as String? ?? 'Veri Fin',
      bio: json['bio'] as String? ?? '完全免费 · 数据自主',
      avatarDataUrl: json['avatarDataUrl'] as String? ?? '',
      gender: ProfileGender.fromStorage(json['gender'] as String?),
      birthday: json['birthday'] as String? ?? '',
      city: json['city'] as String? ?? '',
      occupation: json['occupation'] as String? ?? '',
    );
  }
}

/// 支持面板管理的主页面。
enum PanelPageKind {
  home,
  reports;

  String label(AppLocalizations l10n) {
    switch (this) {
      case PanelPageKind.home:
        return l10n.tabHome;
      case PanelPageKind.reports:
        return l10n.tabReports;
    }
  }

  List<PagePanelSpec> get specs {
    switch (this) {
      case PanelPageKind.home:
        return homePanelSpecs;
      case PanelPageKind.reports:
        return reportPanelSpecs;
    }
  }
}

/// 面板目录项:id 是持久化标识,名称与描述按 id 从 ARB 解析,用于面板管理页展示。
class PagePanelSpec {
  const PagePanelSpec({required this.id});

  final String id;

  String label(AppLocalizations l10n) {
    switch (id) {
      case 'trend':
        return l10n.panelTrendLabel;
      case 'recent':
        return l10n.panelRecentLabel;
      case 'budget':
        return l10n.panelBudgetLabel;
      case 'calendar':
        return l10n.calendarTitle;
      case 'budget_execution':
        return l10n.panelBudgetExecutionLabel;
      case 'category_ring':
        return l10n.panelCategoryRingLabel;
      case 'category_rank':
        return l10n.panelCategoryRankLabel;
      case 'tag_stats':
        return l10n.panelTagStatsLabel;
      case 'daily_trend':
        return l10n.panelDailyTrendLabel;
      case 'monthly_structure':
        return l10n.panelMonthlyStructureLabel;
    }
    return id;
  }

  String description(AppLocalizations l10n) {
    switch (id) {
      case 'trend':
        return l10n.panelTrendDesc;
      case 'recent':
        return l10n.panelRecentDesc;
      case 'budget':
        return l10n.panelBudgetDesc;
      case 'calendar':
        return l10n.panelCalendarDesc;
      case 'budget_execution':
        return l10n.panelBudgetExecutionDesc;
      case 'category_ring':
        return l10n.panelCategoryRingDesc;
      case 'category_rank':
        return l10n.panelCategoryRankDesc;
      case 'tag_stats':
        return l10n.panelTagStatsDesc;
      case 'daily_trend':
        return l10n.panelDailyTrendDesc;
      case 'monthly_structure':
        return l10n.panelMonthlyStructureDesc;
    }
    return '';
  }
}

const List<PagePanelSpec> homePanelSpecs = <PagePanelSpec>[
  PagePanelSpec(id: 'trend'),
  PagePanelSpec(id: 'recent'),
  PagePanelSpec(id: 'budget'),
  PagePanelSpec(id: 'calendar'),
];

const List<PagePanelSpec> reportPanelSpecs = <PagePanelSpec>[
  PagePanelSpec(id: 'budget_execution'),
  PagePanelSpec(id: 'category_ring'),
  PagePanelSpec(id: 'category_rank'),
  PagePanelSpec(id: 'tag_stats'),
  PagePanelSpec(id: 'daily_trend'),
  PagePanelSpec(id: 'monthly_structure'),
];

/// 页面面板的开关状态,列表顺序即页面渲染顺序。
class PagePanelSetting {
  const PagePanelSetting({required this.id, required this.enabled});

  final String id;
  final bool enabled;

  PagePanelSetting copyWith({bool? enabled}) {
    return PagePanelSetting(id: id, enabled: enabled ?? this.enabled);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'enabled': enabled};
  }

  static PagePanelSetting fromJson(Map<String, Object?> json) {
    return PagePanelSetting(
      id: json['id'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.label,
    required this.type,
    required this.iconCode,
    this.parentId,
  });

  final String id;
  final String label;
  final EntryType type;
  final String iconCode;

  /// 父分类 id；`null` 表示顶级分类。子分类与父分类的 [type] 必须一致。
  /// 支持任意层级树形结构（多级分类）。
  final String? parentId;

  /// 是否为顶级分类。
  bool get isRoot => parentId == null;

  Category copyWith({
    String? id,
    String? label,
    EntryType? type,
    String? iconCode,
    // 使用哨兵区分「未传入」与「显式置空」，以便把子分类移动到顶级。
    Object? parentId = _copyWithSentinel,
  }) {
    return Category(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      iconCode: iconCode ?? this.iconCode,
      parentId: identical(parentId, _copyWithSentinel)
          ? this.parentId
          : parentId as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'type': type.storageValue,
      'iconCode': iconCode,
      if (parentId != null) 'parentId': parentId,
    };
  }

  static Category fromJson(Map<String, Object?> json) {
    final rawParent = json['parentId'] as String?;
    return Category(
      id: json['id'] as String,
      label: json['label'] as String? ?? '未命名分类',
      type: EntryType.fromStorage(json['type'] as String? ?? 'expense'),
      iconCode: json['iconCode'] as String? ?? 'category',
      parentId: (rawParent != null && rawParent.isEmpty) ? null : rawParent,
    );
  }
}

const Object _copyWithSentinel = Object();
