/// 账户域模型：账户类型（能力矩阵见 docs/dev/tech-decisions.md）、账户与分组。
library;

import '../../l10n/app_localizations.dart';

import 'ledger_book.dart';
import 'currency.dart';

enum AccountType {
  onlinePayment,
  // 信用账户：花呗 / 白条等有额度、账单日、还款、但无实体卡号的信用类账户。
  // 放在网络支付与信用卡之间。能力矩阵见 docs/dev/tech-decisions.md「账户类型能力矩阵」。
  creditAccount,
  creditCard,
  debitCard,
  investment,
  cash;

  String label(AppLocalizations l10n) {
    switch (this) {
      case AccountType.onlinePayment:
        return l10n.accountTypeOnlinePayment;
      case AccountType.creditAccount:
        return l10n.accountTypeCreditAccount;
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

  String capabilityHint(AppLocalizations l10n) {
    if (supportsCardLast4 && supportsCredit) {
      return l10n.accountTypeCardCreditHint;
    }
    if (supportsCardLast4) {
      return l10n.accountTypeCardHint;
    }
    if (supportsCredit) {
      return l10n.accountTypeCreditHint;
    }
    return l10n.accountTypeBasicHint;
  }

  static AccountType fromStorage(String? value) {
    return AccountType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => AccountType.onlinePayment,
    );
  }

  /// 是否有实体卡号（完整卡号 + 后四位）：信用卡、储蓄卡。
  bool get supportsCardLast4 {
    return this == AccountType.creditCard || this == AccountType.debitCard;
  }

  /// 是否为信用类账户，支持额度 / 账单日 / 还款日 / 还款：信用卡、信用账户。
  bool get supportsCredit {
    return this == AccountType.creditCard || this == AccountType.creditAccount;
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
    this.currencyCode = defaultCurrencyCode,
    this.cardLast4 = '',
    this.cardNumber = '',
    this.cardLast4Follows = true,
    this.creditLimit,
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
  final String currencyCode;
  final String cardLast4;

  /// 完整卡号（选填，仅信用卡/储蓄卡 supportsCardLast4）。列表/首页仍只展示后四位，
  /// 详情页可展示完整卡号并一键复制。
  final String cardNumber;

  /// 「后四位跟随完整卡号」开关，持久化（落库 + 进备份），忠实还原用户选择、不再靠反推。
  /// true：后四位自动取 cardNumber 末四位（`cardLast4Of`），编辑页只读；false：后四位可手填、
  /// 独立于完整卡号。新账户默认 true；仅信用卡/储蓄卡有意义。
  final bool cardLast4Follows;

  /// 信用额度上限（选填，仅信用卡/信用账户 supportsCredit）。设置后展示已用/可用额度。
  final double? creditLimit;

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
    String? currencyCode,
    String? cardLast4,
    String? cardNumber,
    bool? cardLast4Follows,
    double? creditLimit,
    bool clearCreditLimit = false,
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
      currencyCode: currencyCode ?? this.currencyCode,
      cardLast4: cardLast4 ?? this.cardLast4,
      cardNumber: cardNumber ?? this.cardNumber,
      cardLast4Follows: cardLast4Follows ?? this.cardLast4Follows,
      creditLimit: clearCreditLimit ? null : creditLimit ?? this.creditLimit,
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
      'currencyCode': currencyCode,
      'cardLast4': cardLast4,
      'cardNumber': cardNumber,
      'cardLast4Follows': cardLast4Follows,
      if (creditLimit != null) 'creditLimit': creditLimit,
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
      currencyCode: (json['currencyCode'] as String? ?? defaultCurrencyCode)
          .toUpperCase(),
      cardLast4: json['cardLast4'] as String? ?? '',
      cardNumber: json['cardNumber'] as String? ?? '',
      // 旧备份（无此字段）默认 false：保留其手填后四位、不因跟随把它冲成空。
      cardLast4Follows: json['cardLast4Follows'] as bool? ?? false,
      creditLimit: (json['creditLimit'] as num?)?.toDouble(),
      statementDay: (json['statementDay'] as num?)?.toInt(),
      dueDay: (json['dueDay'] as num?)?.toInt(),
    );
  }
}

/// 从完整卡号提取后四位（只取数字，末四位）。空号返回空串。
String cardLast4Of(String cardNumber) {
  final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
  return digits.length > 4 ? digits.substring(digits.length - 4) : digits;
}

class AccountGroup {
  const AccountGroup({
    required this.id,
    required this.bookId,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String bookId;
  final String name;
  final int sortOrder;

  AccountGroup copyWith({
    String? id,
    String? bookId,
    String? name,
    int? sortOrder,
  }) {
    return AccountGroup(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'name': name,
      'sortOrder': sortOrder,
    };
  }

  static AccountGroup fromJson(Map<String, Object?> json) {
    return AccountGroup(
      id: json['id'] as String,
      bookId: json['bookId'] as String? ?? defaultLedgerBookId,
      name: json['name'] as String? ?? '未命名分组',
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}
