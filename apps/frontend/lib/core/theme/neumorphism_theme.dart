import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';


/// Theme moderno "Soft UI" + Glassmorphism
/// Evolución del Neumorphism hacia algo más limpio y funcional
/// Theme moderno "Soft UI" + Glassmorphism
/// Evolución del Neumorphism hacia algo más limpio y funcional
class NeumorphismTheme {
  // Singleton management for Theme Mode
  static ThemeMode _currentMode = ThemeMode.light;
  static bool get isDark => _currentMode == ThemeMode.dark;

  static void setThemeMode(ThemeMode mode) {
    _currentMode = mode;
  }

  // Background:
  // Web: Deep Coffee (0xFF120C0A)
  // Android/Mobile: Neutral Dark (0xFF000000 - matches system bars)
  static Color get background => isDark 
      ? (kIsWeb ? const Color(0xFF120C0A) : const Color(0xFF000000)) 
      : const Color(0xFFF5F2F0); 

  // Surface:
  // Web: Dark Roast (0xFF1E1614)
  // Android/Mobile: Neutral Surface (0xFF141414)
  static Color get surface => isDark
      ? (kIsWeb ? const Color(0xFF1E1614) : const Color(0xFF141414))
      : const Color(0xFFFFFFFF); 

  // Accent: Light (Coffee) / Dark (Light Coffee/Gold)
  static Color get accent => isDark
      ? const Color(0xFFD7CCC8) // Beige claro (invertido)
      : const Color(0xFF8D6E63); // Café suave

  // Accent Dark: Used for heavy contrasts
  static Color get accentDark => isDark
      ? const Color(0xFF8D6E63) // Café suave (invertido)
      : const Color(0xFF5D4037); // Café oscuro

  // Accent Light: Used for subtle highlights
  static Color get accentLight => isDark
      ? const Color(0xFF4E4540) // Café medio oscuro
      : const Color(0xFFD7CCC8); // Café muy claro

  // Text Colors
  static Color get textPrimary => isDark
      ? const Color(0xFFF2EFE9) // Blanco cálido lechoso
      : const Color(0xFF2D2420); // Casi negro cálido
      
  static Color get textSecondary => isDark
      ? const Color(0xFFBCAAA4) // Beige medio-oscuro
      : const Color(0xFF756860); // Gris cálido medio
      
  static Color get textLight => isDark
      ? const Color(0xFF8D7F78) // Café grisáceo
      : const Color(0xFFA89C94); // Gris cálido claro

  // Gradiente de fondo sutil
  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark 
    ? (kIsWeb 
        ? [const Color(0xFF120C0A), const Color(0xFF1A110E)] // Web: Coffee
        : [const Color(0xFF000000), const Color(0xFF101010)] // Mobile: Neutral Black
      )
    : [
        const Color(0xFFF2EFE9), 
        const Color(0xFFE8E2DD),
      ],
  );

  // Gradiente para placeholders
  static LinearGradient get imagePlaceholderGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent,
      accentDark,
    ],
  );

  // Colores para efectos Shimmer
  static Color get shimmerBaseColor => isDark ? const Color(0xFF2C2624) : const Color(0xFFE0E0E0);
  static Color get shimmerHighlightColor => isDark ? const Color(0xFF3E3532) : const Color(0xFFF5F5F5);
  static Color get shimmerContentColor => isDark ? const Color(0xFF362F2C) : const Color(0xFFF0F0F0);

  /// Sombras "Soft UI" - Sutiles y difusas
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: isDark ? const Color(0x40000000) : const Color(0x08000000), // Sombra más visible en dark
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Sombra para elementos flotantes (Player, Dialogs)
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: isDark ? const Color(0x80000000) : const Color(0x125D4037),
      offset: const Offset(0, 10),
      blurRadius: 20,
      spreadRadius: -5,
    ),
  ];

  // --- Backward Compatibility / Legacy Members ---
  static Color get coffeeMedium => accent;
  static Color get coffeeDark => accentDark;
  static Color get beigeMedium => accentLight;
  
  static List<BoxShadow> get neumorphismShadow => softShadow;
  static List<BoxShadow> get floatingCardShadow => floatingShadow;

  /// Decoración Glassmorphism
  static BoxDecoration glassDecoration({double opacity = 0.7}) {
    return BoxDecoration(
      color: (isDark ? const Color(0xFF1E1B19) : Colors.white).withValues(alpha: opacity),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.white).withValues(alpha: isDark ? 0.05 : 0.5),
        width: 1.0,
      ),
    );
  }

  /// Decoración base para contenedores
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: surface,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      border: Border.all(
        color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0D000000),
        width: 1,
      ),
    );
  }

  ThemeData get theme {
    // Definir base theme según modo para defaults de Material
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      
      // Color Scheme
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: isDark ? const Color(0xFF2D2420) : Colors.white,
        secondary: accentDark,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: isDark ? const Color(0xFF3E3532) : const Color(0xFFF0EBE6),
        error: const Color(0xFFE57373),
        onError: Colors.white,
      ),
      
      scaffoldBackgroundColor: background,
      
      // 🚀 FIX: Subtle interactions to prevent "flashing"
      splashColor: isDark ? const Color(0xFFD7CCC8).withValues(alpha: 0.05) : const Color(0xFF8D6E63).withValues(alpha: 0.05),
      highlightColor: isDark ? const Color(0xFFD7CCC8).withValues(alpha: 0.02) : const Color(0xFF8D6E63).withValues(alpha: 0.02),
      splashFactory: InkRipple.splashFactory, // Smoother ripple than default
      
      // Typography
      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
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
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        margin: EdgeInsets.zero,
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? const Color(0xFF2D2420) : Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(30)),
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

