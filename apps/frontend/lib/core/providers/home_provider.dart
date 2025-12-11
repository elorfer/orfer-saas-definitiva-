import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/home_service.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';

/// Provider para el servicio de home
final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService();
});

/// Estado de la pantalla de inicio
class HomeState {
  final List<FeaturedArtist> featuredArtists;
  final List<FeaturedSong> featuredSongs;
  final List<FeaturedPlaylist> featuredPlaylists;
  final List<Song> popularSongs;
  final List<Artist> topArtists;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  const HomeState({
    this.featuredArtists = const [],
    this.featuredSongs = const [],
    this.featuredPlaylists = const [],
    this.popularSongs = const [],
    this.topArtists = const [],
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'featuredArtists':
          featuredArtists.map((a) => a.toJson()).toList(growable: false),
      'featuredSongs':
          featuredSongs.map((s) => s.toJson()).toList(growable: false),
      'featuredPlaylists':
          featuredPlaylists.map((p) => p.toJson()).toList(growable: false),
      'popularSongs':
          popularSongs.map((s) => s.toJson()).toList(growable: false),
      'topArtists': topArtists.map((a) => a.toJson()).toList(growable: false),
      'isLoading': isLoading,
      'error': error,
      'isInitialized': isInitialized,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static HomeState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return HomeState(
        featuredArtists: (json['featuredArtists'] as List<dynamic>?)
                ?.map((e) => FeaturedArtist.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        featuredSongs: (json['featuredSongs'] as List<dynamic>?)
                ?.map((e) => FeaturedSong.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        featuredPlaylists: (json['featuredPlaylists'] as List<dynamic>?)
                ?.map((e) => FeaturedPlaylist.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        popularSongs: (json['popularSongs'] as List<dynamic>?)
                ?.map((e) =>
                    Song.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        topArtists: (json['topArtists'] as List<dynamic>?)
                ?.map((e) =>
                    Artist.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        isLoading: json['isLoading'] as bool? ?? false,
        error: json['error'] as String?,
        isInitialized: json['isInitialized'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  HomeState copyWith({
    List<FeaturedArtist>? featuredArtists,
    List<FeaturedSong>? featuredSongs,
    List<FeaturedPlaylist>? featuredPlaylists,
    List<Song>? popularSongs,
    List<Artist>? topArtists,
    bool? isLoading,
    String? error,
    bool? isInitialized,
  }) {
    return HomeState(
      featuredArtists: featuredArtists ?? this.featuredArtists,
      featuredSongs: featuredSongs ?? this.featuredSongs,
      featuredPlaylists: featuredPlaylists ?? this.featuredPlaylists,
      popularSongs: popularSongs ?? this.popularSongs,
      topArtists: topArtists ?? this.topArtists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  bool get hasError => error != null;
  bool get isEmpty => featuredArtists.isEmpty && featuredSongs.isEmpty && featuredPlaylists.isEmpty;
}

/// Notifier para manejar el estado de la pantalla de inicio
class HomeNotifier extends Notifier<HomeState> {
  late final HomeService _homeService;
  static const String _cacheKey = 'home_state_cache_v1';
  // TTL del cache local para hidratar el home en arranque frío
  static const Duration _cacheTtl = Duration(minutes: 4);
  bool _hasLoadedCache = false;

  @override
  HomeState build() {
    _homeService = ref.read(homeServiceProvider);
    // Inicializar de forma asíncrona y rehidratar desde disco antes de ir a red
    Future.microtask(() async {
      await _loadFromCacheIfNeeded();
      await _initialize();
    });
    return const HomeState(isLoading: true);
  }

  /// Inicializar el servicio y cargar datos
  Future<void> _initialize() async {
    try {
      await _homeService.initialize();
      await loadHomeData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al inicializar: $e',
        isInitialized: true,
      );
    }
  }

  /// Cargar todos los datos de la pantalla de inicio
  Future<void> loadHomeData({bool forceRefresh = false}) async {
    try {
      // Mantener datos actuales para evitar parpadeos; solo marcar loading
      state = state.copyWith(isLoading: true, error: null);

      // Cargar datos individualmente para manejar errores por separado
      List<FeaturedArtist> featuredArtists = [];
      List<FeaturedSong> featuredSongs = [];
      List<FeaturedPlaylist> featuredPlaylists = [];
      List<Song> popularSongs = [];
      List<Artist> topArtists = [];

      // Cargar datos en paralelo para mejor rendimiento
      await Future.wait([
        // Artistas destacados (✅ OPTIMIZACIÓN: pasar forceRefresh para respetar cache)
        _homeService.getFeaturedArtists(limit: 6, forceRefresh: forceRefresh).then((value) => featuredArtists = value).catchError((_) => <FeaturedArtist>[]),
        // Canciones destacadas
        _homeService.getFeaturedSongs(limit: 20, forceRefresh: forceRefresh).then((value) => featuredSongs = value).catchError((_) => <FeaturedSong>[]),
        // Playlists destacadas
        _homeService.getFeaturedPlaylists(limit: 6).then((value) => featuredPlaylists = value).catchError((_) => <FeaturedPlaylist>[]),
        // Canciones populares (error silencioso si falla)
        _homeService.getPopularSongs(limit: 10).then((value) => popularSongs = value).catchError((_) => <Song>[]),
        // Artistas top
        _homeService.getTopArtists(limit: 8).then((value) => topArtists = value).catchError((_) => <Artist>[]),
      ]);

      state = state.copyWith(
        featuredArtists: featuredArtists,
        featuredSongs: featuredSongs,
        featuredPlaylists: featuredPlaylists,
        popularSongs: popularSongs,
        topArtists: topArtists,
        isLoading: false,
        error: null,
        isInitialized: true,
      );
      // Guardar en cache para arranque en frío
      await _saveToCache(state);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar datos: $e',
        isInitialized: true,
      );
    }
  }

  /// Refrescar datos (forzar refresh sin caché)
  Future<void> refresh() async {
    await loadHomeData(forceRefresh: true);
  }

  /// Cargar solo artistas destacados
  Future<void> loadFeaturedArtists() async {
    try {
      final artists = await _homeService.getFeaturedArtists(limit: 6);
      state = state.copyWith(featuredArtists: artists);
      await _saveToCache(state);
    } catch (e) {
      state = state.copyWith(error: 'Error al cargar artistas: $e');
    }
  }

  /// Cargar solo canciones destacadas
  Future<void> loadFeaturedSongs({bool forceRefresh = false}) async {
    try {
      final songs = await _homeService.getFeaturedSongs(limit: 20, forceRefresh: forceRefresh);
      state = state.copyWith(featuredSongs: songs);
      await _saveToCache(state);
    } catch (e) {
      state = state.copyWith(error: 'Error al cargar canciones: $e');
    }
  }

  /// Cargar solo playlists destacadas
  Future<void> loadFeaturedPlaylists() async {
    try {
      final playlists = await _homeService.getFeaturedPlaylists(limit: 6);
      state = state.copyWith(featuredPlaylists: playlists);
      await _saveToCache(state);
    } catch (e) {
      state = state.copyWith(error: 'Error al cargar playlists: $e');
    }
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> _loadFromCacheIfNeeded() async {
    if (_hasLoadedCache) return;
    _hasLoadedCache = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return;

      final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
      final timestampStr = decoded['timestamp'] as String?;
      if (timestampStr == null) return;

      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp == null) return;

      final isExpired = DateTime.now().difference(timestamp) > _cacheTtl;
      if (isExpired) return;

      final cachedState =
          HomeState.fromJson(Map<String, dynamic>.from(decoded));
      if (cachedState != null && (cachedState.isEmpty == false)) {
        state = cachedState.copyWith(
          isLoading: false,
          error: null,
          isInitialized: true,
        );
      }
    } catch (_) {
      // Si falla la lectura, continuamos sin cache
    }
  }

  Future<void> _saveToCache(HomeState newState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(newState.toJson()));
    } catch (_) {
      // Ignorar errores de escritura de cache
    }
  }
}

/// Provider para el estado de home
final homeStateProvider = NotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});

/// Providers específicos para cada sección con selectors para evitar rebuilds innecesarios
/// 🔥 OPTIMIZACIÓN: Usando select() + keepAlive para memoization y evitar recálculos
/// Solo se reconstruyen cuando cambia el valor específico
final featuredArtistsProvider = Provider<List<FeaturedArtist>>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(homeStateProvider.select((state) => state.featuredArtists));
});

final featuredSongsProvider = Provider<List<FeaturedSong>>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(homeStateProvider.select((state) => state.featuredSongs));
});

final featuredPlaylistsProvider = Provider<List<FeaturedPlaylist>>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(homeStateProvider.select((state) => state.featuredPlaylists));
});

final popularSongsProvider = Provider<List<Song>>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(homeStateProvider.select((state) => state.popularSongs));
});

final topArtistsProvider = Provider<List<Artist>>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(homeStateProvider.select((state) => state.topArtists));
});

final isLoadingProvider = Provider<bool>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(homeStateProvider.select((state) => state.isLoading));
});

final homeErrorProvider = Provider<String?>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(homeStateProvider.select((state) => state.error));
});

