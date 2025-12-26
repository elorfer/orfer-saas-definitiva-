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
  Future<void> toggleFavorite(String songId, {Song? songData}) async {
    try {
      final wasFavorite = state.isFavorite(songId);
      
      // ✅ OPTIMIZACIÓN: Optimistic update INMEDIATAMENTE - actualizar UI sin esperar
      if (wasFavorite) {
        // Remover de favoritos
        final newFavorites = state.favorites.where((song) => song.id != songId).toList();
        final newFavoriteIds = Set<String>.from(state.favoriteIds)..remove(songId);
        state = state.copyWith(
          favorites: newFavorites,
          favoriteIds: newFavoriteIds,
        );
      } else {
        // Agregar a favoritos
        final newFavoriteIds = Set<String>.from(state.favoriteIds)..add(songId);
        final newFavorites = List<Song>.from(state.favorites);
        
        // ✅ CRÍTICO: Si tenemos los datos de la canción, agregarla a la lista completa
        // Esto asegura que aparezca inmediatamente en la pantalla de favoritos
        if (songData != null && !newFavorites.any((s) => s.id == songId)) {
          newFavorites.add(songData);
        }
        
        state = state.copyWith(
          favorites: newFavorites,
          favoriteIds: newFavoriteIds,
        );
      }

      // ✅ OPTIMIZACIÓN: Llamar al backend en background (no bloquear UI)
      // La UI ya se actualizó optimísticamente
      final isNowFavorite = await _service!.toggleFavorite(songId);
      
      // 🚨 CRÍTICO: Verificar si el provider sigue montado después del await
      if (!ref.mounted) return;

      // ✅ OPTIMIZACIÓN: Solo recargar si hay discrepancia (no siempre)
      // Si el backend confirma el cambio, no necesitamos recargar todo
      if (isNowFavorite != wasFavorite) {
        // El estado ya está actualizado optimísticamente
        
        // ✅ CRÍTICO: Si agregamos un favorito y no tenemos la canción completa en la lista,
        // intentar obtenerla para que aparezca en la pantalla de favoritos sin refrescar
        if (isNowFavorite && songData == null && !state.favorites.any((s) => s.id == songId)) {
          // Si no pasaron los datos de la canción y no está en la lista, intentar obtenerla
          // Esto solo es necesario para que aparezca en la pantalla de favoritos
          // Si falla, no importa - la próxima vez que se refresque aparecerá
          try {
            final fetchedSong = await _service!.getSongById(songId);
            if (fetchedSong != null && ref.mounted) {
              // Agregar la canción a la lista si todavía no está
              if (!state.favorites.any((s) => s.id == songId)) {
                final updatedFavorites = List<Song>.from(state.favorites)..add(fetchedSong);
                state = state.copyWith(favorites: updatedFavorites);
              }
            }
          } catch (e) {
            // Ignorar errores - la canción aparecerá cuando se refresque la lista
            AppLogger.debug('[FavoritesNotifier] No se pudo obtener canción por ID después de toggle: $e');
          }
        }
      } else {
        // Si hay discrepancia (raro), revertir y recargar
        AppLogger.warning('[FavoritesNotifier] Discrepancia detectada, recargando lista completa');
        await _loadFavorites();
      }
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesNotifier] Error en toggleFavorite: $e', stackTrace);
      
      // 🚨 CRÍTICO: Verificar si el provider sigue montado antes de revertir
      if (!ref.mounted) return;
      
      // ✅ OPTIMIZACIÓN: Revertir solo el cambio optimista, no recargar toda la lista
      // Recargar toda la lista es muy lento - solo revertir el cambio local
      final currentWasFavorite = state.isFavorite(songId);
      if (currentWasFavorite) {
        // Si ahora es favorito pero falló, removerlo
        final newFavoriteIds = Set<String>.from(state.favoriteIds)..remove(songId);
        final newFavorites = state.favorites.where((song) => song.id != songId).toList();
        state = state.copyWith(
          favorites: newFavorites,
          favoriteIds: newFavoriteIds,
        );
      } else {
        // Si ahora NO es favorito pero falló, agregarlo de vuelta
        final newFavoriteIds = Set<String>.from(state.favoriteIds)..add(songId);
        state = state.copyWith(favoriteIds: newFavoriteIds);
      }
      
      // Re-lanzar el error para que el UI pueda manejarlo
      rethrow;
    }
  }

  /// Verificar si una canción es favorita
  bool isFavorite(String songId) {
    return state.isFavorite(songId);
  }
}

