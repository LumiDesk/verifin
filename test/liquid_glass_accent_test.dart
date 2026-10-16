import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/liquid_glass_material.dart';
import 'package:verifin/app/platform_bridge.dart';
import 'package:verifin/app/root_navigation.dart';
import 'package:verifin/app/root_navigation_liquid_glass.dart';

/// 液态玻璃底栏选中项配色：主题主色变体的对比度、通道参数与降级路径的颜色绑定。
void main() {
  group('veriLiquidGlassAccentPair', () {
    const samples = <Color>[
      veriRoyal,
      Color(0xFFFFD600),
      Color(0xFF444444),
      Color(0xFFE91E63),
      Color(0xFF00E5FF),
    ];

    test('两档变体对各自画布都达到对比度下限', () {
      for (final primary in samples) {
        final pair = veriLiquidGlassAccentPair(primary);
        expect(
          veriContrastRatio(pair.overLight, veriCanvasLight),
          greaterThanOrEqualTo(veriLiquidGlassTextContrast),
          reason: '浅底变体 ${pair.overLight} 对比度不足（主色 $primary）',
        );
        expect(
          veriContrastRatio(pair.overDark, veriCanvasDark),
          greaterThanOrEqualTo(veriLiquidGlassTextContrast),
          reason: '深底变体 ${pair.overDark} 对比度不足（主色 $primary）',
        );
      }
    });

    test('调整只改明度，有饱和度的主色保持色相', () {
      for (final primary in samples) {
        final hsl = HSLColor.fromColor(primary);
        if (hsl.saturation < 0.1) {
          continue;
        }
        final pair = veriLiquidGlassAccentPair(primary);
        expect(
          HSLColor.fromColor(pair.overLight).hue,
          closeTo(hsl.hue, 2),
          reason: '浅底变体色相漂移（主色 $primary）',
        );
        expect(
          HSLColor.fromColor(pair.overDark).hue,
          closeTo(hsl.hue, 2),
          reason: '深底变体色相漂移（主色 $primary）',
        );
      }
    });

    test('亮黄主色在浅底上被压暗，而不是原样使用', () {
      const yellow = Color(0xFFFFD600);
      final pair = veriLiquidGlassAccentPair(yellow);
      expect(
        HSLColor.fromColor(pair.overLight).lightness,
        lessThan(HSLColor.fromColor(yellow).lightness),
      );
    });

    test('相对亮度对比度与 WCAG 黑白基准一致', () {
      expect(
        veriContrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
    });
  });

  test('原生外观通道把两档主色变体以 ARGB 整数发送', () async {
    const channel = MethodChannel('verifin/app');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await AppGlassBridge.updateAppearance(
      dark: true,
      accentOverLight: 0xFF112233,
      accentOverDark: 0xFFAABBCC,
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'updateLiquidGlassAppearance');
    expect(calls.single.arguments, <String, Object?>{
      'dark': true,
      'accentOverLight': 0xFF112233,
      'accentOverDark': 0xFFAABBCC,
    });
  });

  test('原生安装通道携带两档主色变体，缺省时不发送颜色', () async {
    const channel = MethodChannel('verifin/app');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await AppGlassBridge.install(
      selectedIndex: 2,
      dark: false,
      accentOverLight: 0xFF0A0B0C,
      accentOverDark: 0xFFF0F1F2,
    );

    final args = calls.single.arguments! as Map<Object?, Object?>;
    expect(calls.single.method, 'installLiquidGlassBar');
    expect(args['selectedIndex'], 2);
    expect(args['dark'], false);
    expect(args['accentOverLight'], 0xFF0A0B0C);
    expect(args['accentOverDark'], 0xFFF0F1F2);
  });

  testWidgets('降级路径的选中项文字随主题主色变化', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);

    const primary = Color(0xFFE91E63);
    await tester.pumpWidget(const _AccentHarness(primary: primary));
    expect(tester.takeException(), isNull);

    final expected = veriLiquidGlassAccentPair(primary).overLight;
    final selectedText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('main_nav_item_0')),
        matching: find.text('首页'),
      ),
    );
    expect(selectedText.style?.color, expected);

    final unselectedText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('main_nav_item_1')),
        matching: find.text('资产'),
      ),
    );
    expect(unselectedText.style?.color, Colors.black.withValues(alpha: 0.7));
  });
}

class _AccentHarness extends StatelessWidget {
  const _AccentHarness({required this.primary});

  final Color primary;

  static const _destinations = <VeriNavigationDestination>[
    VeriNavigationDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: '首页',
    ),
    VeriNavigationDestination(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: '资产',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorScheme: ColorScheme.light(primary: primary)),
      home: Scaffold(
        extendBody: true,
        body: const SizedBox.expand(),
        bottomNavigationBar: VeriRootNavigationHost(
          style: const VeriLiquidGlassRootNavigationStyle(),
          spec: VeriRootNavigationSpec(
            currentIndex: 0,
            destinations: _destinations,
            onSelect: (_) {},
          ),
        ),
      ),
    );
  }
}
