import 'package:flutter/material.dart';

class AppTheme {
  static const wheatGold = Color(0xFFC8963E);
  static const cream = Color(0xFFFFF8EC);
  static const chocolateBrown = Color(0xFF4B2E1E);
  static const crustOrange = Color(0xFFE07B39);

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: wheatGold,
      primary: chocolateBrown,
      secondary: crustOrange,
      surface: cream,
    ),
    scaffoldBackgroundColor: cream,
    useMaterial3: true,
  );

  static final dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: wheatGold,
      brightness: Brightness.dark,
      secondary: crustOrange,
    ),
    useMaterial3: true,
  );
}
