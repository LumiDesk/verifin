import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/root_navigation.dart';
import 'package:verifin/app/root_navigation_docked.dart';
import 'package:verifin/app/root_navigation_styles.dart';
import 'package:verifin/l10n/app_localizations.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/navigation_style_settings_page.dart';

import 'support/test_harness.dart';

/// 导航栏样式偏好与样式选择页。
///
/// 目前注册表里只有默认的停靠样式，因此「选择另一个样式」这条路径用测试专用的假样式
/// 覆盖：选择页只认样式的持久化标识，不依赖具体实现。
void main() {
  useTestDatabases();

  test('导航样式偏好与注册表一一对应', () {
    for (final preference in NavigationStylePreference.values) {
      expect(
        veriRootNavigationStyles.any((style) => style.id == preference.name),
        isTrue,
        reason: '${preference.name} 没有注册实现，KV 里读到它只会静默回退',
      );
    }
    for (final style in veriRootNavigationStyles) {
      expect(
        NavigationStylePreference.values.any(
          (preference) => preference.name == style.id,
        ),
        isTrue,
        reason: '样式 ${style.id} 没有对应的偏好值，用户选了也存不下来',
      );
    }
  });

  test('导航样式默认停靠，非法值回退，重置恢复默认并清键', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    expect(
      controller.navigationStylePreference,
      NavigationStylePreference.docked,
    );
    expect(
      store.read('verifin.nav_style.v1'),
      isNull,
      reason: '默认样式不必占一个 KV 键，缺失即默认',
    );

    await controller.saveAppPreferencesDraft(
      themePreference: controller.themePreference,
      themeColorPreference: controller.themeColorPreference,
      localePreference: controller.localePreference,
      navigationStylePreference: NavigationStylePreference.docked,
      hapticsEnabled: controller.hapticsEnabled,
      amountForceTwoDecimals: controller.amountForceTwoDecimals,
      moneyUnitStyle: controller.moneyUnitStyle,
      hideUnitInSingleCurrency: controller.hideUnitInSingleCurrency,
      fabActionMode: controller.fabActionMode,
      defaultAccountId: controller.defaultAccountId,
      autoSuggestEnabled: controller.autoSuggestEnabled,
      showRunningBalance: controller.showRunningBalance,
      numberPadLayout: controller.numberPadLayout,
    );
    expect(store.read('verifin.nav_style.v1'), 'docked');

    // 未知标识（旧版本、手改或降级安装）一律回退默认样式，不能崩也不能白屏。
    store.write('verifin.nav_style.v1', 'not-a-style');
    final restarted = await makeController(store);
    expect(
      restarted.navigationStylePreference,
      NavigationStylePreference.docked,
    );

    restarted.resetAllData();
    expect(
      restarted.navigationStylePreference,
      NavigationStylePreference.docked,
    );
    expect(store.read('verifin.nav_style.v1'), isNull);
  });

  testWidgets('设置页外观分组提供导航栏样式入口，并显示当前样式名', (tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey<String>('settings_navigation_style'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('导航栏样式')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('停靠底栏')),
      findsOneWidget,
      reason: '入口 trailing 要显示当前生效的样式名',
    );
  });

  testWidgets('设置页里的导航样式与 Controller 当前偏好一致', (tester) async {
    final controller = await pumpApp(tester);

    final host = tester.widget<VeriRootNavigationHost>(
      find.byType(VeriRootNavigationHost),
    );
    expect(host.style.id, controller.navigationStylePreference.name);
    // 四个根目的地与顺序在所有样式下都不变，是样式解耦的硬约束。
    expect(
      host.spec.destinations.map((destination) => destination.label).toList(),
      <String>['首页', '资产', '看板', '我的'],
    );
  });

  test('样式偏好经通知器发布，重复设置同一值不通知也不写 KV', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    var notifications = 0;
    void listener() => notifications++;
    controller.navigationStylePreferenceListenable.addListener(listener);
    addTearDown(
      () => controller.navigationStylePreferenceListenable.removeListener(
        listener,
      ),
    );

    controller.setNavigationStylePreference(NavigationStylePreference.docked);

    expect(notifications, 0, reason: '值没变就不该通知，否则每次重建都会连累整条导航');
    expect(
      store.read('verifin.nav_style.v1'),
      isNull,
      reason: '默认样式保持"缺失即默认"，不占 KV 键',
    );
  });

  testWidgets('未修改就返回时设置页保持原样、不写 KV', (tester) async {
    final store = LocalKeyValueStore();
    await pumpApp(tester, store);
    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('settings_navigation_style')),
    );
    await tester.pumpAndSettle();
    expect(find.text('停靠底栏'), findsWidgets);
    expect(find.text('四个入口在所有样式下保持不变'), findsOneWidget);

    // 未做任何修改：返回不弹未保存询问，也不写 KV。
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('保存修改？'), findsNothing);
    expect(store.read('verifin.nav_style.v1'), isNull);
  });

  testWidgets('样式选择页渲染名称、说明与真机同源预览，且不绘制模糊', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: const NavigationStyleSettingsPage(initialStyleId: 'docked'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('停靠底栏'), findsOneWidget);
    expect(find.text('整宽贴底的不透明底栏，切换时图标扫过'), findsOneWidget);
    // 预览就是样式自己的 buildBar：四个条目与常显标签一起渲染，不是另画的缩略图。
    for (final label in <String>['首页', '资产', '看板', '我的']) {
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('navigation_style_docked')),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('样式选择页选中后保存会回传该样式标识', (tester) async {
    String? popped;
    await tester.pumpWidget(
      zhMaterialApp(home: _PickerLauncher(onResult: (value) => popped = value)),
    );
    await tester.tap(find.text('打开选择页'));
    await tester.pumpAndSettle();

    expect(find.text('停靠底栏'), findsOneWidget);
    expect(find.text('备用样式'), findsOneWidget);

    // 点卡片上缘、也就是预览区域：预览整块 IgnorePointer，点击要穿到卡片自己的
    // onTap，即"点预览也能选中这个样式"。
    final card = tester.getRect(
      find.byKey(const ValueKey<String>('navigation_style_alternate')),
    );
    await tester.tapAt(Offset(card.center.dx, card.top + 8));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(popped, _AlternateStyle.styleId);
  });

  testWidgets('样式选择页修改后返回会询问是否保存', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(home: _PickerLauncher(onResult: (_) {})),
    );
    await tester.tap(find.text('打开选择页'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('navigation_style_alternate')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('保存修改？'), findsOneWidget);
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();

    expect(find.text('打开选择页'), findsOneWidget, reason: '放弃修改后应退回上一页');
  });
}

/// 打开样式选择页并把返回值交回测试的入口。
class _PickerLauncher extends StatelessWidget {
  const _PickerLauncher({required this.onResult});

  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final selected = await Navigator.of(context).push<String>(
              MaterialPageRoute<String>(
                builder: (context) => const NavigationStyleSettingsPage(
                  initialStyleId: 'docked',
                  styles: <VeriRootNavigationStyle>[
                    VeriDockedRootNavigationStyle(),
                    _AlternateStyle(),
                  ],
                ),
              ),
            );
            onResult(selected);
          },
          child: const Text('打开选择页'),
        ),
      ),
    );
  }
}

/// 测试专用样式：只关心标识、名称与说明，绘制一个固定高度的实色条。
class _AlternateStyle implements VeriRootNavigationStyle {
  const _AlternateStyle();

  static const String styleId = 'alternate';

  @override
  String get id => styleId;

  @override
  String label(AppLocalizations l10n) => '备用样式';

  @override
  String description(AppLocalizations l10n) => '测试用样式';

  @override
  VeriRootNavigationLayout get layout =>
      const VeriRootNavigationLayout(extendBody: true, occupiedHeight: 56);

  @override
  Duration get switchDuration => VeriRootNavigationStyle.defaultSwitchDuration;

  @override
  Widget buildBar(BuildContext context, VeriRootNavigationSpec spec) {
    return ColoredBox(
      key: ValueKey<String>(spec.keyOf('bottom_nav')),
      color: Theme.of(context).colorScheme.primary,
      child: const SizedBox(height: 56),
    );
  }
}
