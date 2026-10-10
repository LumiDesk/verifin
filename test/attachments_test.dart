import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/backup_archive.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

const String _img = 'data:image/jpeg;base64,AAAA';

// 合法的 1x1 PNG，供需要真实解码的 widget 测试使用。
const String _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC';

Uint8List _bytesOf(String dataUrl) =>
    base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));

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
    await controller.addAttachment('e1', _bytesOf(_img));
    await controller.addAttachment(
      'e1',
      _bytesOf('data:image/jpeg;base64,BBBB'),
    );
    expect(controller.attachmentCountForEntry('e1'), 2);

    final first = controller.attachmentsForEntry('e1').first;
    expect(
      await controller.attachmentStore.readBytes(first.id),
      _bytesOf(_img),
    );
    controller.removeAttachment(first.id);
    expect(controller.attachmentCountForEntry('e1'), 1);
    controller.dispose();
  });

  test('deleteEntry 级联删除其附件', () async {
    final controller = await makeController();
    controller.addEntry(_entry('e1', controller.activeBook.id));
    await controller.addAttachment('e1', _bytesOf(_img));
    expect(controller.attachmentCountForEntry('e1'), 1);

    await controller.deleteEntry('e1');
    expect(controller.attachmentCountForEntry('e1'), 0);
    controller.dispose();
  });

  test('附件随备份压缩包往返（字节经附件存储，不进 JSON）', () async {
    final source = await makeController();
    source.addEntry(_entry('e1', source.activeBook.id));
    await source.addAttachment('e1', _bytesOf(_img));

    // 元数据 JSON 不再内嵌 base64，附件字节只在 zip 条目里。
    expect(source.exportDataJson(), isNot(contains('data:image/jpeg;base64')));
    final dir = await Directory.systemTemp.createTemp('verifin_att_archive');
    final archivePath = '${dir.path}${Platform.pathSeparator}backup.zip';
    try {
      await packBackupArchiveToFile(
        exportJson: source.exportDataJson(),
        store: source.attachmentStore,
        outputPath: archivePath,
      );

      final target = await makeController();
      final staging = await target.attachmentStore.createStagingStore();
      try {
        final json = await unpackBackupArchiveFile(
          archivePath: archivePath,
          sink: staging,
        );
        await target.importDataJson(
          json,
          readStagedAttachment: staging.readBytes,
        );
        final restored = target.attachmentsForEntry('e1').single;
        expect(
          await target.attachmentStore.readBytes(restored.id),
          _bytesOf(_img),
        );
      } finally {
        await target.attachmentStore.discardStagingStore(staging);
      }
      target.dispose();
    } finally {
      await dir.delete(recursive: true);
    }
    source.dispose();
  });

  test('附件写入存储并被同 store 的新控制器读回', () async {
    final store = LocalKeyValueStore();
    final first = await makeController(store);
    first.addEntry(_entry('e1', first.activeBook.id));
    await first.addAttachment('e1', _bytesOf(_img));
    first.dispose();

    final second = await makeController(store);
    final attachment = second.attachmentsForEntry('e1').single;
    expect(
      await second.attachmentStore.readBytes(attachment.id),
      _bytesOf(_img),
    );
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
      );
    await controller.addAttachment('att-entry', _bytesOf(_png));
    controller.dispose();

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

  testWidgets('长按缩略图也能删除图片附件', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller
      ..addAccount(
        Account(
          id: 'cash-att-longpress',
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
          id: 'att-entry-longpress',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 20,
          categoryId: 'dining',
          accountId: 'cash-att-longpress',
          note: '票据',
          occurredAt: DateTime.now(),
        ),
      );
    await controller.addAttachment('att-entry-longpress', _bytesOf(_png));
    controller.dispose();

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
    expect(find.text('1 张'), findsOneWidget);

    // 长按缩略图本体删除，不必去点右上角的小叉。
    await tester.longPress(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.text('0 张'), findsOneWidget);
  });
}
