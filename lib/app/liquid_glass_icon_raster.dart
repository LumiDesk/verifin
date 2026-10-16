import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 把导航图标光栅化成**白色剪影** PNG，供原生 QWEA0 TabBar 经
/// `imageTintList` 上色（反色配色由原生侧驱动）。
///
/// 剪影化：无论源图标是什么颜色，绘制时统一用白色——tint 需要灰度蒙版。
abstract final class VeriGlassIconRaster {
  /// [sizePx] 是逻辑像素；按设备像素比缩放保证清晰度。
  static Future<Uint8List?> silhouette(IconData icon, {double sizePx = 24}) =>
      _run(
        (canvas, size) => TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: size,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          textDirection: TextDirection.ltr,
        ),
        icon,
        sizePx,
      );

  static Future<Uint8List?> _run(
    TextPainter Function(Canvas, double) painter,
    IconData icon,
    double sizePx,
  ) async {
    try {
      final dpr =
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .firstOrNull
              ?.devicePixelRatio ??
          1.0;
      final size = (sizePx * dpr).roundToDouble();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final tp = painter(canvas, sizePx * dpr);
      tp.layout();
      tp.paint(canvas, Offset.zero);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      // 光栅化失败（字体未加载等）：原生侧退化为纯文字 tab。
      return null;
    }
  }
}
