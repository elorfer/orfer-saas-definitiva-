import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

    // Obtener el tamaño de pantalla para optimizar caché
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
      // Limitar a máximo 3x el tamaño para no sobrecargar memoria
      return (result > screenSize.width * devicePixelRatio * 3)
          ? (screenSize.width * devicePixelRatio * 3).round()
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
      // Limitar a máximo 3x el tamaño para no sobrecargar memoria
      return (result > 800 * devicePixelRatio * 3)
          ? (800 * devicePixelRatio * 3).round()
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
      // Transiciones más rápidas para mejor UX
      fadeInDuration: isLargeCover 
          ? const Duration(milliseconds: 300) 
          : const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholderFadeInDuration: const Duration(milliseconds: 100),
      // Caché optimizado según el contexto
      memCacheWidth: getMemCacheWidth(),
      memCacheHeight: getMemCacheHeight(),
      maxWidthDiskCache: getMaxWidthDiskCache(),
      maxHeightDiskCache: getMaxHeightDiskCache(),
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      // Configuración de caché optimizada
      cacheKey: imageUrl,
      httpHeaders: const {
        'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
      },
      // Usar imagen anterior si la URL cambia (mejor UX durante transiciones)
      useOldImageOnUrlChange: true,
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
                const Color(0xFF667eea).withValues(alpha: 0.2),
                const Color(0xFF764ba2).withValues(alpha: 0.3),
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

    return Container(
      width: width,
      height: height,
      decoration: gradient,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      ),
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
          colors: [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
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
          colors: [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
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

