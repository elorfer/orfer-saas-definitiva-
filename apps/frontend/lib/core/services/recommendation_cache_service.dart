import '../models/song_model.dart';
import '../utils/logger.dart';

/// 🚀 SPOTIFY-LEVEL: CACHE INTELIGENTE DE RECOMENDACIONES
/// Cachea semillas y recomendaciones para reducir latencia y llamadas HTTP
class RecommendationCacheService {
  static final RecommendationCacheService _instance = RecommendationCacheService._internal();
  factory RecommendationCacheService() => _instance;
  RecommendationCacheService._internal();

  // Cache de semillas por canción (5 minutos TTL)
  final Map<String, _CachedSeeds> _seedCache = {};
  static const int _seedCacheTtlMs = 5 * 60 * 1000; // 5 minutos

  // Cache de recomendaciones completas (3 minutos TTL)
  final Map<String, _CachedRecommendations> _recommendationCache = {};
  static const int _recommendationCacheTtlMs = 3 * 60 * 1000; // 3 minutos

  // Set global de IDs usados durante la sesión (para evitar duplicados)
  final Set<String> _usedIdsInSession = {};

  /// Obtener semillas cacheadas para una canción
  List<Song>? getCachedSeeds(String songId) {
    final cached = _seedCache[songId];
    if (cached == null) return null;

    if (DateTime.now().millisecondsSinceEpoch - cached.timestamp > _seedCacheTtlMs) {
      _seedCache.remove(songId);
      AppLogger.debug('[RecommendationCache] Cache de semillas expirado para: $songId');
      return null;
    }

    AppLogger.debug('[RecommendationCache] ✅ Cache hit de semillas para: $songId (${cached.seeds.length} semillas)');
    return cached.seeds;
  }

  /// Guardar semillas en cache
  void cacheSeeds(String songId, List<Song> seeds) {
    if (seeds.isEmpty) return;
    
    _seedCache[songId] = _CachedSeeds(
      seeds: seeds,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    AppLogger.debug('[RecommendationCache] 💾 Semillas cacheadas para: $songId (${seeds.length} semillas)');
    
    // Limpiar cache antiguo (mantener solo últimos 50)
    if (_seedCache.length > 50) {
      final sorted = _seedCache.entries.toList()
        ..sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));
      _seedCache.clear();
      for (int i = 0; i < 50 && i < sorted.length; i++) {
        _seedCache[sorted[i].key] = sorted[i].value;
      }
      AppLogger.debug('[RecommendationCache] 🧹 Cache de semillas limpiado (manteniendo 50 más recientes)');
    }
  }

  /// Obtener recomendaciones cacheadas
  List<Song>? getCachedRecommendations(String cacheKey) {
    final cached = _recommendationCache[cacheKey];
    if (cached == null) return null;

    if (DateTime.now().millisecondsSinceEpoch - cached.timestamp > _recommendationCacheTtlMs) {
      _recommendationCache.remove(cacheKey);
      AppLogger.debug('[RecommendationCache] Cache de recomendaciones expirado para: $cacheKey');
      return null;
    }

    AppLogger.debug('[RecommendationCache] ✅ Cache hit de recomendaciones para: $cacheKey (${cached.recommendations.length} canciones)');
    return cached.recommendations;
  }

  /// Guardar recomendaciones en cache
  void cacheRecommendations(String cacheKey, List<Song> recommendations) {
    if (recommendations.isEmpty) return;
    
    _recommendationCache[cacheKey] = _CachedRecommendations(
      recommendations: recommendations,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    AppLogger.debug('[RecommendationCache] 💾 Recomendaciones cacheadas para: $cacheKey (${recommendations.length} canciones)');
    
    // Limpiar cache antiguo (mantener solo últimos 100)
    if (_recommendationCache.length > 100) {
      final sorted = _recommendationCache.entries.toList()
        ..sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));
      _recommendationCache.clear();
      for (int i = 0; i < 100 && i < sorted.length; i++) {
        _recommendationCache[sorted[i].key] = sorted[i].value;
      }
      AppLogger.debug('[RecommendationCache] 🧹 Cache de recomendaciones limpiado (manteniendo 100 más recientes)');
    }
  }

  /// Verificar si un ID ya fue usado en esta sesión
  bool isIdUsed(String id) {
    return _usedIdsInSession.contains(id);
  }

  /// Marcar ID como usado
  void markIdAsUsed(String id) {
    _usedIdsInSession.add(id);
  }

  /// Marcar múltiples IDs como usados
  void markIdsAsUsed(Iterable<String> ids) {
    _usedIdsInSession.addAll(ids);
  }

  /// Limpiar IDs usados (útil para nueva sesión)
  void clearUsedIds() {
    final count = _usedIdsInSession.length;
    _usedIdsInSession.clear();
    AppLogger.debug('[RecommendationCache] 🧹 Limpiados $count IDs usados de la sesión');
  }

  /// Limpiar todo el cache
  void clearAll() {
    _seedCache.clear();
    _recommendationCache.clear();
    _usedIdsInSession.clear();
    AppLogger.info('[RecommendationCache] 🧹 Todo el cache limpiado');
  }

  /// Obtener estadísticas del cache
  Map<String, dynamic> getStats() {
    return {
      'seedCacheSize': _seedCache.length,
      'recommendationCacheSize': _recommendationCache.length,
      'usedIdsCount': _usedIdsInSession.length,
    };
  }
}

class _CachedSeeds {
  final List<Song> seeds;
  final int timestamp;

  _CachedSeeds({
    required this.seeds,
    required this.timestamp,
  });
}

class _CachedRecommendations {
  final List<Song> recommendations;
  final int timestamp;

  _CachedRecommendations({
    required this.recommendations,
    required this.timestamp,
  });
}










