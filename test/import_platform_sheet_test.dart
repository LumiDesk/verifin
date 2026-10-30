import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/data_management_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('账单来源弹窗在矮屏下可滚动、能到达最后一项且不溢出', (tester) async {
    // 矮屏：确保 8 个平台项超过弹窗可用高度，触发滚动需求。
    tester.view.physicalSize = const Size(400, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      zhMaterialApp(
        home: VeriFinScope(
          controller: controller,
          child: const DataManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 打开「导入账单文件 → 选择账单来源」弹窗（矮屏下该行在页面外，先滚动到它）。
    await tester.scrollUntilVisible(find.text('导入账单文件'), 200);
    await tester.tap(find.text('导入账单文件'));
    await tester.pumpAndSettle();

    // 表头与新增的 Tally / 随手记项都在；弹窗内有滚动容器。
    expect(find.text('选择账单来源'), findsOneWidget);
    expect(find.text('Tally 记账'), findsOneWidget);
    expect(find.text('随手记'), findsOneWidget);
    // 随手记使用 SVG 品牌图标，验证 SVG 分支确实被渲染。
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // 最后一项默认在可视区外；滚动后应可见（证明能上下滑动，且开屏未溢出）。
    final lastItem = find.text('CSV 模板');
    await tester.scrollUntilVisible(
      lastItem,
      120,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(lastItem, findsOneWidget);
    expect(tester.getSize(find.text('选择账单来源')).height, greaterThan(0));
  });
}
