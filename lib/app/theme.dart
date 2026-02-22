import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Casino Colors
  static const feltGreen = Color(0xFF0B5C2C);
  static const darkFelt = Color(0xFF083D1F);
  static const casinoGold = Color(0xFFD4AF37);
  static const chipRed = Color(0xFFDC143C);
  static const cardWhite = Color(0xFFFFFFF0);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: casinoGold,
        secondary: chipRed,
        surface: darkFelt,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
      ),

      // Typography - Casino style with Playfair Display for elegance
      textTheme: GoogleFonts.playfairDisplayTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: casinoGold,
          letterSpacing: 1.2,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          color: Colors.white70,
        ),
        labelLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: darkFelt,
        foregroundColor: casinoGold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: casinoGold,
        ),
      ),

      // Elevated Buttons - Casino style
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
          textStyle: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      scaffoldBackgroundColor: darkFelt,
    );
  }
}

