import 'package:flutter/material.dart';

class AppTheme {
  // --- OLED BLACK & LUXURY GOLD PALETTE ---
  static const Color background = Color(0xFF000000); // 100% OLED Pure Black
  static const Color surface = Color(0xFF0B0B0A);
  static const Color surfaceLight = Color(0xFF141310);
  static const Color surfaceCard = Color(0xFF11100C);

  // Ori metallici e champagne
  static const Color primary = Color(0xFFFFD700); // Oro brillante
  static const Color secondary = Color(0xFFD4AF37); // Oro metallico nobile
  static const Color accentGold = Color(0xFFFFE57F); // Champagne highlight
  static const Color darkGold = Color(0xFF997A15); // Oro antico
  static const Color goldBorder = Color(0x38D4AF37); // Bordo oro satinato
  static const Color goldGlow = Color(0x33FFD700);

  // Tipografia
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFBFB7A3);
  static const Color textMuted = Color(0xFF756F62);
  static const Color divider = Color(0x22D4AF37);

  // Gradienti lusso oro
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFE898), Color(0xFFD4AF37), Color(0xFFAA7C11)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = primaryGradient;

  static const LinearGradient goldSurfaceGradient = LinearGradient(
    colors: [Color(0xFF1C180E), Color(0xFF0D0C08)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF14120B), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF000000),
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF756F62),
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: goldBorder, width: 1),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: Color(0x22FFFFFF),
        thumbColor: primary,
        overlayColor: Color(0x29FFD700),
      ),
    );
  }
}
