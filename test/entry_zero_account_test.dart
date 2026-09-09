import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/entry_detail_page.dart';

import 'support/test_harness.dart';

/// 保存按钮当前是否可点（禁用时 onPressed 为 null）。
bool _saveEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find.byKey(const Key('save_entry_button')),
  );
  return button.onPressed != null;
}

void main() {
  useTestDatabases();

  testWidgets('零账户时记账页给出「添加账户」出口，建好后即可保存', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);

    final controller = await makeController();
    expect(controller.accounts, isEmpty);

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const EntryDetailPage(initialAmount: 30)),
      ),
    );
    await tester.pumpAndSettle();

    // 没有账户时不能保存。
    expect(_saveEnabled(tester), isFalse);
    // 而且要说清楚为什么：按钮灰着不解释，用户只会以为应用坏了。
    expect(find.text('请先添加账户，或选择「无账户」'), findsOneWidget);

    // 空状态必须给出可用出口，否则用户在这页没有任何自救办法。
    final action = find.byKey(const Key('entry_add_account_action'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();

    // 就地建一个账户并返回。
    await tester.enterText(find.byType(TextFormField).first, '现金');
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(controller.accounts.length, 1);
    // 关键回归点：返回后必须能直接保存。金额解析只在首次进页面跑过一次，
    // 不补这一次，保存按钮会一直禁用。
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('缺金额时保存按钮说明「请先输入金额」', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);

    final controller = await makeController();
    controller.addAccount(
      Account(
        id: 'acc-cash',
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
    );

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const EntryDetailPage(initialAmount: 0)),
      ),
    );
    await tester.pumpAndSettle();

    expect(_saveEnabled(tester), isFalse);
    expect(find.text('请先输入金额'), findsOneWidget);
  });
}
