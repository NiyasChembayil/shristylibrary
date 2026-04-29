import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static Color getPrimary(String theme) {
    switch (theme) {
      case 'halloween': return const Color(0xFFFF6B00);
      case 'winter': return const Color(0xFF00D2FF);
      case 'sakura': return const Color(0xFFFF94B4);
      case 'midnight': return const Color(0xFFBB86FC);
      default: return const Color(0xFF6C63FF);
    }
  }

  static Color getBackground(String theme) {
    if (theme == 'halloween') return const Color(0xFF0F0500);
    if (theme == 'midnight') return Colors.black;
    return const Color(0xFF0F0F1E);
  }

  static ThemeData getTheme(String theme) {
    final primary = getPrimary(theme);
    final bg = getBackground(theme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: const Color(0xFF00D2FF),
        surface: const Color(0xFF1E1E2E),
        onSurface: Colors.white,
        onPrimary: Colors.white,
        error: Colors.redAccent,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.white70,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E2E),
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
