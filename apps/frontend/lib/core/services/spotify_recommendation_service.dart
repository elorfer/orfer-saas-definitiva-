import 'package:flutter/foundation.dart';
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
  
  // Cache local con TTL
  final Map<String, CachedRecommendation> _cache = {};
  static const int _cacheTtlMs = 5 * 60 * 1000; // 5 minutos
  
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
    final startTime = DateTime.now();
    _totalRequests++;
    
    debugPrint('🎵 [SpotifyRec] === INICIANDO RECOMENDACIÓN INTELIGENTE ===');
    debugPrint('🎵 [SpotifyRec] Canción actual: $currentSongId');
    debugPrint('👤 [SpotifyRec] Usuario: ${user?.id ?? 'anónimo'}');
    debugPrint('🏷️ [SpotifyRec] Géneros: ${genres?.join(', ') ?? 'auto-detectar'}');

    try {
      // 1. Verificar cache
      if (useCache) {
        final cacheKey = _generateCacheKey(currentSongId, genres, user?.id);
        final cached = _getCachedRecommendation(cacheKey);
        if (cached != null) {
          _cacheHits++;
          debugPrint('⚡ [SpotifyRec] Cache hit! Recomendación desde cache');
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

      // 3. Realizar petición al algoritmo avanzado
      final response = await _httpClient.dio.get(
        '/public/songs/recommended/$currentSongId',
        queryParameters: queryParams,
      );

      debugPrint('🌐 [SpotifyRec] Respuesta del servidor: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Log de métricas del algoritmo
        if (data['algorithm'] != null) {
          debugPrint('🤖 [SpotifyRec] Algoritmo: ${data['algorithm']}');
          debugPrint('⏱️ [SpotifyRec] Tiempo backend: ${data['processingTime']}ms');
        }
        
        if (data['metadata'] != null) {
          final metadata = data['metadata'];
          debugPrint('🧠 [SpotifyRec] Motor: ${metadata['recommendationEngine']}');
          debugPrint('📊 [SpotifyRec] Estrategias: ${metadata['strategies']?.join(', ')}');
          debugPrint('🎯 [SpotifyRec] Factores: ${metadata['scoringFactors']?.join(', ')}');
        }

        if (data['song'] != null) {
          debugPrint('🔍 [SpotifyRec] Raw song data: ${data['song']}');
          
          // APLICAR LA MISMA NORMALIZACIÓN QUE EN HomeService
          final songData = Map<String, dynamic>.from(data['song']);
          
          debugPrint('[SpotifyRec] 🔍 Datos originales de canción recomendada:');
          debugPrint('[SpotifyRec] 🔍 fileUrl: ${songData['fileUrl']}');
          debugPrint('[SpotifyRec] 🔍 file_url: ${songData['file_url']}');
          
          // CORRECCIÓN CRÍTICA: Asegurar que fileUrl se mapee correctamente
          if (songData['fileUrl'] != null && songData['file_url'] == null) {
            songData['file_url'] = songData['fileUrl'];
            debugPrint('[SpotifyRec] 🔧 CORRECCIÓN: Mapeando fileUrl -> file_url');
          }
          
          // Usar DataNormalizer para normalizar la canción
          final normalizedSong = DataNormalizer.normalizeSong(songData);
          
          debugPrint('[SpotifyRec] 🔍 Después de DataNormalizer:');
          debugPrint('[SpotifyRec] 🔍 fileUrl: ${normalizedSong['fileUrl']}');
          debugPrint('[SpotifyRec] 🔍 file_url: ${normalizedSong['file_url']}');
          
          // CORRECCIÓN ADICIONAL: Si aún no hay file_url, usar fileUrl original
          if ((normalizedSong['file_url'] == null || normalizedSong['file_url'] == '') && 
              songData['fileUrl'] != null) {
            normalizedSong['file_url'] = songData['fileUrl'];
            normalizedSong['fileUrl'] = songData['fileUrl'];
            debugPrint('[SpotifyRec] 🔧 CORRECCIÓN ADICIONAL: Usando fileUrl original');
          }
          
          // Normalizar URL de portada
          final rawCoverUrl = normalizedSong['cover_art_url'] as String?;
          final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
          if (normalizedCoverUrl != null) {
            normalizedSong['cover_art_url'] = normalizedCoverUrl;
          }
          
          // IMPORTANTE: También normalizar URL del archivo de audio
          final rawFileUrl = normalizedSong['file_url'] as String?;
          debugPrint('[SpotifyRec] 🔍 rawFileUrl para normalizar: $rawFileUrl');
          if (rawFileUrl != null && rawFileUrl.isNotEmpty) {
            final normalizedFileUrl = UrlNormalizer.normalizeUrl(rawFileUrl);
            normalizedSong['file_url'] = normalizedFileUrl;
            normalizedSong['fileUrl'] = normalizedFileUrl; // También mantener camelCase
            debugPrint('[SpotifyRec] 🔧 URL de audio normalizada: $normalizedFileUrl');
          } else {
            debugPrint('[SpotifyRec] ❌ ERROR: rawFileUrl es null o vacío');
          }
          
          Song song = Song.fromJson(normalizedSong);
          debugPrint('🔍 [SpotifyRec] Parsed song fileUrl: ${song.fileUrl}');
          
          // Corrección temporal de URL (hasta que se reinicie el backend) - YA NO NECESARIA
          // song = _correctSongUrl(song);
          
          // Cachear resultado
          if (useCache) {
            final cacheKey = _generateCacheKey(currentSongId, genres, user?.id);
            _cacheRecommendation(cacheKey, song);
          }
          
          _successfulRecommendations++;
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [SpotifyRec] Recomendación exitosa en ${duration.inMilliseconds}ms');
          debugPrint('🎵 [SpotifyRec] Canción: ${song.title}');
          debugPrint('👤 [SpotifyRec] Artista: ${song.artist?.stageName ?? 'Desconocido'}');
          debugPrint('🏷️ [SpotifyRec] Géneros: ${song.genres?.join(', ') ?? 'ninguno'}');
          debugPrint('⭐ [SpotifyRec] Es destacada: ${song.featured}');
          
          return song;
        } else {
          debugPrint('❌ [SpotifyRec] No hay recomendaciones disponibles');
          debugPrint('💡 [SpotifyRec] Mensaje: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('❌ [SpotifyRec] Error HTTP: ${response.statusCode}');
        debugPrint('📄 [SpotifyRec] Respuesta: ${response.data}');
        return null;
      }
    } catch (error, stackTrace) {
      debugPrint('❌ [SpotifyRec] Error en recomendación: $error');
      debugPrint('📍 [SpotifyRec] Stack trace: $stackTrace');
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
    
    // Limpiar cache antiguo (LRU simple)
    if (_cache.length > 100) {
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
