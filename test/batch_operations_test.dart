import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
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

    controller.deleteEntries(<String>{'a', 'b'});
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
      ..addEntry(_entry('a', bookId, account: 'cash'))
      ..addEntry(_entry('b', bookId, account: 'cash'));
    final changed = controller.setEntriesAccount(<String>{'a', 'b'}, 'card');
    expect(changed, 2);
    expect(controller.entries.every((e) => e.accountId == 'card'), isTrue);
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
}
