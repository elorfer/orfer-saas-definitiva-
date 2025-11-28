import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../services/favorites_service.dart';
import '../utils/logger.dart';

/// Estado de favoritos
class FavoritesState {
  final List<Song> favorites;
  final Set<String> favoriteIds; // Para búsqueda rápida
  final bool isLoading;
  final String? error;

  const FavoritesState({
    this.favorites = const [],
    Set<String>? favoriteIds,
    this.isLoading = false,
    this.error,
  }) : favoriteIds = favoriteIds ?? const {};

  FavoritesState copyWith({
    List<Song>? favorites,
    Set<String>? favoriteIds,
    bool? isLoading,
    String? error,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool isFavorite(String songId) {
    return favoriteIds.contains(songId);
  }
}

/// Provider del servicio de favoritos
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService();
});

/// Provider del estado de favoritos
final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(() {
  return FavoritesNotifier();
});

/// Notifier para manejar el estado de favoritos
class FavoritesNotifier extends Notifier<FavoritesState> {
  FavoritesService? _service;

  @override
  FavoritesState build() {
    _service = ref.read(favoritesServiceProvider);
    // Cargar favoritos automáticamente
    Future.microtask(() => _loadFavorites());
    return const FavoritesState(isLoading: true);
  }

  /// Cargar favoritos del usuario
  Future<void> _loadFavorites() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final favorites = await _service!.getMyFavorites();
      final favoriteIds = favorites.map((song) => song.id).toSet();
      
      state = state.copyWith(
        favorites: favorites,
        favoriteIds: favoriteIds,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesNotifier] Error al cargar favoritos: $e', stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Recargar favoritos
  Future<void> refresh() async {
    await _loadFavorites();
  }

  /// Toggle de favorito (optimistic update)
  Future<void> toggleFavorite(String songId) async {
    try {
      final wasFavorite = state.isFavorite(songId);
      
      // Optimistic update: actualizar UI inmediatamente
      if (wasFavorite) {
        // Remover de favoritos
        final newFavorites = state.favorites.where((song) => song.id != songId).toList();
        final newFavoriteIds = Set<String>.from(state.favoriteIds)..remove(songId);
        state = state.copyWith(
          favorites: newFavorites,
          favoriteIds: newFavoriteIds,
        );
      } else {
        // Agregar a favoritos (necesitamos la canción completa)
        // Por ahora solo agregamos el ID, luego se actualizará cuando se recargue
        final newFavoriteIds = Set<String>.from(state.favoriteIds)..add(songId);
        state = state.copyWith(favoriteIds: newFavoriteIds);
      }

      // Llamar al backend
      final isNowFavorite = await _service!.toggleFavorite(songId);

      // Si el backend confirma, actualizar estado final
      if (isNowFavorite != wasFavorite) {
        // El estado ya está actualizado optimísticamente
        // Si necesitamos recargar la lista completa, lo hacemos aquí
        if (isNowFavorite) {
          // Recargar para obtener la canción completa
          await _loadFavorites();
        }
      } else {
        // Si hay discrepancia, revertir y recargar
        await _loadFavorites();
      }
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesNotifier] Error en toggleFavorite: $e', stackTrace);
      
      // Revertir optimistic update en caso de error
      await _loadFavorites();
      
      // Re-lanzar el error para que el UI pueda manejarlo
      rethrow;
    }
  }

  /// Verificar si una canción es favorita
  bool isFavorite(String songId) {
    return state.isFavorite(songId);
  }
}

