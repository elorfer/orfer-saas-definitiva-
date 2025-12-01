import 'package:flutter/material.dart';
import 'neumorphism_theme.dart';

/// Estilos de texto constantes optimizados para rendimiento
/// Reemplaza GoogleFonts.inter() para evitar cargas repetidas en cada build
class AppTextStyles {
  // Títulos grandes
  static const TextStyle titleLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
  );

  // Subtítulos
  static const TextStyle subtitleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
  );

  static const TextStyle subtitleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle subtitleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
  );

  // Cuerpo de texto
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
  );

  // Texto secundario
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: NeumorphismTheme.textSecondary,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: NeumorphismTheme.textLight,
  );

  // Variantes específicas
  static const TextStyle songTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle artistName = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
  );

  static const TextStyle welcomeText = TextStyle(
    fontSize: 14,
    color: NeumorphismTheme.textSecondary,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle userName = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
  );

  static const TextStyle emptyStateTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
  );

  static const TextStyle emptyStateBody = TextStyle(
    fontSize: 16,
    color: NeumorphismTheme.textSecondary,
    height: 1.5,
  );

  // Estilos para búsqueda
  static const TextStyle searchTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle searchSubtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
  );

  static const TextStyle searchInput = TextStyle(
    fontSize: 16,
    color: NeumorphismTheme.textPrimary,
  );

  static const TextStyle searchHint = TextStyle(
    fontSize: 16,
    color: NeumorphismTheme.textLight,
  );

  static const TextStyle searchSectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: NeumorphismTheme.textPrimary,
  );

  static const TextStyle searchErrorTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
  );

  static const TextStyle searchErrorBody = TextStyle(
    fontSize: 14,
    color: NeumorphismTheme.textSecondary,
  );

  static const TextStyle searchEmptyTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.coffeeDark,
  );

  static const TextStyle searchEmptySubtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: NeumorphismTheme.coffeeMedium,
  );

  // Estilos para auth (texto blanco)
  static const TextStyle authTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle authSubtitle = TextStyle(
    fontSize: 16,
    color: Colors.white,
  );

  static const TextStyle authFormTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle authFormSubtitle = TextStyle(
    fontSize: 16,
    color: Colors.white,
  );

  static const TextStyle authLink = TextStyle(
    fontSize: 14,
    color: NeumorphismTheme.coffeeMedium,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle authText = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  static const TextStyle authTextSecondary = TextStyle(
    fontSize: 14,
    color: Colors.grey,
    fontWeight: FontWeight.w500,
  );

  // Estilos para artist_page (reemplazo de Theme.of(context).textTheme.titleMedium)
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.2,
  );
}

