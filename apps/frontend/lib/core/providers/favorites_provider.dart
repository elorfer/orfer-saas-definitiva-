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

/// Provider del estado de favoritos (persistente)
final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(() {
  return FavoritesNotifier();
});

/// Notifier para manejar el estado de favoritos
class FavoritesNotifier extends Notifier<FavoritesState> {
  FavoritesService? _service;

  @override
  FavoritesState build() {
    _service = ref.read(favoritesServiceProvider);
    // Cargar favoritos después de que el build haya completado
    // Usar un delay más largo para asegurar que el provider esté completamente inicializado
    // y que el estado esté disponible antes de intentar accederlo
    Future.delayed(const Duration(milliseconds: 200), () {
      if (ref.mounted) {
        _loadFavorites();
      }
    });
    return const FavoritesState(isLoading: true);
  }

  /// Cargar favoritos del usuario
  Future<void> _loadFavorites() async {
    // Verificar que el provider esté montado antes de hacer cualquier cosa
    if (!ref.mounted) return;
    
    try {
      // Solo actualizar si el provider está montado
      if (!ref.mounted) return;
      
      // Capturar el estado actual de forma segura
      final currentState = state;
      state = currentState.copyWith(isLoading: true, error: null);
      
      // 🚨 OPERACIÓN ASÍNCRONA: Llamada al servicio
      final favorites = await _service!.getMyFavorites();
      
      // 🚨 CRÍTICO: Verificar si el provider sigue montado después del await
      // Si el usuario navegó fuera de la pantalla durante la espera, salir
      if (!ref.mounted) {
        AppLogger.debug('[FavoritesNotifier] Provider disposed, ignorando resultado de _loadFavorites');
        return;
      }
      
      final favoriteIds = favorites.map((song) => song.id).toSet();
      
      // 🚨 Verificar nuevamente antes de actualizar el estado
      if (!ref.mounted) return;
      
      state = state.copyWith(
        favorites: favorites,
        favoriteIds: favoriteIds,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesNotifier] Error al cargar favoritos: $e', stackTrace);
      
      // 🚨 CRÍTICO: Verificar si el provider sigue montado antes de actualizar el estado de error
      if (!ref.mounted) {
        AppLogger.debug('[FavoritesNotifier] Provider disposed, ignorando error de _loadFavorites');
        return;
      }
      
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
      
      // 🚨 CRÍTICO: Verificar si el provider sigue montado después del await
      if (!ref.mounted) return;

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
      
      // 🚨 CRÍTICO: Verificar si el provider sigue montado antes de revertir
      if (!ref.mounted) return;
      
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

