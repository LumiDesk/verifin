import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

Uint8List _tallyBytes(Map<String, Object?> data) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('backup_data.json', jsonEncode(data)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

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

    testWidgets('纯账户导入：展示账户与余额，可用「账户」按钮确认', (tester) async {
      final controller = await makeController();
      final bytes = _tallyBytes(<String, Object?>{
        'assets': <Object?>[
          <String, Object?>{'id': 1, 'name': '妈妈', 'amount': 2000.0, 'type': 2},
        ],
        'records': <Object?>[],
      });
      final plan = controller.parsePlatformImport(ImportPlatform.tally, bytes);
      final holder = await _openPreview(tester, controller, plan);

      // 账户区默认展开，账户名与余额都可见。
      expect(find.text('妈妈'), findsOneWidget);
      expect(find.textContaining('2000'), findsWidgets);

      // 无交易时确认按钮为「账户」变体。
      final confirm = find.textContaining('个账户');
      expect(confirm, findsWidgets);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(holder.result, isNotNull);
      expect(holder.result!.entries, isEmpty);
      expect(holder.result!.alwaysCreateAccountIds, isNotEmpty);
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
      await tester.tap(find.text('确认'));
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

  group('Tally 导入：账户余额与无流水账户落库', () {
    Uint8List sampleBackup() => _tallyBytes(<String, Object?>{
      'assets': <Object?>[
        <String, Object?>{
          'id': 1,
          'name': '微信余额',
          'amount': 1035.18,
          'type': 0,
        },
        <String, Object?>{'id': 2, 'name': 'qq钱包', 'amount': 0, 'type': 0},
        <String, Object?>{'id': 3, 'name': '妈妈', 'amount': 2000.0, 'type': 2},
      ],
      'records': <Object?>[
        <String, Object?>{
          'date': DateTime(2026, 7, 5, 12).millisecondsSinceEpoch,
          'type': 1,
          'amount': 2996.17,
          'category': '工资',
          'assetId': 1,
          'note': '',
        },
        <String, Object?>{
          'date': DateTime(2026, 7, 5, 13).millisecondsSinceEpoch,
          'type': 0,
          'amount': 1960.99,
          'category': '购物',
          'assetId': 1,
          'note': '',
        },
      ],
    });

    test('只有账户、没有交易也能导入（standaloneAccountIds 非空）', () async {
      final controller = await makeController();
      final bytes = _tallyBytes(<String, Object?>{
        'assets': <Object?>[
          <String, Object?>{'id': 1, 'name': '现金', 'amount': 500.0, 'type': 0},
          <String, Object?>{'id': 2, 'name': '花呗', 'amount': 300.0, 'type': 1},
        ],
        'records': <Object?>[],
      });
      final plan = controller.parsePlatformImport(ImportPlatform.tally, bytes);
      expect(plan.importedCount, 0);
      expect(plan.standaloneAccountIds, isNotEmpty);
      expect(
        plan.newAccounts.map((a) => a.name),
        containsAll(<String>['现金', '花呗']),
      );

      // 空交易 + 独立账户：applyImportEntries 仍创建账户。
      controller.applyImportEntries(
        entries: const <LedgerEntry>[],
        candidateAccounts: plan.newAccounts,
        candidateCategories: plan.newCategories,
        alwaysCreateAccountIds: plan.standaloneAccountIds,
      );
      final cash = controller.accounts.firstWhere((a) => a.name == '现金');
      expect(controller.accountBalance(cash), 500);
      final huabei = controller.accounts.firstWhere((a) => a.name == '花呗');
      expect(controller.accountBalance(huabei), -300);
    });

    test('落库后账户余额对齐 Tally，无流水账户也被创建', () async {
      final controller = await makeController();
      final plan = controller.parsePlatformImport(
        ImportPlatform.tally,
        sampleBackup(),
      );
      final result = ImportPreviewResult(
        entries: plan.entries,
        candidateAccounts: plan.newAccounts,
        candidateCategories: plan.newCategories,
        alwaysCreateAccountIds: plan.standaloneAccountIds,
      );
      controller.applyImportEntries(
        entries: result.entries,
        candidateAccounts: result.candidateAccounts,
        candidateCategories: result.candidateCategories,
        alwaysCreateAccountIds: result.alwaysCreateAccountIds,
      );

      final wechat = controller.accounts.firstWhere((a) => a.name == '微信余额');
      expect(controller.accountBalance(wechat), closeTo(1035.18, 0.001));
      // 无流水的账户也被创建。
      final qq = controller.accounts.firstWhere((a) => a.name == 'qq钱包');
      expect(controller.accountBalance(qq), 0);
      final mama = controller.accounts.firstWhere((a) => a.name == '妈妈');
      expect(controller.accountBalance(mama), 2000);
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
