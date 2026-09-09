import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/entry_detail_page.dart';

import 'support/test_harness.dart';

/// 记账页是懒加载列表，账户为空时会在账户位置渲染带操作的空状态，备注框可能被挤到
/// 视口外而尚未构建。先滚动到备注框，再读/写它。
Future<void> _ensureNoteVisible(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('entry_note_field')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

Account _account(String id, String bookId, String name) => Account(
  id: id,
  bookId: bookId,
  name: name,
  type: AccountType.cash,
  groupId: null,
  initialBalance: 0,
  iconCode: 'cash',
  note: '',
  includeInAssets: true,
  hidden: false,
);

/// 交通分类历史：都用 [accountId] 付、金额 20、备注「打车」。
void _seedTransportHistory(
  VeriFinController controller,
  String bookId, {
  required String accountId,
}) {
  for (var i = 0; i < 4; i++) {
    controller.addEntry(
      LedgerEntry(
        id: 'hist-$i',
        bookId: bookId,
        type: EntryType.expense,
        amount: 20,
        categoryId: 'transport',
        accountId: accountId,
        note: '打车',
        occurredAt: DateTime(2026, 7, i + 1, 9),
      ),
    );
  }
}

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

    // 输入含「打车」的备注 → 自动识别为交通并选中（无可见提示文本）。
    await _ensureNoteVisible(tester);
    await tester.enterText(find.byKey(const Key('entry_note_field')), '打车上班');
    // 备注识别有防抖，先让计时器到点。
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('entry_category_selected_transport')),
      findsOneWidget,
    );

    // 用户手动改选餐饮后，不再被自动识别覆盖。
    await tester.scrollUntilVisible(
      find.byKey(const Key('entry_category_dining')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('entry_category_dining')));
    await tester.pump();
    await _ensureNoteVisible(tester);
    await tester.enterText(find.byKey(const Key('entry_note_field')), '打车回家');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('entry_category_selected_dining')),
      findsOneWidget,
    );
  });

  testWidgets('re-entering a learned amount infers type, category and note', (
    tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    // 历史：88 元都记为收入·利息·备注「利息」。
    for (var i = 0; i < 2; i++) {
      controller.addEntry(
        LedgerEntry(
          id: 'inc-$i',
          bookId: bookId,
          type: EntryType.income,
          amount: 88,
          categoryId: 'interest',
          accountId: '',
          note: '利息',
          occurredAt: DateTime(2026, 7, i + 1, 9),
        ),
      );
    }

    await pumpApp(tester, store);
    await tapBottomTab(tester, 0);

    // 再次输入 88 → 类型应自动切到收入、分类利息、备注回填「利息」。
    await tester.tap(find.byKey(const Key('quick_entry_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('number_key_8')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('number_key_8')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('entry_type_selected_income')), findsOneWidget);

    expect(
      find.byKey(const Key('entry_category_selected_interest')),
      findsOneWidget,
    );

    await _ensureNoteVisible(tester);
    final note = tester.widget<TextField>(
      find.byKey(const Key('entry_note_field')),
    );
    expect(note.controller?.text, '利息');
  });

  testWidgets('auto-suggest fills nothing once the setting is turned off', (
    tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    // 默认开启：老用户升级后行为不变。
    expect(controller.autoSuggestEnabled, isTrue);
    final bookId = controller.activeBook.id;
    // 与上一个用例同样的历史（88 元 → 收入·利息·备注「利息」）。
    for (var i = 0; i < 2; i++) {
      controller.addEntry(
        LedgerEntry(
          id: 'inc-$i',
          bookId: bookId,
          type: EntryType.income,
          amount: 88,
          categoryId: 'interest',
          accountId: '',
          note: '利息',
          occurredAt: DateTime(2026, 7, i + 1, 9),
        ),
      );
    }
    controller.setAutoSuggestEnabled(false);
    expect(store.read('verifin.auto_suggest.v1'), 'false');

    await pumpApp(tester, store);
    await tapBottomTab(tester, 0);

    await tester.tap(find.byKey(const Key('quick_entry_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('number_key_8')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('number_key_8')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();

    // 关掉后一切保持默认：类型仍是支出，备注仍为空。
    expect(
      find.byKey(const Key('entry_type_selected_expense')),
      findsOneWidget,
    );
    await _ensureNoteVisible(tester);
    final note = tester.widget<TextField>(
      find.byKey(const Key('entry_note_field')),
    );
    expect(note.controller?.text, isEmpty);
    expect(find.byKey(const Key('entry_category_interest')), findsNothing);
  });

  // issue #26：历史里有金额相近的退款条目时，记账页此前会被自动识别翻成「退款」
  // 类型，而退款没有任何分类，`categories.first` 抛 Bad state: No element → 白屏。
  testWidgets('refund history does not blank out the entry page', (
    tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    // 一笔原支出 + 两笔挂在它上面的小额退款（小额退款是常见真实场景）。
    controller.addEntry(
      LedgerEntry(
        id: 'exp-1',
        bookId: bookId,
        type: EntryType.expense,
        amount: 30,
        categoryId: 'dining',
        accountId: '',
        note: '外卖',
        occurredAt: DateTime(2026, 7, 20, 12),
      ),
    );
    for (var i = 0; i < 2; i++) {
      controller.addEntry(
        LedgerEntry(
          id: 'refund-$i',
          bookId: bookId,
          type: EntryType.refund,
          amount: 5,
          categoryId: '',
          accountId: '',
          note: '退款到账',
          refundOf: 'exp-1',
          settledAt: DateTime(2026, 7, 21 + i, 12),
          occurredAt: DateTime(2026, 7, 21 + i, 12),
        ),
      );
    }

    await pumpApp(tester, store);
    await tapBottomTab(tester, 0);

    // 输入与退款金额精确相同的 5 进入记账页。
    await tester.tap(find.byKey(const Key('quick_entry_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('number_key_5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();

    // 页面正常渲染（不白屏），且类型没被翻成退款。
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('entry_type_selected_expense')),
      findsOneWidget,
    );
    // 退款条目的备注也不该被带出。
    await _ensureNoteVisible(tester);
    final noteField = tester.widget<TextField>(
      find.byKey(const Key('entry_note_field')),
    );
    expect(noteField.controller?.text, isEmpty);
  });

  testWidgets('备注识别还没到防抖时间就保存时，仍按识别结果落账', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller.addAccount(
      Account(
        id: 'acc-flush',
        bookId: bookId,
        name: '现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 0,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      ),
    );
    for (var i = 0; i < 4; i++) {
      controller.addEntry(
        LedgerEntry(
          id: 'hist-flush-$i',
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

    final appController = await pumpApp(tester, store);
    await tapBottomTab(tester, 0);
    await createQuickEntry(tester);
    await _ensureNoteVisible(tester);

    await tester.enterText(find.byKey(const Key('entry_note_field')), '打车上班');
    // 不等 300ms 防抖，立刻保存：保存前必须把识别 flush 掉。
    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    final saved = appController.entries.firstWhere(
      (entry) => entry.note == '打车上班',
    );
    expect(
      saved.categoryId,
      'transport',
      reason: '保存前 flush 防抖，否则会按未识别的默认分类落账',
    );
  });

  testWidgets('自动识别开启时，账户跟随该分类上次用过的账户', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);

    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(_account('cash', bookId, '现金'))
      ..addAccount(_account('wechat', bookId, '微信'))
      // 账本默认账户是现金，但交通分类的历史习惯是微信。
      ..setDefaultAccountId('cash');
    _seedTransportHistory(controller, bookId, accountId: 'wechat');

    await pumpApp(tester, store);
    await tapBottomTab(tester, 0);
    await createQuickEntry(tester);

    // 新账默认用账本默认账户。
    expect(find.textContaining('现金'), findsWidgets);

    await tester.tap(find.byKey(const Key('entry_category_transport')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('微信'),
      findsWidgets,
      reason: '该分类上次用微信付，应预选微信而不是账本默认的现金',
    );
  });

  testWidgets('关闭自动识别时，账户仍只用账本默认账户', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);

    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(_account('cash', bookId, '现金'))
      ..addAccount(_account('wechat', bookId, '微信'))
      ..setDefaultAccountId('cash')
      ..setAutoSuggestEnabled(false);
    _seedTransportHistory(controller, bookId, accountId: 'wechat');

    await pumpApp(tester, store);
    await tapBottomTab(tester, 0);
    await createQuickEntry(tester);

    await tester.tap(find.byKey(const Key('entry_category_transport')));
    await tester.pumpAndSettle();

    expect(find.textContaining('现金'), findsWidgets);
    expect(
      find.textContaining('微信'),
      findsNothing,
      reason: '关掉自动识别后不该再从历史推断账户',
    );
  });

  testWidgets('自动识别填入的字段带淡标记，手动改动后消失', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);

    final controller = await makeController();
    final bookId = controller.activeBook.id;
    _seedTransportHistory(controller, bookId, accountId: '');

    // 金额 20 与历史精确相同：识别出分类与备注。
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const EntryDetailPage(initialAmount: 20)),
      ),
    );
    await tester.pumpAndSettle();

    // 分类被改写 → 分类旁出现「自动识别」标记；备注是识别填入的 → 后缀标记。
    expect(find.byKey(const Key('entry_category_auto_tag')), findsOneWidget);
    expect(find.text('自动识别'), findsWidgets);

    // 手动改选餐饮：分类的标记作废，不再显示。
    await tester.tap(find.byKey(const Key('entry_category_dining')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entry_category_auto_tag')), findsNothing);
  });

  testWidgets('切换类型会把分类重置为默认值，识别标记随之消失', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);

    final controller = await makeController();
    _seedTransportHistory(controller, controller.activeBook.id, accountId: '');

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const EntryDetailPage(initialAmount: 20)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entry_category_auto_tag')), findsOneWidget);

    // 切成「收入」：分类被换成收入类型的第一个分类，标记不能跟着留下。
    await tester.tap(find.byKey(const Key('entry_type_income')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entry_category_auto_tag')), findsNothing);
  });
}
