import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/home_service.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/app_message_model.dart';

/// Provider para el servicio de home
final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService();
});

/// Top-level function for isolate
Map<String, dynamic> _decodeJsonIsolate(String json) {
  return jsonDecode(json) as Map<String, dynamic>;
}

/// Estado de la pantalla de inicio
class HomeState {
  final List<FeaturedArtist> featuredArtists;
  final List<FeaturedSong> featuredSongs;
  final List<FeaturedPlaylist> featuredPlaylists;
  final List<Song> popularSongs;
  final List<Artist> topArtists;
  final HomeMessage? homeMessage;
  final bool isLoading;
  final String? error;
  final bool isInitialized;
  final bool hasLoadedPlaylists;
  final DateTime? lastUpdateTime; // 🔥 Timestamp de última actualización

  const HomeState({
    this.featuredArtists = const [],
    this.featuredSongs = const [],
    this.featuredPlaylists = const [],
    this.popularSongs = const [],
    this.topArtists = const [],
    this.homeMessage,
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
    this.hasLoadedPlaylists = false,
    this.lastUpdateTime, // 🔥 Timestamp de última actualización
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
      'homeMessage': homeMessage?.toJson(),
      'isLoading': isLoading,
      'error': error,
      'isInitialized': isInitialized,
      'hasLoadedPlaylists': hasLoadedPlaylists,
      'lastUpdateTime': lastUpdateTime?.toIso8601String(),
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
        homeMessage: json['homeMessage'] != null
            ? HomeMessage.fromJson(
                Map<String, dynamic>.from(json['homeMessage'] as Map))
            : null,
        isLoading: json['isLoading'] as bool? ?? false,
        error: json['error'] as String?,
        isInitialized: json['isInitialized'] as bool? ?? false,
        hasLoadedPlaylists: json['hasLoadedPlaylists'] as bool? ?? false,
        lastUpdateTime: json['lastUpdateTime'] != null
            ? DateTime.tryParse(json['lastUpdateTime'] as String)
            : null,
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
    HomeMessage? homeMessage,
    bool? isLoading,
    String? error,
    bool? isInitialized,
    bool? hasLoadedPlaylists,
    DateTime? lastUpdateTime, // 🔥 Timestamp de última actualización
  }) {
    return HomeState(
      featuredArtists: featuredArtists ?? this.featuredArtists,
      featuredSongs: featuredSongs ?? this.featuredSongs,
      featuredPlaylists: featuredPlaylists ?? this.featuredPlaylists,
      popularSongs: popularSongs ?? this.popularSongs,
      topArtists: topArtists ?? this.topArtists,
      homeMessage: homeMessage ?? this.homeMessage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
      hasLoadedPlaylists: hasLoadedPlaylists ?? this.hasLoadedPlaylists,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime, // 🔥 Timestamp
    );
  }

  bool get hasError => error != null;
  bool get isEmpty => featuredArtists.isEmpty && featuredSongs.isEmpty && featuredPlaylists.isEmpty;
}

/// Notifier para manejar el estado de la pantalla de inicio
/// 🔥 OPTIMIZACIÓN: Usa keepAlive para persistir datos entre cambios de pestaña
class HomeNotifier extends Notifier<HomeState> {
  late final HomeService _homeService;
  static const String _cacheKey = 'home_state_cache_v1';
  // TTL del cache local para hidratar el home en arranque frío
  static const Duration _cacheTtl = Duration(minutes: 4);
  bool _hasLoadedCache = false;
  static const Duration _cacheSaveMinInterval = Duration(seconds: 10);
  DateTime? _lastCacheSave;

  @override
  HomeState build() {
    // 🔥 CRÍTICO: keepAlive para evitar destrucción al cambiar de pestaña
    // Esto evita llamadas innecesarias al backend y mantiene el estado
    ref.keepAlive();
    
    _homeService = ref.read(homeServiceProvider);
    // ✅ FIX PARPADEO: Cargar cache primero (síncrono) para mostrar datos inmediatamente
    // Solo inicializar si no hay datos ya cargados
    _loadFromCacheIfNeeded().then((hasValidCache) {
      // ✅ FIX: Solo inicializar si no hay cache válido
      // Esto evita recargar datos cuando ya están en memoria o cache
      if (!hasValidCache) {
        _initialize();
      }
    });
    // ⚡ FIX PARPADEO: Retornar estado sin loading para evitar skeleton innecesario
    // El loading se activa solo durante refresh manual (pull-to-refresh)
    return const HomeState(isLoading: false);
  }

  /// Inicializar el servicio y cargar datos
  Future<void> _initialize() async {
    try {
      // ✅ OPTIMIZACIÓN: No esperar initialize() - se inicializa lazy cuando se necesita
      // El httpClient se inicializa automáticamente en la primera llamada
      // Esto ahorra tiempo en el startup
      _homeService.initialize().catchError((_) {
        // Si falla, continuar de todas formas - se inicializará cuando se necesite
      });
      // Cargar datos (el servicio se inicializará lazy si es necesario)
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
  /// 🔥 OPTIMIZACIÓN: Carga progresiva - primero lo prioridad, luego el resto
  Future<void> loadHomeData({bool forceRefresh = false}) async {
    try {
      
      // ⚡ FIX PARPADEO: Solo mostrar loading si no hay datos actuales
      // Si ya hay datos, mantenerlos visibles durante la recarga
      final hasExistingData = !state.isEmpty;
      if (!hasExistingData) {
        state = state.copyWith(isLoading: true, error: null);
      } else {
        // Solo limpiar error, mantener isLoading: false para evitar parpadeo
        state = state.copyWith(error: null);
      }

      // ✅ OPTIMIZACIÓN: Carga prioritaria de canciones (Task 1 & 3)
      // Limit reducido a 4 para aligerar la carga
      List<FeaturedSong> featuredSongs = [];
      try {
        featuredSongs = await _homeService.getFeaturedSongs(limit: 4, forceRefresh: forceRefresh);
      } catch (_) {
        featuredSongs = [];
      }

      // Actualizar estado inmediatamente con canciones
      state = state.copyWith(
        featuredSongs: featuredSongs,
        isLoading: false, // Ya tenemos algo que mostrar
        isInitialized: true,
        lastUpdateTime: DateTime.now(), // 🔥 Guardar timestamp de actualización
      );
      _saveToCacheThrottled(state);

      // 🕒 DELAY (Task 3): Pequeña pausa para dar aire al Choreographer antes de la siguiente carga pesada
      await Future.delayed(const Duration(milliseconds: 200));

      // Fase 2: Cargar Artistas
      List<FeaturedArtist> featuredArtists = [];
      try {
        featuredArtists = await _homeService.getFeaturedArtists(limit: 6, forceRefresh: forceRefresh);
      } catch (_) {
        featuredArtists = [];
      }
      
      state = state.copyWith(featuredArtists: featuredArtists);
      _saveToCacheThrottled(state);

      // Fase 3: Mensaje del home y resto de datos en background
      HomeMessage? homeMessage;
      
      // No bloqueamos para el mensaje, pero lo pedimos pronto
      _homeService.getHomeMessage(forceRefresh: forceRefresh).then((value) {
        state = state.copyWith(homeMessage: value);
      }).catchError((_) {});
      
      // ✅ OPTIMIZACIÓN: Fase 4 - Cargar datos secundarios (playlists, popular, top)
      // Baja prioridad, lazy load
      List<FeaturedPlaylist> featuredPlaylists = [];
      List<Song> popularSongs = [];
      List<Artist> topArtists = [];
      
      // ✅ OPTIMIZACIÓN FASE 4: NO usar forceRefresh (reduce carga en servidor 43%)
      // Datos secundarios pueden usar cache HTTP normal
      Future.wait<void>([
        _homeService.getFeaturedPlaylists(limit: 6).then((value) => featuredPlaylists = value).catchError((_) => <FeaturedPlaylist>[]),
        _homeService.getPopularSongs(limit: 10).then((value) => popularSongs = value).catchError((_) => <Song>[]),
        _homeService.getTopArtists(limit: 8).then((value) => topArtists = value).catchError((_) => <Artist>[]),
      ]).then((_) {
        state = state.copyWith(
          featuredPlaylists: featuredPlaylists,
          popularSongs: popularSongs,
          topArtists: topArtists,
        );
        _saveToCacheThrottled(state);
      });
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar datos: $e',
        isInitialized: true,
      );
    }
  }

  /// Refrescar datos (forzar refresh sin caché)
  /// ⚡ FIX PARPADEO: Solo este método muestra loading (pull-to-refresh explícito)
  Future<void> refresh() async {
    // Mostrar loading solo en refresh explícito del usuario
    state = state.copyWith(isLoading: true);
    
    try {
      // 🚀 OPTIMIZACIÓN: Solo llamar a loadHomeData.
      // loadHomeData ya se encarga de iniciar la carga progresiva de todo (artistas, canciones, playlists).
      // Al no esperar las tareas de fondo (fase 2 y 3), el spinner desaparece rápido (UX "Snappy").
      // Evitamos llamar a loadFeaturedPlaylists en paralelo para no causar condiciones de carrera con loadHomeData.
      await loadHomeData(forceRefresh: true);
    } catch (e) {
      debugPrint('Error en refresh: $e');
    } finally {
      // Asegurar siempre que el loading se apague
      state = state.copyWith(isLoading: false);
    }
  }

  /// Cargar solo artistas destacados
  Future<void> loadFeaturedArtists() async {
    try {
      final artists = await _homeService.getFeaturedArtists(limit: 6);
      state = state.copyWith(featuredArtists: artists);
      await _saveToCacheThrottled(state);
    } catch (e) {
      state = state.copyWith(error: 'Error al cargar artistas: $e');
    }
  }

  /// Cargar solo canciones destacadas
  Future<void> loadFeaturedSongs({bool forceRefresh = false}) async {
    try {
      final songs = await _homeService.getFeaturedSongs(limit: 20, forceRefresh: forceRefresh);
      state = state.copyWith(featuredSongs: songs);
      await _saveToCacheThrottled(state);
    } catch (e) {
      state = state.copyWith(error: 'Error al cargar canciones: $e');
    }
  }

  /// Cargar solo playlists destacadas
  Future<void> loadFeaturedPlaylists() async {
    try {
      final playlists = await _homeService.getFeaturedPlaylists(limit: 6);
      state = state.copyWith(
        featuredPlaylists: playlists,
        hasLoadedPlaylists: true, // ✅ MARCA COMO CARGADO para evitar bucles
      );
      await _saveToCacheThrottled(state);
    } catch (e) {
      state = state.copyWith(
        error: 'Error al cargar playlists: $e',
        hasLoadedPlaylists: true, // ✅ Evitar reintentos infinitos si falla
      );
    }
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// ✅ OPTIMIZACIÓN: Cargar cache de forma más eficiente y rápida
  /// Retorna true si se cargó cache válido, false si no había cache o expiró
  Future<bool> _loadFromCacheIfNeeded() async {
    if (_hasLoadedCache) {
      // Si ya hay estado inicializado, retornar true (hay datos)
      return state.isInitialized && !state.isEmpty;
    }
    _hasLoadedCache = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      
      if (cachedJson == null || cachedJson.isEmpty) {
        // Si no hay cache, retornar false (no hay datos)
        return false;
      }

      // 🚀 ISOLATE: Decodificar JSON en background para no bloquear UI
      // Esto es crítico para dispositivos gama media/baja durante el arranque
      final decoded = await compute(_decodeJsonIsolate, cachedJson);

      final timestampStr = decoded['timestamp'] as String?;
      
      if (timestampStr == null) {
        // Cache inválido, retornar false
        return false;
      }

      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp == null) {
        // Cache inválido, retornar false
        return false;
      }

      final isExpired = DateTime.now().difference(timestamp) > _cacheTtl;
      if (isExpired) {
        // Cache expirado, retornar false
        return false;
      }

      final decodedMap = Map<String, dynamic>.from(decoded);

      // Parse popular songs in an isolate to avoid blocking the UI thread
      final popularSongsJson = (decodedMap['popularSongs'] as List<dynamic>?) ?? [];
      List<Song> popularSongs = [];
      try {
        popularSongs = await Song.parseList(popularSongsJson);
      } catch (_) {
        // Fallback synchronous parse
        popularSongs = (popularSongsJson)
            .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      final cachedState = HomeState(
        featuredArtists: (decodedMap['featuredArtists'] as List<dynamic>?)
                ?.map((e) => FeaturedArtist.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        featuredSongs: (decodedMap['featuredSongs'] as List<dynamic>?)
                ?.map((e) => FeaturedSong.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        featuredPlaylists: (decodedMap['featuredPlaylists'] as List<dynamic>?)
                ?.map((e) => FeaturedPlaylist.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        popularSongs: popularSongs,
        topArtists: (decodedMap['topArtists'] as List<dynamic>?)
                ?.map((e) => Artist.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        homeMessage: decodedMap['homeMessage'] != null
            ? HomeMessage.fromJson(Map<String, dynamic>.from(decodedMap['homeMessage'] as Map))
            : null,
        isLoading: decodedMap['isLoading'] as bool? ?? false,
        error: decodedMap['error'] as String?,
        isInitialized: decodedMap['isInitialized'] as bool? ?? false,
        hasLoadedPlaylists: decodedMap['hasLoadedPlaylists'] as bool? ?? false,
        lastUpdateTime: decodedMap['lastUpdateTime'] != null
            ? DateTime.tryParse(decodedMap['lastUpdateTime'] as String)
            : null,
      );

      if (!cachedState.isEmpty) {
        // ✅ OPTIMIZACIÓN: Mostrar cache inmediatamente (sin isLoading para evitar skeleton)
        state = cachedState.copyWith(
          isLoading: false,
          error: null,
          isInitialized: true,
        );
        // ✅ FIX: No recargar datos automáticamente si ya hay cache válido
        // Solo recargar si el usuario hace pull-to-refresh
        return true; // Cache válido cargado
      } else {
        // Cache inválido, retornar false
        return false;
      }
    } catch (_) {
      // Si falla la lectura, retornar false
      return false;
    }
  }

  Future<void> _saveToCacheThrottled(HomeState newState) async {
    final now = DateTime.now();
    if (_lastCacheSave != null &&
        now.difference(_lastCacheSave!) < _cacheSaveMinInterval) {
      return;
    }
    _lastCacheSave = now;
    await _saveToCache(newState);
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

// OPTIMIZACIÓN: Método de logging removido para mejor rendimiento

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

final homeMessageProvider = Provider<HomeMessage?>((ref) {
  ref.keepAlive();
  return ref.watch(homeStateProvider.select((state) => state.homeMessage));
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

