// 底栏条目绘制组件。基于 `bottom_bar_matu` 1.5.0 的 `BottomBarDoubleBullet`
// （MIT License, Copyright (c) 2021 Tuannvm）在本项目内自持维护。
//
// 设计要点：
// - key 只在条目数变化时重建，父级重建不影响图标 State 与动画；
// - 只在 `selectedIndex` 真变化时播动画，进度用一次 `forward(from: 0)`；
// - 方向在改下标之前算好并同步传给两端图标；选中态同步更新，
//   `onSelect` 每次点击恰好触发一次；
// - 取切线点距离显式截断到轮廓长度，不依赖 `getTangentForOffset` 的隐式截断。

import 'dart:math';

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 底栏条目的未选中灰阶，集中在此处；改动会影响底栏观感。
const Color _kUnselectedGrey = veriNavigationUnselected;

/// 飞过的圆点在进度过了这个值后淡出。
const double _kDotFadeAt = 0.6;

@immutable
class VeriBottomBarItem {
  const VeriBottomBarItem({
    required this.iconData,
    this.itemKey,
    this.iconSize = 30,
    this.label,
    this.labelTextStyle,
  });

  final IconData iconData;

  /// 条目的稳定 key，供测试与无障碍按条目定位，不依赖等宽几何。
  ///
  /// 契约（见 `root_navigation.dart`）要求每个样式为条目产出 `<前缀>_nav_item_<下标>`。
  final Key? itemKey;

  final double iconSize;
  final String? label;
  final TextStyle? labelTextStyle;
}

/// 视觉上与 `BottomBarDoubleBullet` 一致的底栏：切换时两条圆弧扫过、两枚圆点飞过。
///
/// 与库的差别是**选中状态完全由 [selectedIndex] 驱动**（单一数据源），组件不再自己
/// 记住选中项、也不再延迟回调。父级改变 [selectedIndex] 即触发切换动画。
/// 颜色默认跟随 `Theme.of(context).colorScheme.primary`，不会写死成品牌蓝。
class VeriBottomBar extends StatefulWidget {
  const VeriBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onSelect,
    this.height = 71,
    this.color,
    this.circle1Color,
    this.circle2Color,
    this.backgroundColor = Colors.transparent,
  });

  /// 切换动画的时间尺度。调用方以同一尺度驱动页面切换（页面是弹簧，没有固定
  /// 时长），两者才会同时起步、同时收住。
  static const Duration switchDuration = Duration(milliseconds: 250);

  final List<VeriBottomBarItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final double height;

  /// 选中项、圆弧与圆点的主色。省略时取当前主题的 `colorScheme.primary`，这样
  /// 用户切换动态色或自定义主题色时底栏会一起跟随，不会被默认值锁成品牌蓝。
  final Color? color;

  /// 切换时两枚圆点的颜色；省略时跟随 [color]。
  final Color? circle1Color;
  final Color? circle2Color;
  final Color backgroundColor;

  @override
  State<VeriBottomBar> createState() => _VeriBottomBarState();
}

class _VeriBottomBarState extends State<VeriBottomBar>
    with SingleTickerProviderStateMixin {
  final List<GlobalKey<_VeriBottomBarIconState>> _iconKeys =
      <GlobalKey<_VeriBottomBarIconState>>[];

  late final AnimationController _controller;
  late int _selectedIndex;

  /// 动画起点下标；不在动画中时与 [_selectedIndex] 相同。
  late int _fromIndex;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _fromIndex = widget.selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: VeriBottomBar.switchDuration,
    )..addStatusListener(_handleStatus);
    _syncIconKeys();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VeriBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只在条目数变化时重建 key。父级普通重建不再波及图标 State。
    if (oldWidget.items.length != widget.items.length) {
      _syncIconKeys();
    }
    if (widget.selectedIndex != _selectedIndex) {
      _select(widget.selectedIndex);
    }
  }

  void _syncIconKeys() {
    while (_iconKeys.length < widget.items.length) {
      _iconKeys.add(GlobalKey<_VeriBottomBarIconState>());
    }
    while (_iconKeys.length > widget.items.length) {
      _iconKeys.removeLast();
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    setState(() {
      _animating = false;
      _fromIndex = _selectedIndex;
    });
  }

  /// 切换选中项。
  ///
  /// 每次切换都从旧位置扫到新位置，跨度多大都一样——页面那边同步播同一时长的过渡，
  /// 两者才会一起起步、一起结束。
  void _select(int index) {
    assert(index >= 0 && index < widget.items.length, 'selectedIndex 越界');
    if (index == _selectedIndex) {
      return;
    }

    final previous = _selectedIndex;
    final forward = index > previous;

    setState(() {
      _selectedIndex = index;
      _fromIndex = previous;
      _animating = true;
    });
    _controller.forward(from: 0);

    // 同步更新两端图标：不等任何延迟回调，快速连续切换也不会错位。
    // 条目数刚变少时 previous 可能已经越界（本应用的根导航固定四项，这里只做兜底）。
    if (previous < _iconKeys.length) {
      _iconKeys[previous].currentState?.updateSelect(false, forward);
    }
    _iconKeys[index].currentState?.updateSelect(true, forward);
  }

  double _progress() => _animating ? _controller.value : 1;

  double _centerOf(int index, double iconWidth) =>
      index * iconWidth + iconWidth / 2;

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? Theme.of(context).colorScheme.primary;
    final circle1 = widget.circle1Color ?? accent;
    final circle2 = widget.circle2Color ?? accent;
    return SizedBox(
      height: widget.height,
      child: ColoredBox(
        color: widget.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 用实际布局宽度而不是屏幕宽度：底栏是整宽的，两者相等，但布局宽度
            // 在测试和未来的内嵌场景里才是正确来源。
            final iconWidth = constraints.maxWidth / widget.items.length;
            return Stack(
              children: <Widget>[
                if (_animating)
                  ..._sweepLayers(iconWidth, accent, circle1, circle2),
                Row(children: _iconWidgets(accent)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 切换过程中飞过的两条圆弧与两枚圆点。静止时全部不绘制。
  List<Widget> _sweepLayers(
    double iconWidth,
    Color accent,
    Color circle1,
    Color circle2,
  ) {
    final startX = _centerOf(_fromIndex, iconWidth);
    final endX = _centerOf(_selectedIndex, iconWidth);
    final reverse = _fromIndex > _selectedIndex;
    final path1 = _arcPath(
      startX,
      endX,
      reverse ? 2.5 : 1.5,
      reverse ? 1.5 : 2.5,
    );
    final path2 = _arcPath(
      startX,
      endX,
      reverse ? 1.5 : 2.5,
      reverse ? 2.5 : 1.5,
    );
    final isLeftToRight = _fromIndex < _selectedIndex;

    Widget sweep(Path path) {
      return Positioned.fill(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => ClipPath(
            clipper: _SweepClipper(_progress(), startX, endX, reverse),
            child: CustomPaint(painter: _BulletLinePainter(path, accent)),
          ),
        ),
      );
    }

    Widget dot(Path path, Color color) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _progress();
          final point = _pointOn(path, progress);
          return Positioned(
            top: point.dy - 3,
            left: point.dx + (isLeftToRight ? 13 : -17),
            child: Opacity(
              opacity: progress >= _kDotFadeAt ? 0 : 1,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          );
        },
      );
    }

    return <Widget>[
      sweep(path1),
      dot(path1, circle1),
      sweep(path2),
      dot(path2, circle2),
    ];
  }

  /// 取路径上的点。
  ///
  /// 进度按 1.5 倍前进（圆点比圆弧先到终点）。`getTangentForOffset` 本身会把越界的
  /// 距离截断到轮廓长度，这里仍显式截断一次，避免依赖那条隐式行为。用手动迭代器取
  /// 首段：`PathMetrics` 的迭代器只能用一次。
  Offset _pointOn(Path path, double progress) {
    final iterator = path.computeMetrics().iterator;
    if (!iterator.moveNext()) {
      return Offset.zero;
    }
    final metric = iterator.current;
    final distance = (metric.length * progress * 1.5).clamp(0.0, metric.length);
    return metric.getTangentForOffset(distance)?.position ?? Offset.zero;
  }

  /// 从 [startX] 到 [endX] 的一段三次贝塞尔。[startQuarter] / [endQuarter] 是端点
  /// 在条高四等分中的位置（1.5 与 2.5 分列中线两侧）。
  Path _arcPath(
    double startX,
    double endX,
    double startQuarter,
    double endQuarter,
  ) {
    final width = (startX - endX).abs();
    final isReverse = startX > endX;
    final quarter = widget.height / 4;

    final c1x = isReverse ? endX + 3 * width / 4 : startX + width / 4;
    final c1y = quarter * (isReverse ? 3.5 : 0.5);
    final c2x = isReverse ? endX + width / 4 : startX + 3 * width / 4;
    final c2y = quarter * (isReverse ? 0.5 : 3.5);

    return Path()
      ..moveTo(startX, quarter * startQuarter)
      ..cubicTo(c1x, c1y, c2x, c2y, endX, quarter * endQuarter);
  }

  List<Widget> _iconWidgets(Color accent) {
    return <Widget>[
      for (var index = 0; index < widget.items.length; index++)
        Expanded(
          key: widget.items[index].itemKey,
          // MergeSemantics + selected：条目对 TalkBack 的语义是「一个已选中/未
          // 选中的按钮」，而不是只有名字和点击。缺少 selected 时读屏能念出标签，
          // 却无法告诉用户当前停在第几个 Tab。
          child: MergeSemantics(
            child: Semantics(
              selected: _selectedIndex == index,
              child: InkWell(
                onTap: widget.onSelect == null
                    ? null
                    : () => widget.onSelect!(index),
                // 底栏表面是不透明的，Material 的溅墨只会画在它下面、永远看不见；
                // 关掉不可见的涟漪，选中反馈完全交给图标动效。
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: IgnorePointer(
                  child: _VeriBottomBarIcon(
                    key: _iconKeys[index],
                    item: widget.items[index],
                    color: accent,
                    selected: _selectedIndex == index,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// 切换过程中用来裁出「正在扫过的那一小段」的竖向窗口。
class _SweepClipper extends CustomClipper<Path> {
  const _SweepClipper(this.progress, this.startX, this.endX, this.isReverse);

  final double progress;
  final double startX;
  final double endX;
  final bool isReverse;

  @override
  Path getClip(Size size) {
    final width = (endX - startX).abs();
    final x = isReverse
        ? startX - width * progress * 1.5
        : startX + width * progress * 1.5;
    // 窗口比圆弧本身宽，因此看到的是扫过的一小段而不是整条线。
    final leading = isReverse ? 30 : -30;
    final trailing = isReverse ? -10 : 10;
    return Path()
      ..moveTo(x + leading, 0)
      ..lineTo(x + trailing, 0)
      ..lineTo(x + trailing, size.height)
      ..lineTo(x + leading, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_SweepClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.startX != startX ||
      oldClipper.endX != endX ||
      oldClipper.isReverse != isReverse;
}

class _BulletLinePainter extends CustomPainter {
  const _BulletLinePainter(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BulletLinePainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}

/// 单个底栏条目：图标 + 常显文字。选中时图标由灰渐变为品牌色并轻微摆动。
class _VeriBottomBarIcon extends StatefulWidget {
  const _VeriBottomBarIcon({
    super.key,
    required this.item,
    required this.color,
    this.selected = false,
  });

  final VeriBottomBarItem item;
  final Color color;
  final bool selected;

  @override
  State<_VeriBottomBarIcon> createState() => _VeriBottomBarIconState();
}

class _VeriBottomBarIconState extends State<_VeriBottomBarIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _isSelected;
  bool _isLeftToRight = false;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.selected;
    _controller = AnimationController(
      vsync: this,
      duration: VeriBottomBar.switchDuration,
      value: widget.selected ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 由 [VeriBottomBar] 在切换时同步调用。
  void updateSelect(bool isSelected, bool isLeftToRight) {
    if (_isSelected == isSelected && _isLeftToRight == isLeftToRight) {
      return;
    }
    setState(() {
      _isSelected = isSelected;
      _isLeftToRight = isLeftToRight;
    });
    if (isSelected) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      child: Stack(
        children: <Widget>[
          // 标签固定在条底 5dp，图标区从条顶到条底 10dp。
          Positioned(bottom: 5, left: 0, right: 0, child: _labelWidget()),
          Positioned(
            bottom: widget.item.label != null ? 10 : 0,
            top: 0,
            left: 0,
            right: 0,
            child: _iconWidget(),
          ),
        ],
      ),
    );
  }

  Widget _iconWidget() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        // 颜色在动画前半程就插值完。
        final color = Color.lerp(
          _kUnselectedGrey,
          widget.color,
          (progress * 2).clamp(0.0, 1.0),
        )!;

        // 摆动幅度：0 → 18° → 0，中点最明显。
        //
        // 用凸包函数 5v(1-v) 直接作角度比例：0 → 18° → 0，中点最明显；不在进度
        // 接近 0/1 时发散，避免头尾多圈旋转。
        final wobble = 5 * progress * (1 - progress) / 1.25;
        final angle = (pi / 10) * wobble * (_isLeftToRight ? -1 : 1);

        final icon = Icon(
          widget.item.iconData,
          size: widget.item.iconSize,
          color: color,
        );
        if (wobble <= 0) {
          return icon;
        }
        return Transform.rotate(angle: angle, child: icon);
      },
    );
  }

  Widget _labelWidget() {
    final label = widget.item.label;
    if (label == null) {
      return const SizedBox.shrink();
    }
    return Text(
      label,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: (widget.item.labelTextStyle ?? const TextStyle()).copyWith(
        color: _isSelected ? widget.color : _kUnselectedGrey,
      ),
    );
  }
}
