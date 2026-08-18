/// 账本模型。多账本隔离的锚点：交易/账户/分组都带 bookId。
library;

import 'currency.dart';

const String defaultLedgerBookId = 'default';

class LedgerBook {
  const LedgerBook({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isDefault,
    this.baseCurrencyCode = defaultCurrencyCode,
    this.currencySetupStatus = CurrencySetupStatus.confirmed,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isDefault;
  final String baseCurrencyCode;
  final CurrencySetupStatus currencySetupStatus;

  LedgerBook copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? baseCurrencyCode,
    CurrencySetupStatus? currencySetupStatus,
  }) {
    return LedgerBook(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault,
      baseCurrencyCode: baseCurrencyCode ?? this.baseCurrencyCode,
      currencySetupStatus: currencySetupStatus ?? this.currencySetupStatus,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isDefault': isDefault,
      'baseCurrencyCode': baseCurrencyCode,
      'currencySetupStatus': currencySetupStatus.name,
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
      baseCurrencyCode:
          (json['baseCurrencyCode'] as String? ?? defaultCurrencyCode)
              .toUpperCase(),
      // 无字段的是 v1 备份，必须让用户确认数字原本代表什么币种。
      currencySetupStatus: json.containsKey('currencySetupStatus')
          ? CurrencySetupStatus.fromStorage(
              json['currencySetupStatus'] as String?,
            )
          : CurrencySetupStatus.legacyUnconfirmed,
    );
  }
}
