import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('note auto-selects the category learned from history', (
    tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    // 历史：多笔「打车」都记在交通分类下。
    for (var i = 0; i < 4; i++) {
      controller.addEntry(
        LedgerEntry(
          id: 'hist-$i',
          bookId: bookId,
          type: EntryType.expense,
          amount: 20,
          categoryId: 'transport',
          accountId: '',
          note: '打车',
          occurredAt: DateTime(2026, 7, i + 1, 9),
        ),
      );
    }

    await pumpApp(tester, store);
    await tapBottomTab(tester, 0);
    await createQuickEntry(tester);

    // 输入含「打车」的备注 → 自动识别为交通并选中，且出现「已自动推荐」提示。
    await tester.enterText(find.byKey(const Key('entry_note_field')), '打车上班');
    await tester.pump();

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '交通'),
    );
    expect(chip.selected, isTrue);
    expect(find.text('已自动推荐'), findsOneWidget);

    // 用户手动改选餐饮后，不再被自动推荐覆盖。
    await tester.tap(find.widgetWithText(ChoiceChip, '餐饮'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('entry_note_field')), '打车回家');
    await tester.pump();
    final dining = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '餐饮'),
    );
    expect(dining.selected, isTrue);
    expect(find.text('已自动推荐'), findsNothing);
  });
}
