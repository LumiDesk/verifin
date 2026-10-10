import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'root_navigation.dart';
import 'veri_bottom_bar.dart';

/// 停靠式底栏样式：整宽、不透明、贴底（系统安全区之上）。
///
/// 条目由本项目自有的 [VeriBottomBar] 绘制，选中项有扫过动效。快捷记账按钮不在这里
/// ——它与导航栏解耦，由 Shell 放在右下角浮动。
///
/// 这是默认样式。
class VeriDockedRootNavigationStyle implements VeriRootNavigationStyle {
  const VeriDockedRootNavigationStyle();

  /// 持久化标识。与 `NavigationStylePreference.docked` 的枚举名一致。
  static const String styleId = 'docked';

  /// 条目内容高度（不含系统安全区）。
  static const double barHeight = 64;

  /// 列表末项在 `Scaffold` 让位之外保留的呼吸空间，取值与迁移前一致。
  ///
  /// 同一个数值也是条目 `SafeArea` 的最小底部间距（迁移前两者就是同一个 12dp）：
  /// 系统导航条留白为 0 的 ROM 上，条目因此不会贴住屏幕下边缘。
  static const double listBottomGap = 12;

  static const VeriRootNavigationLayout _layout = VeriRootNavigationLayout(
    extendBody: false,
    occupiedHeight: barHeight,
    listBottomGap: listBottomGap,
  );

  @override
  String get id => styleId;

  @override
  String label(AppLocalizations l10n) => l10n.navigationStyleDockedName;

  @override
  String description(AppLocalizations l10n) => l10n.navigationStyleDockedDesc;

  @override
  VeriRootNavigationLayout get layout => _layout;

  /// 与 [VeriBottomBar] 的选中动效同一尺度：壳层切页弹簧用它计时，
  /// 两者才会同时起步、同时收住。
  @override
  Duration get switchDuration => VeriBottomBar.switchDuration;

  @override
  Widget buildBar(BuildContext context, VeriRootNavigationSpec spec) =>
      VeriDockedRootNavigation(spec: spec);
}

/// 停靠式底栏的绘制实现。
///
/// 平时由 [VeriDockedRootNavigationStyle.buildBar] 调用；测试与预览也可以直接构造。
/// 选中态完全由 [VeriRootNavigationSpec.currentIndex] 驱动，组件自身不记状态。
class VeriDockedRootNavigation extends StatelessWidget {
  const VeriDockedRootNavigation({super.key, required this.spec});

  final VeriRootNavigationSpec spec;

  @override
  Widget build(BuildContext context) {
    assert(spec.destinations.isNotEmpty, '根导航至少要有一个目的地');
    assert(
      spec.currentIndex >= 0 && spec.currentIndex < spec.destinations.length,
      'currentIndex 越界',
    );

    // 表面色要一直铺到屏幕最底（含系统导航条背后），否则那一条会露出页面底色，
    // 和底栏分成两块。因此底衬在最外，条目内容再用内边距让开。
    final surface = veriElevatedSurfaceColor(Theme.of(context).brightness);
    final outline = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);
    // 系统导航条留白。SafeArea 取 max(系统安全区, minimum)：真有系统留白（三键导航
    // 条 48dp、手势提示线约 24dp）时尊重它，为 0 时（提示线关闭，部分 ROM 如此）
    // 落到 12dp 下限，条目不贴屏幕下边缘。是 max 不是相加，不会重复留白。
    // maintainBottomViewPadding：键盘弹出时 padding.bottom 会被 viewInsets 吃掉，
    // 用 viewPadding 才不会让底栏跟着键盘跳动。
    return DecoratedBox(
      key: ValueKey<String>(spec.keyOf('bottom_nav')),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: outline)),
      ),
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        minimum: const EdgeInsets.only(
          bottom: VeriDockedRootNavigationStyle.listBottomGap,
        ),
        child: VeriBottomBar(
          key: ValueKey<String>(spec.keyOf('nav_bar')),
          selectedIndex: spec.currentIndex,
          height: VeriDockedRootNavigationStyle.barHeight,
          onSelect: spec.onSelect,
          items: <VeriBottomBarItem>[
            for (var index = 0; index < spec.destinations.length; index++)
              VeriBottomBarItem(
                itemKey: ValueKey<String>(spec.keyOf('nav_item_$index')),
                // 未选中用线框图标、选中换填充图标：库的选中动画本身就是按
                // 「同一个位置切换图标」设计的，两种风格切换时动效最自然。
                iconData: index == spec.currentIndex
                    ? spec.destinations[index].selectedIcon
                    : spec.destinations[index].icon,
                iconSize: 24,
                label: spec.destinations[index].label,
                labelTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
          // 主色与圆点色都不传：VeriBottomBar 内部取当前主题的 primary，
          // 主题色（动态色 / 自定义色）切换后底栏自动跟随。
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
