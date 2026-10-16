import 'dart:async' show unawaited;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'liquid_glass_icon_raster.dart';
import 'liquid_glass_lens.dart';
import 'liquid_glass_material.dart';
import 'liquid_glass_surface.dart';
import 'platform_bridge.dart';
import 'root_navigation.dart';

/// 液态玻璃底栏样式：原生 QWEA0 玻璃 + Flutter fallback。
///
/// 双模实现：
/// - **原生模式**（Android 且原生栏激活）：玻璃、折射、水滴、tab 全部由原生
///   `LiquidGlassTabBar` 绘制——AGSL 渲染管线；Flutter 侧
///   本 widget 只渲染几何占位（保持避让、稳定 key）并经 `AppGlassBridge` 指挥
///   原生栏与同步选中态。
/// - **fallback 模式**（非 Android、SDK<33、原生初始化失败、高对比度）：沿用
///   自有的 `BackdropFilter + ImageFilter.shader` 近似玻璃与全部交互。
///
/// 四个根目的地、切页状态机、返回键语义与记账按钮在任何模式下都不受影响。
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

  /// 指示块相对胶囊的内缩距离。
  static const double indicatorInset = 3;

  /// 按下后滑向目标项、松手吸附与页面过渡共用的时间尺度。
  /// 水滴 grow 340ms、tab glide 380ms。
  static const Duration pressMoveDuration = Duration(milliseconds: 340);
  static const Duration snapDuration = Duration(milliseconds: 380);

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

  @override
  Duration get switchDuration => snapDuration;

  @override
  Widget buildBar(BuildContext context, VeriRootNavigationSpec spec) =>
      VeriLiquidGlassRootNavigation(spec: spec);
}

/// 液态玻璃底栏的绘制实现。
///
/// 选中态同时接受 [VeriRootNavigationSpec.currentIndex]（外部切页，如返回键与
/// 小组件路由）与自身拖动；拖动只更新指示位置，松手才通过 `spec.onSelect`
/// 交给 Shell，因此 Shell 的切页状态机不需要任何改动。原生模式激活时条目与
/// 手势全部在原生侧，本 widget 退化为几何占位与选中态同步驱动器。
class VeriLiquidGlassRootNavigation extends StatefulWidget {
  const VeriLiquidGlassRootNavigation({super.key, required this.spec});

  final VeriRootNavigationSpec spec;

  @override
  State<VeriLiquidGlassRootNavigation> createState() =>
      _VeriLiquidGlassRootNavigationState();
}

class _VeriLiquidGlassRootNavigationState
    extends State<VeriLiquidGlassRootNavigation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _indicatorController;

  /// 原生玻璃栏是否激活（null = 未探测完成，按 fallback 渲染）。
  bool _nativeActive = false;

  /// 本实例是否真的挂载过原生栏（与 [_nativeActive] 分开：`install` 成功但本
  /// State 随即被销毁时，`_nativeActive` 来不及置 true，仍必须卸载）。
  bool _installedNative = false;

  /// 本实例注册到 [AppGlassBridge.onTabSelected] 的那个回调。
  ///
  /// 该回调在 Bridge 上是**静态**的，而样式选择页会构建只读预览实例（`onSelect`
  /// 为 null、从不 install）——预览被销毁时若无条件置空，会把真实底栏的回调一起
  /// 清掉：原生栏照常切换水滴，Dart 侧却收不到回调，表现为「水滴动了、页面不切」。
  /// 因此销毁时只清除仍属于本实例的那一个。
  void Function(int index)? _registeredOnTabSelected;

  /// 指示块位置，单位是「第几个目的地」，支持小数。
  double _displayIndex = 0;
  double _animationStart = 0;
  double _animationEnd = 0;
  bool _indicatorPressed = false;
  bool _dragging = false;
  bool _suppressNextDestinationTap = false;
  int? _activePointer;
  int? _pressedTargetIndex;
  double? _pointerDownX;
  double? _lastPointerX;
  double _lightMotion = 0;

  @override
  void initState() {
    super.initState();
    assert(widget.spec.destinations.isNotEmpty, '根导航至少要有一个目的地');
    assert(
      widget.spec.currentIndex >= 0 &&
          widget.spec.currentIndex < widget.spec.destinations.length,
      'currentIndex 越界',
    );
    _displayIndex = widget.spec.currentIndex.toDouble();
    _animationStart = _displayIndex;
    _animationEnd = _displayIndex;
    _indicatorController =
        AnimationController(
          vsync: this,
          duration: VeriLiquidGlassRootNavigationStyle.pressMoveDuration,
        )..addListener(() {
          // 水滴/位移用 Decelerate(1.6) 手感。
          final progress = Curves.decelerate.transform(
            _indicatorController.value,
          );
          setState(() {
            _displayIndex = lerpDouble(
              _animationStart,
              _animationEnd,
              progress,
            )!;
          });
        });
  }

  bool _probedNative = false;
  ({bool dark, int accentOverLight, int accentOverDark})? _lastAppearance;
  double? _lastBottomInset;
  Route<void>? _observedRoute;

  /// 当前主题的亮度与主题主色变体，原生栏的配色与此一一对应。
  ({bool dark, int accentOverLight, int accentOverDark}) _appearance() {
    final theme = Theme.of(context);
    final accent = veriLiquidGlassAccentPair(theme.colorScheme.primary);
    return (
      dark: theme.brightness == Brightness.dark,
      accentOverLight: accent.overLight.toARGB32(),
      accentOverDark: accent.overDark.toARGB32(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_probedNative) {
      _probedNative = true;
      unawaited(_probeNativeBar());
      return;
    }
    if (!_nativeActive) {
      return;
    }
    // 切换主题或主题主色时同步原生栏配色：选中项颜色由主色派生，深浅切换也要推送。
    final appearance = _appearance();
    final dark = appearance.dark;
    if (appearance != _lastAppearance) {
      _lastAppearance = appearance;
      unawaited(
        AppGlassBridge.updateAppearance(
          dark: dark,
          accentOverLight: appearance.accentOverLight,
          accentOverDark: appearance.accentOverDark,
        ),
      );
    }
    // 底部 inset 变化（键盘弹出推栏到键盘上方、手势条）时同步几何。
    final inset = MediaQuery.paddingOf(context).bottom;
    // 键盘弹出时原生栏会挡输入框（原生栏不受 Scaffold padding 约束）：
    // 以 viewInsets 作为 inset 下发，原生栏被推到键盘上方。
    final effectiveInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? MediaQuery.viewInsetsOf(context).bottom
        : inset;
    if (effectiveInset != _lastBottomInset) {
      _lastBottomInset = effectiveInset;
      unawaited(
        AppGlassBridge.updateGeometry(dark: dark, bottomInset: effectiveInset),
      );
    }
    _syncRouteVisibility();
  }

  /// 原生栏挂在 Activity 层，感知不到 Flutter 路由：设置页、记账 sheet、
  /// 引导页等任何 route 盖上来时必须隐藏原生栏，回到根级时恢复。
  /// 本 widget 所在 route `isCurrent` = 没有任何 route 盖在上面。
  void _syncRouteVisibility() {
    final route = ModalRoute.of(context);
    if (!identical(route, _observedRoute)) {
      _observedRoute = route;
      route?.animation?.addStatusListener(_routeStatusListener);
    }
    unawaited(AppGlassBridge.setHidden(!(route?.isCurrent ?? false)));
  }

  void _routeStatusListener(AnimationStatus status) {
    // 弹层转场期间/结束时重新求值（isCurrent 随入栈/出栈变化）。
    if (mounted) {
      _syncRouteVisibility();
    }
  }

  /// 探测并挂载原生玻璃栏：白色剪影图标 + 标签 + 选中态 + 真实底部 inset。
  Future<void> _probeNativeBar() async {
    final onSelect = widget.spec.onSelect;
    if (onSelect == null) {
      return;
    }
    final appearance = _appearance();
    final inset = MediaQuery.paddingOf(context).bottom;
    _lastAppearance = appearance;
    _lastBottomInset = inset;
    // 光栅化四目的地图标为白色剪影；失败项原生侧退化为纯文字。
    final tabs = <({String label, Uint8List? icon})>[];
    for (final destination in widget.spec.destinations) {
      final icon = await VeriGlassIconRaster.silhouette(destination.icon);
      if (!mounted) {
        return;
      }
      tabs.add((label: destination.label, icon: icon));
    }
    final active = await AppGlassBridge.install(
      selectedIndex: widget.spec.currentIndex,
      dark: appearance.dark,
      accentOverLight: appearance.accentOverLight,
      accentOverDark: appearance.accentOverDark,
      tabs: tabs,
      bottomInset: inset,
    );
    // 原生栏已经挂上了：先记下归属，后面任何提前返回都要能卸载它，
    // 否则会留下一个「水滴能动、点不动」的僵尸栏。
    if (active) {
      _installedNative = true;
    }
    if (!mounted) {
      if (active) {
        unawaited(AppGlassBridge.uninstall());
        _installedNative = false;
      }
      return;
    }
    if (active) {
      _registeredOnTabSelected = _handleNativeTabSelected;
      AppGlassBridge.onTabSelected = _handleNativeTabSelected;
      setState(() => _nativeActive = true);
      _syncRouteVisibility();
    }
  }

  /// 原生栏发来的切换请求：交回 Shell 的切页状态机。
  void _handleNativeTabSelected(int index) {
    if (mounted && index != widget.spec.currentIndex) {
      widget.spec.onSelect?.call(index);
    }
  }

  @override
  void didUpdateWidget(covariant VeriLiquidGlassRootNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_nativeActive &&
        oldWidget.spec.currentIndex != widget.spec.currentIndex) {
      // Flutter 侧切页（返回键、小组件路由）：同步原生水滴。
      unawaited(AppGlassBridge.updateSelection(widget.spec.currentIndex));
    }
    if (oldWidget.spec.currentIndex != widget.spec.currentIndex &&
        _activePointer == null) {
      _animateIndicatorTo(
        widget.spec.currentIndex.toDouble(),
        VeriLiquidGlassRootNavigationStyle.snapDuration,
      );
    }
  }

  @override
  void dispose() {
    // 只清除仍属于本实例的回调：样式选择页的只读预览实例也会走到这里，
    // 若无条件置空会把真实底栏注册的处理器一起清掉（水滴能动、页面不切）。
    // 用 `==` 而非 `identical`：方法 tear-off 每次取值都是新的闭包对象，
    // `identical` 会恒为 false，而 `==` 对同一实例成立、对不同实例为 false。
    if (AppGlassBridge.onTabSelected == _registeredOnTabSelected) {
      AppGlassBridge.onTabSelected = null;
    }
    _registeredOnTabSelected = null;
    if (_installedNative) {
      // 样式切换/Shell 重建时卸载原生栏，避免与停靠样式叠加；
      // 隐藏态一并复位，下次挂载不被上次遗留的遮盖状态吞掉。
      _installedNative = false;
      unawaited(AppGlassBridge.uninstall());
      unawaited(AppGlassBridge.setHidden(false));
    }
    _indicatorController.dispose();
    super.dispose();
  }

  void _animateIndicatorTo(double target, Duration duration) {
    final count = widget.spec.destinations.length;
    final clampedTarget = target.clamp(0.0, count - 1.0).toDouble();
    _indicatorController.stop();
    _animationStart = _displayIndex;
    _animationEnd = clampedTarget;
    if ((_animationStart - _animationEnd).abs() < 0.001) {
      if (_displayIndex != clampedTarget) {
        setState(() => _displayIndex = clampedTarget);
      }
      return;
    }
    _indicatorController.duration = duration;
    _indicatorController.forward(from: 0);
  }

  void _handlePointerDown(PointerDownEvent event, double slotWidth) {
    if (_activePointer != null) {
      return;
    }
    final count = widget.spec.destinations.length;
    final pressedIndex = (event.localPosition.dx / slotWidth).floor().clamp(
      0,
      count - 1,
    );
    setState(() {
      _activePointer = event.pointer;
      _pointerDownX = event.localPosition.dx;
      _lastPointerX = event.localPosition.dx;
      _lightMotion = 0;
      _pressedTargetIndex = pressedIndex;
      _dragging = false;
      _indicatorPressed = true;
    });
    _animateIndicatorTo(
      pressedIndex.toDouble(),
      VeriLiquidGlassRootNavigationStyle.pressMoveDuration,
    );
  }

  void _handlePointerMove(PointerMoveEvent event, double slotWidth) {
    if (event.pointer != _activePointer ||
        _pointerDownX == null ||
        _pressedTargetIndex == null) {
      return;
    }
    final movement =
        event.localPosition.dx - (_lastPointerX ?? event.localPosition.dx);
    _lastPointerX = event.localPosition.dx;
    setState(
      () => _lightMotion = (_lightMotion * 0.5 + movement / 12 * 0.5).clamp(
        -1.0,
        1.0,
      ),
    );
    final delta = event.localPosition.dx - _pointerDownX!;
    if (!_dragging && delta.abs() < 2) {
      return;
    }
    final desiredIndex = (_pressedTargetIndex! + delta / slotWidth)
        .clamp(0.0, widget.spec.destinations.length - 1.0)
        .toDouble();
    if (!_dragging) {
      setState(() => _dragging = true);
    }
    if (_indicatorController.isAnimating) {
      setState(() => _animationEnd = desiredIndex);
    } else {
      setState(() => _displayIndex = desiredIndex);
    }
  }

  /// 松手：拖动时吸附到最近一项，纯点击时落到按下的那一项。
  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final wasDragging = _dragging;
    final pressedTargetIndex = _pressedTargetIndex;
    final targetIndex = _displayIndex.round().clamp(
      0,
      widget.spec.destinations.length - 1,
    );
    setState(() {
      _activePointer = null;
      _pointerDownX = null;
      _lastPointerX = null;
      _lightMotion = 0;
      _pressedTargetIndex = null;
      _dragging = false;
      _indicatorPressed = false;
    });
    if (wasDragging) {
      _animateIndicatorTo(
        targetIndex.toDouble(),
        VeriLiquidGlassRootNavigationStyle.snapDuration,
      );
      _emitSelection(targetIndex);
    } else if (pressedTargetIndex != null) {
      // 指针事件已经处理了这次点击，抑制条目自身的 InkWell 回调。
      _suppressNextDestinationTap = true;
      _animateIndicatorTo(
        pressedTargetIndex.toDouble(),
        VeriLiquidGlassRootNavigationStyle.snapDuration,
      );
      _emitSelection(pressedTargetIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _suppressNextDestinationTap = false;
      });
    }
  }

  void _handleDestinationTap(int index) {
    if (_suppressNextDestinationTap) {
      _suppressNextDestinationTap = false;
      return;
    }
    _animateIndicatorTo(
      index.toDouble(),
      VeriLiquidGlassRootNavigationStyle.snapDuration,
    );
    _emitSelection(index);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    _indicatorController.stop();
    setState(() {
      _activePointer = null;
      _pointerDownX = null;
      _lastPointerX = null;
      _lightMotion = 0;
      _pressedTargetIndex = null;
      _dragging = false;
      _indicatorPressed = false;
    });
    _animateIndicatorTo(
      widget.spec.currentIndex.toDouble(),
      VeriLiquidGlassRootNavigationStyle.snapDuration,
    );
  }

  void _emitSelection(int index) {
    final onSelect = widget.spec.onSelect;
    if (onSelect == null || index == widget.spec.currentIndex) {
      return;
    }
    onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return SafeArea(
      key: ValueKey<String>(spec.keyOf('bottom_nav')),
      top: false,
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.only(
        bottom: VeriLiquidGlassRootNavigationStyle.bottomGap,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VeriLiquidGlassRootNavigationStyle.sideGap,
        ),
        child: SizedBox(
          key: ValueKey<String>(spec.keyOf('nav_bar')),
          height: VeriLiquidGlassRootNavigationStyle.barHeight,
          child: _nativeActive
              ? _buildNativePlaceholder(spec)
              : _buildFallbackBar(spec),
        ),
      ),
    );
  }

  /// 原生模式：玻璃与条目全部在原生侧绘制，Flutter 只保留几何占位——
  /// 占位本身不可见也不可点，避让高度由 `layout.occupiedHeight` 声明保证，
  /// 稳定 key 供测试定位原生模式占位。
  Widget _buildNativePlaceholder(VeriRootNavigationSpec spec) {
    return RepaintBoundary(
      child: SizedBox.expand(
        key: ValueKey<String>(spec.keyOf('nav_bar_native')),
      ),
    );
  }

  /// fallback 模式：自有着色器近似玻璃（非 Android / SDK<33 / 原生未激活）。
  Widget _buildFallbackBar(VeriRootNavigationSpec spec) {
    // 导航在拖动时每帧重绘，单独成层后不让整屏跟着重绘。
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / spec.destinations.length;
          final selectedIndex = _displayIndex.round().clamp(
            0,
            spec.destinations.length - 1,
          );
          return Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(
                child: VeriLiquidGlassBar(
                  radius: VeriLiquidGlassRootNavigationStyle.barHeight,
                  motion: _lightMotion,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) =>
                      _handlePointerDown(event, slotWidth),
                  onPointerMove: (event) =>
                      _handlePointerMove(event, slotWidth),
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  child: VeriLiquidGlassLens(
                    keyPrefix: spec.keyPrefix,
                    target: Rect.fromLTWH(
                      _displayIndex * slotWidth +
                          VeriLiquidGlassRootNavigationStyle.indicatorInset,
                      VeriLiquidGlassRootNavigationStyle.indicatorInset,
                      slotWidth -
                          VeriLiquidGlassRootNavigationStyle.indicatorInset * 2,
                      constraints.maxHeight -
                          VeriLiquidGlassRootNavigationStyle.indicatorInset * 2,
                    ),
                    pressed: _indicatorPressed || _dragging,
                    motion: _lightMotion,
                    source: Row(
                      children: <Widget>[
                        for (
                          var index = 0;
                          index < spec.destinations.length;
                          index++
                        )
                          Expanded(
                            key: ValueKey<String>(
                              spec.keyOf('nav_item_$index'),
                            ),
                            child: _LiquidGlassTab(
                              destination: spec.destinations[index],
                              selected: index == selectedIndex,
                              enabled: spec.onSelect != null,
                              onTap: () => _handleDestinationTap(index),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiquidGlassTab extends StatelessWidget {
  const _LiquidGlassTab({
    required this.destination,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final VeriNavigationDestination destination;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 选中项取主题主色的对应变体（浅色主题在浅玻璃上压暗，深色主题提亮）；未选中项
    // 用中性墨色。降级路径无法采样底下内容，以主题亮度近似 backdrop 亮度。
    final theme = Theme.of(context);
    final overLight = theme.brightness == Brightness.light;
    final accent = veriLiquidGlassAccentPair(theme.colorScheme.primary);
    final selectedColor = overLight ? accent.overLight : accent.overDark;
    final unselectedColor = overLight
        ? Colors.black.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.85);
    final color = selected ? selectedColor : unselectedColor;
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: enabled ? onTap : null,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 24,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
