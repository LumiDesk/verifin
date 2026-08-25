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
import 'package:verifin/app/feedback.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/data/ledger_repository.dart';
import 'package:verifin/l10n/app_localizations.dart';
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
///
/// [acceptConsent] 默认为 true，预置隐私政策同意标记，使 widget 测试不被首启动
/// 同意弹窗阻塞；测试同意流程本身时传 false。
Future<VeriFinController> makeController([
  LocalKeyValueStore? store,
  bool acceptConsent = true,
]) async {
  final resolvedStore = store ?? LocalKeyValueStore();
  if (acceptConsent) {
    resolvedStore.write('verifin.privacy_consent.v1', 'true');
    // 跳过新用户引导页，避免 widget 测试被首启动引导阻塞。
    resolvedStore.write('verifin.onboarding.v1', 'true');
  }
  // 测试宿主系统语言是 en，「跟随系统」会渲染英文；固定中文让既有中文断言稳定。
  // 测试语言切换本身时可在用例里 setLocalePreference 覆盖。
  if (resolvedStore.read('verifin.locale.v1') == null) {
    resolvedStore.write('verifin.locale.v1', 'zh');
  }
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
  bool acceptConsent = true,
]) async {
  final controller = await makeController(store, acceptConsent);
  await tester.pumpWidget(VeriFinApp(controller: controller));
  return controller;
}

/// 不经 [VeriFinApp]、直接 pump 单页/单组件的测试用：固定中文并带上
/// 本地化代理的 MaterialApp（页面里的 `AppLocalizations.of` 才能解析）。
Widget zhMaterialApp({required Widget home, ThemeData? theme}) {
  return _LocalizedTestApp(home: home, theme: theme);
}

class _LocalizedTestApp extends StatefulWidget {
  const _LocalizedTestApp({required this.home, this.theme});

  final Widget home;
  final ThemeData? theme;

  @override
  State<_LocalizedTestApp> createState() => _LocalizedTestAppState();
}

class _LocalizedTestAppState extends State<_LocalizedTestApp> {
  final VeriFeedbackController _feedback = VeriFeedbackController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: widget.theme,
      builder: (context, child) => VeriFeedbackHost(
        controller: _feedback,
        bottomMargin: 0,
        child: child ?? const SizedBox.shrink(),
      ),
      home: widget.home,
    );
  }
}

Future<void> tapBottomTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('main_tab_$index')));
  await tester.pumpAndSettle();
}

/// 当前页面自身的纵向滚动视图。
///
/// 主壳用横向 [PageView] 承载四个 Tab（支持左右滑动切换页面），它本身也是一个
/// [Scrollable]，会排在 `find.byType(Scrollable).first` 之前——直接取 `.first`
/// 会误命中横向的 PageView。此助手按滚动轴过滤，只取纵向 Scrollable，
/// 在已 push 的子页（PageView 变 offstage、不在场）下同样正确。
Finder firstVerticalScrollable() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up),
    )
    .first;

Future<void> addTestAccount(WidgetTester tester, String name) async {
  await tapBottomTab(tester, 1);
  await tester.tap(find.byTooltip('资产操作'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('添加账户'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, name);
  await tester.pump();
  await tester.tap(find.byTooltip('保存'));
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
