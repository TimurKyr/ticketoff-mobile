import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457C5)),
    useMaterial3: true,
  );
}
