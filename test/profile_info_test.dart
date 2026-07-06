import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/profile_pages.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Future<void> pumpProfilePage(WidgetTester tester, controller) async {
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const ProfileInfoPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('清空简介后保存，简介被真正清空（不再回填默认简介）', (tester) async {
    final controller = await makeController();
    controller.updateProfile(
      controller.profile.copyWith(nickname: '张三', bio: '原来的简介'),
    );

    await pumpProfilePage(tester, controller);

    // 清空简介输入框后保存。
    await tester.enterText(find.text('原来的简介'), '');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    // 昵称非空 → 直接保存，简介为空字符串（此前 bug 会被替换成默认简介）。
    expect(controller.profile.bio, '');
    expect(controller.profile.nickname, '张三');
  });

  testWidgets('昵称留空保存时弹确认框，取消则不保存', (tester) async {
    final controller = await makeController();
    controller.updateProfile(
      controller.profile.copyWith(nickname: '张三', bio: '简介'),
    );

    await pumpProfilePage(tester, controller);

    await tester.enterText(find.text('张三'), '');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    // 弹出提示框。
    expect(find.text('未设置昵称'), findsOneWidget);

    // 取消：不写入，昵称保持原值。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.profile.nickname, '张三');
  });

  testWidgets('昵称留空确认后使用默认昵称保存', (tester) async {
    final controller = await makeController();
    controller.updateProfile(
      controller.profile.copyWith(nickname: '张三', bio: '简介'),
    );

    await pumpProfilePage(tester, controller);

    await tester.enterText(find.text('张三'), '');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    // 确认框里点「保存」→ 用默认昵称落库。
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(controller.profile.nickname, 'Veri Fin');
  });
}
