// 底栏条目绘制组件。抄写自 `bottom_bar_matu` 1.5.0 的 `BottomBarDoubleBullet`
// （MIT License, Copyright (c) 2021 Tuannvm），并在本项目内修复了四处缺陷。
//
// 原库的问题（均已在本文件内修复）：
// 1. `didUpdateWidget` 无条件调用 `_handleTextChangeFromOutside()`，每次都把全部
//    图标的 GlobalKey 清空重建。父级每重建一次（切页过程中会有两三次）四个图标的
//    State 就被整体卸载重建，图标颜色与旋转动画从零开始——表现为图标毫无理由地
//    重新抖一下，快速切换时动画直接断掉。这是最要命的一处。
// 2. `_onChangeIndex` 用同一个 AnimationController 交替 `forward()` / `reverse()`
//    来凑出 0→1 的进度（`_getAnimationValue()` 在 reverse 时返回 `1 - value`）。
//    只有「上一段动画已经跑完」时才会走 `reverse()`，所以动画没播完就再次点击会落到
//    `forward()` 分支：控制器值本身连续，但按状态取值的那层映射会一帧内从 `1-v`
//    跳回 `v`，动效断档。
// 3. `_onChangeIndex` 先把 `_oldSelectedIndex = _selectedIndex` 赋值掉，再在延迟回调里
//    用 `_oldSelectedIndex < _selectedIndex` 判方向——此时两边已经相等，比较恒为
//    false，被取消选中的那个图标永远按同一个方向旋转。
// 4. `_onChangeIndex` 里 `await Future.delayed(200ms)` 之后才回调 `onSelect`。这个续体
//    没有任何 mounted / 世代守卫：被后一次切换顶掉时，它会拿着最新的下标再回调一次，
//    被跳过那次点击的回调永远不会送达，最终下标则被送达两次。
//
// 修复方式：key 只在条目数变化时重建；只在 selectedIndex 真变化时播动画；进度只用
// 一次 `forward(from: 0)`；方向在改下标之前算好并同步传给两端图标；选中态同步更新，
// 不再有延迟回调，`onSelect` 每次点击恰好触发一次。
//
// 另有一处**不是**缺陷、但容易误判：原库取切线点用 `length * (进度 * 1.5)`，进度过
// 2/3 时距离确实越过了路径长度，但 `PathMetric.getTangentForOffset` 会把距离截断到
// 当前轮廓长度（见 Flutter SDK `painting.dart` 该方法的文档），既不返回 null 也不抛
// 异常；实际效果只是圆点在约 67% 处到达终点后停住。本文件仍显式截断一次，以免依赖
// 这条隐式行为。

import 'dart:math';

import 'package:flutter/material.dart';

/// 底栏条目的未选中灰阶。沿用 `bottom_bar_matu` 的 `colorGrey5`；改这个值会改变
/// 底栏观感，不属于本次修复范围，故原样保留并集中在此处。
const Color _kUnselectedGrey = Color(0xFFADADAD);

/// 飞过的圆点在进度过了这个值后淡出（原库的 `value * 1.5 >= 0.9`）。
const double _kDotFadeAt = 0.6;

@immutable
class VeriBottomBarItem {
  const VeriBottomBarItem({
    required this.iconData,
    this.iconSize = 30,
    this.label,
    this.labelTextStyle,
  });

  final IconData iconData;
  final double iconSize;
  final String? label;
  final TextStyle? labelTextStyle;
}

/// 视觉上与 `BottomBarDoubleBullet` 一致的底栏：切换时两条圆弧扫过、两枚圆点飞过。
///
/// 与库的差别是**选中状态完全由 [selectedIndex] 驱动**（单一数据源），组件不再自己
/// 记住选中项、也不再延迟回调。父级改变 [selectedIndex] 即触发切换动画。
class VeriBottomBar extends StatefulWidget {
  const VeriBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onSelect,
    this.height = 71,
    this.color = const Color(0xFF279656),
    this.circle1Color = Colors.blue,
    this.circle2Color = Colors.red,
    this.backgroundColor = Colors.transparent,
  });

  /// 切换动画时长。调用方用同一时长驱动页面切换，两者才会同时起步、同时结束。
  static const Duration switchDuration = Duration(milliseconds: 500);

  final List<VeriBottomBarItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final double height;
  final Color color;
  final Color circle1Color;
  final Color circle2Color;
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

  /// 切换选中项。跨多页跳转（跨度大于一页）不播过场动画：调用方此时是瞬移页面
  /// （见 `VeriFinShell._goToTab`），底栏跟着直接落位，两者仍然同时结束。
  void _select(int index) {
    assert(index >= 0 && index < widget.items.length, 'selectedIndex 越界');
    if (index == _selectedIndex) {
      return;
    }

    final previous = _selectedIndex;
    final forward = index > previous;
    final animate = (index - previous).abs() == 1;

    setState(() {
      _selectedIndex = index;
      _fromIndex = animate ? previous : index;
      _animating = animate;
    });

    if (animate) {
      _controller.forward(from: 0);
    } else {
      _controller.stop();
    }

    // 同步更新两端图标：不等任何延迟回调，快速连续切换也不会错位。
    _iconKeys[previous].currentState?.updateSelect(false, forward);
    _iconKeys[index].currentState?.updateSelect(true, forward);
  }

  double _progress() => _animating ? _controller.value : 1;

  double _centerOf(int index, double iconWidth) =>
      index * iconWidth + iconWidth / 2;

  @override
  Widget build(BuildContext context) {
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
                if (_animating) ..._sweepLayers(iconWidth),
                Row(children: _iconWidgets()),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 切换过程中飞过的两条圆弧与两枚圆点。静止时全部不绘制（与原库一致）。
  List<Widget> _sweepLayers(double iconWidth) {
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
            child: CustomPaint(painter: _BulletLinePainter(path, widget.color)),
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
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        },
      );
    }

    return <Widget>[
      sweep(path1),
      dot(path1, widget.circle1Color),
      sweep(path2),
      dot(path2, widget.circle2Color),
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
  /// 在条高四等分中的位置（1.5 与 2.5 分列中线两侧）。与原库的两条路径同构。
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

  List<Widget> _iconWidgets() {
    return <Widget>[
      for (var index = 0; index < widget.items.length; index++)
        Expanded(
          child: InkWell(
            onTap: widget.onSelect == null
                ? null
                : () => widget.onSelect!(index),
            child: IgnorePointer(
              child: _VeriBottomBarIcon(
                key: _iconKeys[index],
                item: widget.items[index],
                color: widget.color,
                selected: _selectedIndex == index,
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

  /// 由 [VeriBottomBar] 在切换时同步调用（原库是延迟 200ms 的异步回调）。
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
          // 标签固定在条底 5dp（沿用原库）；图标区从条顶到条底 10dp。
          // 原库声明过一个 `labelMarginTop`，但从未参与布局，这里不再保留这个死参数。
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
        // 颜色在动画前半程就插值完（原库的 `value * 2` 截断）。
        final color = Color.lerp(
          _kUnselectedGrey,
          widget.color,
          (progress * 2).clamp(0.0, 1.0),
        )!;

        // 摆动幅度：0 → 18° → 0，中点最明显。
        //
        // 原库写的是 `-pi / (8 * scaleValue)`，其中 `scaleValue = 5v(1-v)`。分母在
        // 进度接近 0 和 1 时趋近 0，图标会在动画头尾各瞬间旋转好几圈才停下，看起来
        // 就是「抖一下」；中点的 18° 才是原意。这里用同一个凸包函数直接作角度比例，
        // 保留中点的姿态、去掉两端的退化旋转。
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
