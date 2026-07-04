import 'package:verifin/app/models.dart';
import 'package:verifin/data/ledger_repository.dart';

/// 纯内存仓储实现，供 widget / 控制器逻辑测试注入。
///
/// saveX 同步更新内部状态（返回已完成的 Future），因此不会引入真实异步 I/O，
/// 避免与 testWidgets 的 fake-async 冲突；同一实例在多个控制器间共享即模拟重启后
/// 从同一存储重新载入。
class InMemoryLedgerRepository implements LedgerRepository {
  List<LedgerEntry> _entries = <LedgerEntry>[];
  List<LedgerBook> _books = <LedgerBook>[];
  List<Account> _accounts = <Account>[];
  List<AccountGroup> _groups = <AccountGroup>[];
  List<Category> _categories = <Category>[];
  List<Tag> _tags = <Tag>[];
  List<Attachment> _attachments = <Attachment>[];
  List<RecurringRule> _recurringRules = <RecurringRule>[];
  Map<String, double> _monthlyBudgets = <String, double>{};
  Map<String, double> _categoryBudgets = <String, double>{};

  @override
  Future<List<LedgerEntry>> loadEntries() async =>
      List<LedgerEntry>.of(_entries);

  @override
  Future<void> saveEntries(List<LedgerEntry> entries) async {
    _entries = List<LedgerEntry>.of(entries);
  }

  @override
  Future<List<LedgerBook>> loadBooks() async => List<LedgerBook>.of(_books);

  @override
  Future<void> saveBooks(List<LedgerBook> books) async {
    _books = List<LedgerBook>.of(books);
  }

  @override
  Future<List<Account>> loadAccounts() async => List<Account>.of(_accounts);

  @override
  Future<void> saveAccounts(List<Account> accounts) async {
    _accounts = List<Account>.of(accounts);
  }

  @override
  Future<List<AccountGroup>> loadAccountGroups() async =>
      List<AccountGroup>.of(_groups);

  @override
  Future<void> saveAccountGroups(List<AccountGroup> groups) async {
    _groups = List<AccountGroup>.of(groups);
  }

  @override
  Future<List<Category>> loadCategories() async =>
      List<Category>.of(_categories);

  @override
  Future<void> saveCategories(List<Category> categories) async {
    _categories = List<Category>.of(categories);
  }

  @override
  Future<List<Tag>> loadTags() async => List<Tag>.of(_tags);

  @override
  Future<void> saveTags(List<Tag> tags) async {
    _tags = List<Tag>.of(tags);
  }

  @override
  Future<List<Attachment>> loadAttachments() async =>
      List<Attachment>.of(_attachments);

  @override
  Future<void> saveAttachments(List<Attachment> attachments) async {
    _attachments = List<Attachment>.of(attachments);
  }

  @override
  Future<List<RecurringRule>> loadRecurringRules() async =>
      List<RecurringRule>.of(_recurringRules);

  @override
  Future<void> saveRecurringRules(List<RecurringRule> rules) async {
    _recurringRules = List<RecurringRule>.of(rules);
  }

  @override
  Future<Map<String, double>> loadMonthlyBudgets() async =>
      Map<String, double>.of(_monthlyBudgets);

  @override
  Future<void> saveMonthlyBudgets(Map<String, double> budgets) async {
    _monthlyBudgets = Map<String, double>.of(budgets);
  }

  @override
  Future<Map<String, double>> loadCategoryBudgets() async =>
      Map<String, double>.of(_categoryBudgets);

  @override
  Future<void> saveCategoryBudgets(Map<String, double> budgets) async {
    _categoryBudgets = Map<String, double>.of(budgets);
  }

  @override
  Future<bool> hasAnyData() async =>
      _entries.isNotEmpty ||
      _books.isNotEmpty ||
      _accounts.isNotEmpty ||
      _groups.isNotEmpty ||
      _categories.isNotEmpty;
}
