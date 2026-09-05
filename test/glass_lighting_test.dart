import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/glass_lighting.dart';

void main() {
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
