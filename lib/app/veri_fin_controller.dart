import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../local_storage/local_storage.dart';
import 'demo_data.dart';
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
  static const String _accountsKey = 'verifin.accounts.v1';
  static const String _accountGroupsKey = 'verifin.account_groups.v1';
  static const String _profileKey = 'verifin.profile.v1';

  final LocalKeyValueStore _store;
  final List<LedgerEntry> _entries = <LedgerEntry>[];
  final List<Account> _accounts = <Account>[];
  final List<AccountGroup> _accountGroups = <AccountGroup>[];

  late final ValueNotifier<ThemePreference> themePreferenceListenable;

  ThemePreference _themePreference = ThemePreference.system;
  UserProfile _profile = defaultUserProfile;

  List<LedgerEntry> get entries => List<LedgerEntry>.unmodifiable(_entries);

  List<Account> get accounts => List<Account>.unmodifiable(_accounts);

  List<AccountGroup> get accountGroups {
    final groups = List<AccountGroup>.from(_accountGroups)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List<AccountGroup>.unmodifiable(groups);
  }

  ThemePreference get themePreference => _themePreference;

  UserProfile get profile => _profile;

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
    _persistAccounts();
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
        name: trimmedName,
        iconCode: 'folder',
        sortOrder: _accountGroups.length,
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
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = groups.removeAt(oldIndex);
    groups.insert(newIndex, moved);
    _accountGroups
      ..clear()
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
    _loadAccountGroups();
    _loadAccounts();
    _loadProfile();
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

  void _loadAccounts() {
    final rawAccounts = _store.read(_accountsKey);
    if (rawAccounts == null || rawAccounts.isEmpty) {
      _accounts
        ..clear()
        ..addAll(defaultAccounts);
      return;
    }

    try {
      final decoded = jsonDecode(rawAccounts) as List<dynamic>;
      _accounts
        ..clear()
        ..addAll(
          decoded.map(
            (item) => Account.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          ),
        );
    } on FormatException {
      _store.delete(_accountsKey);
      _accounts
        ..clear()
        ..addAll(defaultAccounts);
    }
  }

  void _loadAccountGroups() {
    final rawGroups = _store.read(_accountGroupsKey);
    if (rawGroups == null || rawGroups.isEmpty) {
      _accountGroups
        ..clear()
        ..addAll(defaultAccountGroups);
      return;
    }

    try {
      final decoded = jsonDecode(rawGroups) as List<dynamic>;
      _accountGroups
        ..clear()
        ..addAll(
          decoded.map(
            (item) => AccountGroup.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          ),
        );
      _normalizeGroupOrder();
    } on FormatException {
      _store.delete(_accountGroupsKey);
      _accountGroups
        ..clear()
        ..addAll(defaultAccountGroups);
    }
  }

  void _loadProfile() {
    final rawProfile = _store.read(_profileKey);
    if (rawProfile == null || rawProfile.isEmpty) {
      _profile = defaultUserProfile;
      return;
    }

    try {
      _profile = UserProfile.fromJson(
        Map<String, Object?>.from(
          jsonDecode(rawProfile) as Map<dynamic, dynamic>,
        ),
      );
    } on FormatException {
      _store.delete(_profileKey);
      _profile = defaultUserProfile;
    }
  }

  void _persistEntries() {
    _store.write(
      _entriesKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }

  void _persistAccounts() {
    _store.write(
      _accountsKey,
      jsonEncode(_accounts.map((account) => account.toJson()).toList()),
    );
  }

  void _persistAccountGroups() {
    _store.write(
      _accountGroupsKey,
      jsonEncode(_accountGroups.map((group) => group.toJson()).toList()),
    );
  }

  void _normalizeGroupOrder() {
    final groups = List<AccountGroup>.from(_accountGroups)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _accountGroups
      ..clear()
      ..addAll(
        groups.indexed.map((item) => item.$2.copyWith(sortOrder: item.$1)),
      );
  }

  @override
  void dispose() {
    themePreferenceListenable.dispose();
    super.dispose();
  }
}
