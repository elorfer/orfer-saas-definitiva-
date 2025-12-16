import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Helper para usar Google Fonts con fallback automático a fuentes del sistema
/// cuando no hay conexión a internet o falla la carga de fuentes.
/// 
/// Ejemplo de uso:
/// ```dart
/// Text(
///   'Hola',
///   style: SafeGoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
/// )
/// ```
class SafeGoogleFonts {
  /// Obtiene la fuente Inter con fallback automático
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    try {
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        height: height,
        color: color,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      );
    } catch (e) {
      // Si falla Google Fonts, usar la fuente del sistema
      return TextStyle(
        fontFamily: null, // Usa la fuente por defecto del sistema
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        height: height,
        color: color,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      );
    }
  }

  /// Obtiene un TextTheme con Inter y fallback automático
  static TextTheme interTextTheme(TextTheme textTheme) {
    try {
      return GoogleFonts.interTextTheme(textTheme);
    } catch (e) {
      // Si falla Google Fonts, devolver el TextTheme original
      return textTheme;
    }
  }
}






