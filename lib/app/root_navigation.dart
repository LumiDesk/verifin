import 'package:bottom_bar_matu/bottom_bar_matu.dart';

import 'package:flutter/material.dart';

import 'app_theme.dart';

@immutable
class VeriNavigationDestination {
  const VeriNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// 隔离 `Scaffold.extendBody` 注入的底栏 padding。
///
/// Flutter 的嵌套 ScrollView 会在 `padding == null` 时自动继承 MediaQuery
/// padding；若直接把底栏高度传下去，日历和功能宫格会凭空增高。此组件先保存根
/// 列表所需的真实避让高度，再从页面子树移除 bottom padding。
class VeriRootNavigationBody extends StatelessWidget {
  const VeriRootNavigationBody({super.key, required this.child});

  /// 停靠底栏的内容高度（不含系统安全区）。
  static const double barHeight = 64;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _VeriRootNavigationLayout(
      // 停靠底栏不透明且 Scaffold 已为它让位，列表末项只需少量留白。
      listBottomPadding: 12,
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: child,
      ),
    );
  }
}

class _VeriRootNavigationLayout extends InheritedWidget {
  const _VeriRootNavigationLayout({
    required this.listBottomPadding,
    required super.child,
  });

  final double listBottomPadding;

  @override
  bool updateShouldNotify(_VeriRootNavigationLayout oldWidget) {
    return oldWidget.listBottomPadding != listBottomPadding;
  }
}

/// 根页面列表的默认内边距（横向页边距 14、顶部 8、底部留白）。
///
/// 底栏已改为停靠式：`Scaffold` 会为它让出空间，列表末项不再需要按底栏高度避让，
/// 底部只需一点呼吸空间。[VeriRootNavigationBody] 仍负责把 Scaffold 注入的
/// bottom padding 从页面子树里移除（否则未显式给 padding 的 GridView 会被撑高）。
EdgeInsets veriRootPageListPadding(BuildContext context) {
  final layout = context
      .dependOnInheritedWidgetOfExactType<_VeriRootNavigationLayout>();
  return EdgeInsets.fromLTRB(14, 8, 14, layout?.listBottomPadding ?? 12);
}

/// Veri Fin 根页面的停靠底栏。
///
/// 整宽、不透明、贴底（系统安全区之上）：条目由 `bottom_bar_matu` 绘制，
/// 选中项有气泡动效。快捷记账按钮不在这里——它由 Shell 放在右下角浮动。
class VeriRootNavigation extends StatefulWidget {
  const VeriRootNavigation({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    this.keyPrefix = 'main',
  });

  final int currentIndex;
  final List<VeriNavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final String keyPrefix;

  @override
  State<VeriRootNavigation> createState() => _VeriRootNavigationState();
}

class _VeriRootNavigationState extends State<VeriRootNavigation> {
  Key _key(String suffix) => ValueKey('${widget.keyPrefix}_$suffix');

  @override
  void initState() {
    super.initState();
    assert(widget.destinations.isNotEmpty);
    assert(widget.currentIndex >= 0);
    assert(widget.currentIndex < widget.destinations.length);
  }

  void _handleDestinationTap(int index) {
    // bottom_bar_matu 会在 didUpdateWidget 里同步回调 onSelect，也就是在整个构建
    // 过程中；此时切页会重建整棵树，抛「setState() called during build」。
    // 因此只记下意图，等这一帧结束再统一处理。
    _pendingSelection = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _pendingSelection;
      _pendingSelection = null;
      if (target == null) return;
      widget.onDestinationSelected(target);
    });
  }

  int? _pendingSelection;

  @override
  Widget build(BuildContext context) {
    // 表面色要一直铺到屏幕最底（含系统手势条背后），否则手势条区域会露出页面
    // 底色、和底栏分成两块。因此底衬在 SafeArea 之外，条目内容在 SafeArea 之内。
    final surface = veriElevatedSurfaceColor(Theme.of(context).brightness);
    final outline = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);

    return DecoratedBox(
      key: _key('bottom_nav'),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: outline)),
      ),
      child: SafeArea(
        top: false,
        child: BottomBarDoubleBullet(
          key: _key('nav_bar'),
          selectedIndex: widget.currentIndex,
          height: VeriRootNavigationBody.barHeight,
          items: <BottomBarItem>[
            for (var index = 0; index < widget.destinations.length; index++)
              BottomBarItem(
                // 未选中用线框图标、选中换填充图标：库的选中动画本身就是按
                // 「同一个位置切换图标」设计的，两种风格切换时动效最自然。
                iconData: index == widget.currentIndex
                    ? widget.destinations[index].selectedIcon
                    : widget.destinations[index].icon,
                iconSize: 24,
                label: widget.destinations[index].label,
                labelMarginTop: 2,
                labelTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
          color: veriRoyal,
          backgroundColor: Colors.transparent,
          onSelect: _handleDestinationTap,
        ),
      ),
    );
  }
}
