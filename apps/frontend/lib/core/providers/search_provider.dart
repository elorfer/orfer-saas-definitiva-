import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    Map<String, SearchResults>? limitedCache = cache;
    if (limitedCache != null && limitedCache.length > _maxCacheSize) {
      // Eliminar las entradas más antiguas (FIFO)
      final keysToRemove = limitedCache.keys.take(limitedCache.length - _maxCacheSize).toList();
      for (final key in keysToRemove) {
        limitedCache.remove(key);
      }
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
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  @override
  SearchState build() {
    return SearchState();
  }

  void updateQuery(String newQuery) {
    // Cancelar timer anterior
    _debounceTimer?.cancel();

    // Actualizar query inmediatamente
    state = state.copyWith(query: newQuery, error: null);

    // Si la query está vacía, limpiar resultados
    if (newQuery.trim().isEmpty) {
      state = state.copyWith(
        results: SearchResults.empty(),
        isLoading: false,
      );
      return;
    }

    // Verificar cache
    final cachedResults = state.cache[newQuery.trim().toLowerCase()];
    if (cachedResults != null) {
      AppLogger.info('[SearchNotifier] 📦 Usando resultados en caché para: "$newQuery"');
      state = state.copyWith(results: cachedResults, isLoading: false);
      return;
    }

    // Debounce: esperar antes de buscar
    _debounceTimer = Timer(_debounceDuration, () {
      _performSearch(newQuery.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    // Verificar cache nuevamente (por si cambió mientras esperábamos)
    final cachedResults = state.cache[query.toLowerCase()];
    if (cachedResults != null) {
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
      final results = await searchService.search(query, limit: 10);

      // Verificar nuevamente que la query no cambió durante la búsqueda
      if (state.query != query) {
        AppLogger.info('[SearchNotifier] ⚠️ Query cambió después de la búsqueda, ignorando resultados');
        return;
      }

      // Guardar en cache
      final newCache = Map<String, SearchResults>.from(state.cache);
      newCache[query.toLowerCase()] = results;

      state = state.copyWith(
        results: results,
        isLoading: false,
        cache: newCache,
      );

      AppLogger.info('[SearchNotifier] ✅ Búsqueda completada: ${results.artists.length} artistas, ${results.songs.length} canciones, ${results.playlists.length} playlists');
    } catch (e) {
      AppLogger.error('[SearchNotifier] ❌ Error en búsqueda: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    state = SearchState();
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(() {
  return SearchNotifier();
});

