import 'package:flutter/material.dart';
import '../theme/neumorphism_theme.dart';

/// Widget de placeholder reutilizable para imágenes
/// Elimina la duplicación de placeholders en múltiples widgets
class ImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final double? borderRadius;
  final bool showShimmer;
  final bool isCircular;

  const ImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.image,
    this.iconColor,
    this.backgroundColor,
    this.gradientColors,
    this.borderRadius,
    this.showShimmer = false,
    this.isCircular = false,
  });

  /// Placeholder para artistas (color sólido - GAMA BAJA)
  const ImagePlaceholder.artist({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  })  : icon = Icons.person,
        iconColor = Colors.white,
        backgroundColor = NeumorphismTheme.coffeeMedium, // ⚡ GAMA BAJA: Sin gradient
        gradientColors = null,
        showShimmer = false,
        isCircular = false;

  /// Placeholder para artistas redondos (color sólido - GAMA BAJA)
  const ImagePlaceholder.artistRound({
    super.key,
    this.width,
    this.height,
  })  : icon = Icons.person,
        iconColor = Colors.white,
        backgroundColor = NeumorphismTheme.coffeeMedium, // ⚡ GAMA BAJA: Sin gradient
        gradientColors = null,
        borderRadius = null,
        showShimmer = false,
        isCircular = true;

  /// Placeholder para canciones (color sólido - GAMA BAJA)
  const ImagePlaceholder.song({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  })  : icon = Icons.music_note,
        iconColor = Colors.white70,
        backgroundColor = NeumorphismTheme.coffeeMedium, // ⚡ GAMA BAJA: Sin gradient
        gradientColors = null,
        showShimmer = false,
        isCircular = false;

  /// Placeholder con loading (color sólido - GAMA BAJA, sin shimmer)
  const ImagePlaceholder.shimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    List<Color>? gradientColors,
  })  : icon = Icons.image,
        iconColor = Colors.white54,
        backgroundColor = NeumorphismTheme.coffeeMedium, // ⚡ GAMA BAJA: Sin gradient
        gradientColors = null,
        showShimmer = false, // ⚡ GAMA BAJA: Sin shimmer
        isCircular = false;

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (gradientColors != null && gradientColors!.isNotEmpty) {
      child = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors!,
          ),
          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: !isCircular && borderRadius != null ? BorderRadius.circular(borderRadius!) : null,
        ),
        child: showShimmer
            ? Center(
                // ✅ OPTIMIZACIÓN: Icono estático en lugar de CircularProgressIndicator pesado
                child: Icon(
                  icon,
                  color: (iconColor ?? Colors.white).withValues(alpha: 0.5),
                  size: (width != null && width! < 100) ? 32 : 40,
                ),
              )
            : Center(
                child: Icon(
                  icon,
                  color: iconColor ?? Colors.white,
                  size: (width != null && width! < 100) ? 40 : 48,
                ),
              ),
      );
    } else {
      child = Container(
        width: width,
        height: height,
        // ⚡ FIX: No usar color y decoration juntos - usar solo decoration
        decoration: BoxDecoration(
          color: backgroundColor ?? NeumorphismTheme.coffeeMedium,
          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: !isCircular && borderRadius != null ? BorderRadius.circular(borderRadius!) : null,
        ),
        child: Center(
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: (width != null && width! < 100) ? 32 : 40,
          ),
        ),
      );
    }

    if (showShimmer && gradientColors != null) {
      // Aquí podrías agregar un paquete de shimmer si lo necesitas
      // Por ahora, solo mostramos el CircularProgressIndicator
    }

    return child;
  }
}

