import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;

import '../local_storage/local_storage.dart';
import 'demo_data.dart';
import 'ledger_math.dart';
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
  static const String _categoriesKey = 'verifin.categories.v1';
  static const String _categoryBudgetsKey = 'verifin.category_budgets.v1';
  static const String _hapticsKey = 'verifin.haptics.v1';
  static const String _assetViewModeKey = 'verifin.asset_view_mode.v1';
  static const String _assetSectionCollapsedKey =
      'verifin.asset_section_collapsed.v1';
  static const String _assetAccountOrderKey = 'verifin.asset_account_order.v1';
  static const String _assetSectionOrderKey = 'verifin.asset_section_order.v1';

  final LocalKeyValueStore _store;
  final List<LedgerEntry> _entries = <LedgerEntry>[];
  final List<LedgerBook> _ledgerBooks = <LedgerBook>[];
  final List<Account> _accounts = <Account>[];
  final List<AccountGroup> _accountGroups = <AccountGroup>[];
  final List<Category> _categories = <Category>[];
  final Map<String, double> _monthlyBudgets = <String, double>{};
  final Map<String, double> _categoryBudgets = <String, double>{};
  final Set<String> _collapsedAssetSections = <String>{};
  final Map<String, List<String>> _assetAccountOrders =
      <String, List<String>>{};
  final Map<String, List<String>> _assetSectionOrders =
      <String, List<String>>{};

  late final ValueNotifier<ThemePreference> themePreferenceListenable;

  ThemePreference _themePreference = ThemePreference.system;
  UserProfile _profile = defaultUserProfile;
  String _activeBookId = defaultLedgerBookId;
  String _assetCoverUrl = '';
  bool _hapticsEnabled = true;
  AssetAccountViewMode _assetAccountViewMode = AssetAccountViewMode.type;

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

  List<Category> get categories => List<Category>.unmodifiable(
    _categories.isEmpty ? defaultCategories : _categories,
  );

  ThemePreference get themePreference => _themePreference;

  UserProfile get profile => _profile;

  String get assetCoverUrl => _assetCoverUrl;

  bool get hapticsEnabled => _hapticsEnabled;

  AssetAccountViewMode get assetAccountViewMode => _assetAccountViewMode;

  List<Category> categoriesForType(EntryType type) {
    return categoriesFor(type, categories);
  }

  Category categoryById(String id) {
    return categoryByIdFrom(categories, id);
  }

  double monthlyBudget(DateTime month) {
    return _monthlyBudgets[_monthKey(month)] ?? 800;
  }

  void setMonthlyBudget(DateTime month, double amount) {
    _monthlyBudgets[_monthKey(month)] = amount <= 0 ? 0 : amount;
    _persistBudgets();
    notifyListeners();
  }

  double categoryBudget(DateTime month, String categoryId) {
    return _categoryBudgets[_categoryBudgetKey(month, categoryId)] ?? 0;
  }

  void setCategoryBudget(DateTime month, String categoryId, double amount) {
    final key = _categoryBudgetKey(month, categoryId);
    if (amount <= 0) {
      _categoryBudgets.remove(key);
    } else {
      _categoryBudgets[key] = amount;
    }
    _persistCategoryBudgets();
    notifyListeners();
  }

  void setThemePreference(ThemePreference preference) {
    _themePreference = preference;
    themePreferenceListenable.value = preference;
    _store.write(_themeKey, preference.name);
    notifyListeners();
  }

  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
    _store.write(_hapticsKey, enabled.toString());
    notifyListeners();
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

  // 交易列表始终维护 occurredAt 倒序;同一时刻用 id 决出稳定顺序。
  static int _compareEntriesLatestFirst(LedgerEntry a, LedgerEntry b) {
    final byDate = b.occurredAt.compareTo(a.occurredAt);
    if (byDate != 0) {
      return byDate;
    }
    return b.id.compareTo(a.id);
  }

  void addEntry(LedgerEntry entry) {
    _entries.insert(0, entry);
    _entries.sort(_compareEntriesLatestFirst);
    _persistEntries();
    notifyListeners();
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
    _collapsedAssetSections.removeWhere((key) => key.startsWith('$bookId:'));
    _assetAccountOrders.removeWhere((key, _) => key.startsWith('$bookId:'));
    _assetSectionOrders.removeWhere((key, _) => key.startsWith('$bookId:'));
    if (_activeBookId == bookId) {
      _activeBookId = defaultLedgerBookId;
      _store.write(_activeBookKey, _activeBookId);
    }
    _persistLedgerBooks();
    _persistEntries();
    _persistAccounts();
    _persistAccountGroups();
    _persistAssetSectionCollapsed();
    _persistAssetAccountOrders();
    _persistAssetSectionOrders();
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
    _removeAccountFromOrders(accountId);
    _persistAssetAccountOrders();
    _persistAccounts();
    notifyListeners();
  }

  void deleteAccountAndRelatedEntries(String accountId) {
    _entries.removeWhere((entry) => entryTouchesAccount(entry, accountId));
    _accounts.removeWhere((account) => account.id == accountId);
    _removeAccountFromOrders(accountId);
    _persistEntries();
    _persistAssetAccountOrders();
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
    _entries.sort(_compareEntriesLatestFirst);
    _persistEntries();
    notifyListeners();
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

  void addCategory({
    required EntryType type,
    required String label,
    required String iconCode,
  }) {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      return;
    }
    _categories.add(
      Category(
        id: 'category_${DateTime.now().microsecondsSinceEpoch}',
        label: trimmedLabel,
        type: type,
        iconCode: iconCode,
      ),
    );
    _persistCategories();
    notifyListeners();
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

  void reorderCategories(EntryType type, int oldIndex, int newIndex) {
    final typeCategories = categoriesForType(type).toList();
    if (oldIndex < 0 ||
        oldIndex >= typeCategories.length ||
        newIndex < 0 ||
        newIndex > typeCategories.length) {
      return;
    }
    final moved = typeCategories.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, typeCategories.length);
    typeCategories.insert(targetIndex, moved);

    final categoriesByType = <EntryType, List<Category>>{
      for (final entryType in EntryType.values)
        entryType: _categories
            .where((category) => category.type == entryType)
            .toList(),
    };
    categoriesByType[type] = typeCategories;

    _categories
      ..clear()
      ..addAll(
        EntryType.values.expand(
          (entryType) => categoriesByType[entryType] ?? const <Category>[],
        ),
      );
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
    if (categoriesForType(category.type).length <= 1) {
      return false;
    }
    _categories.removeWhere((item) => item.id == categoryId);
    _persistCategories();
    notifyListeners();
    return true;
  }

  int categoryUsageCount(String categoryId) {
    return _entries.where((entry) => entry.categoryId == categoryId).length;
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
      _categoriesKey,
      _categoryBudgetsKey,
      _hapticsKey,
      _assetViewModeKey,
      _assetSectionCollapsedKey,
      _assetAccountOrderKey,
      _assetSectionOrderKey,
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
    _categories
      ..clear()
      ..addAll(defaultCategories);
    _monthlyBudgets.clear();
    _categoryBudgets.clear();
    _profile = defaultUserProfile;
    _themePreference = ThemePreference.system;
    _activeBookId = defaultLedgerBookId;
    _assetCoverUrl = '';
    _hapticsEnabled = true;
    _assetAccountViewMode = AssetAccountViewMode.type;
    _collapsedAssetSections.clear();
    _assetAccountOrders.clear();
    _assetSectionOrders.clear();
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
        'monthlyBudgets': Map<String, double>.from(_monthlyBudgets),
        'categoryBudgets': Map<String, double>.from(_categoryBudgets),
        'profile': _profile.toJson(),
        'themePreference': _themePreference.name,
        'assetCoverUrl': _assetCoverUrl,
        'hapticsEnabled': _hapticsEnabled,
        'assetAccountViewMode': _assetAccountViewMode.name,
        'collapsedAssetSections': _collapsedAssetSections.toList(),
        'assetAccountOrders': _assetAccountOrders,
        'assetSectionOrders': _assetSectionOrders,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  void importDataJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('备份文件格式不正确');
    }
    final root = Map<String, Object?>.from(decoded);
    final dataValue = root['data'] ?? root;
    if (dataValue is! Map) {
      throw const FormatException('备份文件缺少数据内容');
    }
    final data = Map<String, Object?>.from(dataValue);

    final importedBooks = _decodeModelList<LedgerBook>(
      data['ledgerBooks'],
      LedgerBook.fromJson,
    );
    final nextLedgerBooks = <LedgerBook>[
      ...(importedBooks.isEmpty ? defaultLedgerBooks : importedBooks),
    ];
    if (!nextLedgerBooks.any((book) => book.id == defaultLedgerBookId)) {
      nextLedgerBooks.insert(0, defaultLedgerBooks.first);
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
      ...(importedCategories.isEmpty ? defaultCategories : importedCategories),
    ];
    final nextMonthlyBudgets = _decodeBudgets(data['monthlyBudgets']);
    final nextCategoryBudgets = _decodeBudgets(data['categoryBudgets']);

    final profileValue = data['profile'];
    final nextProfile = profileValue is Map
        ? UserProfile.fromJson(Map<String, Object?>.from(profileValue))
        : defaultUserProfile;
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
    _monthlyBudgets
      ..clear()
      ..addAll(nextMonthlyBudgets);
    _categoryBudgets
      ..clear()
      ..addAll(nextCategoryBudgets);
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

    _persistLedgerBooks();
    _store.write(_activeBookKey, _activeBookId);
    _persistEntries();
    _persistAccounts();
    _persistAccountGroups();
    _persistCategories();
    _persistBudgets();
    _persistCategoryBudgets();
    _store.write(_profileKey, jsonEncode(_profile.toJson()));
    _store.write(_themeKey, _themePreference.name);
    _store.write(_hapticsKey, _hapticsEnabled.toString());
    _store.write(_assetViewModeKey, _assetAccountViewMode.name);
    _persistAssetSectionCollapsed();
    _persistAssetAccountOrders();
    _persistAssetSectionOrders();
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

  void _load() {
    _themePreference = ThemePreference.fromStorage(_store.read(_themeKey));
    _loadLedgerBooks();
    _loadCategories();
    _loadAccountGroups();
    _loadAccounts();
    _loadProfile();
    _loadBudgets();
    _loadCategoryBudgets();
    _assetCoverUrl = _store.read(_assetCoverKey) ?? '';
    _hapticsEnabled = _store.read(_hapticsKey) != 'false';
    _assetAccountViewMode = AssetAccountViewMode.fromStorage(
      _store.read(_assetViewModeKey),
    );
    _loadAssetSectionCollapsed();
    _loadAssetAccountOrders();
    _loadAssetSectionOrders();
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
    } catch (_) {
      _store.delete(_entriesKey);
    }
  }

  void _removeAccountFromOrders(String accountId) {
    for (final order in _assetAccountOrders.values) {
      order.remove(accountId);
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
      } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
      _store.delete(_profileKey);
      _profile = defaultUserProfile;
    }
  }

  void _loadCategories() {
    final rawCategories = _store.read(_categoriesKey);
    if (rawCategories == null || rawCategories.isEmpty) {
      _categories
        ..clear()
        ..addAll(defaultCategories);
      return;
    }

    try {
      final decoded = jsonDecode(rawCategories) as List<dynamic>;
      _categories
        ..clear()
        ..addAll(
          decoded.map(
            (item) => Category.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          ),
        );
      if (_categories.isEmpty) {
        _categories.addAll(defaultCategories);
      }
    } catch (_) {
      _store.delete(_categoriesKey);
      _categories
        ..clear()
        ..addAll(defaultCategories);
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
    } catch (_) {
      _store.delete(_budgetsKey);
    }
  }

  void _loadCategoryBudgets() {
    final rawBudgets = _store.read(_categoryBudgetsKey);
    if (rawBudgets == null || rawBudgets.isEmpty) {
      return;
    }

    try {
      _categoryBudgets
        ..clear()
        ..addAll(_decodeBudgets(jsonDecode(rawBudgets)));
    } catch (_) {
      _store.delete(_categoryBudgetsKey);
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

  void _persistCategories() {
    _store.write(
      _categoriesKey,
      jsonEncode(_categories.map((category) => category.toJson()).toList()),
    );
  }

  void _persistBudgets() {
    _store.write(_budgetsKey, jsonEncode(_monthlyBudgets));
  }

  void _persistCategoryBudgets() {
    _store.write(_categoryBudgetsKey, jsonEncode(_categoryBudgets));
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

String _categoryBudgetKey(DateTime month, String categoryId) {
  return '${_monthKey(month)}:$categoryId';
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
