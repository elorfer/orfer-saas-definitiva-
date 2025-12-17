import 'package:flutter/material.dart';

/// Badge de verificación estilo Spotify
/// Muestra un check azul junto al nombre del artista si está verificado
class VerifiedBadge extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showTooltip;

  const VerifiedBadge({
    super.key,
    this.size = 16.0,
    this.color,
    this.showTooltip = false,
  });

  @override
  Widget build(BuildContext context) {
    // Usar el tamaño pasado como parámetro
    final badge = SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.verified_rounded,
        color: color ?? Colors.blueAccent,
        size: size,
      ),
    );
    
    if (showTooltip) {
      return Tooltip(
        message: 'Artista verificado',
        child: badge,
      );
    }
    
    return badge;
  }
}

/// Widget helper para mostrar nombre de artista con badge de verificación
class ArtistNameWithBadge extends StatelessWidget {
  final String artistName;
  final bool isVerified;
  final TextStyle? textStyle;
  final double badgeSize;
  final MainAxisAlignment alignment;
  final int? maxLines;
  final TextOverflow? overflow;

  const ArtistNameWithBadge({
    super.key,
    required this.artistName,
    required this.isVerified,
    this.textStyle,
    this.badgeSize = 16.0,
    this.alignment = MainAxisAlignment.start,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: Verificar si isVerified es true
    if (isVerified) {
      // Log removido para reducir ruido en consola
      // debugPrint('✅ [ArtistNameWithBadge] Mostrando badge para: $artistName');
    }
    
    if (!isVerified) {
      return Text(
        artistName,
        style: textStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          artistName,
          style: textStyle,
          maxLines: maxLines,
          overflow: overflow,
        ),
        const SizedBox(width: 4),
        // Badge con tamaño dinámico basado en badgeSize
        SizedBox(
          width: badgeSize + 2, // Tamaño del badge + pequeño margen
          height: badgeSize + 2,
          child: VerifiedBadge(
            size: badgeSize,
            showTooltip: true,
          ),
        ),
      ],
    );
  }
}

