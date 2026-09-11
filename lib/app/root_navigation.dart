import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'veri_bottom_bar.dart';

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

/// 停靠底栏的最小底部留白（系统导航条留白为 0 时的保底值）。
///
/// 手势提示线关闭的机器上系统底部留白可能是 0；库把标签固定在条底 5dp，条目会直接
/// 贴住屏幕下边缘。给一个下限就不贴边了。取值与页面列表的底部留白一致。
const double _kMinBottomGap = 12;

/// Veri Fin 根页面的停靠底栏。
///
/// 整宽、不透明、贴底（系统安全区之上）：条目由本项目自有的 [VeriBottomBar] 绘制
/// （抄写自 `bottom_bar_matu` 并修复了图标 State 被反复重建等问题，见该文件头注释），
/// 选中项有气泡动效。快捷记账按钮不在这里——它由 Shell 放在右下角浮动。
class VeriRootNavigation extends StatefulWidget {
  const VeriRootNavigation({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    this.keyPrefix = 'main',
  });

  /// 选中切换的动画时长，供调用方对齐切页动画。
  ///
  /// 与 [VeriBottomBar.switchDuration] 同值；调用方用同一时长驱动页面切换，底栏
  /// 动画与页面过渡才会同时起步、同时结束。跨多页（跨度大于一页）同样播这段过场。
  static const Duration switchDuration = VeriBottomBar.switchDuration;

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

  @override
  Widget build(BuildContext context) {
    // 表面色要一直铺到屏幕最底（含系统导航条背后），否则那一条会露出页面底色、
    // 和底栏分成两块。因此底衬在最外，条目内容再用内边距让开。
    final surface = veriElevatedSurfaceColor(Theme.of(context).brightness);
    final outline = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);
    // 系统导航条留白。SafeArea 取 max(系统安全区, minimum)：真有系统留白（三键导航
    // 约 48dp、手势提示线约 24dp）时尊重它，为 0 时（提示线关闭，部分 ROM 如此）
    // 落到 12dp 下限，条目不贴屏幕下边缘。是 max 不是相加，不会重复留白。
    // maintainBottomViewPadding：键盘弹出时 padding.bottom 会被 viewInsets 吃掉，
    // 用 viewPadding 才不会让底栏跟着键盘跳动。
    return DecoratedBox(
      key: _key('bottom_nav'),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: outline)),
      ),
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        minimum: const EdgeInsets.only(bottom: _kMinBottomGap),
        child: VeriBottomBar(
          key: _key('nav_bar'),
          selectedIndex: widget.currentIndex,
          height: VeriRootNavigationBody.barHeight,
          onSelect: widget.onDestinationSelected,
          items: <VeriBottomBarItem>[
            for (var index = 0; index < widget.destinations.length; index++)
              VeriBottomBarItem(
                // 未选中用线框图标、选中换填充图标：库的选中动画本身就是按
                // 「同一个位置切换图标」设计的，两种风格切换时动效最自然。
                iconData: index == widget.currentIndex
                    ? widget.destinations[index].selectedIcon
                    : widget.destinations[index].icon,
                iconSize: 24,
                label: widget.destinations[index].label,
                labelTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
          color: veriRoyal,
          // 库默认 circle1=蓝、circle2=红，切换时飞过两个异色圆点。统一成
          // 品牌色，动效才和整体配色一致。
          circle1Color: veriRoyal,
          circle2Color: veriRoyal,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
