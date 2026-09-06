import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/glass_material.dart';

void main() {
  testWidgets('玻璃出现的零进度帧必须与原背景逐像素一致', (tester) async {
    final key = GlobalKey();
    Future<Uint8List> capture(bool surface, {double reveal = 0}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildVeriFinTheme(Brightness.dark),
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xff2468ac)),
                    ),
                    if (surface)
                      Positioned.fill(
                        child: VeriMaterialScope(
                          advanced: true,
                          child: VeriGlassSurface(
                            grouped: false,
                            reveal: reveal,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        if (reveal == 0 && !Platform.isAndroid) {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          // 本地诊断证据，不作为黄金图依赖。
          final output = File(
            'build/menu-cold/zero-${surface ? 'surface' : 'base'}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(png.buffer.asUint8List());
        }
        image.dispose();
        return Uint8List.fromList(data.buffer.asUint8List());
      }))!;
    }

    final original = await capture(false);
    final transparent = await capture(true);
    var maxDelta = 0;
    var changedChannels = 0;
    for (var i = 0; i < original.length; i++) {
      final delta = (original[i] - transparent[i]).abs();
      if (delta > maxDelta) maxDelta = delta;
      if (delta > 1) changedChannels++;
    }
    expect(
      maxDelta,
      lessThanOrEqualTo(1),
      reason: '零进度已改变 $changedChannels 个颜色通道，不能只检查 reveal 数值',
    );
    for (final progress in [0.000001, 0.0001, 0.01, 0.1, 0.5, 1.0, 0.1, 0.0]) {
      final pixels = await capture(true, reveal: progress);
      var minAlpha = 255;
      var nearZeroDelta = 0;
      for (var offset = 0; offset < pixels.length; offset++) {
        if (offset % 4 == 3 && pixels[offset] < minAlpha) {
          minAlpha = pixels[offset];
        }
        final delta = (pixels[offset] - original[offset]).abs();
        if (delta > nearZeroDelta) nearZeroDelta = delta;
      }
      expect(minAlpha, 255, reason: '进度 $progress 不得把不透明背景擦成透明洞');
      if (progress < 0.001) expect(nearZeroDelta, lessThanOrEqualTo(2));
    }
  }, skip: !veriGlassDesignPreview);
}
