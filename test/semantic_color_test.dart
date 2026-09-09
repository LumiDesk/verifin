import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';

/// WCAG 相对亮度（sRGB）。
double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final high = math.max(la, lb);
  final low = math.min(la, lb);
  return (high + 0.05) / (low + 0.05);
}

/// 浅色主题下语义色可能落在的两种底：卡片白底与画布底色。
const List<Color> _lightSurfaces = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFF3F5F8),
];

void main() {
  test('深色主题沿用原亮色', () {
    expect(veriSemanticFor(Brightness.dark, veriIncome), veriIncome);
    expect(veriSemanticFor(Brightness.dark, veriExpense), veriExpense);
    expect(veriSemanticFor(Brightness.dark, veriBlue), veriBlue);
    expect(veriSemanticFor(Brightness.dark, veriWarning), veriWarning);
  });

  test('浅色主题换成加深变体', () {
    expect(veriSemanticFor(Brightness.light, veriIncome), veriIncomeOnLight);
    expect(veriSemanticFor(Brightness.light, veriExpense), veriExpenseOnLight);
    expect(veriSemanticFor(Brightness.light, veriBlue), veriBlueOnLight);
    expect(veriSemanticFor(Brightness.light, veriWarning), veriWarningOnLight);
  });

  test('非语义色原样返回', () {
    expect(veriSemanticFor(Brightness.light, veriRoyal), veriRoyal);
    expect(veriSemanticFor(Brightness.light, veriLine), veriLine);
  });

  test('浅色底语义色在白色与画布上都达到正文级 AA（4.5:1）', () {
    const List<Color> onLight = <Color>[
      veriIncomeOnLight,
      veriExpenseOnLight,
      veriBlueOnLight,
      veriWarningOnLight,
    ];
    for (final color in onLight) {
      for (final surface in _lightSurfaces) {
        expect(
          _contrast(color, surface),
          greaterThanOrEqualTo(4.5),
          reason:
              '#${color.toARGB32().toRadixString(16)} 在 '
              '#${surface.toARGB32().toRadixString(16)} 上对比度不足',
        );
      }
    }
  });
}
