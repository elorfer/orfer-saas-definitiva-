import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/song_model.dart';
import '../models/user_model.dart';
import 'http_client_service.dart';
import 'retry_service.dart';
import 'http_request_pool.dart';
import 'algorithm_config_service.dart';
import '../utils/data_normalizer.dart';
import '../utils/url_normalizer.dart';
import '../utils/genre_normalizer.dart';

/// �️ RESULTADO DEL BATCH CON METADATA DE VIBE SELECTOR
/// Incluye información sobre cambios automáticos de modo
class BatchResult {
  final List<Song> songs;
  final bool vibeChangedToMix;
  final String? originalGenre;

  const BatchResult({
    required this.songs,
    this.vibeChangedToMix = false,
    this.originalGenre,
  });
}

/// �🎵 SERVICIO DE RECOMENDACIONES ESTILO SPOTIFY
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
  // Cache simple para mapear songId -> genreId y evitar múltiples llamadas
  final Map<String, String?> _songGenreCache = {};
  static const int _cacheTtlMs = 15 * 60 * 1000; // 15 minutos (aumentado para más cache hits)
  static const int _maxCacheSize = 200; // Aumentado de 100 a 200 para más hits
  
  // Métricas
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _successfulRecommendations = 0;
  
  SpotifyRecommendationService(this._httpClient);

  /// 🎯 OBTENER RECOMENDACIÓN INTELIGENTE
  /// Utiliza el algoritmo avanzado del backend
  /// 
  /// [offset]: Parámetro opcional para romper el cache (no afecta la lógica del backend)
  /// Útil para obtener múltiples recomendaciones diferentes con el mismo currentSongId
  Future<Song?> getSmartRecommendation({
    required String currentSongId,
    List<String>? genres,
    User? user,
    bool useCache = true,
    int? offset, // 🚨 NUEVO: Offset para romper cache en llamadas paralelas
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
      
      // 🚨 OFFSET PARA ROMPER CACHE: Agregar offset si se proporciona
      // El backend usará esto para crear claves de cache únicas sin afectar la lógica
      if (offset != null) {
        queryParams['offset'] = offset.toString();
      }

      // 🚀 SPOTIFY-LEVEL: Usar request pool y retry automático
      final requestKey = '/public/songs/recommended/$currentSongId?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      
      final response = await HttpRequestPool().executeRequest(
        key: requestKey,
        useCache: useCache,
        requestFn: () => RetryService().executeWithRetry(
          maxRetries: 3,
          initialDelayMs: 500,
          shouldRetry: RetryService.isRetryableError,
          fn: () => _httpClient.dio.get(
            '/public/songs/recommended/$currentSongId',
            queryParameters: queryParams,
            options: Options(
              receiveTimeout: const Duration(milliseconds: 2000),
              sendTimeout: const Duration(milliseconds: 2000),
            ),
          ),
        ),
      );

      // Depuración: imprimir cuerpo completo de la respuesta (truncado a 2000 chars)
      try {
        final raw = response.data;
        final rawStr = raw is String ? raw : raw.toString();
        debugPrint('🔎 [SpotifyRecommendation] RAW response body (trunc 2000): ${rawStr.length > 2000 ? "${rawStr.substring(0, 2000)}..." : rawStr}');
      } catch (_) {}

      if (response.statusCode == 200) {
        final data = response.data;
        
        // 🚨 LOG DE DEPURACIÓN: Ver qué está devolviendo el backend
        debugPrint('🔍 [SpotifyRecommendation] Respuesta del backend (offset: ${offset ?? 'none'}): ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');
        
        if (data['song'] != null) {
          final songData = Map<String, dynamic>.from(data['song']);
          debugPrint('✅ [SpotifyRecommendation] Canción encontrada en respuesta: ${songData['title'] ?? 'sin título'} (ID: ${songData['id']?.toString().substring(0, 8) ?? 'sin ID'}...)');
          
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
          
          Song song = await Song.parse(normalizedSong);
          
          // Cachear resultado
          if (useCache) {
            final cacheKey = _generateCacheKey(currentSongId, genres, user?.id);
            _cacheRecommendation(cacheKey, song);
          }
          
          _successfulRecommendations++;
          debugPrint('✅ [SpotifyRecommendation] Canción parseada exitosamente: ${song.title}');
          return song;
        } else {
          debugPrint('⚠️ [SpotifyRecommendation] Respuesta del backend no contiene campo "song". Estructura: ${data.keys.toList()}');
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

  /// 🚀 GENERAR BATCH DE RECOMENDACIONES (NUEVO ENDPOINT OPTIMIZADO)
  /// Reemplaza múltiples llamadas individuales por una sola llamada al backend
  /// El backend maneja internamente el batching y garantiza variedad
  /// 🎛️ VIBE SELECTOR: Soporte para filtrar por género específico
  /// 🔄 RETORNA BatchResult con metadata sobre cambios de modo
  Future<BatchResult> generatePlaylistBatch({
    required String seedSongId,
    required int count,
    User? user,
    List<String>? genres,
    List<String> excludeIds = const [],
    bool useCache = true,
    String? genreId, // 🎛️ Género específico del Vibe Selector
  }) async {
    _totalRequests++;
    
    try {
      // Construir parámetros de la consulta
      final queryParams = <String, String>{
        'seed': seedSongId,
        'count': count.toString(),
      };
      
      // 🎛️ VIBE SELECTOR: Normalize genres list and only accept genreId when it's a valid UUID
      final normalizedGenres = normalizeGenres(genres);
      String? resolvedGenreId = genreId;

      // If the provided genreId is not a valid UUID, ignore it (likely a name)
      if (resolvedGenreId != null && resolvedGenreId.isNotEmpty && !isValidUuid(resolvedGenreId)) {
        debugPrint('🎛️ [SpotifyRec Batch] Ignoring invalid genreId (not UUID): $resolvedGenreId');
        resolvedGenreId = null;
      }

      // Si aún no hay genreId, intentar recuperar metadata de la canción (backend)
      if ((resolvedGenreId == null || resolvedGenreId.isEmpty) && !_songGenreCache.containsKey(seedSongId)) {
        try {
          debugPrint('🔍 [SpotifyRec Batch] Obteniendo metadata de canción para extraer genreId: $seedSongId');
          final songResp = await _httpClient.dio.get('/public/songs/$seedSongId',
            options: Options(receiveTimeout: const Duration(seconds: 3), sendTimeout: const Duration(seconds: 3)),
          );
          if (songResp.statusCode == 200 && songResp.data != null) {
            final songData = songResp.data as Map<String, dynamic>;
            final rawCandidate = (songData['genre_id'] as String?) ?? ((songData['genres'] is List && (songData['genres'] as List).isNotEmpty) ? (songData['genres'] as List).first?.toString() : null);
            final candidate = isValidUuid(rawCandidate) ? rawCandidate : null;
            _songGenreCache[seedSongId] = candidate;
            resolvedGenreId = resolvedGenreId ?? candidate;
            debugPrint('🔍 [SpotifyRec Batch] genreId from metadata (raw): $rawCandidate -> accepted: $candidate');
            debugPrint('GENRE_DEBUG resolvedGenreId (after metadata fetch): $resolvedGenreId for seed $seedSongId');
          }
        } catch (e) {
          debugPrint('⚠️ [SpotifyRec Batch] Error fetching song metadata for genreId: $e');
          _songGenreCache[seedSongId] = null;
        }
      } else if (_songGenreCache.containsKey(seedSongId)) {
        resolvedGenreId = resolvedGenreId ?? _songGenreCache[seedSongId];
      }

      if (resolvedGenreId != null && resolvedGenreId.isNotEmpty) {
        queryParams['genreId'] = resolvedGenreId;
      } else if (normalizedGenres.isNotEmpty) {
        queryParams['genres'] = normalizedGenres.join(',');
      }
      
      if (user != null) {
        queryParams['userId'] = user.id;
      }
      
      // ⚡ ADMIN CONTROLADO: Usar effectiveHistorySize del Admin para limitar excludeIds
      // Esto permite controlar desde el Admin cuántas canciones excluir
      final maxExcludeIds = AlgorithmConfigService.instance.currentConfig.effectiveHistorySize;
      var effectiveExcludeIds = excludeIds;
      if (excludeIds.length > maxExcludeIds) {
        debugPrint('⚠️ [SpotifyRec Batch] Demasiados excludeIds (${excludeIds.length}). Limitando a últimos $maxExcludeIds (Admin config).');
        // Tomar solo los últimos N (los más recientes)
        effectiveExcludeIds = excludeIds.skip(excludeIds.length - maxExcludeIds).toList();
      }
      
      if (effectiveExcludeIds.isNotEmpty) {
        queryParams['excludeIds'] = effectiveExcludeIds.join(',');
      }

      // 🚀 NUEVO ENDPOINT: /public/songs/playlist/generate
      debugPrint('🚀 [SpotifyRec Batch] ⚠️ NUEVO ENDPOINT: Llamando a /public/songs/playlist/generate');
      debugPrint('🚀 [SpotifyRec Batch] Parámetros: seed=$seedSongId, count=$count, excludeIds=${excludeIds.length}, genreId=$genreId');
      debugPrint('GENRE_DEBUG before request: seed=$seedSongId resolvedGenreId=$resolvedGenreId providedGenreParam=$genreId');
      
      final requestKey = '/public/songs/playlist/generate?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      
      debugPrint('🚀 [SpotifyRec Batch] Request key: $requestKey');
      // Depuración adicional: imprimir mapa de parámetros final para confirmar genreId
      debugPrint('🔍 [SpotifyRec Batch] Final queryParams: $queryParams');
      debugPrint('🔍 [SpotifyRec Batch] genreId used: ${queryParams['genreId'] ?? 'none'}');
      debugPrint('GENRE_DEBUG Final queryParams (text): ${queryParams.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
      
      final response = await HttpRequestPool().executeRequest(
        key: requestKey,
        useCache: useCache,
        requestFn: () => RetryService().executeWithRetry(
          maxRetries: 3,
          initialDelayMs: 500,
          shouldRetry: RetryService.isRetryableError,
          fn: () => _httpClient.dio.get(
            '/public/songs/playlist/generate',
            queryParameters: queryParams,
            options: Options(
              receiveTimeout: const Duration(seconds: 30), // ⚡ Aumentado temporalmente por lentitud del backend
              sendTimeout: const Duration(seconds: 30),
            ),
          ),
        ),
      );

      // Depuración: imprimir cuerpo completo de la respuesta (truncado a 4000 chars)
      try {
        final raw = response.data;
        final rawStr = raw is String ? raw : raw.toString();
        debugPrint('🔎 [SpotifyRec Batch] RAW response body (trunc 4000): ${rawStr.length > 4000 ? "${rawStr.substring(0, 4000)}..." : rawStr}');
      } catch (_) {}

      if (response.statusCode == 200) {
        final data = response.data;
        
        debugPrint('🚀 [SpotifyRec Batch] Respuesta recibida: ${data['count'] ?? 0}/${data['requested'] ?? count} canciones');
        
        // 🎛️ VIBE SELECTOR: Detectar si hubo cambio automático a MIX
        final bool vibeChangedToMix = data['vibeChangedToMix'] == true;
        final String? originalGenre = data['originalGenre'] as String?;
        
        if (vibeChangedToMix) {
          debugPrint('🔀 [SpotifyRec Batch] ¡Backend activó modo MIX! Género agotado: $originalGenre');
        }
        
        if (data['songs'] != null && data['songs'] is List) {
          final songsList = data['songs'] as List;

          // Normalizar todos los items primero (rápido, sin parse pesado)
          final normalizedList = <Map<String, dynamic>>[];
          for (final songData in songsList) {
            try {
              final songMap = Map<String, dynamic>.from(songData);

              if (songMap['fileUrl'] != null && songMap['file_url'] == null) {
                songMap['file_url'] = songMap['fileUrl'];
              }

              final normalizedSong = DataNormalizer.normalizeSong(songMap);

              if ((normalizedSong['file_url'] == null || normalizedSong['file_url'] == '') &&
                  songMap['fileUrl'] != null) {
                normalizedSong['file_url'] = songMap['fileUrl'];
                normalizedSong['fileUrl'] = songMap['fileUrl'];
              }

              final rawCoverUrl = normalizedSong['cover_art_url'] as String?;
              final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
              if (normalizedCoverUrl != null) {
                normalizedSong['cover_art_url'] = normalizedCoverUrl;
              }

              final rawFileUrl = normalizedSong['file_url'] as String?;
              if (rawFileUrl != null && rawFileUrl.isNotEmpty) {
                final normalizedFileUrl = UrlNormalizer.normalizeUrl(rawFileUrl);
                normalizedSong['file_url'] = normalizedFileUrl;
                normalizedSong['fileUrl'] = normalizedFileUrl;
              }

              normalizedList.add(normalizedSong);
            } catch (e) {
              debugPrint('⚠️ [SpotifyRec Batch] Error normalizando canción: $e');
            }
          }

          // Parsear en batch en un isolate para evitar bloquear el UI thread
          List<Song> parsedSongs = [];
          try {
            parsedSongs = await Song.parseList(normalizedList);
          } catch (_) {
            // Fallback síncrono si falla el isolate
            for (final n in normalizedList) {
              try {
                parsedSongs.add(Song.fromJson(n));
              } catch (_) {}
            }
          }

          final songs = parsedSongs.where((s) => s.isValidForPlayback).toList();

          _successfulRecommendations += songs.length;
          debugPrint('✅ [SpotifyRec Batch] ${songs.length} canciones parseadas exitosamente');

          return BatchResult(
            songs: songs,
            vibeChangedToMix: vibeChangedToMix,
            originalGenre: originalGenre,
          );
        }
        
        debugPrint('⚠️ [SpotifyRec Batch] Respuesta no contiene campo "songs" o no es una lista');
        return const BatchResult(songs: []);
      }
      
      return const BatchResult(songs: []);
    } catch (error) {
      debugPrint('❌ [SpotifyRec Batch] Error: $error');
      return const BatchResult(songs: []);
    }
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
