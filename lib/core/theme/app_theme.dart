import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const green = Color(0xFF123D32);
  static const green2 = Color(0xFF1C5A49);
  static const green3 = Color(0xFF2F8068);
  static const gold = Color(0xFFC7A56B);
  static const cream = Color(0xFFF5F6F2);
  static const ink = Color(0xFF1D2924);
  static const muted = Color(0xFF6F7D76);
  static const border = Color(0xFFE1E8E2);
  static const surface = Color(0xFFFFFFFF);
  static const paleGreen = Color(0xFFEAF3EE);
  static const paleGold = Color(0xFFF7F0E3);
  static const danger = Color(0xFFB54747);

  static const _radius = 16.0;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.light,
      primary: green,
      secondary: gold,
      surface: surface,
      error: danger,
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 34, height: 1.2, fontWeight: FontWeight.w800, color: ink),
      displayMedium: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w800, color: ink),
      headlineLarge: TextStyle(fontSize: 26, height: 1.25, fontWeight: FontWeight.w800, color: ink),
      headlineMedium: TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w800, color: ink),
      headlineSmall: TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w700, color: ink),
      titleLarge: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w800, color: ink),
      titleMedium: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w700, color: ink),
      titleSmall: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w400, color: ink),
      bodyMedium: TextStyle(fontSize: 13, height: 1.55, fontWeight: FontWeight.w400, color: ink),
      bodySmall: TextStyle(fontSize: 11, height: 1.5, fontWeight: FontWeight.w400, color: muted),
      labelLarge: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 10, height: 1.3, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansArabic',
      fontFamilyFallback: const ['NotoKufiArabic'],
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      canvasColor: cream,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: green,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 76,
        titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: green),
        iconTheme: IconThemeData(color: green),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: green2, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: green.withValues(alpha: .35),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: green,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFBFCFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: muted, fontSize: 13),
        labelStyle: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: green3, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: danger, width: 1.6)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink),
        contentTextStyle: const TextStyle(fontSize: 14, height: 1.6, color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: green,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: paleGreen,
        selectedIconTheme: const IconThemeData(color: green, size: 23),
        unselectedIconTheme: const IconThemeData(color: muted, size: 22),
        selectedLabelTextStyle: const TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelTextStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 13),
        groupAlignment: -1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: paleGreen,
        elevation: 8,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? green : muted,
        )),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(paleGreen),
        headingTextStyle: TextStyle(fontWeight: FontWeight.w800, color: green, fontSize: 12),
        dataTextStyle: TextStyle(color: ink, fontSize: 12),
        dividerThickness: 0.7,
        horizontalMargin: 18,
        columnSpacing: 24,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: green3, linearTrackColor: border),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
