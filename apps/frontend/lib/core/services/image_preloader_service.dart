/// Servicio para precargar imágenes de carátulas y evitar parpadeo
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song_model.dart';
import '../utils/url_normalizer.dart';

class ImagePreloaderService {
  static final ImagePreloaderService _instance = ImagePreloaderService._internal();
  factory ImagePreloaderService() => _instance;
  ImagePreloaderService._internal();

  // Cache de imágenes precargadas
  final Set<String> _preloadedImages = <String>{};
  final Set<String> _preloadingImages = <String>{};

  /// Precargar carátula de una canción con ALTA PRIORIDAD (para reproductor instantáneo)
  Future<void> preloadSongCoverHighPriority(Song song, BuildContext context) async {
    if (song.coverArtUrl == null || song.coverArtUrl!.isEmpty) return;

    final normalizedUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl!);
    if (normalizedUrl == null || normalizedUrl.isEmpty) return;
    
    // Para alta prioridad, verificar si ya está precargada
    if (_preloadedImages.contains(normalizedUrl)) {
      debugPrint('⚡ [ImagePreloader] Ya precargada (ALTA PRIORIDAD): ${song.title}');
      return;
    }

    // Si ya está precargándose, esperar
    if (_preloadingImages.contains(normalizedUrl)) {
      debugPrint('⚡ [ImagePreloader] Esperando precarga (ALTA PRIORIDAD): ${song.title}');
      // Esperar un poco para que termine la precarga actual
      await Future.delayed(const Duration(milliseconds: 100));
      return;
    }

    _preloadingImages.add(normalizedUrl);

    try {
      debugPrint('⚡ [ImagePreloader] PRECARGA ALTA PRIORIDAD: ${song.title}');
      
      // Precargar usando CachedNetworkImage con máxima prioridad
      await precacheImage(
        CachedNetworkImageProvider(
          normalizedUrl,
          cacheKey: normalizedUrl,
          // Headers optimizados para carga rápida
          headers: const {
            'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
            'Cache-Control': 'max-age=86400', // Cache por 24 horas
          },
        ),
        context,
      );
      
      _preloadedImages.add(normalizedUrl);
      debugPrint('✅ [ImagePreloader] ALTA PRIORIDAD completada: ${song.title}');
      
    } catch (e) {
      debugPrint('❌ [ImagePreloader] Error ALTA PRIORIDAD ${song.title}: $e');
    } finally {
      _preloadingImages.remove(normalizedUrl);
    }
  }

  /// Precargar carátula de una canción
  Future<void> preloadSongCover(Song song, BuildContext context) async {
    if (song.coverArtUrl == null || song.coverArtUrl!.isEmpty) return;

    final normalizedUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl!);
    if (normalizedUrl == null || normalizedUrl.isEmpty) return;
    
    // Si ya está precargada o precargándose, no hacer nada
    if (_preloadedImages.contains(normalizedUrl) || 
        _preloadingImages.contains(normalizedUrl)) {
      return;
    }

    _preloadingImages.add(normalizedUrl);

    try {
      debugPrint('🖼️ [ImagePreloader] Precargando: ${song.title}');
      
      // Precargar usando CachedNetworkImage
      await precacheImage(
        CachedNetworkImageProvider(
          normalizedUrl,
          cacheKey: normalizedUrl,
        ),
        context,
      );
      
      _preloadedImages.add(normalizedUrl);
      debugPrint('✅ [ImagePreloader] Precargada: ${song.title}');
      
    } catch (e) {
      debugPrint('❌ [ImagePreloader] Error precargando ${song.title}: $e');
    } finally {
      _preloadingImages.remove(normalizedUrl);
    }
  }

  /// Precargar múltiples carátulas
  Future<void> preloadMultipleSongCovers(List<Song> songs, BuildContext context) async {
    final futures = songs.map((song) => preloadSongCover(song, context));
    await Future.wait(futures);
  }

  /// Verificar si una imagen está precargada
  bool isImagePreloaded(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return false;
    final normalizedUrl = UrlNormalizer.normalizeImageUrl(imageUrl);
    if (normalizedUrl == null) return false;
    return _preloadedImages.contains(normalizedUrl);
  }

  /// Marcar imagen como precargada (para uso sin contexto)
  void markAsPreloaded(String imageUrl) {
    final normalizedUrl = UrlNormalizer.normalizeImageUrl(imageUrl);
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      _preloadedImages.add(normalizedUrl);
      debugPrint('✅ [ImagePreloader] Marcada como precargada: $normalizedUrl');
    }
  }

  /// Limpiar cache de imágenes precargadas (para gestión de memoria)
  void clearPreloadedCache() {
    _preloadedImages.clear();
    _preloadingImages.clear();
    debugPrint('🧹 [ImagePreloader] Cache limpiado');
  }

  /// Obtener estadísticas del preloader
  Map<String, int> getStats() {
    return {
      'preloaded': _preloadedImages.length,
      'preloading': _preloadingImages.length,
    };
  }
}
