import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/intersection_observer.dart';
import '../services/http_cache_service.dart';
import '../utils/url_normalizer.dart';

/// Widget optimizado de imagen con carga progresiva y lazy loading
/// - Carga thumbnail primero para scroll rápido
/// - Carga HD cuando es necesario
/// - Placeholder optimizado
/// - Error widget personalizado
/// - Caché inteligente según el contexto (usa ImageCacheManager personalizado)
/// - 🔥 Lazy loading: Solo carga cuando está visible en el viewport (IntersectionObserver)
/// - 🔥 Persistencia en disco: Las imágenes persisten incluso al reiniciar la app
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

  /// Chequeo público para permitir llamadas centralizadas desde otros widgets.
  /// Delegará al registro interno de instancias.
  static void checkAllVisibility() => _OptimizedImageState.checkAllVisibility();
}

class _OptimizedImageState extends State<OptimizedImage> {
  final GlobalKey _imageKey = GlobalKey();
  bool _isVisible = false;
  bool _hasCheckedInitially = false;
  
  // ⚡ GAMA BAJA + FIX PARPADEO: Cache global de URLs ya cargadas
  // Las imágenes que ya cargaron no vuelven a mostrar placeholder
  static final Set<String> _loadedUrls = {};

  @override
  void initState() {
    super.initState();
    // Si lazyLoad está desactivado, cargar inmediatamente
    if (!widget.lazyLoad) {
      _isVisible = true;
    } else if (widget.imageUrl != null && _loadedUrls.contains(widget.imageUrl)) {
      // ⚡ FIX PARPADEO: Si esta URL ya cargó antes, mostrar inmediatamente
      _isVisible = true;
    }
    // Registrar instancia para checks globales de visibilidad
    _instances.add(this);
  }

  void _checkVisibility() {
    if (!mounted || !widget.lazyLoad || _isVisible) return; // 🔥 FIX: No verificar si ya es visible
    
    final isVisible = IntersectionObserver.isVisibleInViewport(
      _imageKey,
      context,
      threshold: widget.visibilityThreshold,
      rootMargin: 100.0, // 100px de margen para precargar
    );
    
    if (isVisible && !_isVisible) {
      // Widget entró en el viewport - cargar imagen
      setState(() {
        _isVisible = true;
      });
    }
  }

  @override
  void dispose() {
    // Remover registro global
    _instances.remove(this);
    super.dispose();
  }

  // Registro global de instancias para chequeos en lote
  static final Set<_OptimizedImageState> _instances = <_OptimizedImageState>{};

  /// Chequea visibilidad de todas las instancias registradas.
  /// Llamar desde un listener central (ej: ScrollNotification) para agrupar checks.
  static void checkAllVisibility() {
    for (final inst in _instances) {
      if (inst.mounted) {
        inst._checkVisibility();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 FIX: Verificar visibilidad inicial después del primer frame
    if (widget.lazyLoad && !_hasCheckedInitially) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hasCheckedInitially = true;
        _checkVisibility();
      });
    }
    
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildDefaultWidget();
    }

    // 🔥 LAZY LOADING: Si lazyLoad está activado y el widget no es visible, mostrar placeholder
    // y escuchar eventos de scroll para verificar visibilidad continuamente
    if (widget.lazyLoad && !_isVisible) {
      // Cuando lazyLoad está activado y aún no es visible, mostramos el placeholder
      // La verificación de visibilidad ahora se realiza desde un listener central
      // (ej: `HomeScreen` NotificationListener que llama a `OptimizedImage.checkAllVisibility()`).
      return SizedBox(
        key: _imageKey,
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ?? _buildPlaceholder(),
      );
    }

    // ✅ OPTIMIZACIÓN: Obtener el tamaño de pantalla para optimizar caché
    // ✅ OPTIMIZACIÓN: Cachear MediaQuery para evitar múltiples llamadas
    // ✅ OPTIMIZACIÓN: Usar sizeOf y devicePixelRatioOf para evitar rebuilds innecesarios
    final screenSize = MediaQuery.sizeOf(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    
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
      // 🔥 OPTIMIZACIÓN: Cache de memoria exacto al tamaño del widget
      // Eliminamos el límite de 300px para permitir scaling perfecto en tiles pequeños
      return result.round();
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
      // 🔥 OPTIMIZACIÓN: Cache de memoria exacto al tamaño del widget
      return result.round();
    }


    // CRÍTICO: Cuando skipFade es true, usar placeholder solo si no se proporciona uno personalizado
    // Si skipFade es true pero no hay placeholder personalizado, usar el placeholder por defecto
    // Esto asegura que siempre haya algo visible mientras la imagen carga
    final Widget effectivePlaceholder = widget.placeholder ?? _buildPlaceholder();

    // CRÍTICO: CachedNetworkImage usa octo_image que NO permite placeholder y progressIndicatorBuilder simultáneamente
    // Solución: Usar Image con CachedNetworkImageProvider y manejar placeholder manualmente con frameBuilder
    // Esto evita el conflicto de assertion de octo_image
    // 🔥 OPTIMIZACIÓN: Usar ImageCacheManager personalizado para persistencia en disco
    // 🔥 OPTIMIZACIÓN: Usar ImageCacheManager personalizado para persistencia en disco
    // ✅ FIX CRÍTICO: Normalizar URL antes de usarla para corregir IPs antiguas en emulador
    final normalizedUrl = UrlNormalizer.normalizeImageUrl(widget.imageUrl);
    
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
        return widget.placeholder ?? _buildPlaceholder();
    }

    final imageProvider = CachedNetworkImageProvider(
      normalizedUrl,
      cacheKey: normalizedUrl, // Usar URL normalizada también como key
      cacheManager: AlbumArtCacheManager.instance, // ✅ Cache manager con persistencia de 90 días
      headers: const {
        'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
        'Cache-Control': 'max-age=7776000', // ✅ 90 días en segundos
      },
      // ⚡ "RIGIDEZ TOTAL": Eliminar fades que causan sensación de "distorsión" al scrollear rápido
      // Cuando la imagen entra en el viewport, debe aparecer INSTANTÁNEAMENTE si está en memoria.
    );
    
    // Precargar imagen en memoria con tamaño optimizado
    final memCacheWidth = getMemCacheWidth();
    final memCacheHeight = getMemCacheHeight();
    
    // ✅ OPTIMIZACIÓN AGRESIVA: SIEMPRE usar ResizeImage para liberar memoria GPU
    // Incluso para thumbnails, el escalado en el hilo de decodificación es vital 
    // si el archivo original es de alta resolución.
    final ImageProvider effectiveImageProvider = ResizeImage(
      imageProvider,
      width: memCacheWidth,
      height: memCacheHeight,
    );
    
    // final ImageProvider effectiveImageProvider = imageProvider; // Desactivado ResizeImage para compatibilidad 90 días cache
    
    final Widget imageWidget = Image(
      key: _imageKey,
      image: effectiveImageProvider,
      fit: widget.fit,
      width: (widget.width != null && widget.width!.isFinite && !widget.width!.isNaN && !widget.width!.isInfinite) ? widget.width : null,
      height: (widget.height != null && widget.height!.isFinite && !widget.height!.isNaN && !widget.height!.isInfinite) ? widget.height : null,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Si la imagen se cargó sincrónicamente o ya tiene frame, mostrarla
        if (wasSynchronouslyLoaded || frame != null) {
          // ⚡ FIX PARPADEO: Registrar URL en cache global
          if (widget.imageUrl != null) {
            _loadedUrls.add(widget.imageUrl!);
          }
          return child;
        }
        // Mientras carga, mostrar placeholder
        return effectivePlaceholder;
      },
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ?? _buildErrorWidget();
      },
      filterQuality: FilterQuality.low, // 🚀 OPTIMIZACIÓN: Calidad baja para mejor rendimiento en scroll
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
    // ⚡ GAMA BAJA: Placeholder simplificado sin gradient
    final color = widget.placeholderColor ?? NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2);

    // Para portadas grandes, usar un placeholder más simple y rápido
    if (widget.isLargeCover) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: color,
        child: const Center(
          child: Icon(
            Icons.music_note,
            color: Colors.white30,
            size: 48,
          ),
        ),
      );
    }

    // ⚡ GAMA BAJA: Placeholder sólido sin indicador de carga
    return Container(
      width: widget.width,
      height: widget.height,
      color: color,
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: NeumorphismTheme.coffeeMedium, // ⚡ GAMA BAJA: Sin gradient
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
      color: NeumorphismTheme.coffeeMedium, // ⚡ GAMA BAJA: Sin gradient
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

