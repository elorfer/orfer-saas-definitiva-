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
  final bool skipFade; // Si es true, elimina fade cuando la imagen está en cache (evita parpadeo)

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
    this.skipFade = false, // Por defecto mantener fade para nuevas imágenes
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


    // CRÍTICO: Cuando skipFade es true, usar placeholder solo si no se proporciona uno personalizado
    // Si skipFade es true pero no hay placeholder personalizado, usar el placeholder por defecto
    // Esto asegura que siempre haya algo visible mientras la imagen carga
    final Widget effectivePlaceholder = placeholder ?? _buildPlaceholder();

    // CRÍTICO: CachedNetworkImage usa octo_image que NO permite placeholder y progressIndicatorBuilder simultáneamente
    // Solución: Usar Image con CachedNetworkImageProvider y manejar placeholder manualmente con frameBuilder
    // Esto evita el conflicto de assertion de octo_image
    final imageProvider = CachedNetworkImageProvider(
      imageUrl!,
      cacheKey: imageUrl,
      headers: const {
        'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
        'Cache-Control': 'max-age=86400',
      },
    );
    
    // Precargar imagen en memoria con tamaño optimizado
    final memCacheWidth = getMemCacheWidth();
    final memCacheHeight = getMemCacheHeight();
    
    final Widget imageWidget = Image(
      image: ResizeImage(
        imageProvider,
        width: memCacheWidth,
        height: memCacheHeight,
      ),
      fit: fit,
      width: (width != null && width!.isFinite && !width!.isNaN && !width!.isInfinite) ? width : null,
      height: (height != null && height!.isFinite && !height!.isNaN && !height!.isInfinite) ? height : null,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Si la imagen se cargó sincrónicamente o ya tiene frame, mostrarla
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        // Mientras carga, mostrar placeholder
        return effectivePlaceholder;
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _buildErrorWidget();
      },
      filterQuality: FilterQuality.medium,
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

