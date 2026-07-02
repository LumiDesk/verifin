import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../local_storage/local_storage.dart';
import 'models.dart';

class VeriFinController extends ChangeNotifier {
  VeriFinController(this._store) {
    _load();
    themePreferenceListenable = ValueNotifier<ThemePreference>(
      _themePreference,
    );
  }

  static const String _entriesKey = 'verifin.entries.v1';
  static const String _themeKey = 'verifin.theme.v1';

  final LocalKeyValueStore _store;
  final List<LedgerEntry> _entries = <LedgerEntry>[];

  late final ValueNotifier<ThemePreference> themePreferenceListenable;

  ThemePreference _themePreference = ThemePreference.system;

  List<LedgerEntry> get entries => List<LedgerEntry>.unmodifiable(_entries);

  ThemePreference get themePreference => _themePreference;

  void setThemePreference(ThemePreference preference) {
    _themePreference = preference;
    themePreferenceListenable.value = preference;
    _store.write(_themeKey, preference.name);
    notifyListeners();
  }

  void addEntry(LedgerEntry entry) {
    _entries.insert(0, entry);
    _persistEntries();
    notifyListeners();
  }

  double accountBalance(Account account) {
    var balance = account.initialBalance;
    for (final entry in _entries.where(
      (item) => item.accountId == account.id,
    )) {
      switch (entry.type) {
        case EntryType.expense:
          balance -= entry.amount;
        case EntryType.income:
          balance += entry.amount;
        case EntryType.transfer:
          break;
      }
    }
    return balance;
  }

  void _load() {
    _themePreference = ThemePreference.fromStorage(_store.read(_themeKey));
    final rawEntries = _store.read(_entriesKey);
    if (rawEntries == null || rawEntries.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawEntries) as List<dynamic>;
      _entries
        ..clear()
        ..addAll(
          decoded.map(
            (item) => LedgerEntry.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          ),
        );
    } on FormatException {
      _store.delete(_entriesKey);
    }
  }

  void _persistEntries() {
    _store.write(
      _entriesKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    themePreferenceListenable.dispose();
    super.dispose();
  }
}
