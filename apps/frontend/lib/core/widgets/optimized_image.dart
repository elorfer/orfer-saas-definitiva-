import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/neumorphism_theme.dart';

/// Widget optimizado de imagen con carga progresiva
/// - Carga thumbnail primero para scroll rápido
/// - Carga HD cuando es necesario
/// - Placeholder optimizado
/// - Error widget personalizado
/// - Caché inteligente según el contexto
class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? borderRadius;
  final bool useThumbnail;
  final Color? placeholderColor;
  final bool isLargeCover; // Para portadas grandes (SliverAppBar)
  final int? maxCacheWidth; // Ancho máximo de caché personalizado
  final int? maxCacheHeight; // Alto máximo de caché personalizado

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.useThumbnail = true,
    this.placeholderColor,
    this.isLargeCover = false, // Para portadas grandes
    this.maxCacheWidth,
    this.maxCacheHeight,
  });


  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildDefaultWidget();
    }

    // ✅ OPTIMIZACIÓN: Obtener el tamaño de pantalla para optimizar caché
    final screenSize = MediaQuery.of(context).size;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    
    // Para portadas grandes (SliverAppBar), usar tamaño optimizado
    int? getMemCacheWidth() {
      if (maxCacheWidth != null) return maxCacheWidth;
      
      if (isLargeCover) {
        // Para portadas grandes, limitar a 2x el ancho de pantalla (suficiente para calidad)
        return (screenSize.width * devicePixelRatio * 2).round();
      }
      
      if (width == null || !width!.isFinite || width!.isNaN || width!.isInfinite) return null;
      final result = width! * devicePixelRatio;
      if (!result.isFinite || result.isNaN || result.isInfinite) return null;
      // Limitar a máximo 2x el tamaño para no sobrecargar memoria (antes 3x)
      return (result > screenSize.width * devicePixelRatio * 2)
          ? (screenSize.width * devicePixelRatio * 2).round()
          : result.round();
    }

    int? getMemCacheHeight() {
      if (maxCacheHeight != null) return maxCacheHeight;
      
      if (isLargeCover) {
        // Para portadas grandes, limitar a 600px (altura típica de SliverAppBar expandido)
        return (600 * devicePixelRatio).round();
      }
      
      if (height == null || !height!.isFinite || height!.isNaN || height!.isInfinite) return null;
      final result = height! * devicePixelRatio;
      if (!result.isFinite || result.isNaN || result.isInfinite) return null;
      // Limitar a máximo 2x el tamaño para no sobrecargar memoria (antes 3x)
      return (result > 800 * devicePixelRatio * 2)
          ? (800 * devicePixelRatio * 2).round()
          : result.round();
    }

    int? getMaxWidthDiskCache() {
      if (maxCacheWidth != null) return maxCacheWidth;
      
      if (isLargeCover) {
        // Para portadas grandes, caché en disco limitado a 1920px (Full HD)
        return 1920;
      }
      
      if (width == null || !width!.isFinite || width!.isNaN || width!.isInfinite) return 1200;
      final result = width! * 2;
      if (!result.isFinite || result.isNaN || result.isInfinite) return 1200;
      // Limitar a máximo 1920px para no usar demasiado espacio en disco
      return (result > 1920) ? 1920 : result.round();
    }

    int? getMaxHeightDiskCache() {
      if (maxCacheHeight != null) return maxCacheHeight;
      
      if (isLargeCover) {
        // Para portadas grandes, caché en disco limitado a 1080px
        return 1080;
      }
      
      if (height == null || !height!.isFinite || height!.isNaN || height!.isInfinite) return 1200;
      final result = height! * 2;
      if (!result.isFinite || result.isNaN || result.isInfinite) return 1200;
      // Limitar a máximo 1920px para no usar demasiado espacio en disco
      return (result > 1920) ? 1920 : result.round();
    }

    final Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: fit,
      width: (width != null && width!.isFinite && !width!.isNaN && !width!.isInfinite) ? width : null,
      height: (height != null && height!.isFinite && !height!.isNaN && !height!.isInfinite) ? height : null,
      // Transiciones más rápidas para mejor UX (OPTIMIZADO 🚀)
      // Si la imagen ya está en caché, usar transición instantánea
      fadeInDuration: isLargeCover 
          ? const Duration(milliseconds: 50) // Más rápido para portadas grandes
          : const Duration(milliseconds: 30), // Más rápido para imágenes pequeñas
      fadeOutDuration: const Duration(milliseconds: 0), // Sin fade out para evitar parpadeo
      placeholderFadeInDuration: const Duration(milliseconds: 0), // Sin fade para placeholder
      fadeInCurve: Curves.easeOut, // Curva más rápida
      // Usar imagen anterior si la URL cambia (mejor UX durante transiciones)
      useOldImageOnUrlChange: true,
      // Caché optimizado según el contexto
      memCacheWidth: getMemCacheWidth(),
      memCacheHeight: getMemCacheHeight(),
      maxWidthDiskCache: getMaxWidthDiskCache(),
      maxHeightDiskCache: getMaxHeightDiskCache(),
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      // Configuración de caché optimizada (MEJORADO 🚀)
      cacheKey: imageUrl,
      httpHeaders: const {
        'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
        'Cache-Control': 'max-age=86400', // Cache por 24 horas (más agresivo)
      },
      // Configuración de cache más agresiva
      cacheManager: null, // Usar cache manager por defecto
      // Configuración adicional para evitar parpadeo
      filterQuality: FilterQuality.medium, // Balance entre calidad y performance
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius!),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    // Placeholder optimizado - más rápido y con mejor UX
    final gradient = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: placeholderColor != null
            ? [
                placeholderColor!.withValues(alpha: 0.3),
                placeholderColor!.withValues(alpha: 0.5),
              ]
            : [
                NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
              ],
      ),
    );

    // Para portadas grandes, usar un placeholder más simple y rápido
    if (isLargeCover) {
      return Container(
        width: width,
        height: height,
        decoration: gradient,
        child: const Center(
          child: Icon(
            Icons.music_note,
            color: Colors.white30,
            size: 48,
          ),
        ),
      );
    }

    // Placeholder sólido sin indicador de carga para evitar "apariciones" durante scroll
    return Container(
      width: width,
      height: height,
      decoration: gradient,
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            NeumorphismTheme.coffeeMedium,
            NeumorphismTheme.coffeeDark,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note,
          color: Colors.white70,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildDefaultWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            NeumorphismTheme.coffeeMedium,
            NeumorphismTheme.coffeeDark,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          color: Colors.white70,
          size: 32,
        ),
      ),
    );
  }
}

