import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_theme.dart';
import 'glass_lighting.dart';

/// 只采样导航自己的图标/文字层；纹理不包含账目、不写磁盘、不对外发送。
class VeriNavigationGlassLens extends StatefulWidget {
  const VeriNavigationGlassLens({
    super.key,
    required this.source,
    required this.target,
    required this.pressed,
    required this.motion,
    required this.revision,
    required this.keyPrefix,
  });
  final Widget source;
  final Rect target;
  final bool pressed;
  final double motion;
  final Object revision;
  final String keyPrefix;

  @override
  State<VeriNavigationGlassLens> createState() =>
      _VeriNavigationGlassLensState();
}

class _VeriNavigationGlassLensState extends State<VeriNavigationGlassLens> {
  final _sourceKey = GlobalKey();
  ui.FragmentShader? _shader;
  ui.Image? _image;
  Object? _capturedRevision;
  Size? _capturedSize;
  bool _captureScheduled = false;

  @override
  void didUpdateWidget(VeriNavigationGlassLens oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 每次交互重新采样，不能复用初次字体尚未就绪或旧布局的文字纹理。
    if (widget.pressed && !oldWidget.pressed) _capturedRevision = null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadShader());
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/navigation_lens.frag',
      );
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (_) {
      // 纯渲染降级：资产载入失败时仍保留导航、形变和方向高光；不影响任何用户操作。
    }
  }

  void _scheduleCapture(Size size) {
    if (!widget.pressed ||
        _shader == null ||
        _captureScheduled ||
        (_capturedRevision == widget.revision && _capturedSize == size)) {
      return;
    }
    _captureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (!mounted) return;
      final boundary = _sourceKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return;
      var paintReady = true;
      assert(() {
        paintReady = !boundary.debugNeedsPaint;
        return true;
      }());
      if (!paintReady) return;
      try {
        final next = boundary.toImageSync(
          // 透镜放大时保留图标/文字的细节，避免低分辨率采样产生重影感。
          pixelRatio: MediaQuery.devicePixelRatioOf(context) * 2,
        );
        final previous = _image;
        setState(() {
          _image = next;
          _capturedRevision = widget.revision;
          _capturedSize = size;
        });
        if (previous != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => previous.dispose(),
          );
        }
      } catch (_) {
        // 页面切换/宿主分离瞬间可能不能读回图层；保留上一帧，下次有效重建重试。
      }
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      _scheduleCapture(size);
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
          final centerX = (widget.target.center.dx + motion * activity * 2)
              .clamp(width / 2 - 2, size.width - width / 2 + 2)
              .toDouble();
          final rect = Rect.fromCenter(
            center: Offset(centerX, widget.target.center.dy),
            width: width,
            height: height,
          );
          // 静止时永远绘制活文字；只在有效交互中以当前布局纹理替换。
          final ready =
              widget.pressed &&
              activity > 0 &&
              _shader != null &&
              _image != null &&
              !highContrast &&
              _capturedRevision == widget.revision &&
              _capturedSize == size;
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
                          ? (dark ? veriSurfaceAltDark : veriSurfaceAltLight)
                          : Colors.white.withValues(
                              alpha: dark
                                  ? 0.10 + activity * 0.10
                                  : 0.28 + activity * 0.26,
                            ),
                      borderRadius: BorderRadius.circular(rect.height / 2),
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
              ClipPath(
                clipper: ready ? _OutsideLensClipper(rect) : null,
                child: RepaintBoundary(key: _sourceKey, child: widget.source),
              ),
              if (ready)
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: ValueKey('${widget.keyPrefix}_lens_refraction'),
                      painter: VeriNavigationLensPainter(
                        shader: _shader!,
                        source: _image!,
                        origin: rect.topLeft,
                        sourceSize: size,
                        activity: activity,
                        motion: motion,
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

class _OutsideLensClipper extends CustomClipper<Path> {
  const _OutsideLensClipper(this.rect);
  final Rect rect;
  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()..addRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    ),
  );
  @override
  bool shouldReclip(_OutsideLensClipper oldClipper) => rect != oldClipper.rect;
}

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
