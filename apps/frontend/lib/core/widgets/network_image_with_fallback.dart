import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/url_normalizer.dart';

/// Widget de imagen de red con manejo de errores y estados de carga unificados
/// Reemplaza los patrones duplicados de errorBuilder y loadingBuilder
class NetworkImageWithFallback extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? borderRadius;
  final bool useCachedImage;
  final Color? backgroundColor;
  final IconData? errorIcon;
  final IconData? placeholderIcon;
  final Color? iconColor;

  const NetworkImageWithFallback({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.useCachedImage = false,
    this.backgroundColor,
    this.errorIcon,
    this.placeholderIcon,
    this.iconColor,
  });

  /// Constructor para imágenes pequeñas (avatars, thumbnails)
  NetworkImageWithFallback.small({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.errorIcon = Icons.person,
    this.placeholderIcon = Icons.person,
    this.iconColor,
    Color? backgroundColor,
  })  : placeholder = null,
        errorWidget = null,
        useCachedImage = false,
        backgroundColor = backgroundColor ?? Colors.grey.shade300;

  /// Constructor para imágenes medianas (covers de canciones, cards)
  NetworkImageWithFallback.medium({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.errorIcon = Icons.music_note,
    this.placeholderIcon = Icons.music_note,
    this.iconColor,
  })  : placeholder = null,
        errorWidget = null,
        useCachedImage = true,
        backgroundColor = Colors.grey.shade300;

  /// Constructor para imágenes grandes (portadas de artistas, banners)
  NetworkImageWithFallback.large({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.errorIcon = Icons.image_not_supported,
    this.placeholderIcon = Icons.image,
    this.iconColor,
  })  : placeholder = null,
        errorWidget = null,
        useCachedImage = false,
        backgroundColor = Colors.grey.shade300;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    // Normalizar la URL para que funcione en todas las plataformas
    final normalizedUrl = UrlNormalizer.normalizeImageUrl(imageUrl);
    
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return _buildErrorWidget();
    }

    Widget imageWidget;

    if (useCachedImage) {
      imageWidget = CachedNetworkImage(
        imageUrl: normalizedUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
        errorWidget: (context, url, error) {
          debugPrint('[NetworkImageWithFallback] Error cargando imagen: $url - Error: $error');
          return errorWidget ?? _buildErrorWidget();
        },
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
      );
    } else {
      imageWidget = Image.network(
        normalizedUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[NetworkImageWithFallback] Error cargando imagen: $normalizedUrl - Error: $error');
          return errorWidget ?? _buildErrorWidget();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? _buildPlaceholder();
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius!),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? Colors.grey.shade300,
      child: Center(
        child: SizedBox(
          width: (width != null && width! < 50) ? 20 : 24,
          height: (height != null && height! < 50) ? 20 : 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: iconColor ?? Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final iconSize = (width != null && width! < 50) || (height != null && height! < 50) ? 20.0 : 32.0;
    
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? Colors.grey.shade300,
      child: Icon(
        errorIcon ?? Icons.image_not_supported,
        color: iconColor ?? Colors.grey,
        size: iconSize,
      ),
    );
  }
}

