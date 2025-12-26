import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/search_service.dart';
import '../utils/logger.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/genre_model.dart';

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

class SearchState {
  final String query;
  final SearchResults? results;
  final bool isLoading;
  final String? error;
  final Map<String, SearchResults> cache; // Cache de resultados

  // 🔥 OPTIMIZACIÓN RAM: Límite reducido para evitar saturación de memoria
  static const int _maxCacheSize = 10; // Reducido de 20 a 10 búsquedas
  
  // 🔥 OPTIMIZACIÓN RAM: TTL para expirar entradas antiguas (5 minutos)
  static const Duration cacheTtl = Duration(minutes: 5);

  SearchState({
    this.query = '',
    this.results,
    this.isLoading = false,
    this.error,
    Map<String, SearchResults>? cache,
  }) : cache = cache ?? {};

  SearchState copyWith({
    String? query,
    SearchResults? results,
    bool? isLoading,
    String? error,
    Map<String, SearchResults>? cache,
  }) {
    // Limitar tamaño del cache para evitar memory leaks
    // OPTIMIZACIÓN: Usar LRU (Least Recently Used) en lugar de FIFO
    Map<String, SearchResults>? limitedCache = cache;
    if (limitedCache != null && limitedCache.length > _maxCacheSize) {
      // No hacer nada aquí, la limpieza LRU se hace en el notifier
      // Esto evita crear una nueva lista innecesariamente
    }

    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      cache: limitedCache ?? this.cache,
    );
  }

  bool get isEmpty => query.isEmpty || (results?.isEmpty ?? true);
}

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounceTimer;
  Timer? _cacheCleanupTimer; // 🔥 Timer para limpieza periódica del cache
  static const Duration _debounceDuration = Duration(milliseconds: 400); // Aumentado de 300ms a 400ms para menos llamadas
  static const int _minQueryLength = 2; // Mínimo de 2 caracteres antes de buscar (optimización)
  
  // Mapa para rastrear acceso al cache (LRU) con timestamps
  final Map<String, DateTime> _cacheAccessTimes = {};
  
  // CancelToken para cancelar búsquedas anteriores
  CancelToken? _currentSearchCancelToken;

  @override
  SearchState build() {
    // 🔥 CRÍTICO: keepAlive para evitar destrucción al cambiar de pestaña
    // Esto mantiene los resultados de búsqueda y evita parpadeos
    ref.keepAlive();
    
    // 🔥 OPTIMIZACIÓN RAM: Iniciar limpieza periódica del cache cada 2 minutos
    _startPeriodicCacheCleanup();
    
    // OPTIMIZACIÓN: Limpiar recursos cuando el provider se dispose
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _cacheCleanupTimer?.cancel();
      _currentSearchCancelToken?.cancel();
      _cacheAccessTimes.clear(); // Limpiar tiempos de acceso
    });
    
    return SearchState();
  }
  
  /// 🔥 OPTIMIZACIÓN RAM: Limpieza periódica del cache para evitar saturación
  void _startPeriodicCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _cleanExpiredCacheEntries();
    });
  }
  
  /// 🔥 OPTIMIZACIÓN RAM: Eliminar entradas expiradas por TTL
  void _cleanExpiredCacheEntries() {
    if (state.cache.isEmpty) return;
    
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    // Identificar entradas expiradas
    for (final entry in _cacheAccessTimes.entries) {
      if (now.difference(entry.value) > SearchState.cacheTtl) {
        expiredKeys.add(entry.key);
      }
    }
    
    if (expiredKeys.isEmpty) return;
    
    // Crear nuevo cache sin las entradas expiradas
    final newCache = Map<String, SearchResults>.from(state.cache);
    for (final key in expiredKeys) {
      newCache.remove(key);
      _cacheAccessTimes.remove(key);
    }
    
    // Actualizar estado solo si hubo cambios
    if (expiredKeys.isNotEmpty) {
      state = state.copyWith(cache: newCache);
      AppLogger.info('[SearchNotifier] 🧹 Limpieza de cache: ${expiredKeys.length} entradas expiradas eliminadas');
    }
  }

  void updateQuery(String newQuery) {
    // Cancelar timer anterior
    _debounceTimer?.cancel();

    // Actualizar query inmediatamente
    state = state.copyWith(query: newQuery, error: null);

    final trimmedQuery = newQuery.trim();
    
    // Si la query está vacía, limpiar resultados
    if (trimmedQuery.isEmpty) {
      state = state.copyWith(
        results: SearchResults.empty(),
        isLoading: false,
      );
      return;
    }

    // OPTIMIZACIÓN: No buscar si tiene menos del mínimo de caracteres
    if (trimmedQuery.length < _minQueryLength) {
      state = state.copyWith(
        results: SearchResults.empty(),
        isLoading: false,
      );
      return;
    }

    // Verificar cache
    final cacheKey = trimmedQuery.toLowerCase();
    final cachedResults = state.cache[cacheKey];
    if (cachedResults != null) {
      // Actualizar tiempo de acceso para LRU
      _cacheAccessTimes[cacheKey] = DateTime.now();
      AppLogger.info('[SearchNotifier] 📦 Usando resultados en caché para: "$trimmedQuery"');
      state = state.copyWith(results: cachedResults, isLoading: false);
      return;
    }

    // Debounce: esperar antes de buscar
    _debounceTimer = Timer(_debounceDuration, () {
      _performSearch(trimmedQuery);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty || query.length < _minQueryLength) return;

    // OPTIMIZACIÓN: Cancelar búsqueda anterior si existe
    _currentSearchCancelToken?.cancel();
    _currentSearchCancelToken = CancelToken();

    // Verificar cache nuevamente (por si cambió mientras esperábamos)
    final cacheKey = query.toLowerCase();
    final cachedResults = state.cache[cacheKey];
    if (cachedResults != null) {
      // Actualizar tiempo de acceso para LRU
      _cacheAccessTimes[cacheKey] = DateTime.now();
      state = state.copyWith(results: cachedResults, isLoading: false);
      return;
    }

    // Verificar que la query actual sigue siendo la misma
    if (state.query != query) {
      AppLogger.info('[SearchNotifier] ⚠️ Query cambió durante la búsqueda, cancelando');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final searchService = ref.read(searchServiceProvider);
      final results = await searchService.search(query, limit: 10, cancelToken: _currentSearchCancelToken);

      // Verificar nuevamente que la query no cambió durante la búsqueda
      if (state.query != query) {
        AppLogger.info('[SearchNotifier] ⚠️ Query cambió después de la búsqueda, ignorando resultados');
        return;
      }

      // OPTIMIZACIÓN: Limpiar cache LRU antes de agregar nueva entrada
      _cleanOldCacheEntries();

      // Guardar en cache con LRU
      final newCache = Map<String, SearchResults>.from(state.cache);
      newCache[cacheKey] = results;
      _cacheAccessTimes[cacheKey] = DateTime.now();

      state = state.copyWith(
        results: results,
        isLoading: false,
        cache: newCache,
      );

      AppLogger.info('[SearchNotifier] ✅ Búsqueda completada: ${results.artists.length} artistas, ${results.songs.length} canciones, ${results.playlists.length} playlists');
    } catch (e) {
      // Ignorar errores de cancelación
      if (e is! Exception || !e.toString().contains('cancel')) {
        AppLogger.error('[SearchNotifier] ❌ Error en búsqueda: $e');
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }
  
  /// Limpia entradas antiguas del cache usando LRU (Least Recently Used)
  /// 🔥 OPTIMIZACIÓN RAM: Limpieza más agresiva para evitar saturación
  void _cleanOldCacheEntries() {
    // Primero limpiar entradas expiradas por TTL
    _cleanExpiredCacheEntries();
    
    // Si aún excede el límite, aplicar LRU
    if (state.cache.length <= SearchState._maxCacheSize) return;
    
    // Ordenar por tiempo de acceso (más antiguas primero)
    final sortedEntries = _cacheAccessTimes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    // Eliminar las entradas más antiguas hasta llegar al límite
    // 🔥 OPTIMIZACIÓN: Dejar espacio extra (límite - 2) para evitar limpiezas frecuentes
    final targetSize = SearchState._maxCacheSize - 2;
    final entriesToRemove = state.cache.length - targetSize;
    
    final newCache = Map<String, SearchResults>.from(state.cache);
    for (int i = 0; i < entriesToRemove && i < sortedEntries.length; i++) {
      final key = sortedEntries[i].key;
      newCache.remove(key);
      _cacheAccessTimes.remove(key);
    }
    
    state = state.copyWith(cache: newCache);
    AppLogger.info('[SearchNotifier] 🧹 LRU cleanup: $entriesToRemove entradas eliminadas, quedan ${newCache.length}');
  }

  /// 🔥 OPTIMIZACIÓN RAM: Limpiar completamente el cache y liberar memoria
  void clear() {
    _debounceTimer?.cancel();
    _currentSearchCancelToken?.cancel(); // OPTIMIZACIÓN: Cancelar búsqueda en progreso
    _cacheAccessTimes.clear(); // Limpiar tiempos de acceso
    state = SearchState(); // Estado completamente nuevo (cache vacío)
    AppLogger.info('[SearchNotifier] 🧹 Cache de búsqueda completamente limpiado');
  }
  
  /// 🔥 OPTIMIZACIÓN RAM: Limpiar solo el cache manteniendo la query actual
  /// Útil cuando el usuario quiere liberar memoria sin perder su búsqueda actual
  void clearCacheOnly() {
    final currentResults = state.results;
    final currentQuery = state.query;
    _cacheAccessTimes.clear();
    state = SearchState(
      query: currentQuery,
      results: currentResults,
      isLoading: false,
      cache: {}, // Cache vacío
    );
    AppLogger.info('[SearchNotifier] 🧹 Cache limpiado, resultados actuales preservados');
  }
}

/// ⚡ OPTIMIZACIÓN: NO usar autoDispose porque SearchScreen es pantalla principal
/// Necesitamos mantener el estado de búsqueda incluso cuando no está visible
final searchProvider = NotifierProvider<SearchNotifier, SearchState>(() {
  return SearchNotifier();
});

/// ✅ OPTIMIZADO: Provider para artistas trending/destacados con keepAlive
/// Mantiene datos en memoria permanentemente y no se recarga al volver
final trendingArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  ref.keepAlive(); // ✅ Mantener en memoria permanentemente
  final searchService = ref.read(searchServiceProvider);
  return await searchService.getTrendingArtists(limit: 6); // ✅ Reducido de 10 a 6 para carga más rápida
});

/// ✅ OPTIMIZADO: Provider para canciones top/populares con keepAlive
/// Mantiene datos en memoria permanentemente para evitar skeletons al volver
final topSongsProvider = FutureProvider<List<Song>>((ref) async {
  ref.keepAlive(); // ✅ Mantener en memoria permanentemente
  final searchService = ref.read(searchServiceProvider);
  return await searchService.getTopSongs(limit: 8);
});

/// ✅ OPTIMIZADO: Provider para todos los géneros con keepAlive
/// Mantiene datos en memoria permanentemente para evitar skeletons al volver
final allGenresProvider = FutureProvider<List<Genre>>((ref) async {
  ref.keepAlive(); // ✅ Mantener en memoria permanentemente
  final searchService = ref.read(searchServiceProvider);
  return await searchService.getAllGenres();
});

