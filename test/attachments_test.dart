import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

const String _img = 'data:image/jpeg;base64,AAAA';

// 合法的 1x1 PNG，供需要真实解码的 widget 测试使用。
const String _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC';

LedgerEntry _entry(String id, String bookId) => LedgerEntry(
  id: id,
  bookId: bookId,
  type: EntryType.expense,
  amount: 10,
  categoryId: 'dining',
  accountId: 'cash',
  note: '',
  occurredAt: DateTime(2026, 7, 4),
);

void main() {
  useTestDatabases();

  test('addAttachment / removeAttachment', () async {
    final controller = await makeController();
    controller.addEntry(_entry('e1', controller.activeBook.id));
    controller.addAttachment('e1', _img);
    controller.addAttachment('e1', 'data:image/jpeg;base64,BBBB');
    expect(controller.attachmentCountForEntry('e1'), 2);

    final first = controller.attachmentsForEntry('e1').first;
    controller.removeAttachment(first.id);
    expect(controller.attachmentCountForEntry('e1'), 1);
    controller.dispose();
  });

  test('deleteEntry 级联删除其附件', () async {
    final controller = await makeController();
    controller.addEntry(_entry('e1', controller.activeBook.id));
    controller.addAttachment('e1', _img);
    expect(controller.attachmentCountForEntry('e1'), 1);

    await controller.deleteEntry('e1');
    expect(controller.attachmentCountForEntry('e1'), 0);
    controller.dispose();
  });

  test('附件随导出/导入往返', () async {
    final source = await makeController();
    source.addEntry(_entry('e1', source.activeBook.id));
    source.addAttachment('e1', _img);
    final backup = source.exportDataJson();
    source.dispose();

    final target = await makeController();
    target.importDataJson(backup);
    expect(target.attachmentsForEntry('e1').single.dataUrl, _img);
    target.dispose();
  });

  test('附件写入仓储并被同 store 的新控制器读回', () async {
    final store = LocalKeyValueStore();
    final first = await makeController(store);
    first.addEntry(_entry('e1', first.activeBook.id));
    first.addAttachment('e1', _img);
    first.dispose();

    final second = await makeController(store);
    expect(second.attachmentsForEntry('e1').single.dataUrl, _img);
    second.dispose();
  });

  testWidgets('交易详情展示并可删除图片附件', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller
      ..addAccount(
        Account(
          id: 'cash-att',
          bookId: controller.activeBook.id,
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
      ..addEntry(
        LedgerEntry(
          id: 'att-entry',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 20,
          categoryId: 'dining',
          accountId: 'cash-att',
          note: '票据',
          occurredAt: DateTime.now(),
        ),
      )
      ..addAttachment('att-entry', _png)
      ..dispose();

    await pumpApp(tester, store);
    await tester.tap(find.text('最近交易'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('图片附件'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // 详情页出现附件区，1 张。
    expect(find.text('图片附件'), findsOneWidget);
    expect(find.text('1 张'), findsOneWidget);

    // 点击缩略图右上角删除。
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('0 张'), findsOneWidget);
  });
}
