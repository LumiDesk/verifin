import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

LedgerEntry _entry(
  String id,
  String bookId, {
  EntryType type = EntryType.expense,
  String category = 'dining',
  String account = 'cash',
}) => LedgerEntry(
  id: id,
  bookId: bookId,
  type: type,
  amount: 10,
  categoryId: category,
  accountId: account,
  note: '',
  occurredAt: DateTime(2026, 7, 4),
);

Account _account(
  String id,
  String bookId, {
  String currencyCode = defaultCurrencyCode,
  double initialBalance = 0,
}) => Account(
  id: id,
  bookId: bookId,
  name: id,
  type: AccountType.cash,
  groupId: null,
  initialBalance: initialBalance,
  iconCode: 'cash',
  note: '',
  includeInAssets: true,
  hidden: false,
  currencyCode: currencyCode,
);

void main() {
  useTestDatabases();

  test('deleteEntries 批量删除并清理附件', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addEntry(_entry('a', bookId))
      ..addEntry(_entry('b', bookId))
      ..addEntry(_entry('c', bookId))
      ..addAttachment('a', 'data:image/jpeg;base64,AAAA');

    await controller.deleteEntries(<String>{'a', 'b'});
    expect(controller.entries.map((e) => e.id), <String>['c']);
    expect(controller.attachmentCountForEntry('a'), 0);
    controller.dispose();
  });

  test('setEntriesCategory 只改同类型交易', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addEntry(_entry('exp', bookId))
      ..addEntry(
        _entry('inc', bookId, type: EntryType.income, category: 'salary'),
      );

    // 目标是支出分类 transport，收入交易应被跳过。
    final changed = controller.setEntriesCategory(<String>{
      'exp',
      'inc',
    }, 'transport');
    expect(changed, 1);
    expect(
      controller.entries.firstWhere((e) => e.id == 'exp').categoryId,
      'transport',
    );
    expect(
      controller.entries.firstWhere((e) => e.id == 'inc').categoryId,
      'salary',
    );
    controller.dispose();
  });

  test('setEntriesAccount 批量改账户', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(_account('cash', bookId))
      ..addAccount(_account('card', bookId))
      ..addEntry(_entry('a', bookId, account: 'cash'))
      ..addEntry(_entry('b', bookId, account: 'cash'));
    final result = await controller.setEntriesAccount(<String>{
      'a',
      'b',
    }, 'card');
    expect(result.status, BatchAccountChangeStatus.success);
    expect(result.changed, 2);
    expect(controller.entries.every((e) => e.accountId == 'card'), isTrue);
    controller.dispose();
  });

  test('setEntriesAccount 拒绝把外币账户金额直接解释为目标账户币种', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    final usdAccount = _account('usd-account', bookId, currencyCode: 'USD');
    controller
      ..addAccount(usdAccount)
      ..addAccount(_account('card', bookId))
      ..addEntry(
        LedgerEntry(
          id: 'usd-entry',
          bookId: bookId,
          type: EntryType.expense,
          amount: 10,
          currencyCode: 'USD',
          accountAmount: 10,
          baseAmount: 72,
          conversionSource: ConversionSource.imported,
          categoryId: 'dining',
          accountId: usdAccount.id,
          note: '',
          occurredAt: DateTime(2026, 7, 4),
        ),
      );

    final candidates = controller.batchAccountChangeCandidates(<String>{
      'usd-entry',
    });
    expect(candidates.map((account) => account.currencyCode).toSet(), <String>{
      'USD',
    });
    final result = await controller.setEntriesAccount(<String>{
      'usd-entry',
    }, 'card');

    expect(result.status, BatchAccountChangeStatus.unsafeSelection);
    final unchanged = controller.entries.single;
    expect(unchanged.accountId, usdAccount.id);
    expect(unchanged.accountAmount, 10);
    expect(unchanged.baseAmount, 72);
    controller.dispose();
  });

  testWidgets('交易列表多选并批量删除', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'cash',
          bookId: bookId,
          name: '现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 0,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addEntry(_entry('a', bookId))
      ..addEntry(_entry('b', bookId))
      ..dispose();

    await pumpApp(tester, store);
    await tester.tap(find.text('最近交易'));
    await tester.pumpAndSettle();

    // 进入多选模式，点选两笔，删除。
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(find.text('暂无交易'), findsOneWidget);
  });

  testWidgets('批量改分类弹出的是多级分类选择器（按类型分区）', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller
      ..addEntry(_entry('a', bookId))
      ..addEntry(_entry('b', bookId))
      ..dispose();

    await pumpApp(tester, store);
    await tester.tap(find.text('最近交易'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('改分类'));
    await tester.pumpAndSettle();

    // 新的多级分类选择器按类型分区、每区带类型标题（旧的扁平弹窗没有）。
    expect(find.text('支出'), findsWidgets);
  });

  testWidgets('批量改账户弹出的账户选择器展示余额', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(_account('cash', bookId))
      ..addAccount(
        Account(
          id: 'zs',
          bookId: bookId,
          name: '招商',
          type: AccountType.debitCard,
          groupId: null,
          initialBalance: 12340,
          iconCode: 'bank',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addEntry(_entry('a', bookId))
      ..addEntry(_entry('b', bookId))
      ..dispose();

    await pumpApp(tester, store);
    await tester.tap(find.text('最近交易'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('改账户'));
    await tester.pumpAndSettle();

    // 新的账户选择器每行显示余额（旧的扁平弹窗只有账户名）。
    expect(find.text('12340'), findsOneWidget);
  });
}
