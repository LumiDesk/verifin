// 测试共享脚手架：控制器构造与常用 UI 操作助手。
//
// 账目类数据现只经 [LedgerRepository]。widget / 控制器逻辑测试注入
// [InMemoryLedgerRepository]（同步、无真实 I/O，兼容 testWidgets 的 fake-async）；
// 数据层真实 SQLite 覆盖见 test/data/。用 [makeController]/[pumpApp] 取代旧的
// 同步 `VeriFinController(store)`；相同 store 复用同一内存仓储（模拟同设备重启后
// 重新载入），传入新 store 则得到隔离仓储。每个测试文件 main() 顶部调用
// [useTestDatabases] 注册清理。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/data/ledger_repository.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/main.dart';

import 'in_memory_ledger_repository.dart';

final Map<LocalKeyValueStore, LedgerRepository> _repoForStore =
    <LocalKeyValueStore, LedgerRepository>{};

/// 在测试 main() 顶部调用：每个用例后重置 store→仓储映射，保证用例间隔离。
void useTestDatabases() {
  tearDown(_repoForStore.clear);
}

/// 构造控制器：相同 [store] 复用同一内存仓储；省略/新 store 则得到独立仓储。
Future<VeriFinController> makeController([LocalKeyValueStore? store]) async {
  final resolvedStore = store ?? LocalKeyValueStore();
  final repository = _repoForStore.putIfAbsent(
    resolvedStore,
    InMemoryLedgerRepository.new,
  );
  return VeriFinController.create(resolvedStore, repository: repository);
}

/// 构造控制器并 pump 进 [VeriFinApp]，返回控制器（可用于断言）。
Future<VeriFinController> pumpApp(
  WidgetTester tester, [
  LocalKeyValueStore? store,
]) async {
  final controller = await makeController(store);
  await tester.pumpWidget(VeriFinApp(controller: controller));
  return controller;
}

Future<void> tapBottomTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('main_tab_$index')));
  await tester.pumpAndSettle();
}

Future<void> addTestAccount(WidgetTester tester, String name) async {
  await tapBottomTab(tester, 1);
  await tester.tap(find.byTooltip('资产操作'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('添加账户'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, name);
  await tester.tap(find.byTooltip('保存账户'));
  await tester.pumpAndSettle();
}

Future<void> createQuickEntry(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('quick_entry_fab')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('number_key_4')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('number_key_5')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('number_pad_ok')));
  await tester.pumpAndSettle();
}
