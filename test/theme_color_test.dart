import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/models.dart';

void main() {
  test('主题色偏好可编码、解码并强制使用不透明颜色', () {
    const source = ThemeColorPreference(
      mode: ThemeColorMode.custom,
      customColorValue: 0x00123456,
    );

    final restored = ThemeColorPreference.fromStorage(source.encode());

    expect(restored.mode, ThemeColorMode.custom);
    expect(restored.customColorValue, 0xFF123456);
  });

  test('非法主题色偏好回退到默认主题色', () {
    expect(
      ThemeColorPreference.fromStorage('{"mode":"custom","color":"x"}'),
      ThemeColorPreference.defaultValue,
    );
    expect(
      ThemeColorPreference.fromStorage('not-json'),
      ThemeColorPreference.defaultValue,
    );
  });

  test('默认主题色保留原有 Veri Royal， 自定义主题色精确使用用户颜色', () {
    final defaultTheme = buildVeriFinTheme(Brightness.light);
    final theme = buildVeriFinTheme(
      Brightness.light,
      colorPreference: const ThemeColorPreference(
        mode: ThemeColorMode.custom,
        customColorValue: 0xFFB3261E,
      ),
    );

    expect(defaultTheme.colorScheme.primary, veriRoyal);
    expect(theme.colorScheme.primary, const Color(0xFFB3261E));
    expect(theme.colorScheme.onPrimary.a, 1);
  });

  test('自定义主题色的明暗前景保持可读', () {
    const seed = Color(0xFFB3261E);
    final theme = buildVeriFinTheme(
      Brightness.light,
      colorPreference: const ThemeColorPreference(
        mode: ThemeColorMode.custom,
        customColorValue: 0xFFB3261E,
      ),
    );

    expect(theme.colorScheme.primary, seed);
    expect(theme.colorScheme.onPrimary, Colors.white);
  });
}
