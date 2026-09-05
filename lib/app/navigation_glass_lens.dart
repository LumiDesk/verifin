import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'glass_lighting.dart';
import 'glass_material.dart';

/// 由引擎过滤当前帧导航图标/文字；不截图、不读回纹理、不采样账目。
class VeriNavigationGlassLens extends StatefulWidget {
  const VeriNavigationGlassLens({
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
  State<VeriNavigationGlassLens> createState() =>
      _VeriNavigationGlassLensState();
}

class _VeriNavigationGlassLensState extends State<VeriNavigationGlassLens> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    unawaited(_loadShader());
  }

  Future<void> _loadShader() async {
    // 独立保护直接使用此组件的入口，未验收平台不加载 Shader。
    if (!veriAdvancedMaterialAvailable ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return;
    }
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/navigation_live_lens.frag',
      );
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (_) {
      // 纯渲染降级：资产载入失败时仍保留导航、形变和方向高光；不影响任何用户操作。
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !veriAdvancedMaterialAvailable
      ? widget.source
      : LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
            final dark = Theme.of(context).brightness == Brightness.dark;
            final highContrast = MediaQuery.highContrastOf(context);
            final reducedMotion = MediaQuery.disableAnimationsOf(context);
            return TweenAnimationBuilder<Offset>(
              tween: Tween(end: Offset(widget.pressed ? 1 : 0, widget.motion)),
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
                final centerX =
                    (widget.target.center.dx + motion * activity * 2)
                        .clamp(width / 2 - 2, size.width - width / 2 + 2)
                        .toDouble();
                final rect = Rect.fromCenter(
                  center: Offset(centerX, widget.target.center.dy),
                  width: width,
                  height: height,
                );
                // 高亮变化仅更新同一帧的 child，不触发快照失效/重新采样。
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
                  final values = [
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
                  children: [
                    Positioned.fromRect(
                      rect: rect,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: ValueKey('${widget.keyPrefix}_liquid_lens'),
                          decoration: BoxDecoration(
                            color: highContrast
                                ? (dark
                                      ? veriSurfaceAltDark
                                      : veriSurfaceAltLight)
                                : Colors.white.withValues(
                                    alpha: dark
                                        ? 0.10 + activity * 0.10
                                        : 0.28 + activity * 0.26,
                                  ),
                            borderRadius: BorderRadius.circular(
                              rect.height / 2,
                            ),
                            boxShadow: [
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
                        key: ValueKey('${widget.keyPrefix}_lens_refraction'),
                        enabled: ready,
                        imageFilter: _shader != null
                            ? ui.ImageFilter.shader(_shader!)
                            : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: CustomPaint(
                          painter: ready
                              ? const _LensInputBoundsPainter()
                              : null,
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
                            key: ValueKey('${widget.keyPrefix}_lens_light'),
                            painter: VeriGlassLightPainter(
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

// 仅在 ImageFiltered 启用的离屏输入中清空完整范围，保证输入边界不随
// 图标字形的包围盒变化。禁用过滤时绝不能以 src 清空真实页面。
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

/// 仅供历史图形诊断入口复现旧采样流程；正式导航使用同帧 ImageFiltered。
class VeriNavigationLensPainter extends CustomPainter {
  const VeriNavigationLensPainter({
    required this.shader,
    required this.source,
    required this.origin,
    required this.sourceSize,
    required this.activity,
    required this.motion,
  });
  final ui.FragmentShader shader;
  final ui.Image source;
  final Offset origin;
  final Size sourceSize;
  final double activity;
  final double motion;
  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      size.width,
      size.height,
      origin.dx,
      origin.dy,
      sourceSize.width,
      sourceSize.height,
      activity,
      motion,
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i, values[i]);
    }
    shader.setImageSampler(0, source);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(VeriNavigationLensPainter oldDelegate) =>
      source != oldDelegate.source ||
      origin != oldDelegate.origin ||
      sourceSize != oldDelegate.sourceSize ||
      activity != oldDelegate.activity ||
      motion != oldDelegate.motion;
}
