import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 🔥 OPTIMIZACIÓN: Helper para precachear imágenes basado en visibilidad
/// Solo precachea imágenes que están realmente visibles o cerca del viewport
class VisibilityPrecacheHelper {
  /// Precachea imágenes de items visibles en un ListView horizontal
  /// 
  /// [scrollController] - Controller del scroll para calcular posición
  /// [itemExtent] - Ancho fijo de cada item (requerido para cálculo preciso)
  /// [itemCount] - Número total de items
  /// [imageUrls] - Lista de URLs de imágenes a precachear
  /// [context] - BuildContext para precachear
  /// [precacheCount] - Número máximo de imágenes a precachear (default: 5)
  static void precacheVisibleHorizontalImages({
    required ScrollController scrollController,
    required double itemExtent,
    required int itemCount,
    required List<String?> imageUrls,
    required BuildContext context,
    int precacheCount = 5,
  }) {
    if (!context.mounted || imageUrls.isEmpty || itemCount == 0) return;
    
    // Calcular índices visibles basado en la posición del scroll
    final scrollPosition = scrollController.position.pixels;
    final viewportWidth = scrollController.position.viewportDimension;
    
    // Índice del primer item visible
    final firstVisibleIndex = (scrollPosition / itemExtent).floor();
    // Índice del último item visible
    final lastVisibleIndex = ((scrollPosition + viewportWidth) / itemExtent).ceil();
    
    // Precachear items visibles + algunos cercanos (precacheCount en cada dirección)
    final startIndex = (firstVisibleIndex - precacheCount).clamp(0, itemCount - 1);
    final endIndex = (lastVisibleIndex + precacheCount).clamp(0, itemCount - 1);
    
    // Precachear imágenes en el rango visible
    for (int i = startIndex; i <= endIndex && i < imageUrls.length; i++) {
      final imageUrl = imageUrls[i];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        ).catchError((error) {
          // 🔥 OPTIMIZACIÓN: Silenciar errores de precache (especialmente cuando no hay conexión)
          // Estos errores son esperados y no deberían mostrarse en la consola
          // El error handler global ya los maneja silenciosamente
        });
      }
    }
  }
  
  /// Precachea imágenes de items visibles en un ListView vertical
  /// 
  /// [scrollController] - Controller del scroll para calcular posición
  /// [itemExtent] - Altura fija de cada item (opcional, mejora precisión)
  /// [itemCount] - Número total de items
  /// [imageUrls] - Lista de URLs de imágenes a precachear
  /// [context] - BuildContext para precachear
  /// [precacheCount] - Número máximo de imágenes a precachear (default: 10)
  static void precacheVisibleVerticalImages({
    required ScrollController scrollController,
    double? itemExtent,
    required int itemCount,
    required List<String?> imageUrls,
    required BuildContext context,
    int precacheCount = 10,
  }) {
    if (!context.mounted || imageUrls.isEmpty || itemCount == 0) return;
    
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
    for (int i = startIndex; i <= endIndex && i < imageUrls.length; i++) {
      final imageUrl = imageUrls[i];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        ).catchError((error) {
          // 🔥 OPTIMIZACIÓN: Silenciar errores de precache (especialmente cuando no hay conexión)
          // Estos errores son esperados y no deberían mostrarse en la consola
          // El error handler global ya los maneja silenciosamente
        });
      }
    }
  }
  
  /// Precachea solo las primeras N imágenes visibles (sin scroll controller)
  /// Útil para precache inicial cuando no hay scroll aún
  static void precacheInitialImages({
    required List<String?> imageUrls,
    required BuildContext context,
    int count = 3,
  }) {
    if (!context.mounted || imageUrls.isEmpty) return;
    
    // Precachear solo las primeras N imágenes (las que están visibles inicialmente)
    final imagesToPrecache = imageUrls.take(count).where((url) => url != null && url.isNotEmpty).toList();
    
    for (final imageUrl in imagesToPrecache) {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        ).catchError((error) {
          // 🔥 OPTIMIZACIÓN: Silenciar errores de precache (especialmente cuando no hay conexión)
          // Estos errores son esperados y no deberían mostrarse en la consola
          // El error handler global ya los maneja silenciosamente
        });
      }
    }
  }
}

