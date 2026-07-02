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
  static const String _budgetsKey = 'verifin.monthly_budgets.v1';
  static const String _ledgerBooksKey = 'verifin.ledger_books.v1';
  static const String _activeBookKey = 'verifin.active_book.v1';
  static const String _assetCoverKey = 'verifin.asset_cover.v1';

  final LocalKeyValueStore _store;
  final List<LedgerEntry> _entries = <LedgerEntry>[];
  final List<LedgerBook> _ledgerBooks = <LedgerBook>[];
  final List<Account> _accounts = <Account>[];
  final List<AccountGroup> _accountGroups = <AccountGroup>[];
  final Map<String, double> _monthlyBudgets = <String, double>{};

  late final ValueNotifier<ThemePreference> themePreferenceListenable;

  ThemePreference _themePreference = ThemePreference.system;
  UserProfile _profile = defaultUserProfile;
  String _activeBookId = defaultLedgerBookId;
  String _assetCoverUrl = '';

  List<LedgerEntry> get entries => List<LedgerEntry>.unmodifiable(
    _entries.where((entry) => entry.bookId == _activeBookId),
  );

  List<LedgerBook> get ledgerBooks => List<LedgerBook>.unmodifiable(
    _ledgerBooks.isEmpty ? defaultLedgerBooks : _ledgerBooks,
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

  ThemePreference get themePreference => _themePreference;

  UserProfile get profile => _profile;

  String get assetCoverUrl => _assetCoverUrl;

  double monthlyBudget(DateTime month) {
    return _monthlyBudgets[_monthKey(month)] ?? 800;
  }

  void setMonthlyBudget(DateTime month, double amount) {
    _monthlyBudgets[_monthKey(month)] = amount <= 0 ? 0 : amount;
    _persistBudgets();
    notifyListeners();
  }

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

  void updateEntry(LedgerEntry entry) {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      return;
    }
    _entries[index] = entry;
    _entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
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
    _entries.removeWhere((entry) => entry.bookId == bookId);
    _accounts.removeWhere((account) => account.bookId == bookId);
    _accountGroups.removeWhere((group) => group.bookId == bookId);
    if (_activeBookId == bookId) {
      _activeBookId = defaultLedgerBookId;
      _store.write(_activeBookKey, _activeBookId);
    }
    _persistLedgerBooks();
    _persistEntries();
    _persistAccounts();
    _persistAccountGroups();
    notifyListeners();
    return true;
  }

  int entryCountForBook(String bookId) {
    return _entries.where((entry) => entry.bookId == bookId).length;
  }

  void deleteEntry(String entryId) {
    _entries.removeWhere((entry) => entry.id == entryId);
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

  void adjustAccountBalance(Account account, double targetBalance) {
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
        note: '余额调整',
        occurredAt: now,
      ),
    );
    _persistEntries();
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
    for (final key in <String>[
      _entriesKey,
      _themeKey,
      _accountsKey,
      _accountGroupsKey,
      _profileKey,
      _budgetsKey,
      _ledgerBooksKey,
      _activeBookKey,
      _assetCoverKey,
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
      ..addAll(defaultLedgerBooks);
    _monthlyBudgets.clear();
    _profile = defaultUserProfile;
    _themePreference = ThemePreference.system;
    _activeBookId = defaultLedgerBookId;
    _assetCoverUrl = '';
    themePreferenceListenable.value = _themePreference;
    notifyListeners();
  }

  double accountBalance(Account account) {
    var balance = account.initialBalance;
    for (final entry in _entries.where(
      (item) => item.bookId == account.bookId && item.accountId == account.id,
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
    _loadLedgerBooks();
    _loadAccountGroups();
    _loadAccounts();
    _loadProfile();
    _loadBudgets();
    _assetCoverUrl = _store.read(_assetCoverKey) ?? '';
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

  void _loadLedgerBooks() {
    final rawBooks = _store.read(_ledgerBooksKey);
    if (rawBooks == null || rawBooks.isEmpty) {
      _ledgerBooks
        ..clear()
        ..addAll(defaultLedgerBooks);
    } else {
      try {
        final decoded = jsonDecode(rawBooks) as List<dynamic>;
        _ledgerBooks
          ..clear()
          ..addAll(
            decoded.map(
              (item) => LedgerBook.fromJson(
                Map<String, Object?>.from(item as Map<dynamic, dynamic>),
              ),
            ),
          );
      } on FormatException {
        _store.delete(_ledgerBooksKey);
        _ledgerBooks
          ..clear()
          ..addAll(defaultLedgerBooks);
      }
    }
    if (!_ledgerBooks.any((book) => book.id == defaultLedgerBookId)) {
      _ledgerBooks.insert(0, defaultLedgerBooks.first);
    }
    _activeBookId = _store.read(_activeBookKey) ?? defaultLedgerBookId;
    if (!_ledgerBooks.any((book) => book.id == _activeBookId)) {
      _activeBookId = defaultLedgerBookId;
      _store.write(_activeBookKey, _activeBookId);
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

  void _loadBudgets() {
    final rawBudgets = _store.read(_budgetsKey);
    if (rawBudgets == null || rawBudgets.isEmpty) {
      return;
    }

    try {
      final decoded = Map<String, Object?>.from(
        jsonDecode(rawBudgets) as Map<dynamic, dynamic>,
      );
      _monthlyBudgets
        ..clear()
        ..addAll(
          decoded.map(
            (key, value) => MapEntry(key, (value as num? ?? 0).toDouble()),
          ),
        );
    } on FormatException {
      _store.delete(_budgetsKey);
    }
  }

  void _persistEntries() {
    _store.write(
      _entriesKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }

  void _persistLedgerBooks() {
    _store.write(
      _ledgerBooksKey,
      jsonEncode(_ledgerBooks.map((book) => book.toJson()).toList()),
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

  void _persistBudgets() {
    _store.write(_budgetsKey, jsonEncode(_monthlyBudgets));
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
    super.dispose();
  }
}

String _monthKey(DateTime month) {
  return '${month.year}-${month.month.toString().padLeft(2, '0')}';
}
