import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('addTag 去重、renameTag、reorderTags', () async {
    final controller = await makeController();
    final a = controller.addTag('工作');
    final b = controller.addTag('  工作  '); // 去空白后重复，返回同一 id
    expect(a, isNotNull);
    expect(b, a);
    expect(controller.tags.length, 1);

    controller.addTag('旅行');
    expect(controller.tags.map((t) => t.label).toList(), <String>['工作', '旅行']);
    controller.reorderTags(1, 0);
    expect(controller.tags.map((t) => t.label).toList(), <String>['旅行', '工作']);

    controller.renameTag(a!, '上班');
    expect(controller.tagById(a)!.label, '上班');
    controller.dispose();
  });

  test('deleteTag 同时从交易移除引用', () async {
    final controller = await makeController();
    final tagId = controller.addTag('报销')!;
    controller.addEntry(
      LedgerEntry(
        id: 'e1',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 30,
        categoryId: 'dining',
        accountId: 'cash',
        note: '',
        occurredAt: DateTime(2026, 7, 4),
        tagIds: <String>[tagId],
      ),
    );
    expect(controller.tagUsageCount(tagId), 1);

    await controller.deleteTag(tagId);
    expect(controller.tagById(tagId), isNull);
    expect(controller.entries.single.tagIds, isEmpty);
    controller.dispose();
  });

  test('标签与交易标签随导出/导入往返', () async {
    final source = await makeController();
    final tagId = source.addTag('必要开销')!;
    source.addEntry(
      LedgerEntry(
        id: 'e1',
        bookId: source.activeBook.id,
        type: EntryType.expense,
        amount: 12,
        categoryId: 'dining',
        accountId: 'cash',
        note: '',
        occurredAt: DateTime(2026, 7, 4),
        tagIds: <String>[tagId],
      ),
    );
    final backup = source.exportDataJson();
    source.dispose();

    final target = await makeController();
    target.importDataJson(backup);
    expect(target.tags.map((t) => t.label), contains('必要开销'));
    expect(target.entries.single.tagIds, <String>[tagId]);
    target.dispose();
  });

  test('标签写入仓储并被同 store 的新控制器读回', () async {
    final store = LocalKeyValueStore();
    final first = await makeController(store);
    first.addTag('复购');
    first.dispose();

    final second = await makeController(store);
    expect(second.tags.map((t) => t.label), contains('复购'));
    second.dispose();
  });
}
