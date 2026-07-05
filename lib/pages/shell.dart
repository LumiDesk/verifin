import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/entry_sheets.dart';
import '../app/platform_bridge.dart';
import '../app/veri_fin_scope.dart';
import '../app/models.dart';
import '../l10n/app_localizations.dart';
import 'ai_entry_sheet.dart';
import 'assets_pages.dart';
import 'entry_detail_page.dart';
import 'home_page.dart';
import 'onboarding_page.dart';
import 'profile_pages.dart';
import 'reports_page.dart';

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
        floatingActionButton: _index == 0
            ? FloatingActionButton(
                key: const Key('quick_entry_fab'),
                onPressed: () => _startQuickEntry(context),
                tooltip: AppLocalizations.of(context).quickEntry,
                child: const Icon(Icons.add),
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

  Future<void> _startQuickEntry(BuildContext context) async {
    // 记一笔按钮设为 AI 记账时，走自然语言解析入口；默认仍是手动记账。
    if (VeriFinScope.of(context).fabActionMode == FabActionMode.ai) {
      await startAiEntry(context);
      return;
    }
    final amount = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => NumberPadSheet(
        title: AppLocalizations.of(context).quickEntry,
        hapticsEnabled: VeriFinScope.of(context).hapticsEnabled,
      ),
    );

    if (!context.mounted || amount == null || amount <= 0) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => EntryDetailPage(initialAmount: amount),
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
