import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../models/user_model.dart';
import 'http_client_service.dart';
import 'spotify_recommendation_service.dart';
import 'home_service.dart';
import '../utils/logger.dart';

/// 🧠 SERVICIO DE CANCIONES DESTACADAS INTELIGENTES
/// 
/// Combina:
/// 1. Canciones destacadas estáticas (marcadas por admin)
/// 2. Recomendaciones dinámicas usando tu algoritmo avanzado
/// 3. Personalización basada en historial de usuario
/// 4. Diversidad y frescura en las recomendaciones
class IntelligentFeaturedService {
  final HomeService _homeService;
  final SpotifyRecommendationService _recommendationService;
  
  // Cache para recomendaciones inteligentes
  final Map<String, CachedFeaturedRecommendations> _cache = {};
  static const int _cacheTtlMs = 3 * 60 * 1000; // 3 minutos para más variedad
  
  // Configuración del algoritmo
  static const int _maxStaticFeatured = 8; // Máximo de canciones destacadas estáticas
  static const int _maxDynamicRecommendations = 12; // Máximo de recomendaciones dinámicas
  static const int _totalFeaturedSongs = 20; // Total de canciones destacadas a mostrar
  
  IntelligentFeaturedService({
    HomeService? homeService,
    SpotifyRecommendationService? recommendationService,
  }) : _homeService = homeService ?? HomeService(),
       _recommendationService = recommendationService ?? SpotifyRecommendationService(HttpClientService());

  /// 🎯 OBTENER CANCIONES DESTACADAS INTELIGENTES
  /// Combina canciones destacadas estáticas con recomendaciones dinámicas
  Future<List<FeaturedSong>> getIntelligentFeaturedSongs({
    int limit = _totalFeaturedSongs,
    User? user,
    String? currentSongId,
    bool forceRefresh = false,
  }) async {
    final startTime = DateTime.now();
    
    debugPrint('🧠 [IntelligentFeatured] === INICIANDO RECOMENDACIONES INTELIGENTES ===');
    debugPrint('🧠 [IntelligentFeatured] Límite: $limit canciones');
    debugPrint('👤 [IntelligentFeatured] Usuario: ${user?.id ?? 'anónimo'}');
    debugPrint('🎵 [IntelligentFeatured] Canción actual: ${currentSongId ?? 'ninguna'}');

    try {
      // 1. Verificar cache
      if (!forceRefresh) {
        final cacheKey = _generateCacheKey(user?.id, currentSongId, limit);
        final cached = _getCachedRecommendations(cacheKey);
        if (cached != null) {
          debugPrint('⚡ [IntelligentFeatured] Cache hit! Retornando ${cached.length} canciones');
          return cached;
        }
      }

      // 2. Obtener canciones destacadas estáticas (base sólida)
      final staticFeatured = await _getStaticFeaturedSongs();
      debugPrint('📌 [IntelligentFeatured] Canciones estáticas: ${staticFeatured.length}');

      // 3. Si hay suficientes canciones estáticas (al menos 4), solo mostrar esas
      // Solo agregar dinámicas si hay menos de 4 canciones estáticas
      List<FeaturedSong> dynamicRecommendations = [];
      
      if (staticFeatured.length < 4) {
        // Solo agregar recomendaciones dinámicas si hay menos de 4 estáticas
        final remainingSlots = limit - staticFeatured.length;
        if (remainingSlots > 0) {
          dynamicRecommendations = await _getDynamicRecommendations(
            count: remainingSlots,
            user: user,
            currentSongId: currentSongId,
            excludeIds: staticFeatured.map((f) => f.song.id).toSet(),
          );
          debugPrint('🤖 [IntelligentFeatured] Recomendaciones dinámicas: ${dynamicRecommendations.length}');
        }
      } else {
        debugPrint('✅ [IntelligentFeatured] Suficientes canciones estáticas (${staticFeatured.length}), no agregar dinámicas');
      }

      // 4. Combinar y diversificar
      final combinedResults = _combineAndDiversify(
        staticFeatured: staticFeatured,
        dynamicRecommendations: dynamicRecommendations,
        limit: limit,
      );

      // 5. Cachear resultado
      if (!forceRefresh) {
        final cacheKey = _generateCacheKey(user?.id, currentSongId, limit);
        _cacheRecommendations(cacheKey, combinedResults);
      }

      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [IntelligentFeatured] Completado en ${duration.inMilliseconds}ms');
      debugPrint('🎵 [IntelligentFeatured] Total: ${combinedResults.length} canciones destacadas inteligentes');
      
      return combinedResults;

    } catch (error, stackTrace) {
      AppLogger.error('[IntelligentFeatured] Error en recomendaciones inteligentes', error, stackTrace);
      
      // Fallback: solo canciones destacadas estáticas
      try {
        final fallback = await _getStaticFeaturedSongs();
        debugPrint('🔄 [IntelligentFeatured] Fallback: ${fallback.length} canciones estáticas');
        return fallback.take(limit).toList();
      } catch (fallbackError) {
        AppLogger.error('[IntelligentFeatured] Error en fallback', fallbackError);
        return [];
      }
    }
  }

  /// 📌 OBTENER CANCIONES DESTACADAS ESTÁTICAS
  /// Estas son las canciones marcadas como destacadas por el administrador
  Future<List<FeaturedSong>> _getStaticFeaturedSongs() async {
    try {
      final staticSongs = await _homeService.getFeaturedSongs(
        limit: _maxStaticFeatured,
        forceRefresh: false,
      );
      
      debugPrint('📌 [IntelligentFeatured] Canciones estáticas obtenidas: ${staticSongs.length}');
      return staticSongs;
    } catch (error) {
      AppLogger.error('[IntelligentFeatured] Error obteniendo canciones estáticas', error);
      return [];
    }
  }

  /// 🤖 OBTENER RECOMENDACIONES DINÁMICAS
  /// Usa tu algoritmo avanzado para generar recomendaciones personalizadas
  Future<List<FeaturedSong>> _getDynamicRecommendations({
    required int count,
    User? user,
    String? currentSongId,
    Set<String> excludeIds = const {},
  }) async {
    if (count <= 0) return [];

    try {
      List<FeaturedSong> recommendations = [];
      Set<String> usedSongIds = Set.from(excludeIds);
      
      // Estrategia 1: Si hay canción actual, usar algoritmo de recomendación
      if (currentSongId != null && !usedSongIds.contains(currentSongId)) {
        final recommendedSongs = await _getRecommendationsBasedOnSong(
          currentSongId: currentSongId,
          user: user,
          count: count,
          excludeIds: usedSongIds,
        );
        
        recommendations.addAll(recommendedSongs);
        usedSongIds.addAll(recommendedSongs.map((r) => r.song.id));
        
        debugPrint('🎯 [IntelligentFeatured] Recomendaciones basadas en canción actual: ${recommendedSongs.length}');
      }
      
      // Estrategia 2: Si aún necesitamos más, usar canciones populares diversas
      if (recommendations.length < count) {
        final remaining = count - recommendations.length;
        final popularSongs = await _getPopularDiverseSongs(
          count: remaining,
          excludeIds: usedSongIds,
        );
        
        recommendations.addAll(popularSongs);
        debugPrint('🔥 [IntelligentFeatured] Canciones populares diversas: ${popularSongs.length}');
      }

      return recommendations.take(count).toList();
    } catch (error) {
      AppLogger.error('[IntelligentFeatured] Error obteniendo recomendaciones dinámicas', error);
      return [];
    }
  }

  /// 🎯 OBTENER RECOMENDACIONES BASADAS EN CANCIÓN
  /// Usa tu algoritmo avanzado de recomendaciones
  Future<List<FeaturedSong>> _getRecommendationsBasedOnSong({
    required String currentSongId,
    User? user,
    required int count,
    Set<String> excludeIds = const {},
  }) async {
    List<FeaturedSong> recommendations = [];
    Set<String> usedIds = Set.from(excludeIds);
    
    // Generar múltiples recomendaciones para tener variedad
    for (int i = 0; i < count && i < 10; i++) {
      try {
        final recommendedSong = await _recommendationService.getSmartRecommendation(
          currentSongId: currentSongId,
          user: user,
          useCache: i == 0, // Solo usar cache en la primera recomendación
        );
        
        if (recommendedSong != null && !usedIds.contains(recommendedSong.id)) {
          final featuredSong = FeaturedSong(
            song: recommendedSong,
            featuredReason: 'Recomendada por IA • ${_getRecommendationReason(i)}',
            rank: i + 1,
          );
          
          recommendations.add(featuredSong);
          usedIds.add(recommendedSong.id);
          
          debugPrint('🎯 [IntelligentFeatured] Recomendación ${i + 1}: ${recommendedSong.title}');
        }
      } catch (error) {
        debugPrint('❌ [IntelligentFeatured] Error en recomendación ${i + 1}: $error');
        continue;
      }
    }
    
    return recommendations;
  }

  /// 🔥 OBTENER CANCIONES POPULARES DIVERSAS
  /// Fallback para llenar espacios restantes
  Future<List<FeaturedSong>> _getPopularDiverseSongs({
    required int count,
    Set<String> excludeIds = const {},
  }) async {
    try {
      final popularSongs = await _homeService.getPopularSongs(limit: count * 2);
      
      final diverseSongs = popularSongs
          .where((song) => !excludeIds.contains(song.id))
          .take(count)
              .map((song) => FeaturedSong(
                song: song,
                featuredReason: 'Trending • ${song.totalStreams} reproducciones',
                rank: 1,
              ))
          .toList();
      
      return diverseSongs;
    } catch (error) {
      AppLogger.error('[IntelligentFeatured] Error obteniendo canciones populares', error);
      return [];
    }
  }

  /// 🎭 COMBINAR Y DIVERSIFICAR RESULTADOS
  /// Mezcla canciones estáticas y dinámicas para máxima variedad
  /// Si solo hay estáticas suficientes (4+), solo devuelve esas sin agregar dinámicas
  List<FeaturedSong> _combineAndDiversify({
    required List<FeaturedSong> staticFeatured,
    required List<FeaturedSong> dynamicRecommendations,
    required int limit,
  }) {
    // Si hay suficientes canciones estáticas (4 o más), solo devolver esas
    if (staticFeatured.length >= 4 && dynamicRecommendations.isEmpty) {
      debugPrint('✅ [IntelligentFeatured] Solo estáticas suficientes: ${staticFeatured.length} canciones');
      return staticFeatured.take(limit).toList();
    }
    
    // Si no hay dinámicas, solo devolver las estáticas disponibles (sin completar hasta el límite)
    if (dynamicRecommendations.isEmpty) {
      debugPrint('📌 [IntelligentFeatured] Solo estáticas disponibles: ${staticFeatured.length} canciones');
      return staticFeatured;
    }
    
    // Si hay ambas, combinar con estrategia de intercalado
    final List<FeaturedSong> result = [];
    int staticIndex = 0;
    int dynamicIndex = 0;
    bool useStatic = true;
    
    while (result.length < limit && 
           (staticIndex < staticFeatured.length || dynamicIndex < dynamicRecommendations.length)) {
      
      if (useStatic && staticIndex < staticFeatured.length) {
        result.add(staticFeatured[staticIndex]);
        staticIndex++;
      } else if (dynamicIndex < dynamicRecommendations.length) {
        result.add(dynamicRecommendations[dynamicIndex]);
        dynamicIndex++;
      } else if (staticIndex < staticFeatured.length) {
        result.add(staticFeatured[staticIndex]);
        staticIndex++;
      }
      
      useStatic = !useStatic; // Alternar entre estáticas y dinámicas
    }
    
    debugPrint('🎭 [IntelligentFeatured] Combinación final: ${result.length} canciones');
    debugPrint('📌 [IntelligentFeatured] Estáticas usadas: $staticIndex/${staticFeatured.length}');
    debugPrint('🤖 [IntelligentFeatured] Dinámicas usadas: $dynamicIndex/${dynamicRecommendations.length}');
    
    return result;
  }

  /// 🏷️ OBTENER RAZÓN DE RECOMENDACIÓN
  String _getRecommendationReason(int index) {
    final reasons = [
      'Perfecta para ti',
      'Género similar',
      'Artista relacionado',
      'Trending ahora',
      'Descubrimiento',
      'Basada en tu historial',
      'Algoritmo avanzado',
      'Recomendación especial',
    ];
    
    return reasons[index % reasons.length];
  }

  /// ⚡ GESTIÓN DE CACHE
  String _generateCacheKey(String? userId, String? currentSongId, int limit) {
    return '${userId ?? 'anon'}-${currentSongId ?? 'none'}-$limit';
  }

  List<FeaturedSong>? _getCachedRecommendations(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - cached.timestamp > _cacheTtlMs) {
      _cache.remove(key);
      return null;
    }
    
    return cached.recommendations;
  }

  void _cacheRecommendations(String key, List<FeaturedSong> recommendations) {
    _cache[key] = CachedFeaturedRecommendations(
      recommendations: recommendations,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    // Limpiar cache antiguo (LRU simple)
    if (_cache.length > 50) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
  }

  /// 🧹 LIMPIAR CACHE
  void clearCache() {
    _cache.clear();
    debugPrint('🧹 [IntelligentFeatured] Cache limpiado');
  }

  /// 📊 OBTENER MÉTRICAS
  Map<String, dynamic> getMetrics() {
    return {
      'cacheSize': _cache.length,
      'maxStaticFeatured': _maxStaticFeatured,
      'maxDynamicRecommendations': _maxDynamicRecommendations,
      'totalFeaturedSongs': _totalFeaturedSongs,
      'cacheTtlMinutes': _cacheTtlMs / (60 * 1000),
    };
  }
}

/// 💾 MODELO PARA CACHE DE RECOMENDACIONES
class CachedFeaturedRecommendations {
  final List<FeaturedSong> recommendations;
  final int timestamp;

  CachedFeaturedRecommendations({
    required this.recommendations,
    required this.timestamp,
  });
}
