import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'liquid_glass_material.dart';
import 'root_navigation.dart';

/// 液态玻璃底栏样式：浮动胶囊 + 背景模糊 + 玻璃指示块。
///
/// 这是与停靠底栏并列的可选样式，只改变导航栏本身的呈现方式：
/// 四个根目的地、切页状态机、返回键语义、记账按钮与页面骨架都不受影响。
///
/// 与停靠样式的差异集中在两处：
/// - [layout] 声明 `extendBody: true`，页面内容会从胶囊下方滚过，
///   玻璃后面才有可折射的内容；
/// - 条目与指示块由本文件自绘，不复用 `VeriBottomBar`。
class VeriLiquidGlassRootNavigationStyle implements VeriRootNavigationStyle {
  const VeriLiquidGlassRootNavigationStyle();

  /// 持久化标识。与 `NavigationStylePreference.liquidGlass` 的枚举名一致。
  static const String styleId = 'liquidGlass';

  /// 胶囊高度（不含系统安全区与底部留白）。
  static const double barHeight = 60;

  /// 胶囊左右外边距。
  static const double sideGap = 12;

  /// 胶囊与系统安全区之间的留白。
  static const double bottomGap = 10;

  /// 列表末项在避让之外额外保留的呼吸空间。
  static const double listBottomGap = 16;

  /// 指示块相对胶囊的内缩距离。
  static const double indicatorInset = 4;

  /// 指示块滑动与页面过渡共用的时间尺度。
  static const Duration switchTime = Duration(milliseconds: 280);

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
  Duration get switchDuration => switchTime;

  @override
  Widget buildBar(BuildContext context, VeriRootNavigationSpec spec) =>
      VeriLiquidGlassRootNavigation(spec: spec);
}

/// 液态玻璃底栏的绘制实现。
///
/// 选中态只由 [VeriRootNavigationSpec.currentIndex] 驱动，组件自身不记业务状态；
/// 指示块位置在样式内部插值，切换时与 Shell 的页面过渡同起同落。
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
  /// 面板背景模糊半径（逻辑像素）。
  static const double _blurSigma = 22;

  /// 受折射影响的边缘厚度与最大采样偏移（逻辑像素）。
  static const double _refractionHeight = 28;
  static const double _refractionAmount = 22;

  final GlobalKey _capsuleKey = GlobalKey();
  late final AnimationController _controller;
  late final Animation<double> _curve;
  ui.FragmentShader? _shader;

  /// 胶囊在背景纹理坐标系中的矩形（物理像素）。
  Rect? _capsuleRectPx;

  /// 指示块起始下标；动画中断时从当前插值位置继续，不会跳回起点。
  late double _fromIndex;
  late int _currentIndex;
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.spec.currentIndex;
    _fromIndex = _currentIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: VeriLiquidGlassRootNavigationStyle.switchTime,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    unawaited(
      VeriLiquidGlassProgram.load().then((_) {
        if (mounted) {
          setState(() {});
        }
      }),
    );
  }

  @override
  void dispose() {
    _shader?.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 面板滤镜：着色器可用时用「先模糊、再折射」的复合滤镜，否则只模糊。
  ui.ImageFilter _panelFilter(double devicePixelRatio) {
    final blur = ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma);
    final program = VeriLiquidGlassProgram.program;
    final rect = _capsuleRectPx;
    if (program == null || rect == null) {
      return blur;
    }
    final shader = _shader ??= program.fragmentShader();
    // uniform 布局：0-1 由引擎写入纹理尺寸，随后依次是矩形原点、矩形尺寸、
    // 折射厚度与折射量。
    shader.setFloat(2, rect.left);
    shader.setFloat(3, rect.top);
    shader.setFloat(4, rect.width);
    shader.setFloat(5, rect.height);
    shader.setFloat(6, _refractionHeight * devicePixelRatio);
    shader.setFloat(7, _refractionAmount * devicePixelRatio);
    return ui.ImageFilter.compose(
      outer: blur,
      inner: ui.ImageFilter.shader(shader),
    );
  }

  /// 布局稳定后记录胶囊在屏幕中的物理像素矩形，供折射着色器定位形状。
  void _measureCapsule(double devicePixelRatio) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final box = _capsuleKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final origin = box.localToGlobal(Offset.zero);
      final rect = Rect.fromLTWH(
        origin.dx * devicePixelRatio,
        origin.dy * devicePixelRatio,
        box.size.width * devicePixelRatio,
        box.size.height * devicePixelRatio,
      );
      if (_capsuleRectPx != rect) {
        setState(() => _capsuleRectPx = rect);
      }
    });
  }

  @override
  void didUpdateWidget(covariant VeriLiquidGlassRootNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.spec.currentIndex;
    if (index == _currentIndex ||
        index < 0 ||
        index >= widget.spec.destinations.length) {
      return;
    }
    setState(() {
      _fromIndex = _animatedIndex;
      _currentIndex = index;
      _pressedIndex = null;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  /// 当前正在显示的指示块下标（含动画中间值）。
  double get _animatedIndex =>
      _fromIndex + (_currentIndex - _fromIndex) * _curve.value;

  void _handlePressStart(int index) {
    if (_pressedIndex == index) {
      return;
    }
    setState(() => _pressedIndex = index);
  }

  void _handlePressEnd() {
    if (_pressedIndex == null) {
      return;
    }
    setState(() => _pressedIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    assert(spec.destinations.isNotEmpty, '根导航至少要有一个目的地');
    assert(
      spec.currentIndex >= 0 && spec.currentIndex < spec.destinations.length,
      'currentIndex 越界',
    );

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final surfaceTint = dark
        ? const Color(0xFF121212).withValues(alpha: 0.46)
        : const Color(0xFFE9EDF3).withValues(alpha: 0.62);
    final rimColor = dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.9);
    final indicatorTint = dark
        ? Colors.white.withValues(alpha: 0.12)
        : accent.withValues(alpha: 0.16);
    final shadowColor = Colors.black.withValues(alpha: dark ? 0.38 : 0.16);

    final borderRadius = BorderRadius.circular(
      VeriLiquidGlassRootNavigationStyle.barHeight / 2,
    );
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    _measureCapsule(devicePixelRatio);

    return DecoratedBox(
      key: ValueKey<String>(spec.keyOf('bottom_nav')),
      // 整条导航不铺任何底色：胶囊以外的区域要能看到页面内容。
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth =
                    constraints.maxWidth / spec.destinations.length;
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            key: _capsuleKey,
                            borderRadius: borderRadius,
                            child: BackdropFilter(
                              filter: _panelFilter(devicePixelRatio),
                              child: ColoredBox(color: surfaceTint),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 指示块画在条目前面、条目内容后面：玻璃块托住选中项，
                    // 同时保证标签与图标始终清晰可读。
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _curve,
                          builder: (context, _) => _GlassIndicator(
                            left:
                                _animatedIndex * tabWidth +
                                VeriLiquidGlassRootNavigationStyle
                                    .indicatorInset,
                            width:
                                tabWidth -
                                VeriLiquidGlassRootNavigationStyle
                                        .indicatorInset *
                                    2,
                            tint: indicatorTint,
                            pressed: _pressedIndex != null,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: Row(
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
                                  selected: _currentIndex == index,
                                  accent: accent,
                                  enabled: spec.onSelect != null,
                                  onTap: spec.onSelect == null
                                      ? null
                                      : () => spec.onSelect!(index),
                                  onPressStart: () => _handlePressStart(index),
                                  onPressEnd: _handlePressEnd,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // 顶部细描边画在最上层且不拦截点击，突出玻璃边缘。
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            border: Border.all(color: rimColor),
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

/// 选中项底下的玻璃指示块；按压缩放由 [pressed] 驱动。
class _GlassIndicator extends StatelessWidget {
  const _GlassIndicator({
    required this.left,
    required this.width,
    required this.tint,
    required this.pressed,
  });

  final double left;
  final double width;
  final Color tint;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    const inset = VeriLiquidGlassRootNavigationStyle.indicatorInset;
    return Stack(
      children: <Widget>[
        Positioned(
          left: left,
          top: inset,
          width: width,
          height: VeriLiquidGlassRootNavigationStyle.barHeight - inset * 2,
          child: AnimatedScale(
            scale: pressed ? 1.06 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(
                  VeriLiquidGlassRootNavigationStyle.barHeight,
                ),
              ),
            ),
          ),
        ),
      ],
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
    required this.onPressStart,
    required this.onPressEnd,
  });

  final VeriNavigationDestination destination;
  final bool selected;
  final Color accent;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: onTap,
          onTapDown: enabled ? (_) => onPressStart() : null,
          onTapUp: enabled ? (_) => onPressEnd() : null,
          onTapCancel: enabled ? onPressEnd : null,
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
