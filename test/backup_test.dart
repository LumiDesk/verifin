import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('exports and imports a local data backup', () async {
    final source = await makeController();
    final account = Account(
      id: 'cash-test',
      bookId: source.activeBook.id,
      name: '现金账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 100,
      iconCode: 'wallet',
      note: '测试账户',
      includeInAssets: true,
      hidden: false,
    );
    source
      ..addAccount(account)
      ..addEntry(
        LedgerEntry(
          id: 'entry-test',
          bookId: source.activeBook.id,
          type: EntryType.expense,
          amount: 45,
          categoryId: 'dining',
          accountId: account.id,
          note: '午餐',
          occurredAt: DateTime(2026, 7, 2, 12),
        ),
      )
      ..setMonthlyBudget(DateTime(2026, 7), 2400)
      ..setCategoryBudget(DateTime(2026, 7), 'dining', 600)
      ..setThemePreference(ThemePreference.dark)
      ..setHapticsEnabled(false)
      ..addCategory(type: EntryType.expense, label: '咖啡', iconCode: 'dining');
    final coffeeIndex = source
        .categoriesForType(EntryType.expense)
        .indexWhere((category) => category.label == '咖啡');
    source.reorderCategories(EntryType.expense, coffeeIndex, 0);

    final backup = source.exportDataJson();
    final target = await makeController();
    target.importDataJson(backup);

    expect(target.accounts.single.name, '现金账户');
    expect(target.entries.single.amount, 45);
    expect(target.entries.single.note, '午餐');
    expect(target.monthlyBudget(DateTime(2026, 7)), 2400);
    expect(target.categoryBudget(DateTime(2026, 7), 'dining'), 600);
    expect(target.themePreference, ThemePreference.dark);
    expect(target.hapticsEnabled, isFalse);
    expect(target.categories.any((category) => category.label == '咖啡'), isTrue);
    expect(target.categoriesForType(EntryType.expense).first.label, '咖啡');

    expect(
      () => target.importDataJson(
        '{"data":{"ledgerBooks":[],"entries":[],"accounts":"bad"}}',
      ),
      throwsFormatException,
    );
    expect(target.entries.single.id, 'entry-test');
    expect(target.accounts.single.id, account.id);

    source.dispose();
    target.dispose();
  });

  test('legacy backup without panel fields falls back to defaults', () async {
    final source = await makeController();
    final exported = source.exportDataJson();
    source.dispose();

    final legacyJson = jsonEncode(
      Map<String, Object?>.from(jsonDecode(exported) as Map<dynamic, dynamic>)
        ..update('data', (value) {
          return Map<String, Object?>.from(value as Map<dynamic, dynamic>)
            ..remove('homePanels')
            ..remove('reportPanels');
        }),
    );

    final target = await makeController();
    target.importDataJson(legacyJson);

    expect(
      target.enabledPanelIds(PanelPageKind.home).length,
      homePanelSpecs.length,
    );
    expect(
      target.enabledPanelIds(PanelPageKind.reports).length,
      reportPanelSpecs.length,
    );

    target.dispose();
  });

  test('sample backup imports into controller', () async {
    final rawJson = File(
      'docs/dev/verifin-sample-backup.json',
    ).readAsStringSync();
    final controller = await makeController();

    controller.importDataJson(rawJson);

    expect(controller.accounts.length, greaterThanOrEqualTo(8));
    expect(controller.entries.length, greaterThanOrEqualTo(20));
    expect(controller.accountGroups.length, greaterThanOrEqualTo(4));
    expect(
      controller.categories.any((category) => category.id == 'coffee'),
      isTrue,
    );
    expect(
      controller.categoryBudget(DateTime(2026, 7), 'dining'),
      greaterThan(0),
    );
    expect(
      controller.isAssetSectionCollapsed(
        mode: AssetAccountViewMode.type,
        sectionId: AccountType.investment.name,
      ),
      isTrue,
    );
    expect(
      controller
          .sortedAssetSections<String>(
            mode: AssetAccountViewMode.type,
            sections: AccountType.values.map((type) => type.name).toList(),
            idOf: (section) => section,
          )
          .first,
      AccountType.onlinePayment.name,
    );
    expect(controller.profile.occupation, '产品设计师');
    expect(
      controller.accounts
          .firstWhere((account) => account.id == 'acc_credit')
          .cardLast4,
      '8321',
    );
    expect(controller.enabledPanelIds(PanelPageKind.home), <String>[
      'trend',
      'budget',
      'recent',
    ]);
    expect(controller.enabledPanelIds(PanelPageKind.reports), <String>[
      'category_ring',
      'budget_execution',
      'category_rank',
      'monthly_structure',
    ]);

    controller.dispose();
  });

  test('imports legacy backup budget keys into the default book', () async {
    // 旧备份里预算键没有 bookId 前缀，导入时应归入默认账本。
    final controller = await makeController();
    controller.importDataJson(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'monthlyBudgets': <String, Object?>{'2026-07': 3000},
          'categoryBudgets': <String, Object?>{'2026-07:dining': 450},
        },
      }),
    );

    expect(controller.monthlyBudget(DateTime(2026, 7)), 3000);
    expect(controller.categoryBudget(DateTime(2026, 7), 'dining'), 450);
    controller.dispose();
  });
}
