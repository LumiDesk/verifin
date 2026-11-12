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

  Future<void> settleTextAutoSave(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
  }

  testWidgets('清空简介后自动保存，简介被真正清空', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    controller.updateProfile(
      controller.profile.copyWith(nickname: '张三', bio: '原来的简介'),
    );

    await pumpProfilePage(tester, controller);

    await tester.enterText(find.text('原来的简介'), '');
    await settleTextAutoSave(tester);

    // 昵称非空 → 简介为空字符串，不回填默认简介。
    expect(controller.profile.bio, '');
    expect(controller.profile.nickname, '张三');
  });

  testWidgets('个人资料页不再显示保存按钮', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await pumpProfilePage(tester, controller);

    expect(find.byTooltip('保存'), findsNothing);
  });

  testWidgets('性别选择后立即提交', (tester) async {
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
        const ValueKey<String>('anchored_menu_item_profile_gender_female'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('女').last);
    await tester.pumpAndSettle();
    expect(controller.profile.gender, ProfileGender.female);
  });

  testWidgets('已设置生日可清除并立即提交', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    addTearDown(controller.dispose);
    controller.updateProfile(
      controller.profile.copyWith(nickname: '张三', birthday: '1990-01-02'),
    );

    await pumpProfilePage(tester, controller);

    expect(find.text('1990-01-02'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile_birthday_clear')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('profile_birthday_field')),
        matching: find.text('不设置'),
      ),
      findsOneWidget,
    );
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(controller.profile.birthday, '');
    final restored = await makeController(store);
    addTearDown(restored.dispose);
    expect(restored.profile.birthday, '');
  });

  testWidgets('昵称留空自动回退默认昵称，不再弹确认框', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    controller.updateProfile(
      controller.profile.copyWith(nickname: '张三', bio: '简介'),
    );

    await pumpProfilePage(tester, controller);

    await tester.enterText(find.text('张三'), '');
    await settleTextAutoSave(tester);

    expect(find.text('未设置昵称'), findsNothing);
    expect(controller.profile.nickname, 'Veri Fin');
  });
}
