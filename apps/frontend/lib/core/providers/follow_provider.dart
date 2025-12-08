import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/follow_artists_api.dart';
import '../utils/logger.dart';
import '../../features/artists/models/artist.dart';

/// Provider para el servicio de seguimiento de artistas
final followArtistsApiProvider = Provider<FollowArtistsApi>((ref) {
  return FollowArtistsApi();
});

/// Estado del seguimiento de artistas
class FollowState {
  final Set<String> followedArtistIds;
  final List<ArtistLite> followedArtists; // Lista completa de artistas
  final bool isLoading;
  final String? error;
  final DateTime? lastLoaded;

  const FollowState({
    this.followedArtistIds = const {},
    this.followedArtists = const [],
    this.isLoading = false,
    this.error,
    this.lastLoaded,
  });

  FollowState copyWith({
    Set<String>? followedArtistIds,
    List<ArtistLite>? followedArtists,
    bool? isLoading,
    String? error,
    DateTime? lastLoaded,
    bool clearError = false,
  }) {
    return FollowState(
      followedArtistIds: followedArtistIds ?? this.followedArtistIds,
      followedArtists: followedArtists ?? this.followedArtists,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastLoaded: lastLoaded ?? this.lastLoaded,
    );
  }

  bool isFollowing(String artistId) {
    return followedArtistIds.contains(artistId);
  }
}

/// Provider para el estado de seguimiento de artistas
/// ⚡ OPTIMIZACIÓN: autoDispose para liberar memoria cuando no hay listeners
final followProvider = NotifierProvider.autoDispose<FollowNotifier, FollowState>(() {
  return FollowNotifier();
});

/// Notifier para manejar el seguimiento de artistas
class FollowNotifier extends Notifier<FollowState> {
  FollowArtistsApi get _api => ref.read(followArtistsApiProvider);

  @override
  FollowState build() {
    // Cargar automáticamente al inicializar el provider (igual que favoritesProvider)
    Future.microtask(() => _loadFollowedArtistsAuto());
    return const FollowState(isLoading: true); // Empezar con loading para mostrar indicador
  }

  /// Cargar automáticamente al inicializar
  Future<void> _loadFollowedArtistsAuto() async {
    try {
      // Cargar siempre al inicializar si no hay datos cargados
      if (state.lastLoaded == null) {
        await loadFollowedArtists(force: true); // Forzar carga inicial
      } else if (state.followedArtistIds.isEmpty) {
        // Si hay timestamp pero no IDs, puede ser que se haya limpiado el estado
        await loadFollowedArtists(force: true);
      }
    } catch (e) {
      AppLogger.error('[FollowNotifier] Error en carga automática', e);
    }
  }

  /// Cargar lista de artistas seguidos
  Future<void> loadFollowedArtists({bool force = false}) async {
    // Si ya está cargando (y no es una carga forzada), no hacer nada
    if (state.isLoading && !force) return;
    
    // Si hay datos recientes (menos de 30 segundos) y no se fuerza, no recargar
    if (!force && state.lastLoaded != null && state.followedArtistIds.isNotEmpty) {
      final now = DateTime.now();
      if (now.difference(state.lastLoaded!) < const Duration(seconds: 30)) {
        return; // Datos recientes, no recargar
      }
    }

    // Actualizar estado de carga
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final artists = await _api.getMyFollowedArtists();
      final followedIds = Set<String>.from(artists.map((a) => a.id));

      // Actualizar estado con nuevos datos (crear nuevos objetos para asegurar reactividad)
      state = FollowState(
        followedArtistIds: followedIds,
        followedArtists: List<ArtistLite>.from(artists),
        isLoading: false,
        lastLoaded: DateTime.now(),
        error: null,
      );
    } catch (e) {
      AppLogger.error('[FollowNotifier] Error cargando artistas seguidos', e);
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar artistas seguidos',
      );
    }
  }

  /// Cargar automáticamente al inicializar (si no hay datos)
  Future<void> ensureLoaded() async {
    // Solo cargar si no hay datos y no está cargando actualmente
    if (state.followedArtistIds.isEmpty && !state.isLoading) {
      // Si no hay datos cargados nunca, o si los datos son muy antiguos (más de 5 minutos)
      final shouldLoad = state.lastLoaded == null || 
          (state.lastLoaded != null && 
           DateTime.now().difference(state.lastLoaded!) > const Duration(minutes: 5));
      
      if (shouldLoad) {
        await loadFollowedArtists();
      }
    }
  }

  /// Seguir un artista
  Future<void> followArtist(String artistId) async {
    // Optimistic update: agregar inmediatamente al set y lista
    final newSet = Set<String>.from(state.followedArtistIds)..add(artistId);
    
    // Crear nuevo estado para asegurar reactividad
    state = FollowState(
      followedArtistIds: newSet,
      followedArtists: List<ArtistLite>.from(state.followedArtists),
      isLoading: state.isLoading,
      lastLoaded: state.lastLoaded,
      error: null,
    );

    try {
      final response = await _api.followArtist(artistId);
      
      // Verificar respuesta del servidor
      final isFollowing = response['isFollowing'] as bool? ?? true;
      if (!isFollowing) {
        // Si el servidor dice que no está siguiendo, revertir el cambio optimista
        final revertedSet = Set<String>.from(state.followedArtistIds)..remove(artistId);
        state = FollowState(
          followedArtistIds: revertedSet,
          followedArtists: List<ArtistLite>.from(state.followedArtists),
          isLoading: state.isLoading,
          lastLoaded: state.lastLoaded,
          error: null,
        );
        return;
      }

      // Si la respuesta incluye el artista actualizado, agregarlo a la lista
      final artistData = response['artist'] as Map<String, dynamic>?;
      if (artistData != null) {
        final artist = ArtistLite.fromJson(artistData);
        final updatedArtists = List<ArtistLite>.from(state.followedArtists);
        // Solo agregar si no existe ya
        if (!updatedArtists.any((a) => a.id == artistId)) {
          updatedArtists.add(artist);
        }
        state = FollowState(
          followedArtistIds: Set<String>.from(state.followedArtistIds),
          followedArtists: updatedArtists,
          isLoading: state.isLoading,
          lastLoaded: state.lastLoaded,
          error: null,
        );
      }
    } catch (e) {
      AppLogger.error('[FollowNotifier] Error siguiendo artista $artistId', e);
      
      // Revertir cambio optimista en caso de error
      final revertedSet = Set<String>.from(state.followedArtistIds)..remove(artistId);
      state = FollowState(
        followedArtistIds: revertedSet,
        followedArtists: List<ArtistLite>.from(state.followedArtists),
        isLoading: state.isLoading,
        lastLoaded: state.lastLoaded,
        error: 'Error al seguir artista',
      );
      rethrow;
    }
  }

  /// Dejar de seguir un artista
  Future<void> unfollowArtist(String artistId) async {
    // Optimistic update: eliminar inmediatamente del set y de la lista
    final newSet = Set<String>.from(state.followedArtistIds)..remove(artistId);
    final updatedArtists = List<ArtistLite>.from(
      state.followedArtists.where((a) => a.id != artistId),
    );
    
    // Crear nuevo estado para asegurar reactividad
    state = FollowState(
      followedArtistIds: newSet,
      followedArtists: updatedArtists,
      isLoading: state.isLoading,
      lastLoaded: state.lastLoaded,
      error: null,
    );

    try {
      final response = await _api.unfollowArtist(artistId);
      
      // Verificar respuesta del servidor
      final isFollowing = response['isFollowing'] as bool? ?? false;
      if (isFollowing) {
        // Si el servidor dice que sigue siguiendo, recargar lista completa
        await loadFollowedArtists(force: true);
      }
    } catch (e) {
      AppLogger.error('[FollowNotifier] Error dejando de seguir artista $artistId', e);
      
      // Recargar lista completa para restaurar estado en caso de error
      await loadFollowedArtists(force: true);
      rethrow;
    }
  }

  /// Verificar si está siguiendo un artista (con caché local)
  bool isFollowing(String artistId) {
    return state.isFollowing(artistId);
  }

  /// Verificar si está siguiendo un artista (con verificación en servidor)
  Future<bool> checkIsFollowing(String artistId) async {
    try {
      return await _api.isFollowing(artistId);
    } catch (e) {
      AppLogger.error('[FollowNotifier] Error verificando seguimiento', e);
      // En caso de error, usar caché local
      return state.isFollowing(artistId);
    }
  }

  /// Sincronizar estado local con servidor para un artista específico
  Future<void> syncArtistStatus(String artistId) async {
    try {
      final isFollowing = await _api.isFollowing(artistId);
      final currentSet = Set<String>.from(state.followedArtistIds);
      
      if (isFollowing) {
        currentSet.add(artistId);
      } else {
        currentSet.remove(artistId);
      }
      
      state = state.copyWith(followedArtistIds: currentSet);
    } catch (e) {
      AppLogger.error('[FollowNotifier] Error sincronizando estado de artista $artistId', e);
    }
  }

  /// Limpiar el estado (útil al cerrar sesión)
  void clear() {
    state = const FollowState();
  }
}

