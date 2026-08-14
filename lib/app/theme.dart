import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const gold = Color(0xffd4af37);
  const violet = Color(0xff813be8);
  const background = Color(0xff100d17);
  const surface = Color(0xff1b1724);
  const elevatedSurface = Color(0xff241d31);
  const text = Color(0xfff4efe5);
  const mutedText = Color(0xffb8adbf);
  final scheme = ColorScheme.dark(
    primary: gold,
    onPrimary: Color(0xff211900),
    primaryContainer: Color(0xff594a0e),
    onPrimaryContainer: Color(0xffffeaa0),
    secondary: violet,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xff452080),
    onSecondaryContainer: Color(0xffeadcff),
    surface: surface,
    onSurface: text,
    surfaceContainerHighest: elevatedSurface,
    outline: Color(0xff51485c),
    error: Color(0xffffb4ab),
    onError: Color(0xff690005),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    useMaterial3: true,
    fontFamily: 'sans',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -.5,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.4, color: text),
      bodyMedium: TextStyle(fontSize: 13, height: 1.35, color: mutedText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff332b3d)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff332b3d)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gold, width: 1.5),
      ),
      hintStyle: const TextStyle(color: mutedText),
      labelStyle: const TextStyle(color: mutedText),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xff332b3d)),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xff15111d),
      selectedIconTheme: IconThemeData(color: gold),
      selectedLabelTextStyle: TextStyle(
        color: gold,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: mutedText),
      unselectedLabelTextStyle: TextStyle(color: mutedText),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xff15111d),
      indicatorColor: Color(0xff594a0e),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(color: text)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xff332b3d)),
  );
}
