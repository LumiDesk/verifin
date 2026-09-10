import 'dart:ui';

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

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _VeriRootNavigationLayout(
      listBottomPadding: MediaQuery.paddingOf(context).bottom + 12,
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

/// Veri Fin 根页面的浮动导航。
///
/// 不透明圆角胶囊：中性表面色 + 单一描边 + 阴影，不使用模糊、折射或方向光。
/// 选中滑块支持按压缩放、指针连续拖动和松手吸附；快捷记账按钮仅由调用方在首页启用。
class VeriRootNavigation extends StatefulWidget {
  const VeriRootNavigation({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.quickEntryLabel,
    this.showQuickEntry = false,
    this.onQuickEntryTap,
    this.onQuickEntryLongPress,
    this.keyPrefix = 'main',
    this.quickEntryKey = const Key('quick_entry_fab'),
  });

  final int currentIndex;
  final List<VeriNavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final String quickEntryLabel;
  final bool showQuickEntry;
  final VoidCallback? onQuickEntryTap;
  final VoidCallback? onQuickEntryLongPress;
  final String keyPrefix;
  final Key quickEntryKey;

  @override
  State<VeriRootNavigation> createState() => _VeriRootNavigationState();
}

class _VeriRootNavigationState extends State<VeriRootNavigation>
    with SingleTickerProviderStateMixin {
  static const _navigationWidth = 298.0;
  static const _pressMoveDuration = Duration(milliseconds: 280);
  static const _snapDuration = Duration(milliseconds: 240);

  late final AnimationController _indicatorController;

  double _displayIndex = 0;
  double _animationStart = 0;
  double _animationEnd = 0;
  bool _dragging = false;
  bool _suppressNextDestinationTap = false;
  int? _activePointer;
  int? _pressedTargetIndex;
  double? _pointerDownX;
  double? _lastPointerX;
  double _lightMotion = 0;
  int? _pendingSelection;

  Key _key(String suffix) => ValueKey('${widget.keyPrefix}_$suffix');

  @override
  void initState() {
    super.initState();
    assert(widget.destinations.isNotEmpty);
    assert(widget.currentIndex >= 0);
    assert(widget.currentIndex < widget.destinations.length);
    _displayIndex = widget.currentIndex.toDouble();
    _animationStart = _displayIndex;
    _animationEnd = _displayIndex;
    _indicatorController =
        AnimationController(vsync: this, duration: _pressMoveDuration)
          ..addListener(() {
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
  void didUpdateWidget(covariant VeriRootNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.destinations.isNotEmpty);
    assert(widget.currentIndex >= 0);
    assert(widget.currentIndex < widget.destinations.length);
    if (oldWidget.currentIndex != widget.currentIndex &&
        _activePointer == null) {
      _animateIndicatorTo(widget.currentIndex.toDouble(), _snapDuration);
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  void _animateIndicatorTo(double target, Duration duration) {
    final clampedTarget = target
        .clamp(0.0, widget.destinations.length - 1.0)
        .toDouble();
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
    final pressedIndex = (event.localPosition.dx / slotWidth).floor().clamp(
      0,
      widget.destinations.length - 1,
    );
    setState(() {
      _activePointer = event.pointer;
      _pointerDownX = event.localPosition.dx;
      _lastPointerX = event.localPosition.dx;
      _lightMotion = 0;
      _pressedTargetIndex = pressedIndex;
      _dragging = false;
    });
    _animateIndicatorTo(pressedIndex.toDouble(), _pressMoveDuration);
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
        .clamp(0.0, widget.destinations.length - 1.0)
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

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final wasDragging = _dragging;
    final pressedTargetIndex = _pressedTargetIndex;
    final targetIndex = _displayIndex.round().clamp(
      0,
      widget.destinations.length - 1,
    );
    setState(() {
      _activePointer = null;
      _pointerDownX = null;
      _lastPointerX = null;
      _lightMotion = 0;
      _pressedTargetIndex = null;
      _dragging = false;
    });
    if (wasDragging) {
      _animateIndicatorTo(targetIndex.toDouble(), _snapDuration);
      _notifyDestination(targetIndex);
    } else if (pressedTargetIndex != null) {
      _suppressNextDestinationTap = true;
      _animateIndicatorTo(pressedTargetIndex.toDouble(), _snapDuration);
      _notifyDestination(pressedTargetIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _suppressNextDestinationTap = false;
      });
    }
  }

  /// 把选中结果上报给外层，延后到当前帧结束。
  ///
  /// 上报会驱动 Shell 切页（PageView 动画 + 整树重建）；若在指针/动画回调里同步
  /// 触发，会和 bottom_bar_matu 自身的动画通知撞在一起，抛
  /// 「setState() called during build」。
  void _notifyDestination(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onDestinationSelected(index);
    });
  }

  void _handleDestinationTap(int index) {
    if (_suppressNextDestinationTap) {
      _suppressNextDestinationTap = false;
      return;
    }
    // bottom_bar_matu 会在 didUpdateWidget 里同步回调 onSelect，也就是在整个构建
    // 过程中；此时 setState（_animateIndicatorTo 会触发）会抛
    // 「setState() called during build」，回灌外层切页更会连带整树重建。
    // 因此这里只记下意图，等这一帧结束再统一处理。
    _pendingSelection = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _pendingSelection;
      _pendingSelection = null;
      if (target == null) return;
      _animateIndicatorTo(target.toDouble(), _snapDuration);
      widget.onDestinationSelected(target);
    });
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
    });
    _animateIndicatorTo(widget.currentIndex.toDouble(), _snapDuration);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      key: _key('bottom_nav'),
      top: false,
      child: Padding(
        key: _key('outer_spacing'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final quickEntrySpace = widget.showQuickEntry ? 68.0 : 0.0;
            final maximumWidth = (constraints.maxWidth - quickEntrySpace).clamp(
              0.0,
              _navigationWidth,
            );
            return SizedBox(
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: widget.showQuickEntry
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: AnimatedContainer(
                      key: _key('nav_capsule'),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: maximumWidth,
                      height: 60,
                      // 导航每帧都在重绘（拖动/吸附），单独成层避免牵连页面重绘。
                      child: RepaintBoundary(child: _buildCapsule(isDark)),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IgnorePointer(
                      key: _key('quick_entry_visibility'),
                      ignoring: !widget.showQuickEntry,
                      child: ExcludeSemantics(
                        excluding: !widget.showQuickEntry,
                        child: AnimatedScale(
                          key: _key('quick_entry_scale'),
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          scale: widget.showQuickEntry ? 1 : 0,
                          child: _QuickEntryButton(
                            keyPrefix: widget.keyPrefix,
                            actionKey: widget.quickEntryKey,
                            label: widget.quickEntryLabel,
                            onTap: widget.onQuickEntryTap,
                            onLongPress: widget.onQuickEntryLongPress,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 不透明导航胶囊：只保留圆角、描边、阴影与整套指针状态机。
  ///
  /// 曾在此实现磨砂玻璃（BackdropFilter）与高级材质方向光/折射透镜；两者都被判定
  /// 为设计败笔而移除。命中区域、Key 契约与拖动行为必须与之前完全一致。
  Widget _buildCapsule(bool isDark) {
    final surface = veriElevatedSurfaceColor(
      isDark ? Brightness.dark : Brightness.light,
    );
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        key: _key('nav_material'),
        color: surface,
        shape: StadiumBorder(side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / widget.destinations.length;
            // 喂给底栏的选中项只在「没有手指按着」时跟随，取整数槽位。
            //
            // 不能把拖动中的连续位置直接传给它：bottom_bar_matu 在 didUpdateWidget
            // 里会回灌 onSelect，而拖动时外层正在重建，于是变成
            // 「setState() called during build」。拖动连续跟随由 _displayIndex 与
            // 自绘层完成，松手吸附后再把最终结果交给它。
            final selectedIndex = _displayIndex.round().clamp(
              0,
              widget.destinations.length - 1,
            );
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => _handlePointerDown(event, slotWidth),
              onPointerMove: (event) => _handlePointerMove(event, slotWidth),
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              // 条目绘制交给 bottom_bar_matu：它负责图标、文字与选中气泡动效。
              // 外面仍由本组件提供胶囊底板、指针拖动状态机与快捷记账按钮；
              // 拖动时把 _displayIndex 四舍五入喂给它，选中反馈跟着手指走。
              //
              // 条目不做逐项 Key：库的 iconBuilder 会被多次调用，同一 Key 会在一帧
              // 里出现多份。选中/拖动只按位置计算，测试改用唯一的中文标签定位。
              child: BottomBarBubble(
                key: _key('nav_bar'),
                selectedIndex: selectedIndex,
                items: <BottomBarItem>[
                  for (final destination in widget.destinations)
                    BottomBarItem(
                      iconData: destination.icon,
                      iconSize: 22,
                      label: destination.label,
                      labelMarginTop: 2,
                      labelTextStyle: TextStyle(
                        fontSize: veriUnifiedDesignPreview ? 12 : 10,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                ],
                // 选中态只做轻微的中性强调：规范要求不给整条导航染品牌蓝，
                // 选中反馈由库自身的气泡动效承担。
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.14),
                backgroundColor: Colors.transparent,
                height: 60,
                bubbleSize: 22,
                onSelect: _handleDestinationTap,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuickEntryButton extends StatelessWidget {
  const _QuickEntryButton({
    required this.keyPrefix,
    required this.actionKey,
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  final String keyPrefix;
  final Key actionKey;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        width: 60,
        height: 60,
        child: Material(
          key: ValueKey('${keyPrefix}_quick_entry_material'),
          color: veriElevatedSurfaceColor(
            isDark ? Brightness.dark : Brightness.light,
          ),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            key: ValueKey('${keyPrefix}_quick_entry_ink'),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Tooltip(
              message: label,
              child: InkWell(
                key: actionKey,
                customBorder: const CircleBorder(),
                hoverColor: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.06,
                ),
                splashColor: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.10,
                ),
                onTap: onTap,
                onLongPress: onLongPress,
                child: const Icon(Icons.add_rounded, color: veriRoyal),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
