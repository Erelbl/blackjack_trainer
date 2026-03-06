import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/store/models/table_theme_item.dart';

class AppTheme {
  // ── Core Casino Color Palette ─────────────────────────────────────────────
  static const feltGreen  = Color(0xFF0B5C2C);
  static const darkFelt   = Color(0xFF083D1F);
  static const casinoGold = Color(0xFFD4AF37);
  static const chipRed    = Color(0xFFDC143C);
  static const cardWhite  = Color(0xFFFFFFF0);
  static const neonCyan   = Color(0xFF00D4E8); // Las Vegas neon accent

  // ── Glow shadows (light — no heavy blur) ─────────────────────────────────
  static const List<Shadow> goldGlow = [
    Shadow(color: Color(0x99D4AF37), blurRadius: 10),
  ];
  static const List<Shadow> neonGlow = [
    Shadow(color: Color(0x8000D4E8), blurRadius: 8),
  ];

  // ── Centralised text style helpers ───────────────────────────────────────

  /// Bebas Neue — condensed bold, Vegas marquee.
  static TextStyle displayStyle({
    double fontSize = 22,
    Color color = casinoGold,
    double letterSpacing = 2,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.bebasNeue(
        fontSize: fontSize,
        color: color,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );

  /// Nunito — clean, modern, highly readable.
  static TextStyle bodyStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.white70,
    double? letterSpacing,
  }) =>
      GoogleFonts.nunito(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // ── Theme builders ────────────────────────────────────────────────────────

  /// Default (green) theme — used before the store finishes loading.
  static ThemeData get darkTheme => withTableTheme(TableThemeTokens.green);

  /// Builds a complete [ThemeData] with colors derived from [tokens].
  ///
  /// Called by [BlackjackTrainerApp] whenever [selectedThemeProvider] changes.
  /// Flutter's [AnimatedTheme] (implicit inside [MaterialApp]) automatically
  /// lerps between old and new [ThemeData], which calls
  /// [TableThemeTokens.lerp] and smoothly crossfades every screen's background.
  static ThemeData withTableTheme(TableThemeTokens tokens) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      extensions: [tokens],

      colorScheme: ColorScheme.dark(
        primary: casinoGold,
        secondary: chipRed,
        surface: tokens.darkFelt,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
      ),

      // Typography — Bebas Neue headlines, Nunito body
      textTheme: ThemeData.dark().textTheme.copyWith(
        headlineLarge: displayStyle(
          fontSize: 36, letterSpacing: 3, shadows: goldGlow,
        ),
        headlineMedium: displayStyle(
          fontSize: 28, color: Colors.white, letterSpacing: 2,
        ),
        titleLarge: displayStyle(fontSize: 22, letterSpacing: 2),
        titleMedium: bodyStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
        ),
        bodyLarge: bodyStyle(fontSize: 16),
        bodyMedium: bodyStyle(fontSize: 14),
        bodySmall: bodyStyle(fontSize: 12, color: Colors.white54),
        labelLarge: bodyStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
      ),

      // AppBar — theme-tinted background
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.darkFelt,
        foregroundColor: casinoGold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: displayStyle(
          fontSize: 26, letterSpacing: 3, shadows: goldGlow,
        ),
      ),

      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: casinoGold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 8,
          shadowColor: casinoGold.withValues(alpha: 0.5),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),

      // Card Theme — theme-tinted surface
      cardTheme: CardThemeData(
        color: tokens.mid,
        elevation: 4,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Scaffold backgrounds use the felt colour so screens that don't
      // wrap their body in TableBackground don't look black.
      // Screens that do use TableBackground override this with the full gradient.
      scaffoldBackgroundColor: tokens.darkFelt,
    );
  }
}
