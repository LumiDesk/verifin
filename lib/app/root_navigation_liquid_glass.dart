import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'liquid_glass_lens.dart';
import 'liquid_glass_surface.dart';
import 'root_navigation.dart';

/// 液态玻璃底栏样式：浮动玻璃胶囊 + 拖动切换 + 透镜形变。
///
/// 手感：按下即向目标项滑动、拖动跟手、松手吸附、拖动时高光方向随移动偏移。它是与
/// 停靠底栏并列的可选样式，四个根目的地、切页状态机、返回键语义与记账按钮都不受影响。
///
/// 玻璃由两部分组成：
/// - 面板：[VeriLiquidGlassSurface] 的背景模糊 + 中性填色 + 沿边缘方向高光；
/// - 透镜：[VeriLiquidGlassLens] 对**导航自身内容**做放大折射，产生液体形变。
///   折射只作用于导航自身图层，不折射页面背景——Flutter 的 `BackdropFilter`
///   无法把模糊结果再交给着色器，强行折射背景会出现坐标错位伪影。
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
  static const Duration pressMoveDuration = Duration(milliseconds: 280);
  static const Duration snapDuration = Duration(milliseconds: 240);

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
/// 交给 Shell，因此 Shell 的切页状态机不需要任何改动。
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
          final progress = Curves.easeOutCubic.transform(
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

  @override
  void didUpdateWidget(covariant VeriLiquidGlassRootNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          // 导航在拖动时每帧重绘，单独成层后不让整屏跟着重绘。
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth =
                    constraints.maxWidth / spec.destinations.length;
                final selectedIndex = _displayIndex.round().clamp(
                  0,
                  spec.destinations.length - 1,
                );
                return Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned.fill(
                      child: VeriLiquidGlassSurface(
                        radius: VeriLiquidGlassRootNavigationStyle.barHeight,
                        grouped: false,
                        tint: veriLiquidGlassTint(
                          isDark ? Brightness.dark : Brightness.light,
                        ),
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
                                VeriLiquidGlassRootNavigationStyle
                                    .indicatorInset,
                            VeriLiquidGlassRootNavigationStyle.indicatorInset,
                            slotWidth -
                                VeriLiquidGlassRootNavigationStyle
                                        .indicatorInset *
                                    2,
                            constraints.maxHeight -
                                VeriLiquidGlassRootNavigationStyle
                                        .indicatorInset *
                                    2,
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
                                    accent: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassTab extends StatelessWidget {
  const _LiquidGlassTab({
    required this.destination,
    required this.selected,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final VeriNavigationDestination destination;
  final bool selected;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                color: selected ? accent : veriNavigationUnselected,
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
                  color: selected ? accent : veriNavigationUnselected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
