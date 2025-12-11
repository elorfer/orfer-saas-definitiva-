import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/intersection_observer.dart';

/// Widget optimizado de imagen con carga progresiva y lazy loading
/// - Carga thumbnail primero para scroll rápido
/// - Carga HD cuando es necesario
/// - Placeholder optimizado
/// - Error widget personalizado
/// - Caché inteligente según el contexto
/// - 🔥 Lazy loading: Solo carga cuando está visible en el viewport (IntersectionObserver)
class OptimizedImage extends StatefulWidget {
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
  final bool lazyLoad; // Si es true, solo carga la imagen cuando está visible (IntersectionObserver)
  final double visibilityThreshold; // Porcentaje de visibilidad necesario para cargar (0.0 - 1.0)

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
    this.lazyLoad = true, // Por defecto activar lazy loading
    this.visibilityThreshold = 0.1, // 10% visible para cargar
  });

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  final GlobalKey _imageKey = GlobalKey();
  bool _isVisible = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    // Si lazyLoad está desactivado, cargar inmediatamente
    if (!widget.lazyLoad) {
      _isVisible = true;
      _hasLoaded = true;
    }
  }

  void _checkVisibility() {
    if (!mounted || !widget.lazyLoad) return;
    
    final isVisible = IntersectionObserver.isVisibleInViewport(
      _imageKey,
      context,
      threshold: widget.visibilityThreshold,
      rootMargin: 100.0, // 100px de margen para precargar
    );
    
    if (isVisible && !_isVisible) {
      // Widget entró en el viewport
      setState(() {
        _isVisible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verificar visibilidad después del primer frame
    if (widget.lazyLoad && !_hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkVisibility();
        _hasLoaded = true;
      });
    }
    
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildDefaultWidget();
    }

    // 🔥 LAZY LOADING: Si lazyLoad está activado y el widget no es visible, mostrar solo placeholder
    if (widget.lazyLoad && !_isVisible) {
      return SizedBox(
        key: _imageKey,
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ?? _buildPlaceholder(),
      );
    }

    // ✅ OPTIMIZACIÓN: Obtener el tamaño de pantalla para optimizar caché
    // ✅ OPTIMIZACIÓN: Cachear MediaQuery para evitar múltiples llamadas
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    
    // Para portadas grandes (SliverAppBar), usar tamaño optimizado
    int? getMemCacheWidth() {
      if (widget.maxCacheWidth != null) return widget.maxCacheWidth;
      
      if (widget.isLargeCover) {
        // Para portadas grandes, limitar a 2x el ancho de pantalla (suficiente para calidad)
        return (screenSize.width * devicePixelRatio * 2).round();
      }
      
      if (widget.width == null || !widget.width!.isFinite || widget.width!.isNaN || widget.width!.isInfinite) return null;
      final result = widget.width! * devicePixelRatio;
      if (!result.isFinite || result.isNaN || result.isInfinite) return null;
      // 🔥 OPTIMIZACIÓN: Limitar a 300px máximo (suficiente para calidad)
      return (result > 300) ? 300 : result.round();
    }

    int? getMemCacheHeight() {
      if (widget.maxCacheHeight != null) return widget.maxCacheHeight;
      
      if (widget.isLargeCover) {
        // Para portadas grandes, limitar a 600px (altura típica de SliverAppBar expandido)
        return (600 * devicePixelRatio).round();
      }
      
      if (widget.height == null || !widget.height!.isFinite || widget.height!.isNaN || widget.height!.isInfinite) return null;
      final result = widget.height! * devicePixelRatio;
      if (!result.isFinite || result.isNaN || result.isInfinite) return null;
      // 🔥 OPTIMIZACIÓN: Limitar a 300px máximo (suficiente para calidad)
      return (result > 300) ? 300 : result.round();
    }


    // CRÍTICO: Cuando skipFade es true, usar placeholder solo si no se proporciona uno personalizado
    // Si skipFade es true pero no hay placeholder personalizado, usar el placeholder por defecto
    // Esto asegura que siempre haya algo visible mientras la imagen carga
    final Widget effectivePlaceholder = widget.placeholder ?? _buildPlaceholder();

    // CRÍTICO: CachedNetworkImage usa octo_image que NO permite placeholder y progressIndicatorBuilder simultáneamente
    // Solución: Usar Image con CachedNetworkImageProvider y manejar placeholder manualmente con frameBuilder
    // Esto evita el conflicto de assertion de octo_image
    final imageProvider = CachedNetworkImageProvider(
      widget.imageUrl!,
      cacheKey: widget.imageUrl,
      headers: const {
        'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
        'Cache-Control': 'max-age=86400',
      },
    );
    
    // Precargar imagen en memoria con tamaño optimizado
    final memCacheWidth = getMemCacheWidth();
    final memCacheHeight = getMemCacheHeight();
    
    // ✅ OPTIMIZACIÓN: Para imágenes pequeñas (thumbnails), evitar ResizeImage
    // ResizeImage es costoso y para thumbnails pequeños no es necesario
    final bool isSmallThumbnail = widget.width != null && widget.width! <= 128 && widget.height != null && widget.height! <= 128;
    
    // Construir el ImageProvider apropiado
    final ImageProvider effectiveImageProvider = isSmallThumbnail && !widget.isLargeCover
        ? imageProvider // Usar provider directo para thumbnails pequeños
        : ResizeImage(
            imageProvider,
            width: memCacheWidth,
            height: memCacheHeight,
          ) as ImageProvider;
    
    final Widget imageWidget = Image(
      key: _imageKey,
      image: effectiveImageProvider,
      fit: widget.fit,
      width: (widget.width != null && widget.width!.isFinite && !widget.width!.isNaN && !widget.width!.isInfinite) ? widget.width : null,
      height: (widget.height != null && widget.height!.isFinite && !widget.height!.isNaN && !widget.height!.isInfinite) ? widget.height : null,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Si la imagen se cargó sincrónicamente o ya tiene frame, mostrarla
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        // Mientras carga, mostrar placeholder
        return effectivePlaceholder;
      },
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ?? _buildErrorWidget();
      },
      filterQuality: isSmallThumbnail ? FilterQuality.low : FilterQuality.medium, // ✅ OPTIMIZACIÓN: Low quality para thumbnails pequeños
    );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius!),
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
        colors: widget.placeholderColor != null
            ? [
                widget.placeholderColor!.withValues(alpha: 0.3),
                widget.placeholderColor!.withValues(alpha: 0.5),
              ]
            : [
                NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
              ],
      ),
    );

    // Para portadas grandes, usar un placeholder más simple y rápido
    if (widget.isLargeCover) {
      return Container(
        width: widget.width,
        height: widget.height,
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
      width: widget.width,
      height: widget.height,
      decoration: gradient,
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
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
      width: widget.width,
      height: widget.height,
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

