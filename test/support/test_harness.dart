// 测试共享脚手架：控制器构造与常用 UI 操作助手。
//
// 账目类数据现只经 [LedgerRepository]。widget / 控制器逻辑测试注入
// [InMemoryLedgerRepository]（同步、无真实 I/O，兼容 testWidgets 的 fake-async）；
// 数据层真实 SQLite 覆盖见 test/repository_test.dart、test/controller_persistence_test.dart、
// test/migration_matrix_test.dart。用 [makeController]/[pumpApp] 取代旧的
// 同步 `VeriFinController(store)`；相同 store 复用同一内存仓储（模拟同设备重启后
// 重新载入），传入新 store 则得到隔离仓储。每个测试文件 main() 顶部调用
// [useTestDatabases] 注册清理。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/attachments/attachment_store.dart';
import 'package:verifin/app/feedback.dart';
import 'package:verifin/app/haptics.dart';
import 'package:verifin/app/logging/app_logger.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/data/ledger_repository.dart';
import 'package:verifin/l10n/app_localizations.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/main.dart';

import 'in_memory_ledger_repository.dart';

final Map<LocalKeyValueStore, LedgerRepository> _repoForStore =
    <LocalKeyValueStore, LedgerRepository>{};

/// 附件存储同样按 store 复用：附件字节是「设备上的数据」，与仓储一样跨控制器重建保留。
final Map<LocalKeyValueStore, AttachmentStore> _attachmentsForStore =
    <LocalKeyValueStore, AttachmentStore>{};

/// 在测试 main() 顶部调用：每个用例后重置 store→仓储映射，保证用例间隔离。
void useTestDatabases() {
  // 直接用 VeriFinController.create 的用例也走内存附件存储，避免测试宿主缺少
  // path_provider 插件；生产入口必须显式注入 FileAttachmentStore。
  setUp(() {
    VeriFinController.debugDefaultAttachmentStore = InMemoryAttachmentStore();
    // 触感闸门是全局镜像：用例之间必须复位，否则关过开关的用例会污染后续断言。
    VeriHaptics.reset();
  });
  tearDown(() {
    _repoForStore.clear();
    _attachmentsForStore.clear();
    VeriFinController.debugDefaultAttachmentStore = null;
    VeriHaptics.reset();
  });
}

/// 可复现的测试 id 生成器：分类按**种子顺序**返回历史形态的 id（`dining`、`transport`…），
/// 用完之后回落到 `<prefix>_<n>`；其它实体沿用「前缀 + 时间戳 + 序号」形态。
///
/// 生产环境的分类 id 是随机生成的纯标识（语义看 [Category.key]，见
/// lib/app/models/category_keys.dart）。既有测试夹具普遍按可读 id
/// （`categoryId: 'dining'`）引用种子分类，这里注入确定性生成器复现同一形态，
/// 避免为了 id 形态改写大量与本次改动无关的用例。
///
/// **前提**：默认账本总是第一个被播种的账本（`_loadFromRepository` 会把它排在最前），
/// 所以它拿到这批可读 id；后续新建账本的分类拿到的是回落的 opaque id。
String Function(String prefix) deterministicTestIds() {
  var categoryCalls = 0;
  var seq = 0;
  return (prefix) {
    if (prefix == 'category' && categoryCalls < defaultCategoryKeys.length) {
      return defaultCategoryKeys[categoryCalls++];
    }
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${seq++}';
  };
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
  final attachmentStore = _attachmentsForStore.putIfAbsent(
    resolvedStore,
    InMemoryAttachmentStore.new,
  );
  return createTestController(
    resolvedStore,
    repository: repository,
    attachmentStore: attachmentStore,
  );
}

/// 直接构造控制器的测试用例统一入口：与 [makeController] 一样注入确定性 id 生成器，
/// 让按可读 id 引用种子分类的夹具在真实仓储（如 SQLite）用例里同样成立。
Future<VeriFinController> createTestController(
  LocalKeyValueStore store, {
  required LedgerRepository repository,
  AttachmentStore? attachmentStore,
  AppLogger? logger,
  bool systemIsEnglish = false,
}) => VeriFinController.create(
  store,
  repository: repository,
  attachmentStore: attachmentStore,
  logger: logger,
  systemIsEnglish: systemIsEnglish,
  idFactory: deterministicTestIds(),
);

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

/// 底栏第 [index] 个条目的中心点。
///
/// 按条目的稳定 key 定位：根导航样式契约要求每个样式为条目产出
/// `<前缀>_nav_item_<下标>`，因此这里不依赖任何样式的几何形状（等宽、间距、外边距）。
/// 不用 `find.byType(Text).at(i)` 定位条目：底栏把标签和图标裹在不参与命中测试的图层里
/// （`VeriBottomBar` 里是 `IgnorePointer` / 原库的同类处理），直接 tap 那个 Text 会
/// 触发 "would not hit test on the specified widget" 警告（虽然点击位置仍落在条目
/// 点击区，功能是对的）。
Offset rootTabCenter(WidgetTester tester, int index) {
  return tester.getCenter(find.byKey(ValueKey<String>('main_nav_item_$index')));
}

Future<void> tapBottomTab(WidgetTester tester, int index) async {
  // 按位置点而不是按文案：测试可能已把界面切成英文，中文标签会找不到。
  await tester.tapAt(rootTabCenter(tester, index));
  // 先推进固定帧数把底栏的 250ms 选中动效和弹簧切页动画走完（同一时间尺度），再 settle
  // 等页面首帧内容（懒加载的列表项等）构建完。`pumpAndSettle` 单用也能收敛，这里
  // 显式推进是为了不依赖「动画恰好自行停下」这一点。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// 切到看板并选中「月统计」Tab。看板默认落在「日常」Tab，断言原有月度面板的
/// 用例必须先切过去（脚手架默认固定中文，故按文案点）。
Future<void> openReportsMonthlyTab(WidgetTester tester) async {
  await tapBottomTab(tester, 2);
  await tester.tap(find.text('月统计').first);
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
