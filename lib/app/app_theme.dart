import 'package:flutter/material.dart';

const Color veriMint = Color(0xFF34DBCB);
const Color veriCyan = Color(0xFF34C2DB);
const Color veriBlue = Color(0xFF3498DB);
const Color veriRoyal = Color(0xFF346EDB);
const Color veriIndigo = Color(0xFF3445DB);

ThemeData buildVeriFinTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: veriBlue,
    brightness: brightness,
    primary: veriBlue,
    secondary: veriRoyal,
    tertiary: veriIndigo,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF101216)
        : const Color(0xFFF4F8FA),
    fontFamily: 'Roboto',
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: veriBlue,
        foregroundColor: Colors.white,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: veriBlue,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: veriBlue,
      unselectedItemColor: isDark ? Colors.white54 : Colors.black45,
      backgroundColor: isDark ? const Color(0xFF0D0F12) : Colors.white,
      showUnselectedLabels: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF171A20) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
