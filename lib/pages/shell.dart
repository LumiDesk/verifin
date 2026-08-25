import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'onboarding_page.dart';
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
      // 隐私政策 / 用户协议同意由 PrivacyConsentGate 门卫处理；本壳只在同意后
      // 才会被构建，故此处直接展示新用户引导。
      await _maybeShowOnboarding();
      if (!mounted) {
        return;
      }
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

  /// 新用户首启动展示引导页；已完成则跳过。
  Future<void> _maybeShowOnboarding() async {
    if (VeriFinScope.of(context).onboardingCompleted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => const OnboardingPage(),
      ),
    );
  }

  @override
  void dispose() {
    AppCaptureBridge.clearQuickEntryHandler();
    AppCaptureBridge.clearSharedCaptureHandler();
    _pageController.dispose();
    super.dispose();
  }

  /// 切换到指定 Tab：底部导航点击与返回键均走此入口，带一段短动画。
  ///
  /// 跨多页动画会依次触发中间页的 [PageView.onPageChanged]；这些页只是过场，
  /// 不能反向覆盖导航滑块正在吸附的最终目标。直接手势翻页时没有 programmatic
  /// target，仍由 [_handlePageChanged] 正常同步导航。
  void _goToTab(int index) {
    if (_programmaticPageTarget == null && index == _index) {
      return;
    }
    setState(() {
      _index = index;
      _programmaticPageTarget = index;
    });
    unawaited(
      _pageController
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
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
        extendBody: true,
        // 四个主页面横向 PageView：左右滑动切换。图表（onHorizontalDrag）与
        // 交易行 Dismissible 都是更深层的手势消费者，会在竞技场里本地胜出，
        // 故在图表/可滑删行上拖动仍走各自交互，仅空白区滑动才切页。
        body: SafeArea(
          key: const Key('main_shell_body_safe_area'),
          bottom: false,
          child: VeriRootNavigationBody(
            child: PageView(
              controller: _pageController,
              onPageChanged: _handlePageChanged,
              children: pages,
            ),
          ),
        ),
        bottomNavigationBar: VeriRootNavigation(
          currentIndex: _index,
          destinations: destinations,
          onDestinationSelected: _goToTab,
          quickEntryLabel: l10n.quickEntry,
          showQuickEntry: _index == 0,
          onQuickEntryTap: () => _startQuickEntry(context),
          onQuickEntryLongPress: () =>
              _startQuickEntry(context, longPress: true),
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
