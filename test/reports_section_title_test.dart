import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

// SectionTitle 必须把 trailing 顶到内容区右端。
//
// 回归背景：调用方的 Column 多为 CrossAxisAlignment.start，Row 只收缩到子项自然
// 宽度；叠加 Flexible 的 Text 会缩回自然宽度，导致 textAlign: end 在自己的窄盒子
// 里生效——看板「分类统计 / 分类明细 / 标签统计 / 日趋势 / 月度趋势」的中文标题
// 右侧数值全部停在卡片中间。
void main() {
  useTestDatabases();

  testWidgets('看板的 SectionTitle 把 trailing 顶到卡片右端', (tester) async {
    await pumpApp(tester, LocalKeyValueStore());
    await tapBottomTab(tester, 2); // 看板
    await tester.pumpAndSettle();

    final titles = find.byType(SectionTitle);
    var checked = 0;
    for (var i = 0; i < titles.evaluate().length; i++) {
      final widget = tester.widget<SectionTitle>(titles.at(i));
      final trailing = widget.trailing;
      if (trailing == null) {
        continue;
      }
      checked++;
      final rowRect = tester.getRect(titles.at(i));
      final trailingRect = tester.getRect(
        find.descendant(of: titles.at(i), matching: find.text(trailing)),
      );
      expect(
        trailingRect.right,
        moreOrLessEquals(rowRect.right, epsilon: 1),
        reason:
            '面板「${widget.title}」的 trailing 应贴卡片右端，'
            '实际差 ${rowRect.right - trailingRect.right}dp',
      );
    }
    expect(checked, greaterThan(0), reason: '看板应有带 trailing 的 SectionTitle');
  });

  testWidgets('统计分析页的 SectionTitle 同样贴右端', (tester) async {
    await pumpApp(tester, LocalKeyValueStore());
    await tapBottomTab(tester, 2);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('统计分析'));
    await tester.pumpAndSettle();

    final titles = find.byType(SectionTitle);
    var checked = 0;
    for (var i = 0; i < titles.evaluate().length; i++) {
      final widget = tester.widget<SectionTitle>(titles.at(i));
      final trailing = widget.trailing;
      if (trailing == null) {
        continue;
      }
      checked++;
      final rowRect = tester.getRect(titles.at(i));
      final trailingRect = tester.getRect(
        find.descendant(of: titles.at(i), matching: find.text(trailing)),
      );
      expect(
        trailingRect.right,
        moreOrLessEquals(rowRect.right, epsilon: 1),
        reason:
            '「${widget.title}」的 trailing 应贴右端，'
            '实际差 ${rowRect.right - trailingRect.right}dp',
      );
    }
    expect(checked, greaterThan(0), reason: '统计分析页应有带 trailing 的 SectionTitle');
  });
}
