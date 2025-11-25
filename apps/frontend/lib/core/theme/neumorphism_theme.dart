import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme con paleta cálida y estilos neumorphism + glassmorphism
class NeumorphismTheme {
  // Paleta de colores cálidos
  static const Color beigeLight = Color(0xFFF2E8DD);
  static const Color beigeMedium = Color(0xFFE4D6C8);
  static const Color beigeDark = Color(0xFFC8B4A4);
  static const Color sandLight = Color(0xFFE8DCC8);
  static const Color sandMedium = Color(0xFFD4C4B0);
  static const Color coffeeLight = Color(0xFFD4C4B0);
  static const Color coffeeMedium = Color(0xFFB8A894);
  static const Color coffeeDark = Color(0xFF9C8C78);
  
  // Colores de texto (más oscuros para mejor contraste)
  static const Color textPrimary = Color(0xFF3D2E20); // Café muy oscuro
  static const Color textSecondary = Color(0xFF5C4A3A); // Café oscuro
  static const Color textLight = Color(0xFF8B7A6A); // Café medio
  
  // Gradiente de fondo suave
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8F4F0),
      Color(0xFFF2E8DD),
      Color(0xFFE8DCC8),
    ],
  );

  /// Sombras para neumorphism (relieve hacia afuera)
  static List<BoxShadow> get neumorphismShadow => [
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.7),
      offset: const Offset(-6, -6),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: coffeeDark.withValues(alpha: 0.15),
      offset: const Offset(6, 6),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Sombras para neumorphism presionado (relieve hacia adentro)
  static List<BoxShadow> get neumorphismPressed => [
    BoxShadow(
      color: coffeeDark.withValues(alpha: 0.15),
      offset: const Offset(-3, -3),
      blurRadius: 6,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.7),
      offset: const Offset(3, 3),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  /// Sombras suaves y difusas para cards flotantes
  static List<BoxShadow> get floatingCardShadow => [
    BoxShadow(
      color: coffeeDark.withValues(alpha: 0.1),
      offset: const Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: coffeeDark.withValues(alpha: 0.05),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Decoración para glassmorphism
  static BoxDecoration get glassDecoration {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.5,
      ),
    );
  }

  ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: coffeeMedium,
        secondary: beigeDark,
        surface: beigeLight,
        error: Color(0xFFE57373),
        onPrimary: Colors.white,
        onSecondary: textPrimary,
        onSurface: textPrimary,
      ),
      
      scaffoldBackgroundColor: beigeLight,
      
      // Typography elegante y delgada con colores oscuros
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w300,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: -0.1,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textLight,
        ),
      ),
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: beigeMedium,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: coffeeMedium,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: beigeMedium.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(
            color: coffeeMedium.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.inter(
          color: textLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      
      // Asegurar que el texto por defecto sea oscuro
      primaryTextTheme: GoogleFonts.interTextTheme(
        ThemeData.light().primaryTextTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}

