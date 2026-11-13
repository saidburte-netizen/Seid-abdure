import 'package:flutter/material.dart';

/// The complete Brade and Cake House palette.
///
/// Green is dominant (~60%), cream follows (~30%), and gold is the accent
/// (~10%). All widgets must read colours from here or from the Material 3
/// [ColorScheme]; never hard-code colours in screens.
class BrandColors {
  const BrandColors._();

  static const Color deepGreen = Color(0xFF0B3B17);
  static const Color forestGreen = Color(0xFF1B5E2F);
  static const Color leafGreen = Color(0xFF2E7D3E);
  static const Color gold = Color(0xFFC9A227);
  static const Color lightGold = Color(0xFFE6C25A);
  static const Color cream = Color(0xFFF6EBDC);
  static const Color ivory = Color(0xFFFFF8EE);
  static const Color chocolate = Color(0xFF4A1F12);
  static const Color crust = Color(0xFFC97011);
  static const Color ink = Color(0xFF0A1F10);
  static const Color error = Color(0xFFB3261E);
  static const Color darkSurface = Color(0xFF06210F);
  static const Color darkSurfaceHigh = Color(0xFF0B2E16);
  static const Color darkCard = Color(0xFF103A1D);
  static const Color splashBackground = Color(0xFFF4E8D8);
  static const Color splashDarkBackground = Color(0xFF06210F);

  static const Color success = leafGreen;
  static const Color warning = crust;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.forestGreen,
      onPrimary: BrandColors.ivory,
      primaryContainer: BrandColors.leafGreen,
      onPrimaryContainer: BrandColors.deepGreen,
      secondary: BrandColors.gold,
      onSecondary: BrandColors.deepGreen,
      secondaryContainer: BrandColors.lightGold,
      onSecondaryContainer: BrandColors.chocolate,
      tertiary: BrandColors.deepGreen,
      onTertiary: BrandColors.ivory,
      error: BrandColors.error,
      onError: BrandColors.ivory,
      surface: BrandColors.cream,
      onSurface: BrandColors.ink,
      surfaceContainerHighest: BrandColors.ivory,
      onSurfaceVariant: BrandColors.chocolate,
      outline: BrandColors.crust,
      outlineVariant: BrandColors.lightGold,
      inverseSurface: BrandColors.deepGreen,
      onInverseSurface: BrandColors.ivory,
      shadow: BrandColors.chocolate,
      scrim: BrandColors.deepGreen,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BrandColors.cream,
      canvasColor: BrandColors.cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.deepGreen,
        foregroundColor: BrandColors.ivory,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BrandColors.ivory,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: BrandColors.ivory),
        actionsIconTheme: IconThemeData(color: BrandColors.ivory),
      ),
      cardTheme: const CardThemeData(
        color: BrandColors.ivory,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: BrandColors.lightGold, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BrandColors.lightGold,
        thickness: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: BrandColors.deepGreen,
        unselectedLabelColor: BrandColors.chocolate,
        indicatorColor: BrandColors.gold,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: BrandColors.deepGreen,
        indicatorColor: BrandColors.forestGreen,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: BrandColors.ivory),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: BrandColors.ivory),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: BrandColors.deepGreen,
        indicatorColor: BrandColors.forestGreen,
        selectedIconTheme: IconThemeData(color: BrandColors.lightGold),
        unselectedIconTheme: IconThemeData(color: BrandColors.ivory),
        selectedLabelTextStyle: TextStyle(color: BrandColors.lightGold),
        unselectedLabelTextStyle: TextStyle(color: BrandColors.ivory),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BrandColors.forestGreen,
        foregroundColor: BrandColors.ivory,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.forestGreen,
          foregroundColor: BrandColors.ivory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.deepGreen,
          foregroundColor: BrandColors.ivory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.forestGreen,
          side: const BorderSide(color: BrandColors.gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BrandColors.leafGreen),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.ivory,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.lightGold),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.lightGold),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.error),
        ),
        labelStyle: const TextStyle(color: BrandColors.chocolate),
        floatingLabelStyle: const TextStyle(color: BrandColors.forestGreen),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: BrandColors.ivory,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: BrandColors.lightGold),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: BrandColors.cream,
        selectedColor: BrandColors.forestGreen,
        labelStyle: TextStyle(color: BrandColors.chocolate),
        secondaryLabelStyle: TextStyle(color: BrandColors.ivory),
        side: BorderSide(color: BrandColors.lightGold),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.deepGreen,
        contentTextStyle: TextStyle(color: BrandColors.ivory),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.forestGreen,
        linearTrackColor: BrandColors.cream,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BrandColors.lightGold
              : BrandColors.ivory,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BrandColors.forestGreen
              : BrandColors.cream,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BrandColors.forestGreen
              : BrandColors.ivory,
        ),
        side: const BorderSide(color: BrandColors.gold),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BrandColors.forestGreen
              : BrandColors.gold,
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: BrandColors.deepGreen,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: BrandColors.ink),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BrandColors.forestGreen,
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: BrandColors.lightGold,
      onPrimary: BrandColors.deepGreen,
      primaryContainer: BrandColors.forestGreen,
      onPrimaryContainer: BrandColors.ivory,
      secondary: BrandColors.gold,
      onSecondary: BrandColors.deepGreen,
      secondaryContainer: BrandColors.darkCard,
      onSecondaryContainer: BrandColors.cream,
      tertiary: BrandColors.leafGreen,
      onTertiary: BrandColors.ivory,
      error: BrandColors.error,
      onError: BrandColors.ivory,
      surface: BrandColors.darkSurface,
      onSurface: BrandColors.cream,
      surfaceContainerHighest: BrandColors.darkSurfaceHigh,
      onSurfaceVariant: BrandColors.cream,
      outline: BrandColors.lightGold,
      outlineVariant: BrandColors.forestGreen,
      inverseSurface: BrandColors.cream,
      onInverseSurface: BrandColors.deepGreen,
      shadow: BrandColors.deepGreen,
      scrim: BrandColors.deepGreen,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BrandColors.darkSurface,
      canvasColor: BrandColors.darkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.darkSurfaceHigh,
        foregroundColor: BrandColors.cream,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BrandColors.cream,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: BrandColors.lightGold),
        actionsIconTheme: IconThemeData(color: BrandColors.lightGold),
      ),
      cardTheme: const CardThemeData(
        color: BrandColors.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: BrandColors.forestGreen, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BrandColors.forestGreen,
        thickness: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: BrandColors.lightGold,
        unselectedLabelColor: BrandColors.cream,
        indicatorColor: BrandColors.gold,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: BrandColors.darkSurfaceHigh,
        indicatorColor: BrandColors.forestGreen,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: BrandColors.cream),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: BrandColors.cream),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: BrandColors.darkSurfaceHigh,
        indicatorColor: BrandColors.forestGreen,
        selectedIconTheme: IconThemeData(color: BrandColors.lightGold),
        unselectedIconTheme: IconThemeData(color: BrandColors.cream),
        selectedLabelTextStyle: TextStyle(color: BrandColors.lightGold),
        unselectedLabelTextStyle: TextStyle(color: BrandColors.cream),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BrandColors.forestGreen,
        foregroundColor: BrandColors.ivory,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.forestGreen,
          foregroundColor: BrandColors.ivory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.forestGreen,
          foregroundColor: BrandColors.ivory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.lightGold,
          side: const BorderSide(color: BrandColors.gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BrandColors.lightGold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.forestGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.forestGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.error),
        ),
        labelStyle: const TextStyle(color: BrandColors.cream),
        floatingLabelStyle: const TextStyle(color: BrandColors.lightGold),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: BrandColors.darkSurfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: BrandColors.forestGreen),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: BrandColors.darkSurfaceHigh,
        selectedColor: BrandColors.forestGreen,
        labelStyle: TextStyle(color: BrandColors.cream),
        secondaryLabelStyle: TextStyle(color: BrandColors.ivory),
        side: BorderSide(color: BrandColors.forestGreen),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.deepGreen,
        contentTextStyle: TextStyle(color: BrandColors.ivory),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.lightGold,
        linearTrackColor: BrandColors.darkSurfaceHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BrandColors.lightGold
              : BrandColors.cream,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BrandColors.forestGreen
              : BrandColors.darkSurfaceHigh,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BrandColors.forestGreen
              : BrandColors.darkSurfaceHigh,
        ),
        side: const BorderSide(color: BrandColors.gold),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BrandColors.lightGold
              : BrandColors.gold,
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: BrandColors.lightGold,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: BrandColors.cream),
      ),
      listTileTheme: const ListTileThemeData(iconColor: BrandColors.lightGold),
    );
  }
}
