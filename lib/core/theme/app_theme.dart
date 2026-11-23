import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const navy = Color(0xFF1A1A18);
  static const brand = navy;
  static const brandDeep = navy;
  static const tint = Color(0xFFF5F4F1);
  static const muted = Color(0xFF4B5563);
  static const background = Color(0xFFF2F1EE);
  static const line = Color(0xFFE4E1DA);
  static const freeBackground = Color(0xFFE3F5EA);
  static const free = Color(0xFF0F7B45);

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: brand,
      primary: brand,
      onPrimary: Colors.white,
      secondary: brandDeep,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: navy,
    ),
    scaffoldBackgroundColor: background,
    dividerColor: line,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: navy,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: navy,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: tint,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB42318)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: brandDeep),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
    ),
  );
}
