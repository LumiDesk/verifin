import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
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
    await tester.pump();
    final saveButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.save_outlined),
    );
    expect(saveButton.onPressed, isNotNull);
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    // 昵称非空 → 直接保存，简介为空字符串（此前 bug 会被替换成默认简介）。
    expect(controller.profile.bio, '');
    expect(controller.profile.nickname, '张三');
  });

  testWidgets('个人资料未修改时保存按钮禁用', (tester) async {
    final controller = await makeController();
    await pumpProfilePage(tester, controller);

    final saveButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.save_outlined),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('性别使用锚点菜单并在保存后提交', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await pumpProfilePage(tester, controller);

    final genderChoice = find.byKey(const Key('profile_gender_choice'));
    await tester.ensureVisible(genderChoice);
    await tester.pumpAndSettle();
    await tester.tap(genderChoice);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('veri_menu_item_profile_gender_female'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('女').last);
    await tester.pumpAndSettle();
    expect(controller.profile.gender, ProfileGender.unset);

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.profile.gender, ProfileGender.female);
  });

  testWidgets('已设置生日可清除并在保存后提交', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    addTearDown(controller.dispose);
    controller.updateProfile(
      controller.profile.copyWith(nickname: '张三', birthday: '1990-01-02'),
    );

    await pumpProfilePage(tester, controller);

    expect(find.text('1990-01-02'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile_birthday_clear')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('profile_birthday_field')),
        matching: find.text('不设置'),
      ),
      findsOneWidget,
    );
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(controller.profile.birthday, '1990-01-02');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.profile.birthday, '');
    final restored = await makeController(store);
    addTearDown(restored.dispose);
    expect(restored.profile.birthday, '');
  });

  testWidgets('昵称留空保存时弹确认框，取消则不保存', (tester) async {
    final controller = await makeController();
    controller.updateProfile(
      controller.profile.copyWith(nickname: '张三', bio: '简介'),
    );

    await pumpProfilePage(tester, controller);

    await tester.enterText(find.text('张三'), '');
    await tester.pump();
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
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    // 确认框里点「保存」→ 用默认昵称落库。
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(controller.profile.nickname, 'Veri Fin');
  });
}
