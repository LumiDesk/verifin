import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/platform_bridge.dart';
import '../app/veri_fin_scope.dart';
import '../app/models.dart';
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
  int _index = 0;
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    AppPlatformBridge.setQuickEntryHandler(_openQuickEntryFromPlatform);
    AppPlatformBridge.setSharedCaptureHandler(_openSharedCaptureFromPlatform);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 隐私政策 / 用户协议同意由 PrivacyConsentGate 门卫处理；本壳只在同意后
      // 才会被构建，故此处直接展示新用户引导。
      await _maybeShowOnboarding();
      if (!mounted) {
        return;
      }
      if (await AppPlatformBridge.consumeInitialQuickEntryIntent() && mounted) {
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
    AppPlatformBridge.clearQuickEntryHandler();
    AppPlatformBridge.clearSharedCaptureHandler();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const AssetsPage(),
      const ReportsPage(),
      const ProfilePage(),
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
        body: SafeArea(child: pages[_index]),
        // 自绘 FAB：由单个 InkWell 同时持有点击与长按（FloatingActionButton 内部
        // InkWell 会吞掉外层 GestureDetector 的长按，故不用它）。外观沿用 FAB 主题
        // 的 veriRoyal 圆角方形 + 白色加号。
        floatingActionButton: _index == 0
            ? Tooltip(
                message: AppLocalizations.of(context).quickEntry,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Material(
                    color: veriRoyal,
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(veriRadiusLg),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('quick_entry_fab'),
                      onTap: () => _startQuickEntry(context),
                      onLongPress: () =>
                          _startQuickEntry(context, longPress: true),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ),
              )
            : null,
        bottomNavigationBar: VeriBottomNav(
          currentIndex: _index,
          onTap: (value) => setState(() => _index = value),
        ),
      ),
    );
  }

  void _handleRootBack() {
    if (_index != 0) {
      setState(() => _index = 0);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).pressBackAgainToExit),
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
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).quickEntry,
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
      setState(() => _index = 0);
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

class VeriBottomNav extends StatelessWidget {
  const VeriBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <_NavItem>[
      _NavItem(Icons.home_outlined, Icons.home, l10n.tabHome),
      _NavItem(
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet,
        l10n.tabAssets,
      ),
      _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, l10n.tabReports),
      _NavItem(Icons.person_outline, Icons.person, l10n.tabProfile),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      key: const Key('main_bottom_nav'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0F12) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : veriLine),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: <Widget>[
              for (var index = 0; index < items.length; index += 1)
                Expanded(
                  child: _BottomNavButton(
                    key: Key('main_tab_$index'),
                    item: items[index],
                    selected: currentIndex == index,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? veriRoyal
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Tooltip(
      message: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Semantics(
          label: item.label,
          selected: selected,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: selected ? 42 : 38,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? veriRoyal.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  color: color,
                  size: selected ? 22 : 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
