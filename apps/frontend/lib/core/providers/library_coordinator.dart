import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../../features/artists/models/artist.dart';
import 'favorites_provider.dart';
import 'follow_provider.dart';
import 'play_history_provider.dart';
import 'saved_playlists_provider.dart';
import '../models/playlist_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎯 LIBRARY COORDINATOR - ARQUITECTURA EVENT-DRIVEN
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Este coordinador centraliza la gestión de estado de la Biblioteca:
/// - Sincronización transversal entre providers (Favorites, Follow, History)
/// - Estrategia Offline-First con Hive para datos persistentes
/// - Eventos reactivos para actualización instantánea de UI
/// - Cache inteligente con TTL y LRU
/// ═══════════════════════════════════════════════════════════════════════════

/// Estado unificado de la biblioteca
class LibraryState {
  final List<Song> recentlyPlayed;
  final List<Song> favorites;
  final List<ArtistLite> followedArtists;
  final List<Playlist> savedPlaylists; // ✅ NUEVO
  final Set<String> favoriteIds;
  final Set<String> followedArtistIds;
  final Set<String> savedPlaylistIds; // ✅ NUEVO
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final DateTime? lastSyncTime;
  final LibrarySyncStatus syncStatus;

  const LibraryState({
    this.recentlyPlayed = const [],
    this.favorites = const [],
    this.followedArtists = const [],
    this.savedPlaylists = const [], // ✅ NUEVO
    this.favoriteIds = const {},
    this.followedArtistIds = const {},
    this.savedPlaylistIds = const {}, // ✅ NUEVO
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastSyncTime,
    this.syncStatus = LibrarySyncStatus.idle,
  });

  LibraryState copyWith({
    List<Song>? recentlyPlayed,
    List<Song>? favorites,
    List<ArtistLite>? followedArtists,
    List<Playlist>? savedPlaylists, // ✅ NUEVO
    Set<String>? favoriteIds,
    Set<String>? followedArtistIds,
    Set<String>? savedPlaylistIds, // ✅ NUEVO
    bool? isLoading,
    bool? isSyncing,
    String? error,
    DateTime? lastSyncTime,
    LibrarySyncStatus? syncStatus,
    bool clearError = false,
  }) {
    return LibraryState(
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      favorites: favorites ?? this.favorites,
      followedArtists: followedArtists ?? this.followedArtists,
      savedPlaylists: savedPlaylists ?? this.savedPlaylists, // ✅ NUEVO
      favoriteIds: favoriteIds ?? this.favoriteIds,
      followedArtistIds: followedArtistIds ?? this.followedArtistIds,
      savedPlaylistIds: savedPlaylistIds ?? this.savedPlaylistIds, // ✅ NUEVO
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Verificar si una canción es favorita
  bool isFavorite(String songId) => favoriteIds.contains(songId);

  /// Verificar si un artista está siendo seguido
  bool isFollowing(String artistId) => followedArtistIds.contains(artistId);

  /// Obtener estadísticas de la biblioteca
  LibraryStats get stats => LibraryStats(
    totalFavorites: favorites.length,
    totalFollowedArtists: followedArtists.length,
    totalRecentlyPlayed: recentlyPlayed.length,
    totalSavedPlaylists: savedPlaylists.length, // ✅ NUEVO
  );
}

/// Estado de sincronización
enum LibrarySyncStatus {
  idle,
  syncing,
  synced,
  error,
}

/// Estadísticas de la biblioteca
class LibraryStats {
  final int totalFavorites;
  final int totalFollowedArtists;
  final int totalRecentlyPlayed;
  final int totalSavedPlaylists; // ✅ NUEVO

  const LibraryStats({
    required this.totalFavorites,
    required this.totalFollowedArtists,
    required this.totalRecentlyPlayed,
    required this.totalSavedPlaylists, // ✅ NUEVO
  });
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎯 LIBRARY COORDINATOR NOTIFIER
/// ═══════════════════════════════════════════════════════════════════════════
class LibraryCoordinator extends Notifier<LibraryState> {
  // Hive boxes para persistencia offline
  static const String _recentlyPlayedBoxName = 'recently_played_v2';
  static const String _favoritesBoxName = 'favorites_cache_v2';
  static const String _followedArtistsBoxName = 'followed_artists_v2';
  
  // Configuración
  static const int _maxRecentlyPlayed = 50;
  static const Duration _syncCooldown = Duration(seconds: 30);
  static const Duration _backgroundSyncInterval = Duration(minutes: 5);

  Box<String>? _recentlyPlayedBox;
  Box<String>? _favoritesBox;
  Box<String>? _followedArtistsBox;
  
  Timer? _backgroundSyncTimer;
  bool _isInitialized = false;

  @override
  LibraryState build() {
    // 🔥 keepAlive para persistir entre cambios de pestaña
    ref.keepAlive();
    
    // Inicializar Hive y cargar datos locales
    _initializeAsync();
    
    // 🔥 SINCRONIZACIÓN TRANSVERSAL: Escuchar cambios de otros providers
    _setupCrossProviderListeners();
    
    // Limpiar recursos al dispose
    ref.onDispose(() {
      _backgroundSyncTimer?.cancel();
      _closeHiveBoxes();
    });

    return const LibraryState(isLoading: true);
  }

  /// Inicialización asíncrona (Hive + carga de datos locales)
  Future<void> _initializeAsync() async {
    if (_isInitialized) return;
    
    try {
      await _initHiveBoxes();
      await _loadLocalData();
      _isInitialized = true;
      
      // Iniciar sincronización silenciosa con backend
      _startBackgroundSync();
      
      AppLogger.info('[LibraryCoordinator] ✅ Inicializado correctamente');
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] ❌ Error en inicialización: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al inicializar biblioteca',
      );
    }
  }

  /// Inicializar Hive boxes
  Future<void> _initHiveBoxes() async {
    try {
      _recentlyPlayedBox = await Hive.openBox<String>(_recentlyPlayedBoxName);
      _favoritesBox = await Hive.openBox<String>(_favoritesBoxName);
      _followedArtistsBox = await Hive.openBox<String>(_followedArtistsBoxName);
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] Error abriendo Hive boxes: $e');
    }
  }

  /// Cerrar Hive boxes
  Future<void> _closeHiveBoxes() async {
    await _recentlyPlayedBox?.close();
    await _favoritesBox?.close();
    await _followedArtistsBox?.close();
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🔄 SINCRONIZACIÓN TRANSVERSAL (Event-Driven)
  /// ═══════════════════════════════════════════════════════════════════════
  void _setupCrossProviderListeners() {
    // 🎯 Escuchar cambios en Favorites
    ref.listen<FavoritesState>(favoritesProvider, (previous, next) {
      _onFavoritesChanged(previous, next);
    });

    // 🎯 Escuchar cambios en Follow
    ref.listen<FollowState>(followProvider, (previous, next) {
      _onFollowChanged(previous, next);
    });

    // 🎯 Escuchar cambios en Play History
    ref.listen<List<Song>>(playHistoryProvider, (previous, next) {
      _onHistoryChanged(previous, next);
    });

    // 🎯 Escuchar cambios en Saved Playlists (Likes)
    ref.listen<SavedPlaylistsState>(savedPlaylistsProvider, (previous, next) {
      _onSavedPlaylistsChanged(previous, next);
    });
  }

  /// Handler: Cambios en Favorites
  void _onFavoritesChanged(FavoritesState? previous, FavoritesState next) {
    // Solo actualizar si hay cambios reales respecto al estado actual del coordinador
    if (!_setsEqual(state.favoriteIds, next.favoriteIds) || 
        state.favorites.length != next.favorites.length) {
      
      AppLogger.info('[LibraryCoordinator] 🔄 Syncing favorites: ${next.favorites.length} items');
      
      state = state.copyWith(
        favorites: next.favorites,
        favoriteIds: next.favoriteIds,
      );
      
      // Persistir en Hive
      _saveFavoritesToLocal(next.favorites);
    }
  }

  /// Handler: Cambios en Follow
  void _onFollowChanged(FollowState? previous, FollowState next) {
    // Solo actualizar si hay cambios reales respecto al estado actual
    if (!_setsEqual(state.followedArtistIds, next.followedArtistIds) ||
        state.followedArtists.length != next.followedArtists.length) {
      
      AppLogger.info('[LibraryCoordinator] 🔄 Syncing followed artists: ${next.followedArtists.length} items');
      
      state = state.copyWith(
        followedArtists: next.followedArtists,
        followedArtistIds: next.followedArtistIds,
      );
      
      // Persistir en Hive
      _saveFollowedArtistsToLocal(next.followedArtists);
    }
  }

  /// Handler: Cambios en History
  void _onHistoryChanged(List<Song>? previous, List<Song> next) {
    AppLogger.info('[LibraryCoordinator] 📥 UPDATE: Recibidas ${next.length} canciones de PlayHistoryProvider');
    
    // 🎯 ESCUCHA SIEMPRE: PlayHistoryProvider es la fuente única de verdad
    final recentlyPlayed = next.reversed.take(_maxRecentlyPlayed).toList();
    
    AppLogger.info('[LibraryCoordinator] 🔄 Sincronizando historial (${recentlyPlayed.length} items)');
    
    // Actualizar estado local
    state = state.copyWith(recentlyPlayed: recentlyPlayed);
  }

  /// Handler: Cambios en Saved Playlists
  void _onSavedPlaylistsChanged(SavedPlaylistsState? previous, SavedPlaylistsState next) {
    // Solo actualizar si hay cambios reales respecto al estado actual
    if (!_setsEqual(state.savedPlaylistIds, next.savedIds) ||
        state.savedPlaylists.length != next.playlists.length) {
      
      AppLogger.info('[LibraryCoordinator] 🔄 Syncing saved playlists: ${next.playlists.length} items');
      
      state = state.copyWith(
        savedPlaylists: next.playlists,
        savedPlaylistIds: next.savedIds,
      );
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 💾 ESTRATEGIA OFFLINE-FIRST (Hive)
  /// ═══════════════════════════════════════════════════════════════════════
  
  /// Cargar datos locales desde Hive y sincronizar con providers actuales
  Future<void> _loadLocalData() async {
    try {
      // 1. Cargar desde Hive (Cache persistente del coordinador)
      final localRecents = await _loadRecentlyPlayedFromLocal();
      final localFavorites = await _loadFavoritesFromLocal();
      final localFollowed = await _loadFollowedArtistsFromLocal();
      
      // 2. Obtener estado actual de los providers (Fuente de Verdad)
      final favoritesState = ref.read(favoritesProvider);
      final followState = ref.read(followProvider);
      final historyList = ref.read(playHistoryProvider);
      final savedPlaylistsState = ref.read(savedPlaylistsProvider);

      // 3. Fusionar: Priorizar providers si tienen datos, si no usar Hive
      final favorites = favoritesState.favorites.isNotEmpty 
          ? favoritesState.favorites 
          : localFavorites;
          
      final followedArtists = followState.followedArtists.isNotEmpty 
          ? followState.followedArtists 
          : localFollowed;
          
      final recentlyPlayed = historyList.reversed.take(_maxRecentlyPlayed).toList();

      state = state.copyWith(
        recentlyPlayed: recentlyPlayed,
        favorites: favorites,
        favoriteIds: favorites.isEmpty && favoritesState.favoriteIds.isNotEmpty 
            ? favoritesState.favoriteIds 
            : favorites.map((s) => s.id).toSet(),
        followedArtists: followedArtists,
        followedArtistIds: followedArtists.isEmpty && followState.followedArtistIds.isNotEmpty 
            ? followState.followedArtistIds 
            : followedArtists.map((a) => a.id).toSet(),
        savedPlaylists: savedPlaylistsState.playlists,
        savedPlaylistIds: savedPlaylistsState.savedIds,
        isLoading: false,
      );

      AppLogger.info('[LibraryCoordinator] 📂 Datos locales cargados: '
          '${recentlyPlayed.length} recientes, '
          '${favorites.length} favoritos, '
          '${followedArtists.length} artistas seguidos');
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] Error cargando datos locales: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Cargar recently played desde Hive
  Future<List<Song>> _loadRecentlyPlayedFromLocal() async {
    try {
      final box = _recentlyPlayedBox;
      if (box == null || box.isEmpty) return [];

      final decodedList = <Map<String, dynamic>>[];
      for (final key in box.keys) {
        final json = box.get(key);
        if (json != null) {
          try {
            final decoded = jsonDecode(json);
            if (decoded is Map<String, dynamic>) decodedList.add(decoded);
          } catch (_) {}
        }
      }

      if (decodedList.isEmpty) return [];

      try {
        return await Song.parseList(decodedList);
      } catch (_) {
        // Fallback a parsing individual si el batch falla
        final songs = <Song>[];
        for (final m in decodedList) {
          try {
            songs.add(Song.fromJson(m));
          } catch (_) {}
        }
        return songs;
      }
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] Error loading recently played: $e');
      return [];
    }
  }

  /// Cargar favorites desde Hive
  Future<List<Song>> _loadFavoritesFromLocal() async {
    try {
      final box = _favoritesBox;
      if (box == null || box.isEmpty) return [];

      final decodedList = <Map<String, dynamic>>[];
      for (final key in box.keys) {
        final json = box.get(key);
        if (json != null) {
          try {
            final decoded = jsonDecode(json);
            if (decoded is Map<String, dynamic>) decodedList.add(decoded);
          } catch (_) {}
        }
      }

      if (decodedList.isEmpty) return [];

      try {
        return await Song.parseList(decodedList);
      } catch (_) {
        final songs = <Song>[];
        for (final m in decodedList) {
          try {
            songs.add(Song.fromJson(m));
          } catch (_) {}
        }
        return songs;
      }
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] Error loading favorites: $e');
      return [];
    }
  }

  /// Cargar followed artists desde Hive
  Future<List<ArtistLite>> _loadFollowedArtistsFromLocal() async {
    try {
      final box = _followedArtistsBox;
      if (box == null || box.isEmpty) return [];

      final artists = <ArtistLite>[];
      for (final key in box.keys) {
        final json = box.get(key);
        if (json != null) {
          try {
            artists.add(ArtistLite.fromJson(jsonDecode(json)));
          } catch (_) {}
        }
      }
      return artists;
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] Error loading followed artists: $e');
      return [];
    }
  }

  /// Guardar recently played en Hive
  Future<void> _saveRecentlyPlayedToLocal(List<Song> songs) async {
    try {
      final box = _recentlyPlayedBox;
      if (box == null) return;

      await box.clear();
      for (int i = 0; i < songs.length; i++) {
        await box.put('song_$i', jsonEncode(songs[i].toJson()));
      }
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] Error saving recently played: $e');
    }
  }

  /// Guardar favorites en Hive
  Future<void> _saveFavoritesToLocal(List<Song> songs) async {
    try {
      final box = _favoritesBox;
      if (box == null) return;

      await box.clear();
      for (final song in songs) {
        await box.put(song.id, jsonEncode(song.toJson()));
      }
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] Error saving favorites: $e');
    }
  }

  /// Guardar followed artists en Hive
  Future<void> _saveFollowedArtistsToLocal(List<ArtistLite> artists) async {
    try {
      final box = _followedArtistsBox;
      if (box == null) return;

      await box.clear();
      for (final artist in artists) {
        await box.put(artist.id, jsonEncode(artist.toJson()));
      }
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] Error saving followed artists: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🔄 SINCRONIZACIÓN EN BACKGROUND
  /// ═══════════════════════════════════════════════════════════════════════
  
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(_backgroundSyncInterval, (_) {
      _performBackgroundSync();
    });
    
    // Primera sincronización inmediata
    _performBackgroundSync();
  }

  Future<void> _performBackgroundSync() async {
    // Verificar cooldown
    if (state.lastSyncTime != null) {
      final elapsed = DateTime.now().difference(state.lastSyncTime!);
      if (elapsed < _syncCooldown) return;
    }

    state = state.copyWith(isSyncing: true, syncStatus: LibrarySyncStatus.syncing);

    try {
      // Sincronizar desde los providers originales (que hablan con el backend)
      // Esto asegura que los datos estén actualizados sin duplicar llamadas
      
      // Los providers ya tienen sus propios mecanismos de carga
      // Solo necesitamos "tocar" el estado para que recarguen si es necesario
      ref.read(favoritesProvider.notifier).refresh();
      ref.read(followProvider.notifier).loadFollowedArtists();

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        syncStatus: LibrarySyncStatus.synced,
        clearError: true,
      );

      AppLogger.info('[LibraryCoordinator] ✅ Sincronización en background completada');
    } catch (e) {
      AppLogger.error('[LibraryCoordinator] ❌ Error en sincronización: $e');
      state = state.copyWith(
        isSyncing: false,
        syncStatus: LibrarySyncStatus.error,
        error: 'Error de sincronización',
      );
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🎯 API PÚBLICA
  /// ═══════════════════════════════════════════════════════════════════════

  /// Forzar sincronización con backend
  Future<void> forceSync() async {
    state = state.copyWith(lastSyncTime: null); // Reset cooldown
    await _performBackgroundSync();
  }

  /// Refrescar todos los datos
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadLocalData();
    await forceSync();
  }

  /// Limpiar todos los datos locales (logout)
  Future<void> clearAll() async {
    await _recentlyPlayedBox?.clear();
    await _favoritesBox?.clear();
    await _followedArtistsBox?.clear();
    state = const LibraryState();
  }

  /// Verificar si una canción es favorita (desde cache local)
  bool isFavorite(String songId) => state.isFavorite(songId);

  /// Verificar si un artista está siendo seguido (desde cache local)
  bool isFollowing(String artistId) => state.isFollowing(artistId);

  /// Helper para comparar sets
  bool _setsEqual<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎯 PROVIDERS
/// ═══════════════════════════════════════════════════════════════════════════

/// Provider principal del Library Coordinator
final libraryCoordinatorProvider = NotifierProvider<LibraryCoordinator, LibraryState>(() {
  return LibraryCoordinator();
});

/// Providers derivados optimizados para UI (evitan rebuilds innecesarios)
final libraryRecentlyPlayedProvider = Provider<List<Song>>((ref) {
  return ref.watch(libraryCoordinatorProvider.select((s) => s.recentlyPlayed));
});

final libraryFavoritesProvider = Provider<List<Song>>((ref) {
  return ref.watch(libraryCoordinatorProvider.select((s) => s.favorites));
});

final libraryFollowedArtistsProvider = Provider<List<ArtistLite>>((ref) {
  return ref.watch(libraryCoordinatorProvider.select((s) => s.followedArtists));
});

final libraryStatsProvider = Provider<LibraryStats>((ref) {
  return ref.watch(libraryCoordinatorProvider.select((s) => s.stats));
});

final libraryIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(libraryCoordinatorProvider.select((s) => s.isLoading));
});

final libraryIsSyncingProvider = Provider<bool>((ref) {
  return ref.watch(libraryCoordinatorProvider.select((s) => s.isSyncing));
});
