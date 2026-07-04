import 'package:flutter/material.dart';

enum EntryType {
  expense,
  income,
  transfer;

  String get label {
    switch (this) {
      case EntryType.expense:
        return '支出';
      case EntryType.income:
        return '收入';
      case EntryType.transfer:
        return '转账';
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

  String get label {
    switch (this) {
      case ThemePreference.system:
        return '跟随系统';
      case ThemePreference.light:
        return '浅色';
      case ThemePreference.dark:
        return '深色';
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

enum AccountType {
  onlinePayment,
  creditCard,
  debitCard,
  investment,
  cash;

  String get label {
    switch (this) {
      case AccountType.onlinePayment:
        return '网络支付';
      case AccountType.creditCard:
        return '信用卡';
      case AccountType.debitCard:
        return '储蓄卡';
      case AccountType.investment:
        return '投资账户';
      case AccountType.cash:
        return '现金';
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

  String get label {
    switch (this) {
      case AssetAccountViewMode.group:
        return '分类视图';
      case AssetAccountViewMode.type:
        return '类型视图';
    }
  }

  String get toggleLabel {
    switch (this) {
      case AssetAccountViewMode.group:
        return '切换为类型视图';
      case AssetAccountViewMode.type:
        return '切换为分类视图';
    }
  }

  static AssetAccountViewMode fromStorage(String? value) {
    return AssetAccountViewMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AssetAccountViewMode.type,
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

  String get label {
    switch (this) {
      case ProfileGender.unset:
        return '不设置';
      case ProfileGender.male:
        return '男';
      case ProfileGender.female:
        return '女';
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

  String get label {
    switch (this) {
      case PanelPageKind.home:
        return '首页';
      case PanelPageKind.reports:
        return '看板';
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

/// 面板目录项:id 是持久化标识,名称与描述用于面板管理页展示。
class PagePanelSpec {
  const PagePanelSpec({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

const List<PagePanelSpec> homePanelSpecs = <PagePanelSpec>[
  PagePanelSpec(id: 'trend', label: '支出走势', description: '按 7 天周期展示支出趋势与结余'),
  PagePanelSpec(id: 'recent', label: '最近交易', description: '展示最近 5 条交易记录'),
  PagePanelSpec(id: 'budget', label: '月度预算', description: '本月预算进度与分类超支提醒'),
  PagePanelSpec(id: 'calendar', label: '日历', description: '按日历查看每天的收支情况'),
];

const List<PagePanelSpec> reportPanelSpecs = <PagePanelSpec>[
  PagePanelSpec(
    id: 'budget_execution',
    label: '预算执行',
    description: '本月预算、支出与分类预算执行情况',
  ),
  PagePanelSpec(id: 'category_ring', label: '分类统计', description: '本月支出分类占比环形图'),
  PagePanelSpec(id: 'category_rank', label: '分类明细', description: '本月支出分类排行与占比'),
  PagePanelSpec(id: 'daily_trend', label: '日趋势', description: '近 7 天每日支出趋势'),
  PagePanelSpec(
    id: 'monthly_structure',
    label: '月度收支',
    description: '今年每月支出结构柱状图',
  ),
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
  });

  final String id;
  final String label;
  final EntryType type;
  final String iconCode;

  Category copyWith({
    String? id,
    String? label,
    EntryType? type,
    String? iconCode,
  }) {
    return Category(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      iconCode: iconCode ?? this.iconCode,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'type': type.storageValue,
      'iconCode': iconCode,
    };
  }

  static Category fromJson(Map<String, Object?> json) {
    return Category(
      id: json['id'] as String,
      label: json['label'] as String? ?? '未命名分类',
      type: EntryType.fromStorage(json['type'] as String? ?? 'expense'),
      iconCode: json['iconCode'] as String? ?? 'category',
    );
  }
}
