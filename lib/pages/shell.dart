import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/models.dart';
import '../app/feedback.dart';
import '../app/platform_bridge.dart';
import '../app/root_navigation.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'ai_entry_sheet.dart';
import 'assets_pages.dart';
import 'capture_entry.dart';
import 'entry_detail_page.dart';
import 'home_page.dart';
import 'profile_pages.dart';
import 'reports_page.dart';
import 'sheets.dart';

class VeriFinShell extends StatefulWidget {
  const VeriFinShell({super.key});

  @override
  State<VeriFinShell> createState() => _VeriFinShellState();
}

class _VeriFinShellState extends State<VeriFinShell> {
  static const _rootPageCount = 4;

  int _index = 0;
  int? _programmaticPageTarget;
  DateTime? _lastBackPressedAt;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    AppCaptureBridge.setQuickEntryHandler(_openQuickEntryFromPlatform);
    AppCaptureBridge.setSharedCaptureHandler(_openSharedCaptureFromPlatform);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 同意与引导由外部门卫完成后才构建本壳。
      if (await AppCaptureBridge.consumeInitialQuickEntryIntent() && mounted) {
        await _openQuickEntryFromPlatform();
      }
      if (!mounted) {
        return;
      }
      // 冷启动带着分享/外部采集内容时（分享截图给 Veri Fin 等），开屏即识别。
      await startSharedCaptureEntry(context);
    });
  }

  @override
  void dispose() {
    AppCaptureBridge.clearQuickEntryHandler();
    AppCaptureBridge.clearSharedCaptureHandler();
    _pageController.dispose();
    super.dispose();
  }

  /// 切换到指定 Tab：底部导航点击与返回键均走此入口。
  ///
  /// 相邻两页之间播一段短动画；**跨多页（跨度大于一页）直接瞬移**。此前一律走
  /// 500ms 的 [PageController.animateToPage]，从第 4 个 Tab 回首页时要在半秒内扫过
  /// 三个整页，每个中间页都要跟着滚动、合成一遍，这就是「在别的页面按返回回首页」
  /// 时卡顿的来源。瞬移也符合用户预期（返回首页本来就该立刻到位）；底栏在同样跨度
  /// 下也不播过场动画（见 [VeriBottomBar]），两者仍然同时结束。
  ///
  /// 跨多页动画还会依次触发中间页的 [PageView.onPageChanged]；这些页只是过场，
  /// 不能反向覆盖导航滑块正在吸附的最终目标。直接手势翻页时没有 programmatic
  /// target，仍由 [_handlePageChanged] 正常同步导航。
  void _goToTab(int index) {
    if (_programmaticPageTarget == null && index == _index) {
      return;
    }
    final crossesMultiplePages = (index - _index).abs() > 1;
    setState(() {
      _index = index;
      _programmaticPageTarget = index;
    });
    if (crossesMultiplePages) {
      _pageController.jumpToPage(index);
      _programmaticPageTarget = null;
      return;
    }
    unawaited(
      _pageController
          .animateToPage(
            index,
            // 与底栏的选中动画同时长：点击后两者同时起步、同时结束。
            duration: VeriRootNavigation.switchDuration,
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(() {
            if (!mounted || _programmaticPageTarget != index) {
              return;
            }
            final settledIndex = (_pageController.page ?? index).round().clamp(
              0,
              _rootPageCount - 1,
            );
            setState(() {
              _index = settledIndex;
              _programmaticPageTarget = null;
            });
          }),
    );
  }

  void _handlePageChanged(int value) {
    final target = _programmaticPageTarget;
    if (target != null) {
      if (value == target) {
        _programmaticPageTarget = null;
      }
      return;
    }
    if (_index != value) {
      setState(() => _index = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = <Widget>[
      const HomePage(),
      const AssetsPage(),
      const ReportsPage(),
      const ProfilePage(),
    ];
    final destinations = <VeriNavigationDestination>[
      VeriNavigationDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: l10n.tabHome,
      ),
      VeriNavigationDestination(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        label: l10n.tabAssets,
      ),
      VeriNavigationDestination(
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart_rounded,
        label: l10n.tabReports,
      ),
      VeriNavigationDestination(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: l10n.tabProfile,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleRootBack();
      },
      child: Scaffold(
        key: const Key('main_shell_scaffold'),
        // 停靠底栏是不透明的，内容不再延伸到它背后（否则会被底栏盖住半截）。
        extendBody: false,
        // 四个主页面横向 PageView：左右滑动切换。图表（onHorizontalDrag）与
        // 交易行 Dismissible 都是更深层的手势消费者，会在竞技场里本地胜出，
        // 故在图表/可滑删行上拖动仍走各自交互，仅空白区滑动才切页。
        body: SafeArea(
          key: const Key('main_shell_body_safe_area'),
          bottom: false,
          child: Stack(
            children: <Widget>[
              VeriRootNavigationBody(
                child: RepaintBoundary(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _handlePageChanged,
                    // 保活四个根页面：离屏即卸载会让每次切回都整页重建，并重跑首页
                    // 与资产页的 O(账户数×交易数) 聚合。页面本身仍会随 Controller
                    // 通知重建，数据不会因为保活而过期。
                    children: <Widget>[
                      for (final page in pages) _KeepAlivePage(child: page),
                    ],
                  ),
                ),
              ),
              // 记账按钮：右下角浮动，压住内容之上；只在首页显示，进出带缩放淡入。
              // 圆角方形（veriRadiusLg）+ veriRoyal，与最初的设计一致；用自绘
              // Material+InkWell 而不是 FloatingActionButton，因为后者内部会吞掉
              // 长按，而长按要走 AI 记账。
              Positioned(
                key: const Key('quick_entry_fab_slot'),
                right: 16,
                bottom: 16,
                child: IgnorePointer(
                  ignoring: _index != 0,
                  child: AnimatedScale(
                    key: const Key('quick_entry_scale'),
                    scale: _index == 0 ? 1 : 0.7,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      key: const Key('quick_entry_opacity'),
                      opacity: _index == 0 ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Tooltip(
                          message: l10n.quickEntry,
                          child: Material(
                            key: const Key('quick_entry_fab'),
                            color: veriRoyal,
                            elevation: 6,
                            shadowColor: Colors.black.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(veriRadiusLg),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: const Key('quick_entry_action'),
                              onTap: () => _startQuickEntry(context),
                              onLongPress: () =>
                                  _startQuickEntry(context, longPress: true),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: VeriRootNavigation(
          currentIndex: _index,
          destinations: destinations,
          onDestinationSelected: _goToTab,
        ),
      ),
    );
  }

  void _handleRootBack() {
    if (_index != 0) {
      _goToTab(0);
      return;
    }
    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);
    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressedAt = now;
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: AppLocalizations.of(context).pressBackAgainToExit,
        duration: VeriFeedbackDuration.short,
        dedupeKey: 'root-exit',
      ),
    );
  }

  Future<void> _startQuickEntry(
    BuildContext context, {
    bool longPress = false,
  }) async {
    final controller = VeriFinScope.of(context);
    // 「点击手动·长按 AI」模式按手势区分；纯手动/纯 AI 模式两种手势一致。
    final useAi = switch (controller.fabActionMode) {
      FabActionMode.manual => false,
      FabActionMode.ai => true,
      FabActionMode.manualTapAiLongPress => longPress,
    };
    if (useAi) {
      await startAiEntry(context);
      return;
    }
    final defaultAccount = controller.defaultAccountId == null
        ? null
        : controller.accounts
              .where((account) => account.id == controller.defaultAccountId)
              .firstOrNull;
    final inputCurrencyCode =
        defaultAccount?.currencyCode ?? controller.activeBook.baseCurrencyCode;
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).quickEntry,
      showTitle: false,
      currencyCode: inputCurrencyCode,
    );

    if (!context.mounted || amount == null || amount <= 0) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => EntryDetailPage(
          initialAmount: amount,
          // 未设默认账户时为 null，记账页回落到首个账户（沿用原行为）。
          initialAccountId: controller.defaultAccountId,
        ),
      ),
    );
  }

  Future<void> _openQuickEntryFromPlatform() async {
    if (!mounted) {
      return;
    }
    if (_index != 0) {
      _goToTab(0);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted) {
      return;
    }
    await _startQuickEntry(context);
  }

  /// 应用运行中收到分享/外部采集内容（原生 onNewIntent 通知）时拉取并识别。
  Future<void> _openSharedCaptureFromPlatform() async {
    if (!mounted) {
      return;
    }
    await startSharedCaptureEntry(context);
  }
}

/// 让 PageView 里的根页面保持存活（`addAutomaticKeepAlives` 默认开启）。
/// 用包装类而不是给四个页面各自加 mixin：页面本身不必改成 StatefulWidget。
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
