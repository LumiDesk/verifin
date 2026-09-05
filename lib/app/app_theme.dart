import 'package:flutter/material.dart';

/// 候选设计只通过显式构建参数开启；正常 Android/Web 构建仍使用已发布外观。
const bool veriUnifiedDesignPreview = bool.fromEnvironment(
  'UNIFIED_DESIGN_PREVIEW',
);
const bool veriGlassDesignPreview =
    veriUnifiedDesignPreview && bool.fromEnvironment('GLASS_DESIGN_PREVIEW');
const Color veriGlassCanvasTopLight = Color(0xFFDCE8F5);
const Color veriGlassCanvasBottomLight = Color(0xFFDFEDEE);
const Color veriGlassCanvasTopDark = Color(0xFF152238);
const Color veriGlassCanvasBottomDark = Color(0xFF152B30);

Color veriGlassTint(Brightness brightness, {bool overlay = false}) =>
    brightness == Brightness.dark
    ? (overlay
          ? veriSurfaceDark.withValues(alpha: 0.80)
          : Colors.white.withValues(alpha: 0.055))
    : Colors.white.withValues(alpha: overlay ? 0.72 : 0.50);

// 候选材质令牌：实体内容与中性画布；不用于模拟玻璃折射。
const Color veriPreviewCanvasLight = Color(0xFFF3F5F8);
const Color veriPreviewCanvasDark = Color(0xFF101318);
const Color veriPreviewSurfaceDark = Color(0xFF1A1F27);
const double veriCardRadius = veriUnifiedDesignPreview ? 16 : veriRadiusMd;
const double veriCompactCardRadius = 16;
const double veriCompactHeaderHeight = 56;

/// 内容卡片与资产封面共用的实体基色。
Color veriContentSurfaceColor(Brightness brightness) =>
    brightness == Brightness.dark
    ? (veriUnifiedDesignPreview ? veriPreviewSurfaceDark : veriSurfaceDark)
    : veriSurfaceLight;

const Color veriMint = Color(0xFF34DBCB);
const Color veriCyan = Color(0xFF34C2DB);
const Color veriBlue = Color(0xFF3498DB);
const Color veriRoyal = Color(0xFF346EDB);
const Color veriIndigo = Color(0xFF3445DB);
const Color veriInk = Color(0xFF151922);
const Color veriLine = Color(0xFFE1E8F1);
const Color veriExpense = Color(0xFFE84D6A);
const Color veriIncome = Color(0xFF12B8A6);
const Color veriWarning = Color(0xFFFFB33E);
const Color veriSurfaceLight = Color(0xFFFFFFFF);
const Color veriSurfaceDark = Color(0xFF0E1117);
const Color veriSurfaceAltLight = Color(0xFFF5F8FC);
const Color veriSurfaceAltDark = Color(0xFF151A22);
const double veriRadiusSm = 6;
const double veriRadiusMd = veriUnifiedDesignPreview ? 12 : 8;
const double veriRadiusLg = veriUnifiedDesignPreview ? 16 : 12;
const double veriRadiusXl = 24;
const double veriHeaderHeight = veriUnifiedDesignPreview ? 56 : 52;
const double veriPageMaxWidth = 440;

ThemeData buildVeriFinTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final seedScheme = ColorScheme.fromSeed(
    seedColor: veriRoyal,
    brightness: brightness,
    primary: veriRoyal,
    secondary: veriBlue,
    tertiary: veriIncome,
  );
  final canvas = isDark ? veriPreviewCanvasDark : veriPreviewCanvasLight;
  final colorScheme = veriUnifiedDesignPreview
      ? seedScheme.copyWith(
          surface: veriGlassDesignPreview ? veriGlassTint(brightness) : canvas,
          surfaceContainerHighest: veriGlassDesignPreview
              ? veriGlassTint(brightness)
              : seedScheme.surfaceContainerHighest,
          onSurface: isDark ? const Color(0xFFF0F3F8) : veriInk,
        )
      : seedScheme;

  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: veriGlassDesignPreview
        ? Colors.transparent
        : veriUnifiedDesignPreview
        ? canvas
        : isDark
        ? const Color(0xFF0B0F15)
        : const Color(0xFFF3F7FC),
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.compact,
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white10 : veriLine,
      thickness: 0.8,
      space: 1,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: veriRoyal,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(veriRadiusMd),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(36, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: veriRoyal,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(veriRadiusLg)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: veriRoyal,
      unselectedItemColor: isDark ? Colors.white54 : Colors.black45,
      backgroundColor: isDark ? veriSurfaceDark : veriSurfaceLight,
      elevation: 0,
      selectedIconTheme: const IconThemeData(size: 25),
      unselectedIconTheme: const IconThemeData(size: 24),
      showUnselectedLabels: false,
      showSelectedLabels: false,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? veriSurfaceAltDark : veriSurfaceLight,
      selectedColor: veriRoyal.withValues(alpha: 0.14),
      secondarySelectedColor: veriRoyal.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        color: isDark ? Colors.white.withValues(alpha: 0.86) : veriInk,
        fontSize: 12,
      ),
      secondaryLabelStyle: TextStyle(
        color: isDark ? Colors.white.withValues(alpha: 0.88) : veriInk,
        fontSize: 12,
      ),
      side: BorderSide(color: isDark ? Colors.white10 : veriLine),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: veriGlassDesignPreview
          ? veriGlassTint(brightness)
          : isDark
          ? (veriUnifiedDesignPreview
                ? veriPreviewSurfaceDark
                : veriSurfaceAltDark)
          : veriSurfaceLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(veriRadiusMd),
        borderSide: veriGlassDesignPreview
            ? BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.17 : 0.65),
              )
            : BorderSide.none,
      ),
    ),
  );

  return baseTheme.copyWith(
    textTheme: baseTheme.textTheme.copyWith(
      displayLarge: baseTheme.textTheme.displayLarge?.copyWith(
        fontSize: veriUnifiedDesignPreview ? 40 : 38,
        height: 1.05,
        letterSpacing: 0,
      ),
      displayMedium: baseTheme.textTheme.displayMedium?.copyWith(
        fontSize: 32,
        height: 1.08,
        letterSpacing: 0,
      ),
      displaySmall: baseTheme.textTheme.displaySmall?.copyWith(
        fontSize: veriUnifiedDesignPreview ? 32 : 26,
        height: 1.12,
        letterSpacing: 0,
      ),
      headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
        fontSize: 21,
        height: 1.18,
        letterSpacing: 0,
      ),
      headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
        fontSize: 19,
        height: 1.2,
        letterSpacing: 0,
      ),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        fontSize: veriUnifiedDesignPreview ? 22 : 17,
        height: 1.25,
        letterSpacing: 0,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        fontSize: veriUnifiedDesignPreview ? 16 : 14,
        height: 1.25,
        letterSpacing: 0,
      ),
      titleSmall: baseTheme.textTheme.titleSmall?.copyWith(
        fontSize: veriUnifiedDesignPreview ? 14 : 13,
        height: 1.25,
        letterSpacing: 0,
      ),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
        fontSize: 14,
        height: 1.35,
        letterSpacing: 0,
      ),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        height: 1.35,
        letterSpacing: 0,
      ),
      bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.35,
        letterSpacing: 0,
      ),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
        fontSize: 12,
        height: 1.25,
        letterSpacing: 0,
      ),
      labelMedium: baseTheme.textTheme.labelMedium?.copyWith(
        fontSize: veriUnifiedDesignPreview ? 12 : 11,
        height: 1.25,
        letterSpacing: 0,
      ),
      labelSmall: baseTheme.textTheme.labelSmall?.copyWith(
        fontSize: veriUnifiedDesignPreview ? 11 : 10,
        height: 1.2,
        letterSpacing: 0,
      ),
    ),
  );
}
