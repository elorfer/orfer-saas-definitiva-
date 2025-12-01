import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/search_service.dart';
import '../utils/logger.dart';

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

class SearchState {
  final String query;
  final SearchResults? results;
  final bool isLoading;
  final String? error;
  final Map<String, SearchResults> cache; // Cache de resultados

  static const int _maxCacheSize = 20; // Limitar cache a 20 búsquedas

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
  static const Duration _debounceDuration = Duration(milliseconds: 400); // Aumentado de 300ms a 400ms para menos llamadas
  static const int _minQueryLength = 2; // Mínimo de 2 caracteres antes de buscar (optimización)
  
  // Mapa para rastrear acceso al cache (LRU)
  final Map<String, DateTime> _cacheAccessTimes = {};
  
  // CancelToken para cancelar búsquedas anteriores
  CancelToken? _currentSearchCancelToken;

  @override
  SearchState build() {
    // OPTIMIZACIÓN: Limpiar recursos cuando el provider se dispose
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _currentSearchCancelToken?.cancel();
    });
    
    return SearchState();
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
  void _cleanOldCacheEntries() {
    if (state.cache.length <= SearchState._maxCacheSize) return;
    
    // Ordenar por tiempo de acceso (más antiguas primero)
    final sortedEntries = _cacheAccessTimes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    // Eliminar las entradas más antiguas hasta llegar al límite
    final entriesToRemove = state.cache.length - SearchState._maxCacheSize;
    for (int i = 0; i < entriesToRemove && i < sortedEntries.length; i++) {
      final key = sortedEntries[i].key;
      state.cache.remove(key);
      _cacheAccessTimes.remove(key);
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    _currentSearchCancelToken?.cancel(); // OPTIMIZACIÓN: Cancelar búsqueda en progreso
    state = SearchState();
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(() {
  return SearchNotifier();
});

