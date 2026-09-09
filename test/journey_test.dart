import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/pages/home_page.dart';

import 'support/test_harness.dart';

/// 跨页面「核心旅程」测试：用完整 App（pumpApp）串起记账 → 首页 → 资产余额，
/// 验证一笔账在各页面口径一致。放在 test/（而非 device-only 的 integration_test/），
/// 以便 headless CI 也能真实执行。
void main() {
  useTestDatabases();

  testWidgets('切换根页面后首页保持存活，不整页重建', (tester) async {
    await pumpApp(tester);
    expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);

    await tapBottomTab(tester, 1);
    await tester.pumpAndSettle();
    // 保活：离屏的首页仍在树里，切回来不必重新构建整页与重跑聚合。
    expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);

    await tapBottomTab(tester, 3);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('记账旅程：记一笔支出，首页与资产余额同步更新且可累计', (tester) async {
    await pumpApp(tester);
    await addTestAccount(tester, '现金账户');
    await tapBottomTab(tester, 0); // 首页

    // 记一笔 45 支出（默认分类 餐饮）并保存。
    await createQuickEntry(tester);
    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    // 首页「最近交易」反映原币金额；单币种账本默认隐藏重复单位。
    expect(find.text('最近交易'), findsOneWidget);
    expect(find.text('-45'), findsAtLeastNWidgets(1));

    // 资产页：账户余额同步为 -45。
    await tapBottomTab(tester, 1);
    expect(find.text('现金账户'), findsAtLeastNWidgets(1));
    expect(find.text('-45'), findsAtLeastNWidgets(1));

    // 再记一笔 45 支出，账户余额累计到 -90。
    await tapBottomTab(tester, 0);
    await createQuickEntry(tester);
    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    await tapBottomTab(tester, 1);
    expect(find.text('-90'), findsAtLeastNWidgets(1));
  });
}
