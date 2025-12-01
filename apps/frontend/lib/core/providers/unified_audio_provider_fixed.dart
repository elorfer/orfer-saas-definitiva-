import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../services/spotify_recommendation_service.dart';
import '../services/http_client_service.dart';
import '../utils/url_normalizer.dart';
import '../services/professional_audio_service.dart';
import '../services/home_service.dart';
import '../utils/data_normalizer.dart';

/// Estado unificado del reproductor de audio - ÚNICA FUENTE DE VERDAD
@immutable
class UnifiedAudioState {
  final Song? currentSong;
  final bool isPlaying;
  final bool isBuffering;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlayerExpanded;
  final double volume;
  final bool isLoading;

  const UnifiedAudioState({
    this.currentSong,
    this.isPlaying = false,
    this.isBuffering = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isPlayerExpanded = false,
    this.volume = 0.85,
    this.isLoading = false,
  });

  /// Calcular progreso de 0.0 a 1.0
  double get progress {
    if (totalDuration.inMilliseconds <= 0) {
      return 0.0;
    }
    final calculatedProgress = (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
    return calculatedProgress;
  }

  /// Verificar si hay una canción cargada
  bool get hasSong => currentSong != null;

  /// Verificar si se puede reproducir
  bool get canPlay => hasSong && !isLoading;

  UnifiedAudioState copyWith({
    Song? currentSong,
    bool? isPlaying,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isPlayerExpanded,
    double? volume,
    bool? isLoading,
  }) {
    return UnifiedAudioState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isPlayerExpanded: isPlayerExpanded ?? this.isPlayerExpanded,
      volume: volume ?? this.volume,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedAudioState &&
        other.currentSong?.id == currentSong?.id &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.currentPosition == currentPosition &&
        other.totalDuration == totalDuration &&
        other.isPlayerExpanded == isPlayerExpanded &&
        other.volume == volume &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return Object.hash(
      currentSong?.id,
      isPlaying,
      isBuffering,
      currentPosition,
      totalDuration,
      isPlayerExpanded,
      volume,
      isLoading,
    );
  }

  @override
  String toString() {
    return 'UnifiedAudioState(song: ${currentSong?.title}, playing: $isPlaying, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}

/// Notifier unificado que maneja el estado del audio
/// ÚNICA INSTANCIA DE AudioPlayer - ÚNICA FUENTE DE VERDAD
class UnifiedAudioNotifier extends Notifier<UnifiedAudioState> {
  // ✅ UN SOLO AudioPlayer para toda la aplicación
  AudioPlayer? _player;
  
  // ✅ Servicio profesional de audio para background playback
  ProfessionalAudioService? _audioService;
  
  // ✅ Suscripciones a los streams del AudioPlayer - SIN DUPLICADOS
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // ✅ Flag de inicialización
  bool _isInitialized = false;
  
  // 🛡️ PROTECCIÓN CONTRA MÚLTIPLES LLAMADAS Y LOOPS
  bool _isSearchingNextSong = false;
  
  String? _lastRecommendedSongId;
  DateTime? _lastRecommendationTime;
  
  // 🛡️ PROTECCIÓN: Timestamp de última operación manual de play/pause
  // Para evitar que el stream sobrescriba el estado inmediatamente después de una acción del usuario
  DateTime? _lastManualToggleTime;
  bool? _lastManualToggleState; // El estado que el usuario quiere (true = playing, false = paused)
  
  // 🆕 MEJORA 1: Precarga de siguiente canción
  Song? _preloadedNextSong;
  bool _isPreloadingNext = false;
  bool _hasTriggeredPreload = false; // Evitar múltiples precargas
  
  // 🆕 MEJORA 3: Historial de últimas canciones reproducidas (protección contra loops)
  final List<String> _recentSongIds = [];
  static const int _maxRecentSongs = 10; // Últimas 10 canciones
  
  // ✅ OPTIMIZACIÓN: Cache de últimos valores de streams para evitar emisiones duplicadas
  Duration? _lastPosition;
  Duration? _lastDuration;
  PlayerState? _lastPlayerState;

  @override
  UnifiedAudioState build() {
    // Inicializar el AudioPlayer cuando se crea el notifier
    _initializePlayer();
    
    // Limpiar recursos cuando se dispose
    ref.onDispose(() {
      _dispose();
    });
    
    return const UnifiedAudioState();
  }

  /// ✅ Inicializar el AudioPlayer usando ProfessionalAudioService
  void _initializePlayer() {
    if (_player != null || _isInitialized) {
      // Sin logs para mejor rendimiento
      return;
    }
    
    try {
      // Sin logs para mejor rendimiento
      _audioService = ProfessionalAudioService();
      
      if (!_audioService!.isInitialized) {
        // Sin logs para mejor rendimiento
        _audioService!.initialize(enableBackground: true).then((_) {
          _completeInitialization();
        });
      } else {
        _completeInitialization();
      }
    } catch (e) {
      // Sin logs para mejor rendimiento
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error inicializando AudioPlayer: $e');
    }
  }

  /// Completar la inicialización después de que el servicio esté listo
  void _completeInitialization() {
    try {
      _player = _audioService!.controller?.player;
      if (_player == null) {
        // Sin logs para mejor rendimiento
        throw Exception('No se pudo obtener AudioPlayer del ProfessionalAudioService');
      }
      
      // Sin logs para mejor rendimiento
      
      _setupListeners();
      _isInitialized = true;
      // Sin logs para mejor rendimiento
      AppLogger.info('[UnifiedAudioNotifier] ✅ AudioPlayer inicializado con ProfessionalAudioService');
    } catch (e) {
      // Sin logs para mejor rendimiento
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error completando inicialización: $e');
    }
  }

  /// ✅ Configurar listeners del AudioPlayer - OBLIGATORIOS PARA BARRAS DE PROGRESO
  void _setupListeners() {
    if (_player == null) {
      // Sin logs para mejor rendimiento
      return;
    }

    // Sin logs para mejor rendimiento

    // 🎯 LISTENER DE POSICIÓN - CRÍTICO PARA BARRA DE PROGRESO
    // ✅ OPTIMIZACIÓN: Comparación manual para evitar emisiones duplicadas
    _positionSubscription = _player!.positionStream.listen((position) {
      // Solo actualizar si cambió significativamente (comparar en milisegundos)
      if (_lastPosition == null || _lastPosition!.inMilliseconds != position.inMilliseconds) {
        _lastPosition = position;
        _updatePosition(position);
      }
    });

    // 🎯 LISTENER DE DURACIÓN - CRÍTICO PARA BARRA DE PROGRESO
    // ✅ OPTIMIZACIÓN: Comparación manual para evitar emisiones duplicadas
    _durationSubscription = _player!.durationStream.listen((duration) {
      if (duration != null) {
        // Solo actualizar si cambió
        if (_lastDuration == null || _lastDuration != duration) {
          _lastDuration = duration;
          _updateDuration(duration);
        }
      }
    });

    // 🎯 LISTENER DE ESTADO DEL PLAYER - CRÍTICO PARA PLAY/PAUSE
    // ✅ OPTIMIZACIÓN: Comparación manual para evitar emisiones duplicadas
    _playerStateSubscription = _player!.playerStateStream.listen((playerState) {
      // Solo actualizar si cambió el estado relevante
      if (_lastPlayerState == null || 
          _lastPlayerState!.playing != playerState.playing ||
          _lastPlayerState!.processingState != playerState.processingState) {
        _lastPlayerState = playerState;
        _updatePlayerState(playerState);
      }
    });

    // ✅ OPTIMIZACIÓN: positionStream ya emite actualizaciones frecuentes (no necesitamos timer)
    // El timer duplicado causaba actualizaciones redundantes y peor rendimiento

    AppLogger.info('[UnifiedAudioNotifier] ✅ Listeners configurados correctamente');
  }

  /// ✅ Actualizar posición - OPTIMIZADO: comparar en milisegundos para evitar actualizaciones microscópicas
  /// 🆕 MEJORA 1: Detecta cuando queden 10-15 segundos para precargar siguiente canción
  void _updatePosition(Duration position) {
    // Comparar en milisegundos para evitar actualizaciones redundantes de microsegundos
    if (position.inMilliseconds != state.currentPosition.inMilliseconds) {
      state = state.copyWith(currentPosition: position);
      
      // 🆕 MEJORA 1: PRECARGA INTELIGENTE - Precargar cuando queden 10-15 segundos
      if (state.currentSong != null && 
          state.totalDuration.inMilliseconds > 0 &&
          !_isPreloadingNext && 
          !_hasTriggeredPreload) {
        final remaining = state.totalDuration - position;
        if (remaining.inSeconds <= 15 && remaining.inSeconds >= 10) {
          _hasTriggeredPreload = true;
          _preloadNextSong();
        }
      }
    }
  }

  /// ✅ Actualizar duración - LLAMAR notifyListeners()
  void _updateDuration(Duration duration) {
    if (state.totalDuration != duration) {
      state = state.copyWith(totalDuration: duration);
      // Duración actualizada sin log para mejor rendimiento
    }
  }

  /// Actualizar estado del player
  void _updatePlayerState(PlayerState playerState) {
    final newIsPlaying = playerState.playing;
    final newIsBuffering = playerState.processingState == ProcessingState.loading ||
                          playerState.processingState == ProcessingState.buffering;

    // 🛡️ PROTECCIÓN: Si acabamos de hacer una operación manual de toggle,
    // ignorar actualizaciones del stream durante los primeros 200ms para evitar
    // que sobrescriba el estado optimista antes de que la operación se complete
    final now = DateTime.now();
    if (_lastManualToggleTime != null && 
        _lastManualToggleState != null &&
        now.difference(_lastManualToggleTime!).inMilliseconds < 200) {
      // Durante los primeros 200ms después de un toggle manual, usar el estado manual
      // Solo actualizar buffering, pero mantener el estado de playing del toggle manual
      if (state.isBuffering != newIsBuffering) {
        state = state.copyWith(
          isPlaying: _lastManualToggleState!,
          isBuffering: newIsBuffering,
        );
      }
    } else {
      // Pasado el período de protección, actualizar normalmente desde el stream
      if (state.isPlaying != newIsPlaying || state.isBuffering != newIsBuffering) {
        state = state.copyWith(
          isPlaying: newIsPlaying,
          isBuffering: newIsBuffering,
        );
      }
      // Limpiar el flag de protección después del período
      if (_lastManualToggleTime != null) {
        _lastManualToggleTime = null;
        _lastManualToggleState = null;
      }
    }

    if (playerState.processingState == ProcessingState.completed && 
        !_isSearchingNextSong) {
      _handleSongCompletion();
    }
  }

  /// ✅ Manejar cuando una canción termina - OPTIMIZADO
  void _handleSongCompletion() {
    debugPrint('🎵 [ALGORITMO] Iniciando búsqueda de siguiente canción...');
    
    // 🛡️ PROTECCIÓN: Evitar múltiples llamadas simultáneas
    if (_isSearchingNextSong) {
      debugPrint('⚠️ [ALGORITMO] Ya buscando, ignorando...');
      return;
    }

    final currentSong = state.currentSong;
    if (currentSong == null) {
      debugPrint('❌ [ALGORITMO] Sin canción actual');
      return;
    }

    // 🛡️ PROTECCIÓN: Evitar búsquedas muy frecuentes (mínimo 2 segundos)
    final now = DateTime.now();
    if (_lastRecommendationTime != null && 
        now.difference(_lastRecommendationTime!).inSeconds < 2) {
      debugPrint('⚠️ [ALGORITMO] Muy rápido, esperando...');
      return;
    }
    
    debugPrint('✅ [ALGORITMO] Canción: ${currentSong.title} → Buscando recomendación...');

    // ✅ MARCAR COMO EN PROCESO
    _isSearchingNextSong = true;
    _lastRecommendationTime = now;

    // ✅ TRANSICIÓN FLUIDA: Mantener estado visual mientras busca siguiente
    state = state.copyWith(
      currentPosition: state.totalDuration,
      // NO mostrar isLoading para evitar fondo gris
      // NO cambiar isPlaying para transición más suave
    );

    debugPrint('🚀 [ALGORITMO] Activando tu algoritmo de recomendaciones...');
    
    // 🧠 ACTIVAR SISTEMA DE SIGUIENTE CANCIÓN INMEDIATAMENTE (sin crossfade para evitar gris)
    _triggerNextSongRecommendation();
  }


  /// 🧠 Activar recomendación de siguiente canción - OPTIMIZADO
  void _triggerNextSongRecommendation() async {
    debugPrint('🤖 [TU ALGORITMO] Procesando recomendación...');
    try {
      final currentSong = state.currentSong;
      if (currentSong == null) {
        _resetSearchState();
        return;
      }

      // 🧠 BUSCAR Y REPRODUCIR SIGUIENTE CANCIÓN
      await _findAndPlayNextSong(currentSong);
      
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] Error activando recomendaciones: $e');
      _resetSearchState();
    }
  }

  /// 🔍 Buscar y reproducir siguiente canción - COMPLETAMENTE OPTIMIZADO
  /// 🆕 MEJORA 2: Sistema de fallback inteligente con múltiples estrategias
  Future<void> _findAndPlayNextSong(Song currentSong) async {
    try {
      Song? nextSong;
      
      // 🆕 MEJORA 1: Estrategia 0 - Usar canción precargada si existe
      if (_preloadedNextSong != null && _isValidNextSong(_preloadedNextSong!, currentSong)) {
        debugPrint('✅ [ALGORITMO] Usando canción precargada: ${_preloadedNextSong!.title}');
        nextSong = _preloadedNextSong;
        _preloadedNextSong = null;
        _hasTriggeredPreload = false;
      }
      
      // 🆕 MEJORA 2: Estrategia 1 - Algoritmo de recomendaciones principal
      if (nextSong == null) {
        try {
          final recommendationService = SpotifyRecommendationService(HttpClientService());
          
          nextSong = await recommendationService.getSmartRecommendation(
            currentSongId: currentSong.id,
            genres: currentSong.genres,
            user: null, // Nota: Pasar usuario cuando esté disponible
          );
          
          if (nextSong != null && !_isValidNextSong(nextSong, currentSong)) {
            nextSong = null;
          }
        } catch (e) {
          debugPrint('⚠️ [ALGORITMO] Error en recomendación principal: $e');
          nextSong = null;
        }
      }
      
      // 🆕 MEJORA 2: Estrategia 2 - Fallback por género (mismo género, diferente artista)
      if (nextSong == null && currentSong.genres != null && currentSong.genres!.isNotEmpty) {
        try {
          debugPrint('🔄 [ALGORITMO] Intentando fallback por género...');
          nextSong = await _getGenreFallback(currentSong);
          if (nextSong != null) {
            debugPrint('✅ [ALGORITMO] Fallback por género exitoso: ${nextSong.title}');
          }
        } catch (e) {
          debugPrint('⚠️ [ALGORITMO] Error en fallback por género: $e');
        }
      }
      
      // 🆕 MEJORA 2: Estrategia 3 - Fallback por artista (otra canción del mismo artista)
      if (nextSong == null && currentSong.artistId != null) {
        try {
          debugPrint('🔄 [ALGORITMO] Intentando fallback por artista...');
          nextSong = await _getArtistFallback(currentSong);
          if (nextSong != null) {
            debugPrint('✅ [ALGORITMO] Fallback por artista exitoso: ${nextSong.title}');
          }
        } catch (e) {
          debugPrint('⚠️ [ALGORITMO] Error en fallback por artista: $e');
        }
      }
      
      // 🆕 MEJORA 2: Estrategia 4 - Fallback por canción destacada aleatoria
      if (nextSong == null) {
        try {
          debugPrint('🔄 [ALGORITMO] Intentando fallback por destacada...');
          nextSong = await _getFeaturedFallback(currentSong);
          if (nextSong != null) {
            debugPrint('✅ [ALGORITMO] Fallback por destacada exitoso: ${nextSong.title}');
          }
        } catch (e) {
          debugPrint('⚠️ [ALGORITMO] Error en fallback por destacada: $e');
        }
      }

      // ▶️ REPRODUCIR SIGUIENTE CANCIÓN SI ES VÁLIDA
      if (nextSong != null) {
        // 🎯 GUARDAR ID PARA EVITAR REPETICIONES
        _lastRecommendedSongId = nextSong.id;
        
        // 🎵 REPRODUCIR AUTOMÁTICAMENTE
        await playSong(nextSong);
        
      } else {
        // ⏸️ MANTENER PAUSADO SI NO HAY SIGUIENTE (todas las estrategias fallaron)
        debugPrint('❌ [ALGORITMO] Todas las estrategias fallaron, pausando...');
        state = state.copyWith(
          isPlaying: false,
        );
      }

    } catch (e) {
      // ⏸️ MANTENER PAUSADO EN CASO DE ERROR
      debugPrint('❌ [ALGORITMO] Error general: $e');
      state = state.copyWith(
        isPlaying: false,
      );
    } finally {
      // 🛡️ SIEMPRE RESETEAR ESTADO DE BÚSQUEDA Y PRECARGA
      _resetSearchState();
      _preloadedNextSong = null;
      _hasTriggeredPreload = false;
    }
  }
  
  /// 🆕 MEJORA 1: Precargar siguiente canción cuando queden 10-15 segundos
  Future<void> _preloadNextSong() async {
    if (_isPreloadingNext || state.currentSong == null) return;
    
    _isPreloadingNext = true;
    debugPrint('⚡ [PRECARGA] Iniciando precarga de siguiente canción...');
    
    try {
      final currentSong = state.currentSong!;
      final nextSong = await _findNextSong(currentSong);
      
      if (nextSong != null && _isValidNextSong(nextSong, currentSong)) {
        _preloadedNextSong = nextSong;
        debugPrint('✅ [PRECARGA] Canción precargada: ${nextSong.title}');
      } else {
        debugPrint('⚠️ [PRECARGA] No se pudo precargar canción válida');
      }
    } catch (e) {
      debugPrint('❌ [PRECARGA] Error precargando: $e');
    } finally {
      _isPreloadingNext = false;
    }
  }
  
  /// 🆕 Helper para buscar siguiente canción (sin reproducir)
  Future<Song?> _findNextSong(Song currentSong) async {
    try {
      final recommendationService = SpotifyRecommendationService(HttpClientService());
      return await recommendationService.getSmartRecommendation(
        currentSongId: currentSong.id,
        genres: currentSong.genres,
        user: null,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// 🆕 MEJORA 3: Validar si una canción es válida como siguiente (evita loops)
  bool _isValidNextSong(Song nextSong, Song currentSong) {
    // Evitar la misma canción
    if (nextSong.id == currentSong.id) {
      debugPrint('⚠️ [VALIDACIÓN] Misma canción, rechazando');
      return false;
    }
    
    // 🆕 MEJORA 3: Evitar canciones recientes (últimas 10)
    if (_recentSongIds.contains(nextSong.id)) {
      debugPrint('⚠️ [VALIDACIÓN] Canción reciente, evitando: ${nextSong.title}');
      return false;
    }
    
    // Evitar última recomendada
    if (nextSong.id == _lastRecommendedSongId) {
      debugPrint('⚠️ [VALIDACIÓN] Última recomendada, evitando');
      return false;
    }
    
    // Validar que tenga URL válida
    if (nextSong.fileUrl == null || nextSong.fileUrl!.isEmpty) {
      debugPrint('⚠️ [VALIDACIÓN] Sin URL válida, rechazando');
      return false;
    }
    
    return true;
  }
  
  /// 🆕 MEJORA 2: Fallback por género - Obtener canción del mismo género pero diferente artista
  Future<Song?> _getGenreFallback(Song currentSong) async {
    if (currentSong.genres == null || currentSong.genres!.isEmpty) return null;
    
    try {
      final httpClient = HttpClientService();
      final genre = currentSong.genres!.first; // Usar primer género
      
      // Buscar canciones por género (usar endpoint de búsqueda o featured)
      final response = await httpClient.dio.get(
        '/public/songs',
        queryParameters: {
          'limit': 20,
          'genres': genre,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final songsList = (data['songs'] as List?) ?? (data is List ? data : []);
        
        if (songsList.isNotEmpty) {
          // Buscar una canción válida del mismo género pero diferente artista
          for (var songData in songsList) {
            try {
              final normalized = DataNormalizer.normalizeSong(songData);
              final song = Song.fromJson(normalized);
              
              if (_isValidNextSong(song, currentSong) && 
                  song.artistId != currentSong.artistId) {
                return song;
              }
            } catch (e) {
              continue;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error en fallback por género: $e');
    }
    
    return null;
  }
  
  /// 🆕 MEJORA 2: Fallback por artista - Obtener otra canción del mismo artista
  Future<Song?> _getArtistFallback(Song currentSong) async {
    if (currentSong.artistId == null) return null;
    
    try {
      final httpClient = HttpClientService();
      
      // Obtener canciones del artista
      final response = await httpClient.dio.get(
        '/public/songs',
        queryParameters: {
          'artistId': currentSong.artistId,
          'limit': 20,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final songsList = (data['songs'] as List?) ?? (data is List ? data : []);
        
        if (songsList.isNotEmpty) {
          // Buscar otra canción del mismo artista
          for (var songData in songsList) {
            try {
              final normalized = DataNormalizer.normalizeSong(songData);
              final song = Song.fromJson(normalized);
              
              if (_isValidNextSong(song, currentSong)) {
                return song;
              }
            } catch (e) {
              continue;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error en fallback por artista: $e');
    }
    
    return null;
  }
  
  /// 🆕 MEJORA 2: Fallback por destacada - Obtener canción destacada aleatoria
  Future<Song?> _getFeaturedFallback(Song currentSong) async {
    try {
      final homeService = HomeService();
      final featuredSongs = await homeService.getFeaturedSongs(limit: 20);
      
      if (featuredSongs.isNotEmpty) {
        // Mezclar aleatoriamente para variedad
        final shuffled = List<FeaturedSong>.from(featuredSongs)..shuffle();
        
        for (var featuredSong in shuffled) {
          final song = featuredSong.song;
          if (_isValidNextSong(song, currentSong)) {
            return song;
          }
        }
      }
    } catch (e) {
      debugPrint('Error en fallback por destacada: $e');
    }
    
    return null;
  }

  /// 🛡️ Resetear estado de búsqueda de siguiente canción
  /// 🆕 MEJORA 1: También resetea flags de precarga
  void _resetSearchState() {
    _isSearchingNextSong = false;
    _isPreloadingNext = false;
    _hasTriggeredPreload = false;
    // Estado de búsqueda reseteado sin log para mejor rendimiento
  }

  /// ✅ Forzar inicialización del player (método público)
  void ensureInitialized() {
    if (!_isInitialized) {
      _initializePlayer();
    }
  }

  /// ✅ Reproducir una canción - Optimizado para respuesta inmediata sin parpadeo
  /// 🆕 MEJORA 3: Agrega canción al historial para evitar repeticiones
  Future<void> playSong(Song song) async {
    if (_player == null) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ AudioPlayer no inicializado');
      return;
    }

    try {
      // 🆕 MEJORA 3: Agregar al historial de canciones recientes
      _recentSongIds.add(song.id);
      if (_recentSongIds.length > _maxRecentSongs) {
        _recentSongIds.removeAt(0); // Remover la más antigua (FIFO)
      }
      debugPrint('📝 [HISTORIAL] Agregada: ${song.title} (Total: ${_recentSongIds.length})');
      
      // 🛡️ PROTECCIÓN: Registrar que estamos iniciando una reproducción manual
      // Esto evitará que el stream cause parpadeo durante la carga inicial
      _lastManualToggleTime = DateTime.now();
      _lastManualToggleState = true; // Queremos que esté reproduciendo
      
      // Resetear flags de precarga
      _preloadedNextSong = null;
      _hasTriggeredPreload = false;
      
      // Actualización optimista inmediata (una sola vez)
      state = state.copyWith(
        currentSong: song,
        isPlaying: true, // Establecer como playing inmediatamente
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
        isPlayerExpanded: false,
      );

      // Verificar que la URL no sea null
      if (song.fileUrl == null || song.fileUrl!.isEmpty) {
        throw Exception('URL de canción inválida: ${song.fileUrl}');
      }
      
      // Normalizar URL
      final normalizedUrl = UrlNormalizer.normalizeUrl(song.fileUrl!);

      // Cargar y reproducir - usar await para evitar múltiples actualizaciones
      try {
        await _player!.setUrl(normalizedUrl);
        final duration = _player!.duration ?? Duration.zero;
        await _player!.play();
        _player!.setVolume(1.0);
        
        // Actualizar solo una vez después de que todo esté listo
        // El período de protección del stream evitará actualizaciones intermedias
        state = state.copyWith(
          isPlaying: true,
          totalDuration: duration,
        );
      } catch (e) {
        AppLogger.error('[UnifiedAudioNotifier] ❌ Error en playSong: $e');
        state = state.copyWith(isPlaying: false);
        _lastManualToggleTime = null;
        _lastManualToggleState = null;
      }
      
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error reproduciendo: $e');
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
      );
      _lastManualToggleTime = null;
      _lastManualToggleState = null;
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player == null || state.currentSong == null) return;

    try {
      final newIsPlaying = !state.isPlaying;
      state = state.copyWith(isPlaying: newIsPlaying);
      
      if (newIsPlaying) {
        await _player!.play();
      } else {
        await _player!.pause();
      }
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] Error toggle: $e');
      state = state.copyWith(isPlaying: !state.isPlaying);
    }
  }

  /// Toggle play/pause con lógica inteligente estilo Spotify
  /// Lógica:
  /// 1. Si no hay canción → reproducir nueva
  /// 2. Si es otra canción → cambiar a esa
  /// 3. Si es la misma → toggle play/pause
  Future<void> togglePlay([Song? song]) async {
    if (_player == null) {
      AppLogger.error('[UnifiedAudioNotifier] AudioPlayer no inicializado');
      return;
    }

    try {
      if (state.currentSong == null) {
        if (song != null) {
          // Ejecutar sin await para no bloquear
          playSong(song);
        }
        return;
      }

      final currentSong = state.currentSong!;
      
      if (song != null && song.id != currentSong.id) {
        // Ejecutar sin await para no bloquear
        playSong(song);
        return;
      }

      // Actualización optimista inmediata (antes de esperar al player)
      final newIsPlaying = !state.isPlaying;
      
      // 🛡️ PROTECCIÓN: Registrar que estamos haciendo un toggle manual
      // Esto evitará que el stream sobrescriba el estado durante los próximos 200ms
      _lastManualToggleTime = DateTime.now();
      _lastManualToggleState = newIsPlaying;
      
      state = state.copyWith(isPlaying: newIsPlaying);

      // Ejecutar operación y esperar a que se complete para garantizar sincronización
      if (newIsPlaying) {
        try {
          await _player!.play();
          // Verificar que el estado del player coincida con nuestro estado optimista
          // Si no coincide, el stream lo corregirá automáticamente después del período de protección
        } catch (e) {
          AppLogger.error('[UnifiedAudioNotifier] Error play: $e');
          state = state.copyWith(isPlaying: false);
          _lastManualToggleTime = null;
          _lastManualToggleState = null;
        }
      } else {
        try {
          await _player!.pause();
          // CRÍTICO: Asegurar que el estado se mantenga en pause después de la operación
          // Verificar el estado actual del player para asegurar sincronización
          final currentPlayerState = _player!.playerState;
          if (currentPlayerState.playing) {
            // Si el player sigue reproduciendo, forzar pause nuevamente
            await _player!.pause();
          }
          // Asegurar que el estado refleje pause
          state = state.copyWith(isPlaying: false);
        } catch (e) {
          AppLogger.error('[UnifiedAudioNotifier] Error pause: $e');
          state = state.copyWith(isPlaying: true);
          _lastManualToggleTime = null;
          _lastManualToggleState = null;
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('[UnifiedAudioNotifier] Error en togglePlay: $e', stackTrace);
    }
  }

  /// Pausar
  Future<void> pause() async {
    if (_player == null) return;
    
    try {
      state = state.copyWith(isPlaying: false);
      await _player!.pause();
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] Error pause: $e');
      state = state.copyWith(isPlaying: true);
    }
  }

  /// Reanudar
  Future<void> play() async {
    if (_player == null) return;
    
    try {
      state = state.copyWith(
        isPlaying: true,
        isPlayerExpanded: false,
      );
      
      await _player!.play();
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] Error play: $e');
      state = state.copyWith(isPlaying: false);
    }
  }

  /// ✅ Buscar posición
  Future<void> seek(Duration position) async {
    if (_player == null) return;
    
    try {
      await _player!.seek(position);
      AppLogger.info('[UnifiedAudioNotifier] ⏭️ Seek: ${position.inSeconds}s');
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error seek: $e');
    }
  }

  /// ✅ Cambiar volumen
  Future<void> setVolume(double volume) async {
    if (_player == null) return;
    
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player!.setVolume(clampedVolume);
      state = state.copyWith(volume: clampedVolume);
      AppLogger.info('[UnifiedAudioNotifier] 🔊 Volumen: ${(clampedVolume * 100).toInt()}%');
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error volumen: $e');
    }
  }

  /// ✅ Expandir/colapsar reproductor
  void setPlayerExpanded(bool expanded) {
    state = state.copyWith(isPlayerExpanded: expanded);
    AppLogger.info('[UnifiedAudioNotifier] 🎬 Player expanded: $expanded');
  }

  /// ✅ Abrir reproductor completo
  void openFullPlayer() {
    state = state.copyWith(isPlayerExpanded: true);
    AppLogger.info('[UnifiedAudioNotifier] 🎬 Abriendo reproductor completo');
  }

  /// ✅ Cerrar reproductor completo
  void closeFullPlayer() {
    state = state.copyWith(isPlayerExpanded: false);
    AppLogger.info('[UnifiedAudioNotifier] 🎬 Cerrando reproductor completo');
  }

  /// ✅ Toggle expandir/colapsar reproductor
  void toggleExpandedPlayer() {
    final newState = !state.isPlayerExpanded;
    state = state.copyWith(isPlayerExpanded: newState);
    AppLogger.info('[UnifiedAudioNotifier] 🎬 Toggle player expanded: $newState');
  }

  /// ✅ Detener completamente
  Future<void> stop() async {
    if (_player == null) return;
    
    try {
      await _player!.stop();
      state = state.copyWith(
        isPlaying: false,
        currentPosition: Duration.zero,
      );
      AppLogger.info('[UnifiedAudioNotifier] ⏹️ Detenido');
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error stop: $e');
    }
  }

  /// ✅ Siguiente canción (placeholder para futura implementación)
  Future<void> next() async {
    AppLogger.info('[UnifiedAudioNotifier] ⏭️ Next - Por implementar con playlist');
    // Nota: Implementar cuando se agregue soporte para playlists
  }

  /// ✅ Canción anterior (placeholder para futura implementación)
  Future<void> previous() async {
    AppLogger.info('[UnifiedAudioNotifier] ⏮️ Previous - Por implementar con playlist');
    // Nota: Implementar cuando se agregue soporte para playlists
  }

  /// ✅ Limpiar recursos
  /// 🆕 MEJORA 1 y 3: Limpia también precarga e historial
  void _dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player?.dispose();
    
    _positionSubscription = null;
    _durationSubscription = null;
    _playerStateSubscription = null;
    _player = null;
    _isInitialized = false;
    
    // 🆕 Limpiar precarga e historial
    _preloadedNextSong = null;
    _isPreloadingNext = false;
    _hasTriggeredPreload = false;
    _recentSongIds.clear();
    
    AppLogger.info('[UnifiedAudioNotifier] 🧹 Recursos limpiados');
  }
}

/// ✅ Provider unificado del reproductor de audio
/// ESTA ES LA ÚNICA FUENTE DE VERDAD para todo el estado del audio
final unifiedAudioProviderFixed = NotifierProvider<UnifiedAudioNotifier, UnifiedAudioState>(() {
  return UnifiedAudioNotifier();
});

/// ✅ Providers de conveniencia para acceso rápido a partes específicas del estado
/// CRÍTICO: isPlaying y currentSong NO usan select para garantizar actualización inmediata
final currentSongProviderFixed = Provider<Song?>((ref) {
  return ref.watch(unifiedAudioProviderFixed).currentSong;
});

final isPlayingProviderFixed = Provider<bool>((ref) {
  return ref.watch(unifiedAudioProviderFixed).isPlaying;
});

final audioProgressProviderFixed = Provider<double>((ref) {
  return ref.watch(
    unifiedAudioProviderFixed.select((state) => state.progress),
  );
});

final audioPositionProviderFixed = Provider<Duration>((ref) {
  return ref.watch(
    unifiedAudioProviderFixed.select((state) => state.currentPosition),
  );
});

final audioDurationProviderFixed = Provider<Duration>((ref) {
  return ref.watch(
    unifiedAudioProviderFixed.select((state) => state.totalDuration),
  );
});

final isBufferingProviderFixed = Provider<bool>((ref) {
  return ref.watch(
    unifiedAudioProviderFixed.select((state) => state.isBuffering),
  );
});

final audioVolumeProviderFixed = Provider<double>((ref) {
  return ref.watch(
    unifiedAudioProviderFixed.select((state) => state.volume),
  );
});
