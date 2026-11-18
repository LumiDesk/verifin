import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'root_navigation.dart';

/// 可选液态玻璃底栏：把应用的根导航契约适配到 `GlassTabBar.bottom`。
///
/// 第三方玻璃实现只允许出现在这里，不能扩散到卡片、菜单、弹层或页面背景。
/// 四个目的地、回调时机和 Shell 切页状态机仍由 [VeriRootNavigationSpec] 决定。
class VeriLiquidGlassRootNavigationStyle implements VeriRootNavigationStyle {
  const VeriLiquidGlassRootNavigationStyle();

  /// 持久化标识。与 `NavigationStylePreference.liquidGlass` 的枚举名一致。
  static const String styleId = 'liquidGlass';

  /// 胶囊高度（不含系统安全区与底部留白）。
  static const double barHeight = 60;

  /// 胶囊左右外边距。
  static const double sideGap = 12;

  /// 胶囊与系统安全区之间的留白。
  static const double bottomGap = 24;

  /// 列表末项在避让之外额外保留的呼吸空间。
  static const double listBottomGap = 16;

  static const VeriRootNavigationLayout _layout = VeriRootNavigationLayout(
    extendBody: true,
    occupiedHeight: barHeight + bottomGap,
    listBottomGap: listBottomGap,
  );

  @override
  String get id => styleId;

  @override
  String label(AppLocalizations l10n) => l10n.navigationStyleLiquidGlassName;

  @override
  String description(AppLocalizations l10n) =>
      l10n.navigationStyleLiquidGlassDesc;

  @override
  VeriRootNavigationLayout get layout => _layout;

  /// 页面切页弹簧与底栏玻璃动画共用的时间尺度。
  ///
  /// `GlassTabBar.bottom` 的指示器使用库内弹簧，库没有公开 `.bottom` 的弹簧参数；
  /// 这里沿用原液态玻璃样式的时间尺度，避免 Shell 的切页动画先于或晚于底栏落位。
  @override
  Duration get switchDuration => const Duration(milliseconds: 240);

  @override
  Widget buildBar(BuildContext context, VeriRootNavigationSpec spec) =>
      VeriLiquidGlassRootNavigation(spec: spec);
}

/// `GlassTabBar.bottom` 的根导航适配层。
///
/// 预览场景把 [VeriRootNavigationSpec.onSelect] 设为 null；这里传入空回调以满足
/// 库的必填参数，但预览外层会通过 `IgnorePointer` 阻止交互。
class VeriLiquidGlassRootNavigation extends StatelessWidget {
  const VeriLiquidGlassRootNavigation({super.key, required this.spec});

  final VeriRootNavigationSpec spec;

  /// 深色底栏的磨砂材质。
  ///
  /// `ios27Dark` 的 12% 白色 tint 会让底栏发灰发白，1.4 的饱和度还会
  /// 放大后方页面的蓝色。这里压低白色 tint 与饱和度，仅保留轻量模糊，
  /// 用很弱的黑色 backer 压住高光，同时维持玻璃边缘和选中态。
  static final LiquidGlassSettings _darkSettings = LiquidGlassSettings.ios27Dark
      .copyWith(
        glassColor: const Color(0x00000000),
        blur: 2,
        frost: 4,
        frostOpacity: 0.68,
        frostClamp: -0.3,
        saturation: 0.65,
        bodyShade: 0.18,
        backerColor: const Color(0x12000000),
      );

  /// 冻结预览的浅色材质：与库内 `kBottomBarGlassDefaults` 的可见部分一致
  /// （24% 白 tint），只把 blur 归零。
  ///
  /// 预览永远贴在同一张纯色卡片上，模糊没有任何可见效果（浅色/深色都做过像素级
  /// A/B 对比，差异只在抗锯齿的小数点后）；但 `GlassQuality.minimal` 的磨砂路径
  /// 会为 blur > 0 生成一层实时 `BackdropFilter`。那一层位于 `GlassTabBar`
  /// 自己的 `RepaintBoundary` 内，在部分设备上背景捕获是空的，Impeller 会把空捕获
  /// 画成不透明黑：整个胶囊全黑，直到一次重绘（用户滚动一下）才恢复——Issue 72。
  /// 冻结预览不需要实时背景，因此直接走无 backdrop 的纯绘制路径。
  static const LiquidGlassSettings _lightPreviewSettings = LiquidGlassSettings(
    blur: 0,
    glassColor: Color(0x3DFFFFFF),
  );

  /// 深色冻结预览：沿用 [_darkSettings] 的调校，只去掉 blur（原因同上）。
  static final LiquidGlassSettings _darkPreviewSettings = _darkSettings
      .copyWith(blur: 0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 预览是静态的，不承载交互；premium 玻璃层的 shader 在父级滚动时
    // 仍会沿用上一帧的位置。预览改用库的无 shader 降级路径，避免背景
    // 面板在滚动时与图标分离。真实底栏仍使用 premium。
    final isPreview = spec.onSelect == null;
    final LiquidGlassSettings? settings = isPreview
        ? (isDark ? _darkPreviewSettings : _lightPreviewSettings)
        : (isDark ? _darkSettings : null);
    final tabs = <GlassTab>[
      for (var index = 0; index < spec.destinations.length; index++)
        GlassTab(
          // `GlassTab` 本身没有 key；把稳定 key 放在未选中图标上。库会同时绘制
          // 未选中层和选中层，`activeIcon` 不重复挂 key，避免同一棵树出现重复 key。
          icon: KeyedSubtree(
            key: ValueKey<String>(spec.keyOf('nav_item_$index')),
            child: Icon(spec.destinations[index].icon),
          ),
          activeIcon: Icon(spec.destinations[index].selectedIcon),
          label: spec.destinations[index].label,
          semanticLabel: spec.destinations[index].label,
        ),
    ];

    return SafeArea(
      key: ValueKey<String>(spec.keyOf('bottom_nav')),
      top: false,
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.only(
        bottom: VeriLiquidGlassRootNavigationStyle.bottomGap,
      ),
      child: GlassTabBar.bottom(
        key: ValueKey<String>(spec.keyOf('nav_bar')),
        tabs: tabs,
        selectedIndex: spec.currentIndex,
        onTabSelected: spec.onSelect ?? (_) {},
        horizontalPadding: VeriLiquidGlassRootNavigationStyle.sideGap,
        // 当前样式的几何是 60dp 胶囊 + 24dp 底部留白；库的 verticalPadding
        // 会把自身高度算进 preferredSize，因此这里保持 0，由外层 SafeArea 提供留白。
        verticalPadding: 0,
        barHeight: VeriLiquidGlassRootNavigationStyle.barHeight,
        iconSize: 24,
        labelFontSize: 12,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        selectedIconColor: scheme.primary,
        unselectedIconColor: veriNavigationUnselected,
        selectedLabelColor: scheme.primary,
        unselectedLabelColor: veriNavigationUnselected,
        adaptiveBrightness: false,
        // 浅色模式保持组件库默认材质；深色模式使用压暗、低白雾的磨砂材质。
        // 预览一律使用 blur 归零的预览材质，不生成实时 backdrop（Issue 72）。
        settings: settings,
        indicatorColor: isDark ? Colors.white.withValues(alpha: 0.06) : null,
        quality: isPreview ? GlassQuality.minimal : GlassQuality.premium,
        backgroundQuality: isPreview ? GlassQuality.minimal : null,
      ),
    );
  }
}
