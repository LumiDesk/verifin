import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'liquid_glass_material.dart';
import 'liquid_glass_surface.dart';

/// 由引擎过滤当前帧的导航图标与文字：不截图、不读回纹理、不采样账目。
///
/// 把导航自身的内容放大、在胶囊内产生透镜形变，而不是去折射页面背景（Flutter 的
/// `BackdropFilter` 无法把模糊结果再交给着色器，强行折射背景会产生坐标错位伪影）。
class VeriLiquidGlassLens extends StatefulWidget {
  const VeriLiquidGlassLens({
    super.key,
    required this.source,
    required this.target,
    required this.pressed,
    required this.motion,
    required this.keyPrefix,
  });

  final Widget source;
  final Rect target;
  final bool pressed;
  final double motion;
  final String keyPrefix;

  @override
  State<VeriLiquidGlassLens> createState() => _VeriLiquidGlassLensState();
}

class _VeriLiquidGlassLensState extends State<VeriLiquidGlassLens> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    unawaited(_loadShader());
  }

  Future<void> _loadShader() async {
    if (!veriLiquidGlassLensAvailable) {
      return;
    }
    await VeriLiquidGlassProgram.load();
    final program = VeriLiquidGlassProgram.program;
    if (!mounted || program == null) {
      return;
    }
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!veriLiquidGlassLensAvailable) {
      return widget.source;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) {
          return const SizedBox.shrink();
        }
        final dark = Theme.of(context).brightness == Brightness.dark;
        final highContrast = MediaQuery.highContrastOf(context);
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        return TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(
            end: Offset(widget.pressed ? 1 : 0, widget.motion),
          ),
          duration: Duration(milliseconds: reducedMotion ? 0 : 160),
          curve: Curves.easeOutCubic,
          builder: (context, state, _) {
            final activity = state.dx;
            final motion = state.dy;
            final width =
                (widget.target.width *
                        (1 + activity * (0.30 + motion.abs() * 0.08)))
                    .clamp(0.0, size.width + 4)
                    .toDouble();
            final height = widget.target.height * (1 + activity * 0.26);
            final centerX = (widget.target.center.dx + motion * activity * 2)
                .clamp(width / 2 - 2, size.width - width / 2 + 2)
                .toDouble();
            final rect = Rect.fromCenter(
              center: Offset(centerX, widget.target.center.dy),
              width: width,
              height: height,
            );
            final ready =
                widget.pressed &&
                activity > 0 &&
                _shader != null &&
                !highContrast;
            const paddingX = 6.0;
            const paddingY = 12.0;
            final filterSize = Size(
              size.width + paddingX * 2,
              size.height + paddingY * 2,
            );
            if (_shader != null) {
              final values = <double>[
                (rect.left + paddingX) / filterSize.width,
                (rect.top + paddingY) / filterSize.height,
                rect.width / filterSize.width,
                rect.height / filterSize.height,
                ready ? activity : 0.0,
                motion,
              ];
              for (var i = 0; i < values.length; i++) {
                _shader!.setFloat(i + 2, values[i]);
              }
            }
            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: ValueKey<String>('${widget.keyPrefix}_liquid_lens'),
                      decoration: BoxDecoration(
                        color: highContrast
                            ? (dark ? veriSurfaceAltDark : veriSurfaceAltLight)
                            : Colors.white.withValues(
                                alpha: dark
                                    ? 0.10 + activity * 0.10
                                    : 0.28 + activity * 0.26,
                              ),
                        borderRadius: BorderRadius.circular(rect.height / 2),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.08 + activity * 0.05,
                            ),
                            blurRadius: 10 + activity * 10,
                            offset: Offset(motion * 2, 3 + activity * 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -paddingX,
                  right: -paddingX,
                  top: -paddingY,
                  bottom: -paddingY,
                  child: ImageFiltered(
                    key: ValueKey<String>(
                      '${widget.keyPrefix}_lens_refraction',
                    ),
                    enabled: ready,
                    imageFilter: _shader != null
                        ? ui.ImageFilter.shader(_shader!)
                        : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: CustomPaint(
                      painter: ready ? const _LensInputBoundsPainter() : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: paddingX,
                          vertical: paddingY,
                        ),
                        child: widget.source,
                      ),
                    ),
                  ),
                ),
                if (!highContrast)
                  Positioned.fromRect(
                    rect: rect,
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: ValueKey<String>('${widget.keyPrefix}_lens_light'),
                        painter: VeriLiquidGlassLightPainter(
                          radius: rect.height / 2,
                          brightness: Theme.of(context).brightness,
                          activity: activity,
                          motion: motion,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 仅在 ImageFiltered 启用的离屏输入中清空完整范围，保证输入边界不随图标
/// 字形的包围盒变化；禁用过滤时绝不能以 src 清空真实页面。
class _LensInputBoundsPainter extends CustomPainter {
  const _LensInputBoundsPainter();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.src,
  );

  @override
  bool shouldRepaint(_LensInputBoundsPainter oldDelegate) => false;
}
