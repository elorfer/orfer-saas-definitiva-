import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../services/favorites_service.dart';
import '../utils/logger.dart';

/// ESTADO DE FAVORITOS
class FavoritesState {
  final List<Song> favorites;
  final Set<String> favoriteIds;
  final bool isLoading;
  final String? error;
  final bool isInitialized;
  final int totalCount;

  const FavoritesState({
    this.favorites = const [],
    this.favoriteIds = const {},
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
    this.totalCount = 0,
  });

  bool isFavorite(String songId) => favoriteIds.contains(songId);

  FavoritesState copyWith({
    List<Song>? favorites,
    Set<String>? favoriteIds,
    bool? isLoading,
    String? error,
    bool? isInitialized,
    int? totalCount,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

/// Provider de comunicación asíncrona con el backend
final favoritesServiceProvider = Provider((ref) => FavoritesService());

/// Provider del estado de favoritos (persistente)
final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(() {
  return FavoritesNotifier();
});

/// Notifier para manejar el estado de favoritos
class FavoritesNotifier extends Notifier<FavoritesState> {
  FavoritesService? _service;
  bool _disposed = false;

  bool get isMounted => !_disposed;

  @override
  FavoritesState build() {
    // 🔥 CRÍTICO: keepAlive para persistir el estado y evitar recargas en cada navegación
    ref.keepAlive();
    ref.onDispose(() => _disposed = true);
    
    _service = ref.read(favoritesServiceProvider);
    
    // Cargar favoritos inicial (Cold Start)
    Future.microtask(() {
      if (isMounted) {
         _loadFavorites();
      }
    });
    
    return const FavoritesState(isLoading: true);
  }

  /// Cargar favoritos del usuario
  Future<void> _loadFavorites() async {
    if (!isMounted) return;
    
    try {
      if (!isMounted) return;
      
      final currentState = state;
      state = currentState.copyWith(isLoading: true, error: null);
      
      final favorites = await _service!.getMyFavorites();
      
      if (!isMounted) return;
      
      final favoriteIds = favorites.map((song) => song.id).toSet();
      
      state = state.copyWith(
        favorites: favorites,
        favoriteIds: favoriteIds,
        totalCount: favorites.length,
        isLoading: false,
        isInitialized: true,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesNotifier] Error al cargar favoritos: $e', stackTrace);
      
      if (!isMounted) return;
      
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isInitialized: true,
      );
    }
  }

  /// Recargar favoritos
  Future<void> refresh() async {
    await _loadFavorites();
  }

  /// Toggle de favorito (optimistic update)
  Future<void> toggleFavorite(String songId, {Song? songData}) async {
    try {
      final wasFavorite = state.isFavorite(songId);
      
      // ✅ Optimistic update
      if (wasFavorite) {
        final newFavorites = state.favorites.where((song) => song.id != songId).toList();
        final newFavoriteIds = Set<String>.from(state.favoriteIds)..remove(songId);
        state = state.copyWith(
          favorites: newFavorites,
          favoriteIds: newFavoriteIds,
          totalCount: newFavorites.length,
        );
      } else {
        final newFavoriteIds = Set<String>.from(state.favoriteIds)..add(songId);
        final newFavorites = List<Song>.from(state.favorites);
        
        if (songData != null && !newFavorites.any((s) => s.id == songId)) {
          newFavorites.insert(0, songData);
        }
        
        state = state.copyWith(
          favorites: newFavorites,
          favoriteIds: newFavoriteIds,
          totalCount: newFavorites.length,
        );
      }

      // Sincronizar con backend
      final isNowFavorite = await _service!.toggleFavorite(songId);
      
      if (!isMounted) return;

      if (isNowFavorite != wasFavorite) {
        // Todo OK
        if (isNowFavorite && songData == null && !state.favorites.any((s) => s.id == songId)) {
          try {
            final fetchedSong = await _service!.getSongById(songId);
            if (fetchedSong != null && isMounted) {
              if (!state.favorites.any((s) => s.id == songId)) {
                final updatedFavorites = List<Song>.from(state.favorites)..insert(0, fetchedSong);
                state = state.copyWith(favorites: updatedFavorites, totalCount: updatedFavorites.length);
              }
            }
          } catch (e) {
            AppLogger.debug('[FavoritesNotifier] No se pudo obtener canción por ID: $e');
          }
        }
      } else {
        // Revertir si hay discrepancia
        await _loadFavorites();
      }
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesNotifier] Error en toggleFavorite: $e', stackTrace);
      
      if (!isMounted) return;
      
      // Revertir cambio optimista
      await _loadFavorites();
      rethrow;
    }
  }

  /// Verificar si una canción es favorita
  bool isFavorite(String songId) => state.isFavorite(songId);
}
