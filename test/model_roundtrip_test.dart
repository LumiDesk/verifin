import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/data/app_database.dart';
import 'package:verifin/data/ledger_repository.dart';

/// 模型字段往返测试：防「四处手写映射」漂移。
///
/// 每个持久化模型都有 toJson/fromJson（备份）与 _xToRow/_xFromRow（SQLite）两对
/// 手写映射，新增字段漏改任何一处都不会报错、只会静默丢数据。本文件用「全字段
/// 非默认值」夹具做两条往返（JSON 与 SQLite），再比对 toJson 输出，任一映射漏
/// 字段即失败。
///
/// **给模型加字段时必须同步更新这里的夹具**，且夹具值要满足：
/// - 与该字段在 fromJson/fromRow 里的兜底默认值**不同**（否则「写了但读丢、
///   恰好落回默认值」检测不出来）；
/// - DateTime 只到毫秒精度（SQLite 存 millisecondsSinceEpoch，微秒会被截断，
///   不是映射 bug）。
void main() {
  setUpAll(sqfliteFfiInit);

  // ---- 全字段非默认值夹具 ----

  final entryFull = LedgerEntry(
    id: 'entry-full',
    bookId: 'book-x',
    type: EntryType.refund,
    amount: 123.45,
    currencyCode: 'USD',
    accountAmount: 888.12,
    toAccountAmount: 99.87,
    baseAmount: 777.65,
    conversionSource: ConversionSource.imported,
    categoryId: 'cat-x',
    accountId: 'acc-x',
    toAccountId: 'acc-y',
    note: '往返夹具',
    occurredAt: DateTime(2026, 7, 12, 10, 30, 15, 123),
    tagIds: const <String>['t1', 't2'],
    fee: 2.5,
    reimbursable: true,
    refundedBaseAmount: 11.5,
    refundOf: 'entry-orig',
    settledAt: DateTime(2026, 7, 13, 9, 0, 0, 456),
  );

  /// 可空字段全空、可省略字段全默认：保证 null / 缺省路径同样无损。
  final entryMinimal = LedgerEntry(
    id: 'entry-min',
    bookId: 'book-x',
    type: EntryType.expense,
    amount: 1,
    categoryId: 'cat-x',
    accountId: '',
    note: '',
    occurredAt: DateTime(2026, 1, 2, 3, 4, 5),
  );

  final book = LedgerBook(
    id: 'book-x',
    name: '旅行账本',
    createdAt: DateTime(2026, 5, 1, 12, 0, 0, 789),
    isDefault: true,
    baseCurrencyCode: 'GBP',
    currencySetupStatus: CurrencySetupStatus.legacyUnconfirmed,
  );

  const accountFull = Account(
    id: 'acc-x',
    bookId: 'book-x',
    name: '往返测试卡',
    type: AccountType.cash,
    groupId: 'grp-1',
    initialBalance: -50.25,
    iconCode: 'bank',
    note: '账户备注',
    includeInAssets: false,
    hidden: true,
    currencyCode: 'EUR',
    cardLast4: '6789',
    cardNumber: '6222 1234 5678 6789',
    cardLast4Follows: true,
    creditLimit: 8000.5,
    statementDay: 5,
    dueDay: 25,
  );

  const accountGroup = AccountGroup(
    id: 'grp-1',
    bookId: 'book-x',
    name: '投资分组',
    sortOrder: 3,
  );

  const categoryChild = Category(
    id: 'cat-x',
    label: '往返分类',
    type: EntryType.income,
    iconCode: 'emoji:🍜',
    parentId: 'cat-parent',
  );

  const categoryRoot = Category(
    id: 'cat-parent',
    label: '顶级分类',
    type: EntryType.income,
    iconCode: 'salary',
  );

  const tag = Tag(id: 'tag-1', label: '出差');

  const attachment = Attachment(
    id: 'att-1',
    entryId: 'entry-full',
    dataUrl: 'data:image/jpeg;base64,QUJD',
  );

  final rule = RecurringRule(
    id: 'rule-1',
    bookId: 'book-x',
    type: EntryType.income,
    amount: 999.99,
    currencyCode: 'HKD',
    accountAmount: 888.88,
    toAccountAmount: 777.77,
    baseAmount: 666.66,
    ratePolicy: RecurringRatePolicy.latestAvailable,
    categoryId: 'cat-x',
    accountId: 'acc-x',
    toAccountId: 'acc-y',
    note: '工资',
    frequency: RecurringFrequency.weekly,
    startDate: DateTime(2026, 6, 1, 8, 0, 0, 1),
    nextRunDate: DateTime(2026, 7, 1, 8, 0, 0, 2),
    active: false,
  );

  final exchangeRate = ExchangeRate(
    id: 'rate-1',
    bookId: 'book-x',
    baseCurrencyCode: 'GBP',
    currencyCode: 'USD',
    effectiveDate: DateTime(2026, 7, 1),
    rateToBase: 0.7345678912,
    source: ExchangeRateSource.imported,
    createdAt: DateTime(2026, 7, 1, 8, 0, 0, 123),
    updatedAt: DateTime(2026, 7, 2, 9, 0, 0, 456),
  );

  /// 经真实 jsonEncode/jsonDecode 走一圈再 fromJson：既验证映射互逆，也验证
  /// toJson 产物真的可被 JSON 编码（残留 DateTime 等原始对象会在这里炸）。
  Map<String, Object?> jsonRoundTrip(Map<String, Object?> json) {
    return jsonDecode(jsonEncode(json)) as Map<String, Object?>;
  }

  group('JSON 往返（备份导出→导入）', () {
    test('LedgerEntry 全字段与全空字段', () {
      for (final entry in <LedgerEntry>[entryFull, entryMinimal]) {
        final restored = LedgerEntry.fromJson(jsonRoundTrip(entry.toJson()));
        expect(restored.toJson(), entry.toJson());
      }
    });

    test('LedgerBook', () {
      final restored = LedgerBook.fromJson(jsonRoundTrip(book.toJson()));
      expect(restored.toJson(), book.toJson());
    });

    test('Account', () {
      final restored = Account.fromJson(jsonRoundTrip(accountFull.toJson()));
      expect(restored.toJson(), accountFull.toJson());
    });

    test('AccountGroup', () {
      final restored = AccountGroup.fromJson(
        jsonRoundTrip(accountGroup.toJson()),
      );
      expect(restored.toJson(), accountGroup.toJson());
    });

    test('AccountGroup 忽略旧备份的图标字段', () {
      final restored = AccountGroup.fromJson(<String, Object?>{
        ...accountGroup.toJson(),
        'iconCode': 'wallet',
      });
      expect(restored.toJson(), accountGroup.toJson());
      expect(restored.toJson(), isNot(contains('iconCode')));
    });

    test('Category 子分类与顶级分类', () {
      for (final category in <Category>[categoryChild, categoryRoot]) {
        final restored = Category.fromJson(jsonRoundTrip(category.toJson()));
        expect(restored.toJson(), category.toJson());
      }
    });

    test('Tag', () {
      final restored = Tag.fromJson(jsonRoundTrip(tag.toJson()));
      expect(restored.toJson(), tag.toJson());
    });

    test('Attachment', () {
      final restored = Attachment.fromJson(jsonRoundTrip(attachment.toJson()));
      expect(restored.toJson(), attachment.toJson());
    });

    test('RecurringRule', () {
      final restored = RecurringRule.fromJson(jsonRoundTrip(rule.toJson()));
      expect(restored.toJson(), rule.toJson());
    });

    test('ExchangeRate', () {
      final restored = ExchangeRate.fromJson(
        jsonRoundTrip(exchangeRate.toJson()),
      );
      expect(restored.toJson(), exchangeRate.toJson());
    });

    test('UserProfile', () {
      const profile = UserProfile(
        nickname: '测试昵称',
        bio: '测试简介',
        avatarDataUrl: 'data:image/png;base64,QUJD',
        gender: ProfileGender.female,
        birthday: '1990-01-02',
        city: '上海',
        occupation: '工程师',
      );
      final restored = UserProfile.fromJson(jsonRoundTrip(profile.toJson()));
      expect(restored.toJson(), profile.toJson());
    });

    test('PagePanelSetting', () {
      const setting = PagePanelSetting(id: 'trend', enabled: false);
      final restored = PagePanelSetting.fromJson(
        jsonRoundTrip(setting.toJson()),
      );
      expect(restored.toJson(), setting.toJson());
    });
  });

  group('SQLite 往返（落库→载入）', () {
    final opened = <AppDatabase>[];
    tearDown(() async {
      for (final db in opened) {
        await db.close();
      }
      opened.clear();
    });

    Future<LedgerRepository> openRepo() async {
      final db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      opened.add(db);
      return SqliteLedgerRepository(db);
    }

    test('全部账目类模型经数据库往返后 toJson 不变', () async {
      final repo = await openRepo();
      await repo.saveEntries(<LedgerEntry>[entryFull, entryMinimal]);
      await repo.saveBooks(<LedgerBook>[book]);
      await repo.saveAccounts(<Account>[accountFull]);
      await repo.saveAccountGroups(<AccountGroup>[accountGroup]);
      await repo.saveCategories(<Category>[categoryChild, categoryRoot]);
      await repo.saveTags(<Tag>[tag]);
      await repo.saveAttachments(<Attachment>[attachment]);
      await repo.saveRecurringRules(<RecurringRule>[rule]);
      await repo.saveExchangeRates(<ExchangeRate>[exchangeRate]);

      final entries = await repo.loadEntries();
      expect(
        entries.singleWhere((e) => e.id == entryFull.id).toJson(),
        entryFull.toJson(),
      );
      expect(
        entries.singleWhere((e) => e.id == entryMinimal.id).toJson(),
        entryMinimal.toJson(),
      );
      expect((await repo.loadBooks()).single.toJson(), book.toJson());
      expect((await repo.loadAccounts()).single.toJson(), accountFull.toJson());
      expect(
        (await repo.loadAccountGroups()).single.toJson(),
        accountGroup.toJson(),
      );
      final categories = await repo.loadCategories();
      expect(
        categories.singleWhere((c) => c.id == categoryChild.id).toJson(),
        categoryChild.toJson(),
      );
      expect(
        categories.singleWhere((c) => c.id == categoryRoot.id).toJson(),
        categoryRoot.toJson(),
      );
      expect((await repo.loadTags()).single.toJson(), tag.toJson());
      expect(
        (await repo.loadAttachments()).single.toJson(),
        attachment.toJson(),
      );
      expect((await repo.loadRecurringRules()).single.toJson(), rule.toJson());
      expect(
        (await repo.loadExchangeRates()).single.toJson(),
        exchangeRate.toJson(),
      );
    });
  });
}
