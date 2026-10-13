import 'package:flutter/material.dart';

/// Dark "haunted" palette: near-black with deep purple.
class AppColors {
  static const bg = Color(0xFF040006);
  static const surface = Color(0xE60E0718); // slightly see-through over the animated background
  static const surface2 = Color(0xFF160B26);
  static const border = Color(0xFF2A1745);
  static const purple = Color(0xFF7C3AED);
  static const purpleDeep = Color(0xFF3B0F6E);
  static const purpleGlow = Color(0xFFB57BFF);
  static const purpleTint = Color(0xFF1A0D2E);
  static const text = Color(0xFFEDE7F6);
  static const textMuted = Color(0xFF9A8CB3);
  static const textFaint = Color(0xFF6B5B85);
  static const blood = Color(0xFFF0455A);
  static const bloodBg = Color(0xFF2A0812);
  static const green = Color(0xFF3EE8A6);
  static const greenBg = Color(0xFF07261C);
  static const amber = Color(0xFFFBBF24);
  static const amberBg = Color(0xFF2A1F05);
  static const code = Color(0xFF07030D);
  static const codeText = Color(0xFFD8CCF0);
}

/// "Creepy" page transition: the new page fades in from a slight zoom and blur-like scale.
class _HauntTransitionsBuilder extends PageTransitionsBuilder {
  const _HauntTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final out = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.0).animate(out),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.94).animate(out),
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 1.08, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      ),
    );
  }
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.purple,
    onPrimary: Colors.white,
    secondary: AppColors.purpleGlow,
    surface: AppColors.surface2,
    onSurface: AppColors.text,
    error: AppColors.blood,
  );

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    // Transparent so the animated background shows through every screen.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.surface2,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.purpleTint,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      hintStyle: const TextStyle(color: AppColors.textFaint),
      prefixIconColor: AppColors.purpleGlow,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.purpleGlow, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.purpleGlow,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.purpleGlow),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface2,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.purpleGlow,
      linearTrackColor: AppColors.purpleTint,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.purpleGlow : AppColors.textFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.purpleDeep : AppColors.surface2,
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.purpleGlow, textColor: AppColors.text),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: _HauntTransitionsBuilder()},
    ),
  );
}
