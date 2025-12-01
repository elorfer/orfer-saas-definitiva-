import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


/// Theme moderno "Soft UI" + Glassmorphism
/// Evolución del Neumorphism hacia algo más limpio y funcional
class NeumorphismTheme {
  // Paleta de colores "Clean Coffee" - Más suave y moderna
  static const Color background = Color(0xFFF5F2F0); // Gris cálido muy claro
  static const Color surface = Color(0xFFFFFFFF); // Blanco puro para superficies
  static const Color accent = Color(0xFF8D6E63); // Café suave
  static const Color accentDark = Color(0xFF5D4037); // Café oscuro
  static const Color accentLight = Color(0xFFD7CCC8); // Café muy claro
  
  // Colores de texto
  static const Color textPrimary = Color(0xFF2D2420); // Casi negro cálido
  static const Color textSecondary = Color(0xFF756860); // Gris cálido medio
  static const Color textLight = Color(0xFFA89C94); // Gris cálido claro
  
  // Gradiente de fondo sutil
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFDFBF9),
      Color(0xFFF5F2F0),
    ],
  );

  // Gradiente para placeholders de imágenes (usado en widgets de búsqueda y otros)
  static const LinearGradient imagePlaceholderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent, // coffeeMedium
      accentDark, // coffeeDark
    ],
  );

  // Colores para efectos Shimmer (skeleton loaders)
  static const Color shimmerBaseColor = Color(0xFFE0E0E0);
  static const Color shimmerHighlightColor = Color(0xFFF5F5F5);
  static const Color shimmerContentColor = Color(0xFFF0F0F0);

  /// Sombras "Soft UI" - Sutiles y difusas
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Color(0x0A000000), // 4% opacidad
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x05000000), // 2% opacidad
      offset: const Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  /// Sombra para elementos flotantes (Player, Dialogs)
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Color(0x1A5D4037), // 10% opacidad café oscuro
      offset: const Offset(0, 20),
      blurRadius: 40,
      spreadRadius: -10,
    ),
    BoxShadow(
      color: Color(0x0D000000), // 5% opacidad
      offset: const Offset(0, 10),
      blurRadius: 20,
      spreadRadius: -5,
    ),
  ];

  // --- Backward Compatibility / Legacy Members ---
  // Estos miembros se mantienen para evitar romper el código existente
  // que aún no ha sido migrado al nuevo sistema de diseño.

  static const Color coffeeMedium = accent;
  static const Color coffeeDark = accentDark;
  static const Color beigeMedium = accentLight; // Aproximación

  static List<BoxShadow> get neumorphismShadow => softShadow;
  static List<BoxShadow> get floatingCardShadow => floatingShadow;

  /// Decoración Glassmorphism (requiere ClipRRect + BackdropFilter en el widget padre)
  static BoxDecoration glassDecoration({double opacity = 0.7}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.5),
        width: 1.0,
      ),
    );
  }

  /// Decoración base para contenedores
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: softShadow,
    );
  }

  ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: accentDark,
        surface: surface,
        error: Color(0xFFE57373),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      
      scaffoldBackgroundColor: background,
      
      // Typography: Inter, limpia y legible
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textLight,
          letterSpacing: 0.5,
        ),
      ),
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: accent.withValues(alpha: 0.2),
        thumbColor: accent,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
    );
  }
}

// Extensiones útiles para UI
extension UIHelpers on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;
  EdgeInsets get padding => MediaQuery.of(this).padding;
}

