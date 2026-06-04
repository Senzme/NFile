import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color seedColor = Color(0xFF369FE7);
  
  static ThemeData getAppTheme({
    required bool light,
    bool pitchBlack = false,
    Color? seed,
    ColorScheme? customScheme,
    String fontFamily = 'default',
  }) {
    final rawColor = seed ?? seedColor;
    final brightness = light ? Brightness.light : Brightness.dark;

    ColorScheme colorScheme;
    if (customScheme != null) {
      colorScheme = customScheme.copyWith(brightness: brightness);
    } else {
      final baseScheme = ColorScheme.fromSeed(
        seedColor: rawColor,
        brightness: brightness,
        contrastLevel: 0.05,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      colorScheme = baseScheme.copyWith(
        primary: rawColor,
      );
    }

    final effectivePrimary = colorScheme.primary;
    final mainColorMultiplier = pitchBlack ? 0.1 : 0.8;
    final pitchGrey = pitchBlack ? const Color.fromARGB(255, 20, 20, 20) : const Color.fromARGB(255, 35, 35, 35);
    final pitchBlackColor = pitchBlack ? const Color.fromARGB(255, 0, 0, 0) : null;

    int getColorAlpha(int a) => (a * mainColorMultiplier).round();
    Color getMainColorWithAlpha(int a) => effectivePrimary.withAlpha(getColorAlpha(a));

    final cardColor = Color.alphaBlend(
      getMainColorWithAlpha(35),
      light ? const Color.fromARGB(255, 255, 255, 255) : pitchGrey,
    );

    // Map font keys to actual font families/themes
    TextTheme? textTheme;
    String? effectiveFontFamily;

    final baseTextTheme = ThemeData(brightness: brightness).textTheme;

    switch (fontFamily) {
      case 'nothing':
        effectiveFontFamily = 'NType82';
        textTheme = const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Ndot57'),
          displayMedium: TextStyle(fontFamily: 'Ndot57'),
          displaySmall: TextStyle(fontFamily: 'Ndot57'),
          headlineLarge: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          titleSmall: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontFamily: 'NType82'),
          bodyMedium: TextStyle(fontFamily: 'NType82'),
          bodySmall: TextStyle(fontFamily: 'NType82'),
          labelLarge: TextStyle(fontFamily: 'NType82', fontWeight: FontWeight.bold),
          labelMedium: TextStyle(fontFamily: 'NType82'),
          labelSmall: TextStyle(fontFamily: 'NType82'),
        );
        break;
      case 'outfit':
        effectiveFontFamily = 'Outfit';
        textTheme = GoogleFonts.outfitTextTheme(baseTextTheme);
        break;
      case 'jetbrains':
        effectiveFontFamily = 'JetBrains Mono';
        textTheme = GoogleFonts.jetBrainsMonoTextTheme(baseTextTheme);
        break;
      case 'montserrat':
        effectiveFontFamily = 'Montserrat';
        textTheme = GoogleFonts.montserratTextTheme(baseTextTheme);
        break;
      case 'custom':
        effectiveFontFamily = 'CustomFont';
        break;
      case 'default':
      default:
        effectiveFontFamily = 'LexendDeca';
        break;
    }

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: effectiveFontFamily,
      textTheme: textTheme,
      fontFamilyFallback: const ['sans-serif', 'Roboto'],
      scaffoldBackgroundColor: pitchBlackColor ?? (light ? Color.alphaBlend(effectivePrimary.withAlpha(10), Colors.white) : null),
      splashColor: Colors.transparent,
      highlightColor: light ? Colors.black.withAlpha(20) : Colors.white.withAlpha(pitchBlackColor == null ? 10 : 25),
      disabledColor: light ? const Color.fromARGB(200, 160, 160, 160) : const Color.fromARGB(200, 60, 60, 60),
      applyElevationOverlayColor: false,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: pitchBlackColor ?? (light ? Color.alphaBlend(effectivePrimary.withAlpha(25), Colors.white) : null),
        actionsIconTheme: IconThemeData(
          color: light ? const Color.fromARGB(200, 40, 40, 40) : const Color.fromARGB(200, 233, 233, 233),
        ),
        iconTheme: IconThemeData(
          color: light ? const Color.fromARGB(200, 40, 40, 40) : const Color.fromARGB(200, 233, 233, 233),
        ),
        titleTextStyle: TextStyle(
          color: light ? Colors.black.withAlpha(160) : Colors.white.withAlpha(210),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: effectiveFontFamily,
        ),
      ),
      secondaryHeaderColor: light ? const Color.fromARGB(200, 240, 240, 240) : const Color.fromARGB(222, 10, 10, 10),
      iconTheme: IconThemeData(
        color: light ? const Color.fromARGB(200, 40, 40, 40) : const Color.fromARGB(200, 233, 233, 233),
      ),
      shadowColor: light ? const Color.fromARGB(180, 100, 100, 100) : const Color.fromARGB(222, 10, 10, 10),
      dividerTheme: const DividerThemeData(
        thickness: 4,
        indent: 0.0,
        endIndent: 0.0,
      ),
      cardColor: cardColor,
      cardTheme: CardThemeData(
        elevation: 12.0,
        color: Color.alphaBlend(
          getMainColorWithAlpha(45),
          light ? const Color.fromARGB(255, 255, 255, 255) : pitchGrey,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.0 * 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0 * 1.5)),
        backgroundColor: light
            ? Color.alphaBlend(getMainColorWithAlpha(60), Colors.white)
            : Color.alphaBlend(getMainColorWithAlpha(20), pitchBlackColor ?? const Color.fromARGB(255, 12, 12, 12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        elevation: 12.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0 * 1.5),
        ),
        color: light ? Color.alphaBlend(cardColor.withAlpha(180), Colors.white) : Color.alphaBlend(cardColor.withAlpha(180), Colors.black),
      ),
    );
  }

  static ThemeData get lightTheme => getAppTheme(light: true);
  static ThemeData get darkTheme => getAppTheme(light: false);
}
