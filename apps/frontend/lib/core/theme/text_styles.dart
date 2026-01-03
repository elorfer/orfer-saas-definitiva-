import 'package:flutter/material.dart';
import 'neumorphism_theme.dart';

/// Estilos de texto constantes optimizados para rendimiento
/// Reemplaza GoogleFonts.inter() para evitar cargas repetidas en cada build
class AppTextStyles {
  // Títulos grandes
  static TextStyle get titleLarge => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.8, // 🚀 PREMIUM: Tighter tracking for large titles
  );

  static TextStyle get titleMedium => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.6, // 🚀 PREMIUM: Tight tracking
  );

  static TextStyle get titleSmall => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.4, // 🚀 PREMIUM: Tight tracking
  );

  // Subtítulos
  static TextStyle get subtitleLarge => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
  );

  static TextStyle get subtitleMedium => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get subtitleSmall => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
  );

  // Cuerpo de texto
  static TextStyle get bodyLarge => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textPrimary,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
  );

  static TextStyle get bodySmall => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
  );

  // Texto secundario
  static TextStyle get caption => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: NeumorphismTheme.textSecondary,
  );

  static TextStyle get overline => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: NeumorphismTheme.textLight,
  );

  // Variantes específicas
  static TextStyle get songTitle => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get artistName => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
  );

  static TextStyle get welcomeText => TextStyle(
    fontSize: 14,
    color: NeumorphismTheme.textSecondary,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get userName => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
  );

  static TextStyle get emptyStateTitle => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
  );

  static TextStyle get emptyStateBody => TextStyle(
    fontSize: 16,
    color: NeumorphismTheme.textSecondary,
    height: 1.5,
  );

  // Estilos para búsqueda
  static TextStyle get searchTitle => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get searchSubtitle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
  );

  static TextStyle get searchInput => TextStyle(
    fontSize: 16,
    color: NeumorphismTheme.textPrimary,
  );

  static TextStyle get searchHint => TextStyle(
    fontSize: 16,
    color: NeumorphismTheme.textLight,
  );

  static TextStyle get searchSectionTitle => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
  );

  static TextStyle get searchErrorTitle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
  );

  static TextStyle get searchErrorBody => TextStyle(
    fontSize: 14,
    color: NeumorphismTheme.textSecondary,
  );

  static TextStyle get searchEmptyTitle => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.coffeeDark,
  );

  static TextStyle get searchEmptySubtitle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: NeumorphismTheme.coffeeMedium,
  );

  // Estilos para auth (texto blanco)
  static TextStyle get authTitle => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static TextStyle get authSubtitle => TextStyle(
    fontSize: 16,
    color: Colors.white,
  );

  static TextStyle get authFormTitle => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static TextStyle get authFormSubtitle => TextStyle(
    fontSize: 16,
    color: Colors.white,
  );

  static TextStyle get authLink => TextStyle(
    fontSize: 14,
    color: NeumorphismTheme.coffeeMedium,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get authText => TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  static TextStyle get authTextSecondary => TextStyle(
    fontSize: 14,
    color: Colors.grey,
    fontWeight: FontWeight.w500,
  );

  // Estilos para artist_page (reemplazo de Theme.of(context).textTheme.titleMedium)
  static TextStyle get sectionTitle => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.2,
  );
}

