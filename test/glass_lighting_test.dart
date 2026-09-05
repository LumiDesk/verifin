import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/glass_lighting.dart';

void main() {
  test('方向高光不为每个微小线段创建独立模糊任务', () {
    for (final size in [const Size(360, 180), const Size(72, 54)]) {
      final canvas = TestRecordingCanvas();
      const VeriGlassLightPainter(radius: 16).paint(canvas, size);
      final blurredDraws = canvas.invocations.where((record) {
        final args = record.invocation.positionalArguments;
        return args.any((arg) => arg is Paint && arg.maskFilter != null);
      });
      // 卡片大小不能让独立模糊任务随周长增长，避免数百个离屏绘制。
      expect(blurredDraws.length, lessThanOrEqualTo(2));
      expect(
        canvas.invocations.where(
          (record) =>
              record.invocation.memberName == #drawVertices ||
              record.invocation.memberName == #drawPath,
        ),
        isNotEmpty,
        reason: '不能通过停止绘制高光来满足资源上限',
      );
    }
  });
  test('左上右下高光强，右上左下消隐', () {
    final n = 1 / math.sqrt(2);
    expect(veriGlassEdgeLight(Offset.zero, Offset(-n, -n)), greaterThan(0.9));
    expect(
      veriGlassEdgeLight(const Offset(1, 1), Offset(n, n)),
      greaterThan(0.8),
    );
    expect(
      veriGlassEdgeLight(const Offset(1, 0), Offset(n, -n)),
      closeTo(0, 0.001),
    );
    expect(
      veriGlassEdgeLight(const Offset(0, 1), Offset(-n, n)),
      closeTo(0, 0.001),
    );
  });
  test('拖动方向改变光照响应', () {
    const position = Offset(0.25, 0);
    const normal = Offset(0, -1);
    expect(
      veriGlassEdgeLight(position, normal, motion: 1),
      isNot(closeTo(veriGlassEdgeLight(position, normal, motion: -1), 0.01)),
    );
  });
}
