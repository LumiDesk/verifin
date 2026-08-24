import 'dart:ui';

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

/// Veri Fin 根页面的浮动玻璃导航。
///
/// 玻璃基底只使用均匀中性透明色、背景模糊、单一轮廓和阴影，不绘制渐变或
/// 固定染色。选中滑块支持按压缩放、指针连续拖动和松手吸附；快捷记账按钮仅
/// 由调用方在首页启用。
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
  bool _indicatorPressed = false;
  bool _dragging = false;
  bool _suppressNextDestinationTap = false;
  int? _activePointer;
  int? _pressedTargetIndex;
  double? _pointerDownX;

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
      _pressedTargetIndex = pressedIndex;
      _dragging = false;
      _indicatorPressed = true;
    });
    _animateIndicatorTo(pressedIndex.toDouble(), _pressMoveDuration);
  }

  void _handlePointerMove(PointerMoveEvent event, double slotWidth) {
    if (event.pointer != _activePointer ||
        _pointerDownX == null ||
        _pressedTargetIndex == null) {
      return;
    }
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
      _pressedTargetIndex = null;
      _dragging = false;
      _indicatorPressed = false;
    });
    if (wasDragging) {
      _animateIndicatorTo(targetIndex.toDouble(), _snapDuration);
      widget.onDestinationSelected(targetIndex);
    } else if (pressedTargetIndex != null) {
      _suppressNextDestinationTap = true;
      _animateIndicatorTo(pressedTargetIndex.toDouble(), _snapDuration);
      widget.onDestinationSelected(pressedTargetIndex);
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
    _animateIndicatorTo(index.toDouble(), _snapDuration);
    widget.onDestinationSelected(index);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    _indicatorController.stop();
    setState(() {
      _activePointer = null;
      _pointerDownX = null;
      _pressedTargetIndex = null;
      _dragging = false;
      _indicatorPressed = false;
    });
    _animateIndicatorTo(widget.currentIndex.toDouble(), _snapDuration);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      key: _key('bottom_nav'),
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                    child: _buildGlassCapsule(isDark),
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
    );
  }

  Widget _buildGlassCapsule(bool isDark) {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            key: _key('nav_material'),
            color: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              key: _key('nav_ink'),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.055 : 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.10),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slotWidth =
                      constraints.maxWidth / widget.destinations.length;
                  final selectedIndex = _displayIndex.round().clamp(
                    0,
                    widget.destinations.length - 1,
                  );
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) =>
                        _handlePointerDown(event, slotWidth),
                    onPointerMove: (event) =>
                        _handlePointerMove(event, slotWidth),
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Positioned(
                          key: _key('nav_indicator_position'),
                          left: _displayIndex * slotWidth + 3,
                          top: 3,
                          bottom: 3,
                          width: slotWidth - 6,
                          child: IgnorePointer(
                            child: AnimatedScale(
                              key: _key('nav_indicator_scale'),
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              scale: _indicatorPressed || _dragging ? 0.94 : 1,
                              child: DecoratedBox(
                                key: _key('nav_indicator'),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: isDark ? 0.12 : 0.065),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(
                                              alpha: isDark ? 0.16 : 0.08,
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            for (
                              var index = 0;
                              index < widget.destinations.length;
                              index += 1
                            )
                              Expanded(
                                child: _DestinationButton(
                                  key: _key('tab_$index'),
                                  inkKey: _key('tab_ink_$index'),
                                  destination: widget.destinations[index],
                                  selected: index == selectedIndex,
                                  onTap: () => _handleDestinationTap(index),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
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
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Material(
              key: ValueKey('${keyPrefix}_quick_entry_material'),
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                key: ValueKey('${keyPrefix}_quick_entry_ink'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: isDark ? 0.055 : 0.14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.10),
                  ),
                ),
                child: Tooltip(
                  message: label,
                  child: InkWell(
                    key: actionKey,
                    customBorder: const CircleBorder(),
                    hoverColor: Colors.white.withValues(
                      alpha: isDark ? 0.08 : 0.26,
                    ),
                    splashColor: Colors.white.withValues(
                      alpha: isDark ? 0.12 : 0.34,
                    ),
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: const Icon(Icons.add_rounded, color: veriRoyal),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationButton extends StatefulWidget {
  const _DestinationButton({
    super.key,
    required this.inkKey,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final Key inkKey;
  final VeriNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DestinationButton> createState() => _DestinationButtonState();
}

class _DestinationButtonState extends State<_DestinationButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.selected
        ? scheme.onSurface.withValues(alpha: 0.94)
        : scheme.onSurface.withValues(alpha: _hovered ? 0.76 : 0.48);
    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.destination.label,
      child: Tooltip(
        message: widget.destination.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: widget.inkKey,
              borderRadius: BorderRadius.circular(999),
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onHover: (value) {
                if (_hovered != value) {
                  setState(() => _hovered = value);
                }
              },
              onTap: widget.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    widget.selected
                        ? widget.destination.selectedIcon
                        : widget.destination.icon,
                    size: 21,
                    color: color,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.destination.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
