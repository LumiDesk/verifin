import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/chart_painters.dart';

void main() {
  group('trendChartRect 绘图区内边距', () {
    const size = Size(100, 50);

    test('有 X/Y 轴标签：左留 30、右留 8、底留 22', () {
      final rect = trendChartRect(size, hasXLabels: true, hasYLabels: true);
      expect(rect, const Rect.fromLTWH(30, 0, 62, 28));
    });

    test('无轴标签：仅右留 8，占满高度', () {
      final rect = trendChartRect(size, hasXLabels: false, hasYLabels: false);
      expect(rect, const Rect.fromLTWH(0, 0, 92, 50));
    });

    test('仅 Y 轴标签：左留 30、底不缩', () {
      final rect = trendChartRect(size, hasXLabels: false, hasYLabels: true);
      expect(rect, const Rect.fromLTWH(30, 0, 62, 50));
    });
  });

  group('barChartRect 绘图区内边距', () {
    const size = Size(100, 50);

    test('有 X/Y 轴标签：左留 30、右留 4、底留 22', () {
      final rect = barChartRect(size, hasXLabels: true, hasYLabels: true);
      expect(rect, const Rect.fromLTWH(30, 0, 66, 28));
    });

    test('无 Y 轴标签：占满宽度（无右内边距）', () {
      final rect = barChartRect(size, hasXLabels: false, hasYLabels: false);
      expect(rect, const Rect.fromLTWH(0, 0, 100, 50));
    });
  });

  group('chartNearestIndex 折线命中最近点', () {
    const rect = Rect.fromLTWH(0, 0, 100, 50);

    test('空数据返回 null', () {
      expect(chartNearestIndex(const Offset(50, 25), rect, 0), isNull);
    });

    test('单点：区内任意位置命中 0', () {
      expect(chartNearestIndex(const Offset(50, 25), rect, 1), 0);
    });

    test('按横坐标比例取最近点', () {
      expect(chartNearestIndex(const Offset(0, 25), rect, 5), 0);
      expect(chartNearestIndex(const Offset(25, 25), rect, 5), 1);
      expect(chartNearestIndex(const Offset(50, 25), rect, 5), 2);
      expect(chartNearestIndex(const Offset(100, 25), rect, 5), 4);
    });

    test('左右越界按 clamp 命中端点', () {
      expect(chartNearestIndex(const Offset(-8, 25), rect, 5), 0);
      expect(chartNearestIndex(const Offset(108, 25), rect, 5), 4);
    });

    test('落在膨胀区(14)之外返回 null', () {
      expect(chartNearestIndex(const Offset(200, 25), rect, 5), isNull);
      expect(chartNearestIndex(const Offset(50, 100), rect, 5), isNull);
    });
  });

  group('chartSlotIndex 柱状图命中槽位', () {
    const rect = Rect.fromLTWH(0, 0, 100, 50);

    test('空数据返回 null', () {
      expect(chartSlotIndex(const Offset(50, 25), rect, 0), isNull);
    });

    test('按等宽槽位 floor 命中', () {
      // count 4 → gap 25。
      expect(chartSlotIndex(const Offset(0, 25), rect, 4), 0);
      expect(chartSlotIndex(const Offset(24, 25), rect, 4), 0);
      expect(chartSlotIndex(const Offset(25, 25), rect, 4), 1);
      expect(chartSlotIndex(const Offset(99, 25), rect, 4), 3);
    });

    test('右边界 clamp 到最后一个槽位', () {
      expect(chartSlotIndex(const Offset(100, 25), rect, 4), 3);
    });

    test('落在膨胀区(10)之外返回 null', () {
      expect(chartSlotIndex(const Offset(200, 25), rect, 4), isNull);
      expect(chartSlotIndex(const Offset(50, 100), rect, 4), isNull);
    });
  });
}
