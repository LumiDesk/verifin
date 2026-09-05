import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/glass_lighting.dart';
import 'package:verifin/app/navigation_glass_lens.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/home_page.dart';
import 'package:verifin/pages/settings_page.dart';

import 'support/test_harness.dart';

Future<bool> saveMaterial(VeriFinController c, bool enabled) =>
    c.saveAppPreferencesDraft(
      advancedMaterialEnabled: enabled,
      themePreference: c.themePreference,
      localePreference: c.localePreference,
      hapticsEnabled: c.hapticsEnabled,
      amountForceTwoDecimals: c.amountForceTwoDecimals,
      moneyUnitStyle: c.moneyUnitStyle,
      hideUnitInSingleCurrency: c.hideUnitInSingleCurrency,
      fabActionMode: c.fabActionMode,
      defaultAccountId: c.defaultAccountId,
      autoSuggestEnabled: c.autoSuggestEnabled,
    );

class FailingMaterialStore extends LocalKeyValueStore {
  @override
  Future<void> writeAndFlush(String key, String value) async {
    if (key == 'verifin.advanced_material.v1') throw StateError('write failed');
    await super.writeAndFlush(key, value);
  }
}

void main() {
  useTestDatabases();
  test('材质默认关闭，保存后冷读，初始化及备份恢复保留本机选择', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    addTearDown(controller.dispose);
    expect(controller.advancedMaterialEnabled, isFalse);
    final backup = controller.exportDataJson();
    expect(await saveMaterial(controller, true), isTrue);
    expect(controller.advancedMaterialListenable.value, isTrue);
    expect(controller.exportDataJson(), isNot(contains('advancedMaterial')));
    controller.importDataJson(backup);
    controller.resetAllData();
    final reopened = await makeController(store);
    addTearDown(reopened.dispose);
    expect(reopened.advancedMaterialEnabled, isTrue);
  });

  test('材质保存失败不更新运行状态或冷读结果，并报告失败', () async {
    final store = FailingMaterialStore();
    final controller = await makeController(store);
    addTearDown(controller.dispose);
    var errors = 0;
    controller.onPersistError = (_) => errors++;
    expect(await saveMaterial(controller, true), isFalse);
    expect(errors, 1);
    expect(controller.advancedMaterialEnabled, isFalse);
    expect(controller.advancedMaterialListenable.value, isFalse);
    final reopened = await makeController(store);
    addTearDown(reopened.dispose);
    expect(reopened.advancedMaterialEnabled, isFalse);
  });

  test('深色高光低于浅色且静态峰值不再接近纯白', () {
    const dark = VeriGlassLightPainter(radius: 16, brightness: Brightness.dark);
    const light = VeriGlassLightPainter(radius: 16);
    expect(dark.peakOpacity, lessThan(light.peakOpacity * 0.55));
    expect(light.peakOpacity, lessThan(0.5));
    expect(dark.shouldRepaint(light), isTrue);
  });

  testWidgets('分区标题不绘制 hover 底色，点击仍可打开交易', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionHeaderAction(
            title: '最近交易',
            trailing: '',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.hoverColor, Colors.transparent);
    await tester.tap(find.text('最近交易'));
    expect(taps, 1);
  });

  testWidgets('关闭不创建透镜，设置草稿保存后开启，再关闭会释放透镜', (tester) async {
    final controller = await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.byType(VeriNavigationGlassLens), findsNothing);
    final context = tester.element(find.byType(HomePage));
    // 等待路由关闭会阻塞后续表单交互；测试在下方通过保存主动关闭。
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('advanced_material_setting'));
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(controller.advancedMaterialEnabled, isFalse);
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.advancedMaterialEnabled, isTrue);
    expect(find.byType(VeriNavigationGlassLens), findsOneWidget);
    await saveMaterial(controller, false);
    await tester.pumpAndSettle();
    expect(find.byType(VeriNavigationGlassLens), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !veriGlassDesignPreview);
}
