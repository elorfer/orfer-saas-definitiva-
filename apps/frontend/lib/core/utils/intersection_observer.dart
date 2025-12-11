import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'logger.dart';

/// 🔥 OPTIMIZACIÓN: Sistema de Intersection Observer para Flutter
/// Detecta cuando widgets entran o salen del viewport
/// Similar a IntersectionObserver de JavaScript pero para Flutter
class IntersectionObserver {
  /// Callback que se ejecuta cuando un widget entra en el viewport
  final VoidCallback? onEnter;
  
  /// Callback que se ejecuta cuando un widget sale del viewport
  final VoidCallback? onExit;
  
  /// Porcentaje de visibilidad necesario para considerar el widget "visible" (0.0 - 1.0)
  final double threshold;
  
  /// Margen adicional alrededor del viewport para precargar (en píxeles)
  final double rootMargin;
  
  const IntersectionObserver({
    this.onEnter,
    this.onExit,
    this.threshold = 0.1, // 10% visible
    this.rootMargin = 100.0, // 100px de margen para precargar
  });
  
  /// Crea un widget que detecta su propia visibilidad
  Widget observe({
    required Widget child,
    required GlobalKey key,
    required BuildContext context,
  }) {
    return _IntersectionObserverWidget(
      key: key,
      observer: this,
      child: child,
    );
  }
  
  /// Verifica si un widget con el GlobalKey dado está visible en el viewport
  static bool isVisibleInViewport(
    GlobalKey key,
    BuildContext context, {
    double threshold = 0.1,
    double rootMargin = 100.0,
  }) {
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return false;
    
    final RenderBox? viewport = context.findRenderObject() as RenderBox?;
    if (viewport == null) return false;
    
    // Obtener posición del widget en coordenadas globales
    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    
    // Obtener posición y tamaño del viewport
    final Offset viewportPosition = viewport.localToGlobal(Offset.zero);
    final Size viewportSize = viewport.size;
    
    // Calcular intersección con margen
    final double left = position.dx;
    final double top = position.dy;
    final double right = left + size.width;
    final double bottom = top + size.height;
    
    final double viewportLeft = viewportPosition.dx - rootMargin;
    final double viewportTop = viewportPosition.dy - rootMargin;
    final double viewportRight = viewportPosition.dx + viewportSize.width + rootMargin;
    final double viewportBottom = viewportPosition.dy + viewportSize.height + rootMargin;
    
    // Calcular área de intersección
    final double intersectLeft = left > viewportLeft ? left : viewportLeft;
    final double intersectTop = top > viewportTop ? top : viewportTop;
    final double intersectRight = right < viewportRight ? right : viewportRight;
    final double intersectBottom = bottom < viewportBottom ? bottom : viewportBottom;
    
    if (intersectLeft >= intersectRight || intersectTop >= intersectBottom) {
      return false; // No hay intersección
    }
    
    // Calcular porcentaje de visibilidad
    final double intersectArea = (intersectRight - intersectLeft) * (intersectBottom - intersectTop);
    final double widgetArea = size.width * size.height;
    final double visibilityRatio = widgetArea > 0 ? intersectArea / widgetArea : 0.0;
    
    return visibilityRatio >= threshold;
  }
}

/// Widget interno que detecta su propia visibilidad
class _IntersectionObserverWidget extends StatefulWidget {
  final IntersectionObserver observer;
  final Widget child;
  
  const _IntersectionObserverWidget({
    required super.key,
    required this.observer,
    required this.child,
  });
  
  @override
  State<_IntersectionObserverWidget> createState() => _IntersectionObserverWidgetState();
}

class _IntersectionObserverWidgetState extends State<_IntersectionObserverWidget> {
  bool _wasVisible = false;
  
  @override
  void initState() {
    super.initState();
    // Verificar visibilidad después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }
  
  void _checkVisibility() {
    if (!mounted || widget.key is! GlobalKey) return;
    
    final isVisible = IntersectionObserver.isVisibleInViewport(
      widget.key as GlobalKey,
      context,
      threshold: widget.observer.threshold,
      rootMargin: widget.observer.rootMargin,
    );
    
    if (isVisible && !_wasVisible) {
      // Widget entró en el viewport
      _wasVisible = true;
      widget.observer.onEnter?.call();
    } else if (!isVisible && _wasVisible) {
      // Widget salió del viewport
      _wasVisible = false;
      widget.observer.onExit?.call();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Verificar visibilidad en cada build (cuando el scroll cambia)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
    
    return widget.child;
  }
}

/// 🔥 OPTIMIZACIÓN: Helper mejorado para lazy loading de imágenes
/// Usa IntersectionObserver para cargar imágenes solo cuando están visibles
class LazyImageLoader {
  /// Precachea imágenes de items visibles usando IntersectionObserver
  /// 
  /// [scrollController] - Controller del scroll para calcular posición
  /// [itemExtent] - Tamaño fijo de cada item (requerido para cálculo preciso)
  /// [itemCount] - Número total de items
  /// [imageUrls] - Lista de URLs de imágenes a precachear
  /// [context] - BuildContext para precachear
  /// [precacheCount] - Número máximo de imágenes a precachear (default: 5)
  static Future<void> precacheVisibleImages({
    required ScrollController scrollController,
    required double itemExtent,
    required int itemCount,
    required List<String?> imageUrls,
    required BuildContext context,
    int precacheCount = 5,
  }) async {
    if (!context.mounted || imageUrls.isEmpty || itemCount == 0) return;

    // ✅ OPTIMIZACIÓN: Verificar conectividad antes de precachear
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty) {
      AppLogger.debug('[LazyImageLoader] No hay conexión, omitiendo precache de imágenes.');
      return;
    }

    // Guardar contexto antes de async gap
    if (!context.mounted) return;
    final mountedContext = context;

    // Calcular índices visibles basado en la posición del scroll
    final scrollPosition = scrollController.position.pixels;
    final viewportDimension = scrollController.position.viewportDimension;

    // Índice del primer item visible
    final firstVisibleIndex = (scrollPosition / itemExtent).floor();
    // Índice del último item visible
    final lastVisibleIndex = ((scrollPosition + viewportDimension) / itemExtent).ceil();

    // Precachear items visibles + algunos cercanos (precacheCount en cada dirección)
    final startIndex = (firstVisibleIndex - precacheCount).clamp(0, itemCount - 1);
    final endIndex = (lastVisibleIndex + precacheCount).clamp(0, itemCount - 1);

    // Precachear imágenes en el rango visible
    final futures = <Future>[];
    for (int i = startIndex; i <= endIndex && i < imageUrls.length; i++) {
      final imageUrl = imageUrls[i];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        futures.add(
          precacheImage(
            CachedNetworkImageProvider(imageUrl),
            mountedContext,
          ).catchError((error, stackTrace) {
            // Ignorar errores de pre-cache (ej: sin conexión, imagen no encontrada)
            AppLogger.debug('[LazyImageLoader] Error al precachear imagen (silenciado): $error');
          }),
        );
      }
    }
    
    // Esperar a que todas las imágenes se precachen (con timeout)
    try {
      await Future.wait(
        futures,
        eagerError: false, // No fallar si una imagen falla
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.debug('[LazyImageLoader] Timeout al precachear imágenes');
          return <void>[]; // Retornar lista vacía en caso de timeout
        },
      );
    } catch (e) {
      AppLogger.debug('[LazyImageLoader] Error al precachear imágenes: $e');
    }
  }
  
  /// Precachea imágenes de items visibles en un ListView vertical
  static Future<void> precacheVisibleVerticalImages({
    required ScrollController scrollController,
    double? itemExtent,
    required int itemCount,
    required List<String?> imageUrls,
    required BuildContext context,
    int precacheCount = 10,
  }) async {
    if (!context.mounted || imageUrls.isEmpty || itemCount == 0) return;

    // ✅ OPTIMIZACIÓN: Verificar conectividad antes de precachear
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty) {
      AppLogger.debug('[LazyImageLoader] No hay conexión, omitiendo precache de imágenes.');
      return;
    }

    // Guardar contexto antes de async gap
    if (!context.mounted) return;
    final mountedContext = context;

    // Calcular índices visibles basado en la posición del scroll
    final scrollPosition = scrollController.position.pixels;
    final viewportHeight = scrollController.position.viewportDimension;

    int firstVisibleIndex;
    int lastVisibleIndex;

    if (itemExtent != null) {
      // Si tenemos itemExtent, cálculo preciso
      firstVisibleIndex = (scrollPosition / itemExtent).floor();
      lastVisibleIndex = ((scrollPosition + viewportHeight) / itemExtent).ceil();
    } else {
      // Estimación conservadora: asumir altura promedio de 80px
      const estimatedItemHeight = 80.0;
      firstVisibleIndex = (scrollPosition / estimatedItemHeight).floor();
      lastVisibleIndex = ((scrollPosition + viewportHeight) / estimatedItemHeight).ceil();
    }

    // Precachear items visibles + algunos cercanos (precacheCount en cada dirección)
    final startIndex = (firstVisibleIndex - precacheCount).clamp(0, itemCount - 1);
    final endIndex = (lastVisibleIndex + precacheCount).clamp(0, itemCount - 1);

    // Precachear imágenes en el rango visible
    final futures = <Future>[];
    for (int i = startIndex; i <= endIndex && i < imageUrls.length; i++) {
      final imageUrl = imageUrls[i];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        futures.add(
          precacheImage(
            CachedNetworkImageProvider(imageUrl),
            mountedContext,
          ).catchError((error, stackTrace) {
            // Ignorar errores de pre-cache
            AppLogger.debug('[LazyImageLoader] Error al precachear imagen (silenciado): $error');
          }),
        );
      }
    }
    
    // Esperar a que todas las imágenes se precachen (con timeout)
    try {
      await Future.wait(
        futures,
        eagerError: false, // No fallar si una imagen falla
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.debug('[LazyImageLoader] Timeout al precachear imágenes');
          return <void>[]; // Retornar lista vacía en caso de timeout
        },
      );
    } catch (e) {
      AppLogger.debug('[LazyImageLoader] Error al precachear imágenes: $e');
    }
  }
  
  /// Precachea solo las primeras N imágenes visibles (sin scroll controller)
  static Future<void> precacheInitialImages({
    required List<String?> imageUrls,
    required BuildContext context,
    int count = 3,
  }) async {
    if (!context.mounted || imageUrls.isEmpty) return;

    // ✅ OPTIMIZACIÓN: Verificar conectividad antes de precachear
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty) {
      AppLogger.debug('[LazyImageLoader] No hay conexión, omitiendo precache de imágenes.');
      return;
    }

    // Guardar contexto antes de async gap
    if (!context.mounted) return;
    final mountedContext = context;

    // Precachear solo las primeras N imágenes (las que están visibles inicialmente)
    final imagesToPrecache = imageUrls.take(count).where((url) => url != null && url.isNotEmpty).toList();

    final futures = <Future>[];
    for (final imageUrl in imagesToPrecache) {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        futures.add(
          precacheImage(
            CachedNetworkImageProvider(imageUrl),
            mountedContext,
          ).catchError((error, stackTrace) {
            // Ignorar errores de pre-cache
            AppLogger.debug('[LazyImageLoader] Error al precachear imagen (silenciado): $error');
          }),
        );
      }
    }
    
    // Esperar a que todas las imágenes se precachen (con timeout)
    try {
      await Future.wait(
        futures,
        eagerError: false, // No fallar si una imagen falla
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.debug('[LazyImageLoader] Timeout al precachear imágenes');
          return <void>[]; // Retornar lista vacía en caso de timeout
        },
      );
    } catch (e) {
      AppLogger.debug('[LazyImageLoader] Error al precachear imágenes: $e');
    }
  }
}

