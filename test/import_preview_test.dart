import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/payment_import.dart';
import 'package:verifin/app/backup/transaction_import.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/entry_detail_page.dart';
import 'package:verifin/pages/import_preview_page.dart';

import 'support/test_harness.dart';

Uint8List _csvBytes(String csv) => Uint8List.fromList(utf8.encode(csv));

const _csv =
    '日期,类型,金额,分类,账户,转入账户,备注\n'
    '2026-02-01,支出,12.5,测试餐饮,测试钱包A,,午饭\n'
    '2026-02-02,支出,30,测试交通,测试钱包B,,打车\n';

// 两笔都引用同一个新账户「新钱包甲」，用于验证映射批量生效。
const _mapCsv =
    '日期,类型,金额,分类,账户,转入账户,备注\n'
    '2026-02-01,支出,10,测试餐饮,新钱包甲,,a\n'
    '2026-02-02,支出,20,测试餐饮,新钱包甲,,b\n';

class _Holder {
  ImportPreviewResult? result;
}

Future<_Holder> _openPreview(
  WidgetTester tester,
  dynamic controller,
  ImportPlan plan,
) async {
  final holder = _Holder();
  await tester.pumpWidget(
    VeriFinScope(
      controller: controller,
      child: zhMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  holder.result = await Navigator.of(context)
                      .push<ImportPreviewResult>(
                        MaterialPageRoute<ImportPreviewResult>(
                          builder: (_) => ImportPreviewPage(
                            plan: plan,
                            sourceLabel: '其他 CSV',
                          ),
                        ),
                      );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return holder;
}

void main() {
  useTestDatabases();

  group('parsePlatformImport（只解析不落库）', () {
    test('解析返回计划但不修改账本', () async {
      final controller = await makeController();
      final beforeEntries = controller.entries.length;
      final beforeAccounts = controller.accounts.length;
      final plan = controller.parsePlatformImport(
        ImportPlatform.genericCsv,
        _csvBytes(_csv),
      );
      expect(plan.importedCount, 2);
      expect(
        plan.newAccounts.map((a) => a.name),
        containsAll(<String>['测试钱包A', '测试钱包B']),
      );
      // 未落库：账本不变。
      expect(controller.entries.length, beforeEntries);
      expect(controller.accounts.length, beforeAccounts);
    });
  });

  group('applyImportEntries（落库被引用子集）', () {
    test('全部保留：交易与其引用的新账户/分类都落地', () async {
      final controller = await makeController();
      final beforeEntries = controller.entries.length;
      final plan = controller.parsePlatformImport(
        ImportPlatform.genericCsv,
        _csvBytes(_csv),
      );
      controller.applyImportEntries(
        entries: plan.entries,
        candidateAccounts: plan.newAccounts,
        candidateCategories: plan.newCategories,
      );
      expect(controller.entries.length, beforeEntries + 2);
      expect(controller.accounts.any((a) => a.name == '测试钱包A'), isTrue);
      expect(controller.accounts.any((a) => a.name == '测试钱包B'), isTrue);
      expect(controller.categories.any((c) => c.label == '测试交通'), isTrue);
    });

    test('排除某笔后：只创建被保留交易引用到的账户/分类', () async {
      final controller = await makeController();
      final plan = controller.parsePlatformImport(
        ImportPlatform.genericCsv,
        _csvBytes(_csv),
      );
      final walletAId = plan.newAccounts
          .firstWhere((a) => a.name == '测试钱包A')
          .id;
      // 只保留第一笔（引用 测试钱包A / 测试餐饮）。
      final kept = plan.entries.where((e) => e.accountId == walletAId).toList();
      expect(kept, hasLength(1));
      controller.applyImportEntries(
        entries: kept,
        candidateAccounts: plan.newAccounts,
        candidateCategories: plan.newCategories,
      );
      expect(controller.accounts.any((a) => a.name == '测试钱包A'), isTrue);
      expect(controller.categories.any((c) => c.label == '测试餐饮'), isTrue);
      // 第二笔被排除：测试钱包B 与 测试交通 不应被创建。
      expect(controller.accounts.any((a) => a.name == '测试钱包B'), isFalse);
      expect(controller.categories.any((c) => c.label == '测试交通'), isFalse);
    });
  });

  group('ImportPreviewPage', () {
    testWidgets('渲染待导入交易，可排除后确认返回子集', (tester) async {
      final controller = await makeController();
      final plan = controller.parsePlatformImport(
        ImportPlatform.genericCsv,
        _csvBytes(_csv),
      );
      final holder = await _openPreview(tester, controller, plan);

      // 两笔交易都渲染。
      expect(find.text('测试餐饮'), findsOneWidget);
      expect(find.text('测试交通'), findsOneWidget);
      // 初始确认按钮：全部 2 笔。
      expect(find.text('确认导入（2）'), findsOneWidget);

      // 点第一笔（测试餐饮）排除 → 变 1 笔。
      await tester.tap(find.text('测试餐饮'));
      await tester.pumpAndSettle();
      expect(find.text('确认导入（1）'), findsOneWidget);

      // 确认导入，返回被保留的那一笔。
      await tester.tap(find.text('确认导入（1）'));
      await tester.pumpAndSettle();
      expect(holder.result, isNotNull);
      expect(holder.result!.entries, hasLength(1));
      expect(holder.result!.entries.single.note, '打车');
    });

    testWidgets('映射区把新账户整体映射到现有账户（批量生效）', (tester) async {
      final controller = await makeController();
      final cash = Account(
        id: 'cash1',
        bookId: controller.activeBook.id,
        name: '现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 0,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      );
      controller.addAccount(cash);
      final plan = controller.parsePlatformImport(
        ImportPlatform.genericCsv,
        _csvBytes(_mapCsv),
      );
      // 两笔都引用同一个新账户「新钱包甲」。
      expect(plan.newAccounts.where((a) => a.name == '新钱包甲'), hasLength(1));

      final holder = await _openPreview(tester, controller, plan);

      // 展开「导入账户」映射区，点开唯一的账户行，映射到现有「现金」。
      await tester.tap(find.text('导入账户'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('现金'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认导入（2）'));
      await tester.pumpAndSettle();

      expect(holder.result, isNotNull);
      // 两笔都被整体改到现有「现金」账户。
      expect(
        holder.result!.entries.every((e) => e.accountId == 'cash1'),
        isTrue,
      );
    });

    testWidgets('映射区可给新账户改名', (tester) async {
      final controller = await makeController();
      final plan = controller.parsePlatformImport(
        ImportPlatform.genericCsv,
        _csvBytes(_mapCsv),
      );
      final provisionalId = plan.newAccounts
          .firstWhere((a) => a.name == '新钱包甲')
          .id;

      final holder = await _openPreview(tester, controller, plan);

      await tester.tap(find.text('导入账户'));
      await tester.pumpAndSettle();
      // 点改名图标 → 弹窗输入新名。
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '我的钱包');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认导入（2）'));
      await tester.pumpAndSettle();

      expect(holder.result, isNotNull);
      expect(
        holder.result!.candidateAccounts
            .firstWhere((a) => a.id == provisionalId)
            .name,
        '我的钱包',
      );
    });
  });

  group('EntryDetailPage.draft（草稿编辑不落库）', () {
    testWidgets('编辑后返回修改草稿，账本不变', (tester) async {
      final controller = await makeController();
      final account = Account(
        id: 'acc_x',
        bookId: controller.activeBook.id,
        name: '测试账户',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 0,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      );
      controller.addAccount(account);
      // 临时（未落库）分类，经 extraCategories 传入草稿编辑页解析。
      const category = Category(
        id: 'cat_x',
        label: '测试类',
        type: EntryType.expense,
        iconCode: 'category',
      );
      final entry = LedgerEntry(
        id: 'draft_1',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 42,
        categoryId: category.id,
        accountId: account.id,
        note: '原备注',
        occurredAt: DateTime(2026, 2, 3, 9, 0),
      );
      final before = controller.entries.length;
      LedgerEntry? popped;
      await tester.pumpWidget(
        VeriFinScope(
          controller: controller,
          child: zhMaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      popped = await Navigator.of(context).push<LedgerEntry>(
                        MaterialPageRoute<LedgerEntry>(
                          builder: (_) => EntryDetailPage.draft(
                            entry: entry,
                            extraCategories: const <Category>[category],
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 预填了原备注。
      expect(find.text('原备注'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('entry_note_field')), '改后备注');
      await tester.tap(find.byKey(const Key('save_entry_button')));
      await tester.pumpAndSettle();

      expect(popped, isNotNull);
      expect(popped!.id, 'draft_1');
      expect(popped!.note, '改后备注');
      expect(popped!.amount, 42);
      // 未落库：账本交易数不变。
      expect(controller.entries.length, before);
    });
  });
}
