import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  HomeState build() {
    _homeService = ref.read(homeServiceProvider);
    // Inicializar de forma asíncrona
    Future.microtask(() => _initialize());
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
      state = state.copyWith(isLoading: true, error: null);

      // Cargar datos individualmente para manejar errores por separado
      List<FeaturedArtist> featuredArtists = [];
      List<FeaturedSong> featuredSongs = [];
      List<FeaturedPlaylist> featuredPlaylists = [];
      List<Song> popularSongs = [];
      List<Artist> topArtists = [];

      // Cargar datos en paralelo para mejor rendimiento
      await Future.wait([
        // Artistas destacados
        _homeService.getFeaturedArtists(limit: 6).then((value) => featuredArtists = value).catchError((_) => <FeaturedArtist>[]),
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
    } catch (e) {
      state = state.copyWith(error: 'Error al cargar artistas: $e');
    }
  }

  /// Cargar solo canciones destacadas
  Future<void> loadFeaturedSongs({bool forceRefresh = false}) async {
    try {
      final songs = await _homeService.getFeaturedSongs(limit: 20, forceRefresh: forceRefresh);
      state = state.copyWith(featuredSongs: songs);
    } catch (e) {
      state = state.copyWith(error: 'Error al cargar canciones: $e');
    }
  }

  /// Cargar solo playlists destacadas
  Future<void> loadFeaturedPlaylists() async {
    try {
      final playlists = await _homeService.getFeaturedPlaylists(limit: 6);
      state = state.copyWith(featuredPlaylists: playlists);
    } catch (e) {
      state = state.copyWith(error: 'Error al cargar playlists: $e');
    }
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider para el estado de home
final homeStateProvider = NotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});

/// Providers específicos para cada sección con selectors para evitar rebuilds innecesarios
/// Usando select() para optimizar: solo se reconstruyen cuando cambia el valor específico
final featuredArtistsProvider = Provider<List<FeaturedArtist>>((ref) {
  return ref.watch(homeStateProvider.select((state) => state.featuredArtists));
});

final featuredSongsProvider = Provider<List<FeaturedSong>>((ref) {
  return ref.watch(homeStateProvider.select((state) => state.featuredSongs));
});

final featuredPlaylistsProvider = Provider<List<FeaturedPlaylist>>((ref) {
  return ref.watch(homeStateProvider.select((state) => state.featuredPlaylists));
});

final popularSongsProvider = Provider<List<Song>>((ref) {
  return ref.watch(homeStateProvider.select((state) => state.popularSongs));
});

final topArtistsProvider = Provider<List<Artist>>((ref) {
  return ref.watch(homeStateProvider.select((state) => state.topArtists));
});

final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(homeStateProvider.select((state) => state.isLoading));
});

final homeErrorProvider = Provider<String?>((ref) {
  return ref.watch(homeStateProvider.select((state) => state.error));
});

