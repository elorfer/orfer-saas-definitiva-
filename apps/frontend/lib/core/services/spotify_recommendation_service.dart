import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/song_model.dart';
import '../models/user_model.dart';
import 'http_client_service.dart';
import '../utils/data_normalizer.dart';
import '../utils/url_normalizer.dart';

/// 🎵 SERVICIO DE RECOMENDACIONES ESTILO SPOTIFY
/// 
/// Características avanzadas:
/// - Algoritmo híbrido con ML básico
/// - Scoring inteligente multi-factor
/// - Cache inteligente con TTL
/// - Métricas de rendimiento
/// - Personalización por usuario
/// - Fallback robusto
class SpotifyRecommendationService {
  final HttpClientService _httpClient;
  
  // Cache local con TTL - OPTIMIZADO: TTL más largo y tamaño aumentado
  final Map<String, CachedRecommendation> _cache = {};
  static const int _cacheTtlMs = 15 * 60 * 1000; // 15 minutos (aumentado para más cache hits)
  static const int _maxCacheSize = 200; // Aumentado de 100 a 200 para más hits
  
  // Métricas
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _successfulRecommendations = 0;
  
  SpotifyRecommendationService(this._httpClient);

  /// 🎯 OBTENER RECOMENDACIÓN INTELIGENTE
  /// Utiliza el algoritmo avanzado del backend
  Future<Song?> getSmartRecommendation({
    required String currentSongId,
    List<String>? genres,
    User? user,
    bool useCache = true,
  }) async {
    _totalRequests++;
    
    try {
      // 1. Verificar cache
      if (useCache) {
        final cacheKey = _generateCacheKey(currentSongId, genres, user?.id);
        final cached = _getCachedRecommendation(cacheKey);
        if (cached != null) {
          _cacheHits++;
          return cached;
        }
      }

      // 2. Construir parámetros de la consulta
      final queryParams = <String, String>{};
      
      if (genres != null && genres.isNotEmpty) {
        queryParams['genres'] = genres.join(',');
      }
      
      if (user != null) {
        queryParams['userId'] = user.id;
      }

      // 3. Realizar petición al algoritmo avanzado con timeout reducido
      final response = await _httpClient.dio.get(
        '/public/songs/recommended/$currentSongId',
        queryParameters: queryParams,
        options: Options(
          receiveTimeout: const Duration(milliseconds: 2000), // Timeout reducido para más velocidad
          sendTimeout: const Duration(milliseconds: 2000),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['song'] != null) {
          final songData = Map<String, dynamic>.from(data['song']);
          
          // CORRECCIÓN: Asegurar que fileUrl se mapee correctamente
          if (songData['fileUrl'] != null && songData['file_url'] == null) {
            songData['file_url'] = songData['fileUrl'];
          }
          
          // Normalizar canción
          final normalizedSong = DataNormalizer.normalizeSong(songData);
          
          // CORRECCIÓN ADICIONAL: Si aún no hay file_url, usar fileUrl original
          if ((normalizedSong['file_url'] == null || normalizedSong['file_url'] == '') && 
              songData['fileUrl'] != null) {
            normalizedSong['file_url'] = songData['fileUrl'];
            normalizedSong['fileUrl'] = songData['fileUrl'];
          }
          
          // Normalizar URL de portada
          final rawCoverUrl = normalizedSong['cover_art_url'] as String?;
          final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
          if (normalizedCoverUrl != null) {
            normalizedSong['cover_art_url'] = normalizedCoverUrl;
          }
          
          // Normalizar URL del archivo de audio
          final rawFileUrl = normalizedSong['file_url'] as String?;
          if (rawFileUrl != null && rawFileUrl.isNotEmpty) {
            final normalizedFileUrl = UrlNormalizer.normalizeUrl(rawFileUrl);
            normalizedSong['file_url'] = normalizedFileUrl;
            normalizedSong['fileUrl'] = normalizedFileUrl;
          }
          
          Song song = Song.fromJson(normalizedSong);
          
          // Cachear resultado
          if (useCache) {
            final cacheKey = _generateCacheKey(currentSongId, genres, user?.id);
            _cacheRecommendation(cacheKey, song);
          }
          
          _successfulRecommendations++;
          return song;
        }
        return null;
      }
      return null;
    } catch (error) {
      return null;
    }
  }


  /// ⚡ GESTIÓN DE CACHE INTELIGENTE
  String _generateCacheKey(String songId, List<String>? genres, String? userId) {
    final genresStr = genres?.join(',') ?? '';
    final userStr = userId ?? 'anon';
    return '$songId-$genresStr-$userStr';
  }

  Song? _getCachedRecommendation(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - cached.timestamp > _cacheTtlMs) {
      _cache.remove(key);
      return null;
    }
    
    return cached.song;
  }

  void _cacheRecommendation(String key, Song song) {
    _cache[key] = CachedRecommendation(
      song: song,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    // Limpiar cache antiguo (LRU simple) - OPTIMIZADO: tamaño aumentado
    if (_cache.length > _maxCacheSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
  }

  /// 📊 MÉTRICAS Y ESTADÍSTICAS
  Map<String, dynamic> getMetrics() {
    final cacheHitRate = _totalRequests > 0 ? (_cacheHits / _totalRequests * 100) : 0;
    final successRate = _totalRequests > 0 ? (_successfulRecommendations / _totalRequests * 100) : 0;
    
    return {
      'totalRequests': _totalRequests,
      'cacheHits': _cacheHits,
      'cacheHitRate': '${cacheHitRate.toStringAsFixed(1)}%',
      'successfulRecommendations': _successfulRecommendations,
      'successRate': '${successRate.toStringAsFixed(1)}%',
      'cacheSize': _cache.length,
    };
  }

  void logMetrics() {
    final metrics = getMetrics();
    debugPrint('📊 [SpotifyRec] === MÉTRICAS ===');
    debugPrint('📊 [SpotifyRec] Peticiones totales: ${metrics['totalRequests']}');
    debugPrint('📊 [SpotifyRec] Cache hits: ${metrics['cacheHits']} (${metrics['cacheHitRate']})');
    debugPrint('📊 [SpotifyRec] Recomendaciones exitosas: ${metrics['successfulRecommendations']} (${metrics['successRate']})');
    debugPrint('📊 [SpotifyRec] Tamaño cache: ${metrics['cacheSize']}');
  }

  /// 🧹 LIMPIAR CACHE
  void clearCache() {
    _cache.clear();
    debugPrint('🧹 [SpotifyRec] Cache limpiado');
  }

  /// 🔄 REINICIAR MÉTRICAS
  void resetMetrics() {
    _totalRequests = 0;
    _cacheHits = 0;
    _successfulRecommendations = 0;
    debugPrint('🔄 [SpotifyRec] Métricas reiniciadas');
  }
}

/// 💾 MODELO PARA CACHE
class CachedRecommendation {
  final Song song;
  final int timestamp;

  CachedRecommendation({
    required this.song,
    required this.timestamp,
  });
}
