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

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.note,
    required this.occurredAt,
  });

  final String id;
  final EntryType type;
  final double amount;
  final String categoryId;
  final String accountId;
  final String note;
  final DateTime occurredAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.storageValue,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note,
      'occurredAt': occurredAt.toIso8601String(),
    };
  }

  static LedgerEntry fromJson(Map<String, Object?> json) {
    return LedgerEntry(
      id: json['id'] as String,
      type: EntryType.fromStorage(json['type'] as String? ?? 'expense'),
      amount: (json['amount'] as num).toDouble(),
      categoryId: json['categoryId'] as String? ?? 'dining',
      accountId: json['accountId'] as String? ?? 'alipay',
      note: json['note'] as String? ?? '',
      occurredAt:
          DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.group,
    required this.initialBalance,
    required this.icon,
  });

  final String id;
  final String name;
  final String group;
  final double initialBalance;
  final IconData icon;
}

class Category {
  const Category({
    required this.id,
    required this.label,
    required this.type,
    required this.icon,
  });

  final String id;
  final String label;
  final EntryType type;
  final IconData icon;
}
