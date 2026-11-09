import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brand = Color(0xFFFB923C);
  static const brandDeep = Color(0xFFC2410C);
  static const navy = Color(0xFF1B2338);
  static const tint = Color(0xFFFFF1E3);
  static const muted = Color(0xFF5F6577);
  static const background = Color(0xFFF7F6F4);
  static const line = Color(0xFFE7E4DF);
  static const freeBackground = Color(0xFFE3F5EA);
  static const free = Color(0xFF0F7B45);

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: brand,
      primary: brand,
      onPrimary: navy,
      secondary: brandDeep,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: navy,
    ),
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: navy,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: navy,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
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
        foregroundColor: navy,
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
