import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 根导航的一个目的地：图标、选中图标与常显标签。
///
/// 只描述数据，不描述绘制；具体形态由 [VeriRootNavigationStyle] 决定。
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

/// 四个根目的地的标准定义（首页 / 资产 / 看板 / 我的）。
///
/// 壳层与样式选择页预览共用同一份定义，避免两处各写一套图标和标签。
List<VeriNavigationDestination> veriRootNavigationDestinations(
  AppLocalizations l10n,
) => <VeriNavigationDestination>[
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

/// 根导航样式的布局描述：壳层需要知道的全部几何信息。
///
/// 样式只声明事实，避让高度由 [contentBottomPadding] 统一推算，避免每个样式各自
/// 算一套 padding 而和壳层对不上。
@immutable
class VeriRootNavigationLayout {
  const VeriRootNavigationLayout({
    required this.extendBody,
    required this.occupiedHeight,
    this.listBottomGap = 12,
  });

  /// 内容是否延伸到导航栏背后。停靠式底栏为 false；悬浮栏通常为 true。
  final bool extendBody;

  /// 栏本体连同外边距在屏幕底部占用的高度，不含系统安全区。
  ///
  /// 停靠样式 = 条目高度；悬浮样式 = 浮层高度 + 上下外边距。
  final double occupiedHeight;

  /// 列表末项在避让之外额外保留的呼吸空间。
  final double listBottomGap;

  /// 根页面列表末项的底部内边距。
  ///
  /// [extendBody] 为 true 时 `Scaffold` 不会为栏让位，内容会伸到栏背后，避让必须自己
  /// 把整条栏算进去；为 false 时 `Scaffold` 已经让位，只要少量留白。
  double get contentBottomPadding =>
      (extendBody ? occupiedHeight : 0) + listBottomGap;
}

/// 渲染一次根导航所需的纯数据快照。
///
/// 不依赖 Controller、KV 或 Navigator，因此同一份样式实现既能渲染真实导航栏，
/// 也能直接用在设置页的样式预览里。
@immutable
class VeriRootNavigationSpec {
  const VeriRootNavigationSpec({
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
    this.keyPrefix = 'main',
  });

  /// 当前选中的目的地下标。
  final int currentIndex;

  final List<VeriNavigationDestination> destinations;

  /// 条目点击回调；预览场景传 null，条目既不可点也不回调。
  final ValueChanged<int>? onSelect;

  /// 稳定 key 前缀。
  ///
  /// 每个样式都必须产出 [keyOf]`('bottom_nav')`（整条导航表面）与
  /// [keyOf]`('nav_item_<index>')`（每个条目）；贴底悬浮样式还应产出
  /// [keyOf]`('nav_bar')`（条目所在容器）。测试、无障碍与诊断都按这些 key 定位，
  /// 不依赖具体样式的几何形状。
  final String keyPrefix;

  /// 生成该前缀下的稳定 key，例如 `keyOf('nav_item_2')`。
  String keyOf(String suffix) => '${keyPrefix}_$suffix';
}

/// 一种根导航样式。
///
/// 实现只负责「画成什么样」：不接触 Controller、KV 或 Navigator，也不负责记账按钮
/// ——按钮与导航栏解耦，见 `docs/dev/navigation-style-decoupling-design.md`。
abstract interface class VeriRootNavigationStyle {
  const VeriRootNavigationStyle();

  /// 样式没有自己的选中动效时，返回该值即可与壳层切页动画保持一致。
  static const Duration defaultSwitchDuration = Duration(milliseconds: 250);

  /// 持久化标识。一旦发布不得更名；改名必须提供迁移或别名。
  ///
  /// 与 `NavigationStylePreference` 的枚举名一一对应，测试会断言两者不许漂移。
  String get id;

  /// 设置页入口与样式选择卡片上的名称。
  String label(AppLocalizations l10n);

  /// 设置页样式选择卡片上的说明文案。
  String description(AppLocalizations l10n);

  VeriRootNavigationLayout get layout;

  /// 选中动效的时间尺度。壳层用它驱动切页弹簧，两者才能同时起步、同时收住。
  Duration get switchDuration;

  /// 绘制导航栏本体（含自身表面、描边与安全区处理）。
  Widget buildBar(BuildContext context, VeriRootNavigationSpec spec);
}

/// 壳层渲染根导航的固定锚点。
///
/// 具体形态由 [VeriRootNavigationStyle] 决定；测试与诊断从这里的 [spec] 读取当前下标
/// 或触发切换，不需要认识任何具体样式类型。
class VeriRootNavigationHost extends StatelessWidget {
  const VeriRootNavigationHost({
    super.key,
    required this.style,
    required this.spec,
  });

  final VeriRootNavigationStyle style;
  final VeriRootNavigationSpec spec;

  @override
  Widget build(BuildContext context) => style.buildBar(context, spec);
}

/// 隔离 `Scaffold.extendBody` 注入的底栏 padding。
///
/// Flutter 的嵌套 ScrollView 会在 `padding == null` 时自动继承 MediaQuery
/// padding；若直接把底栏高度传下去，日历和功能宫格会凭空增高。此组件先保存根
/// 列表所需的真实避让高度，再从页面子树移除 bottom padding。
class VeriRootNavigationBody extends StatelessWidget {
  const VeriRootNavigationBody({
    super.key,
    required this.layout,
    required this.child,
  });

  /// 当前样式的布局描述；避让高度取它的
  /// [VeriRootNavigationLayout.contentBottomPadding]。
  final VeriRootNavigationLayout layout;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _VeriRootNavigationLayout(
      listBottomPadding: layout.contentBottomPadding,
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
/// 底部留白取自当前样式的 `contentBottomPadding`：停靠底栏已由 `Scaffold` 让位，
/// 列表末项只需一点呼吸空间；悬浮样式则要把整条浮层的高度让出来，否则末项会被遮住。
/// [VeriRootNavigationBody] 仍负责把 Scaffold 注入的 bottom padding 从页面子树里移除
/// （否则未显式给 padding 的 GridView 会被撑高）。
EdgeInsets veriRootPageListPadding(BuildContext context) {
  final layout = context
      .dependOnInheritedWidgetOfExactType<_VeriRootNavigationLayout>();
  return EdgeInsets.fromLTRB(14, 8, 14, layout?.listBottomPadding ?? 12);
}
