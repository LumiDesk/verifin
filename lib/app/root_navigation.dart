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

/// 根页面列表在浮动导航后方绘制时所需的内容留白。
EdgeInsets veriRootPageListPadding(BuildContext context) {
  final layout = context
      .dependOnInheritedWidgetOfExactType<_VeriRootNavigationLayout>();
  return EdgeInsets.fromLTRB(
    14,
    8,
    14,
    layout?.listBottomPadding ?? MediaQuery.paddingOf(context).bottom + 12,
  );
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
  bool _suppressNextDestinationTap = false;

  Key _key(String suffix) => ValueKey('${widget.keyPrefix}_$suffix');

  @override
  void initState() {
    super.initState();
    assert(widget.destinations.isNotEmpty);
    assert(widget.currentIndex >= 0);
    assert(widget.currentIndex < widget.destinations.length);
  }

  void _handleDestinationTap(int index) {
    if (_suppressNextDestinationTap) {
      _suppressNextDestinationTap = false;
      return;
    }
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

  /// 处理一次原始指针点击。
  ///
  /// 不能只靠条目自身的 InkWell：底栏是自身的 Stack，条目上的点击与底栏的
  /// 命中区域会重叠，这里统一按点击位置换算成条目下标，并用
  /// [_suppressNextDestinationTap] 吞掉随后到来的那次条目点击，避免一次点按
  /// 切两次页。
  void _handleTapUp(TapUpDetails details) {
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    final slot = width / widget.destinations.length;
    final index = (details.localPosition.dx / slot).floor().clamp(
      0,
      widget.destinations.length - 1,
    );
    _suppressNextDestinationTap = true;
    _handleDestinationTap(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressNextDestinationTap = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 停靠底栏自带不透明背景，必须让出系统手势条，否则最下面会被系统导航盖住。
    // 再加一层实色底衬：`extendBody` 下滚动内容会画到这一层里，只靠库自身的
    // 背景色会透出下面的日历/列表。
    final surface = veriElevatedSurfaceColor(Theme.of(context).brightness);
    return SafeArea(
      top: false,
      child: Stack(
        key: _key('bottom_nav'),
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          // 实色底衬：`extendBody` 下滚动内容会画到这一层，只靠库自身的背景色
          // 会透出下面的日历/列表。放在底栏之下，不参与它的动画绘制。
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
          ),
          // 停靠底栏：整宽、贴底，条目动画由 bottom_bar_matu 提供。
          // 不覆盖 circle1/2Color：库用它们画选中时的小圆点，强制成同一个亮色会
          // 在条目上糊出一条色块。
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTapUp,
            child: BottomBarDoubleBullet(
              key: _key('nav_bar'),
              selectedIndex: widget.currentIndex,
              height: VeriRootNavigationBody.barHeight,
              items: <BottomBarItem>[
                for (var index = 0; index < widget.destinations.length; index++)
                  BottomBarItem(
                    iconData: widget.destinations[index].icon,
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
        ],
      ),
    );
  }
}
