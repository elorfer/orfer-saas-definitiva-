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
  });

  /// Placeholder para artistas (gradiente vintage)
  const ImagePlaceholder.artist({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  })  : icon = Icons.person,
        iconColor = Colors.white,
        backgroundColor = null,
        gradientColors = const [
          Color(0xFFF2740B),
          Color(0xFFE35A01),
        ],
        showShimmer = false;

  /// Placeholder para canciones (gradiente púrpura)
  const ImagePlaceholder.song({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  })  : icon = Icons.music_note,
        iconColor = Colors.white70,
        backgroundColor = null,
        gradientColors = const [
          NeumorphismTheme.coffeeMedium,
          NeumorphismTheme.coffeeDark,
        ],
        showShimmer = false;

  /// Placeholder con shimmer effect para loading
  const ImagePlaceholder.shimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    List<Color>? gradientColors,
  })  : icon = Icons.image,
        iconColor = Colors.white,
        backgroundColor = null,
        gradientColors = gradientColors ?? const [
          NeumorphismTheme.coffeeMedium,
          NeumorphismTheme.coffeeDark,
        ],
        showShimmer = true;

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
          borderRadius: borderRadius != null ? BorderRadius.circular(borderRadius!) : null,
        ),
        child: showShimmer
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
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
        color: backgroundColor ?? Colors.grey.shade300,
        decoration: borderRadius != null
            ? BoxDecoration(
                color: backgroundColor ?? Colors.grey.shade300,
                borderRadius: BorderRadius.circular(borderRadius!),
              )
            : null,
        child: Center(
          child: Icon(
            icon,
            color: iconColor ?? Colors.grey,
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

