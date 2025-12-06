import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../services/spotify_recommendation_service.dart';
import '../services/http_client_service.dart';
import '../services/streams_api.dart';
import '../utils/url_normalizer.dart';
import '../services/home_service.dart';
import '../utils/data_normalizer.dart';

// ignore_for_file: unused_element

/// Modo de repetición del reproductor
enum RepeatMode {
  off,  // Sin repetición
  all,  // Repetir todas las canciones
  one,  // Repetir canción actual
}

/// Modo de reproducción del reproductor
enum PlaybackMode {
  algorithm,   // Modo algoritmo (recomendaciones)
  fixedQueue,  // Modo cola fija (playlist/artista)
  none,        // Sin modo activo
}

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
  final bool isShuffled;
  final RepeatMode repeatMode;
  final PlaybackMode playbackMode; // Modo de reproducción activo
  final String? contextId; // ID del contexto actual (playlistId o artistId)

  const UnifiedAudioState({
    this.currentSong,
    this.isPlaying = false,
    this.isBuffering = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isPlayerExpanded = false,
    this.volume = 0.85,
    this.isLoading = false,
    this.isShuffled = false,
    this.repeatMode = RepeatMode.off,
    this.playbackMode = PlaybackMode.none,
    this.contextId,
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
    bool? isShuffled,
    RepeatMode? repeatMode,
    PlaybackMode? playbackMode,
    String? contextId,
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
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
      playbackMode: playbackMode ?? this.playbackMode,
      contextId: contextId ?? this.contextId,
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
        other.isLoading == isLoading &&
        other.isShuffled == isShuffled &&
        other.repeatMode == repeatMode &&
        other.playbackMode == playbackMode &&
        other.contextId == contextId;
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
      isShuffled,
      repeatMode,
      playbackMode,
      contextId,
    );
  }

  @override
  String toString() {
    return 'UnifiedAudioState(song: ${currentSong?.title}, playing: $isPlaying, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}

/// Notifier unificado que maneja el estado del audio
/// DOS REPRODUCTORES SEPARADOS: algorithmPlayer y fixedQueuePlayer
class UnifiedAudioNotifier extends Notifier<UnifiedAudioState> {
  // ✅ DOS AudioPlayers separados: uno para algoritmo, otro para cola fija
  AudioPlayer? _algorithmPlayer;
  AudioPlayer? _fixedQueuePlayer;
  
  // ✅ Referencia al reproductor activo actual
  AudioPlayer? get _activePlayer {
    switch (state.playbackMode) {
      case PlaybackMode.algorithm:
        return _algorithmPlayer;
      case PlaybackMode.fixedQueue:
        return _fixedQueuePlayer;
      case PlaybackMode.none:
        return null;
    }
  }
  
  
  // ✅ Suscripciones a los streams del AudioPlayer - SIN DUPLICADOS
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // ✅ Flag de inicialización
  bool _isInitialized = false;
  
  // 🛡️ PROTECCIÓN CONTRA MÚLTIPLES LLAMADAS Y LOOPS
  bool _isSearchingNextSong = false;
  
  // 🛡️ PROTECCIÓN: Timestamp de última operación manual de play/pause
  // Para evitar que el stream sobrescriba el estado inmediatamente después de una acción del usuario
  DateTime? _lastManualToggleTime;
  bool? _lastManualToggleState; // El estado que el usuario quiere (true = playing, false = paused)
  
  // 🛡️ PROTECCIÓN: Timestamp de última operación de seek
  // Para evitar que el stream sobrescriba el estado inmediatamente después de un seek
  DateTime? _lastSeekTime;
  bool? _lastSeekPlayingState; // El estado de playing antes del seek
  
  // 🛡️ PROTECCIÓN: Flag para rastrear cuando estamos cambiando de canción
  // Evita que los listeners de posición reinicien la posición durante el cambio
  bool _isChangingSong = false;
  DateTime? _songChangeStartTime;
  
  // ⚡ PROTECCIÓN: Flag para evitar múltiples toques simultáneos en pause/play
  bool _isToggling = false;
  
  // 🆕 FLAG: Activar algoritmo cuando termine la canción actual (desde playFromCard)
  bool _shouldActivateAlgorithmOnCompletion = false;
  
  // 🆕 MEJORA 1: Precarga de siguiente canción
  Song? _preloadedNextSong;
  bool _isPreloadingNext = false;
  bool _hasTriggeredPreload = false; // Evitar múltiples precargas
  
  // ⚡ OPTIMIZACIÓN SPOTIFY: Precargar audio del player antes de que termine
  AudioPlayer? _preloadedPlayer;
  String? _preloadedSongId;

  // 🎵 STREAMS TRACKING
  final StreamsApi _streamsApi = StreamsApi();
  int _lastTrackedProgressMs = 0;
  static const int _streamTrackIntervalMs = 5000; // Trackear cada 5 segundos de progreso

  // 🆕 MEJORA 3: Historial de últimas canciones reproducidas (protección contra loops)
  final List<String> _recentSongIds = [];
  static const int _maxRecentSongs = 3; // Últimas 3 canciones (reducido para más variedad)
  
  // 🎯 SPOTIFY-STYLE QUEUE SYSTEM
  /// Cola principal hacia adelante (Upcoming Queue)
  /// Contiene: recomendaciones precargadas, playlist, orden de reproducción
  final List<Song> _upcomingQueue = [];
  
  /// Pila de historial (History Stack) - LIFO
  /// Contiene canciones ya reproducidas en orden inverso (más reciente al final)
  final List<Song> _historyStack = [];
  static const int _maxHistorySize = 50;
  
  // 🎵 PLAYLIST MODE: Lista de canciones para modo fixedQueue
  List<Song> _fixedQueueSongs = [];
  
  // ⚡ LEGACY: Mantener para compatibilidad temporal durante migración
  final List<Song> _userQueue = [];
  final List<Song> _algorithmQueue = [];
  
  /// PlaySession: Información de la sesión de reproducción actual
  int _currentIndex = 0;
  
  /// Cooldowns para evitar repeticiones
  String? _lastArtistId; // Último artista reproducido (cooldown 1 canción)
  final Set<String> _recentAlgorithmSongs = {}; // Canciones recientes del algoritmo (máx 20)
  static const int _maxRecentAlgorithmSongs = 20;
  
  /// Precarga continua (prefetch) - OPTIMIZADO
  Song? _prefetchedNextSong;
  bool _isPrefetching = false;
  bool _isGeneratingQueue = false; // Flag para evitar múltiples generaciones simultáneas
  static const int _minAlgorithmQueueSize = 15; // ⚡ Cola optimizada (reducida de 20 a 15)
  static const int _maxConcurrentRequests = 6; // ⚡ Llamadas concurrentes optimizadas (reducido de 20)
  static const int _batchRegenerationThreshold = 5; // ⚡ Regenerar cuando quedan 5 canciones
  DateTime? _lastPrefetchTime; // Para evitar precargas muy frecuentes
  
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

  /// ✅ Inicializar ambos AudioPlayers usando ProfessionalAudioService
  void _initializePlayer() {
    if (_isInitialized) {
      return;
    }
    
    try {
      // Inicializar ambos reproductores
      _algorithmPlayer = AudioPlayer();
      _fixedQueuePlayer = AudioPlayer();
      
      // Configurar listeners para el reproductor de algoritmo por defecto
      _setupListenersForActivePlayer();
      _isInitialized = true;
      AppLogger.info('[UnifiedAudioNotifier] ✅ Ambos AudioPlayers inicializados');
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error inicializando AudioPlayers: $e');
    }
  }
  
  /// ⚡ CRÍTICO: Detener el reproductor activo ANTES de cambiar de modo
  /// Se usa cuando se va a cambiar de modo para asegurar que el reproductor actual se detenga
  /// @param currentMode: El modo actual ANTES del cambio (para determinar qué reproductor está activo)
  Future<void> _stopActivePlayerBeforeModeChange({PlaybackMode? currentMode}) async {
    try {
      // Usar el modo proporcionado o el modo actual del estado
      final modeToCheck = currentMode ?? state.playbackMode;
      
      // Determinar qué reproductor está activo basado en el modo ACTUAL
      AudioPlayer? currentActivePlayer;
      switch (modeToCheck) {
        case PlaybackMode.algorithm:
          currentActivePlayer = _algorithmPlayer;
          break;
        case PlaybackMode.fixedQueue:
          currentActivePlayer = _fixedQueuePlayer;
          break;
        case PlaybackMode.none:
          currentActivePlayer = null;
          break;
      }
      
      if (currentActivePlayer != null) {
        final playerState = currentActivePlayer.playerState;
        if (playerState.playing || playerState.processingState != ProcessingState.idle) {
          // ⚡ CRÍTICO: Detener completamente el reproductor activo (no solo pausar)
          await currentActivePlayer.setVolume(0.0);
          await currentActivePlayer.stop();
          await currentActivePlayer.pause();
          AppLogger.info('[UnifiedAudioNotifier] 🛑 Reproductor activo detenido antes de cambiar modo (${modeToCheck.name})');
        }
      }
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] Error deteniendo reproductor activo: $e');
    }
  }

  /// Pausar el reproductor inactivo cuando cambia el modo (no bloqueante)
  void _pauseInactivePlayer() {
    try {
      final inactivePlayer = state.playbackMode == PlaybackMode.algorithm
          ? _fixedQueuePlayer
          : _algorithmPlayer;
      
      if (inactivePlayer != null) {
        final playerState = inactivePlayer.playerState;
        if (playerState.playing) {
          // ✅ NO BLOQUEANTE: Pausar sin await para no bloquear la UI
          inactivePlayer.pause().catchError((e) {
            // Ignorar errores al pausar reproductor inactivo
            AppLogger.error('[UnifiedAudioNotifier] Error pausando reproductor inactivo: $e');
          });
        }
      }
    } catch (e) {
      // Ignorar errores al pausar reproductor inactivo
      AppLogger.error('[UnifiedAudioNotifier] Error pausando reproductor inactivo: $e');
    }
  }
  
  /// Configurar listeners para el reproductor activo actual
  /// ✅ OPTIMIZADO: Configura listeners de forma asíncrona para no bloquear
  void _setupListenersForActivePlayer() {
    // ✅ Diferir la configuración al siguiente microtask para evitar bloqueos
    Future.microtask(() {
      _setupListenersForActivePlayerSync();
    });
  }
  
  /// ⚡ Configurar listeners de forma SINCRONA para cambio inmediato
  void _setupListenersForActivePlayerSync() {
    final player = _activePlayer;
    if (player == null) return;
    
    // Cancelar suscripciones anteriores
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    
    // Resetear cache de valores previos al cambiar de reproductor
    _lastPosition = null;
    _lastDuration = null;
    _lastPlayerState = null;
    
    // Configurar listeners del reproductor activo INMEDIATAMENTE
    _positionSubscription = player.positionStream.listen((position) {
      if (_lastPosition == null || _lastPosition!.inMilliseconds != position.inMilliseconds) {
        _lastPosition = position;
        _updatePosition(position);
      }
    });

    _durationSubscription = player.durationStream.listen((duration) {
      if (duration != null && (_lastDuration == null || _lastDuration != duration)) {
        _lastDuration = duration;
        _updateDuration(duration);
      }
    });

    _playerStateSubscription = player.playerStateStream.listen((playerState) {
      if (_lastPlayerState == null || _lastPlayerState != playerState) {
        _lastPlayerState = playerState;
        _updatePlayerState(playerState);
      }
    });
    
    // ✅ IMPORTANTE: Sincronizar estado inicial del reproductor activo
    // Esto asegura que el mini player muestre el estado correcto al cambiar de modo
    final currentPlayerState = player.playerState;
    if (state.isPlaying != currentPlayerState.playing) {
      state = state.copyWith(isPlaying: currentPlayerState.playing);
    }
  }


  /// ✅ Actualizar posición - OPTIMIZADO: comparar en milisegundos para evitar actualizaciones microscópicas
  /// 🆕 MEJORA 1: Detecta cuando queden 10-15 segundos para precargar siguiente canción
  /// 🎵 STREAMS: Trackear progreso cada 5 segundos
  /// 🎵 PLAYLIST: Detecta cuando la canción termina por posición (backup para ProcessingState.completed)
  void _updatePosition(Duration position) {
    // 🛡️ PROTECCIÓN ULTRA-RÁPIDA: Solo ignorar posición cero por tiempo MUY corto
    // Para cambio inmediato, la protección solo dura 100ms
    if (_isChangingSong && position.inMilliseconds == 0) {
      final timeSinceChange = _songChangeStartTime != null 
          ? DateTime.now().difference(_songChangeStartTime!).inMilliseconds 
          : 0;
      final currentPositionInState = state.currentPosition.inMilliseconds;
      
      // Solo ignorar si la posición en el estado también es cero y han pasado menos de 100ms
      // Tiempo muy corto para permitir cambio inmediato
      if (currentPositionInState == 0 && timeSinceChange < 100) {
        return; // Ignorar silenciosamente para no afectar rendimiento
      }
      
      // Auto-reset inmediato después de 100ms
      if (timeSinceChange >= 100) {
        _isChangingSong = false;
        _songChangeStartTime = null;
      }
    }
    
    // 🛡️ PROTECCIÓN ADICIONAL: Auto-reset del flag si pasó mucho tiempo (prevenir bloqueo)
    if (_isChangingSong && _songChangeStartTime != null) {
      final timeSinceChange = DateTime.now().difference(_songChangeStartTime!).inMilliseconds;
      if (timeSinceChange > 500) {
        _isChangingSong = false;
        _songChangeStartTime = null;
      }
    }
    
    // Comparar en milisegundos para evitar actualizaciones redundantes de microsegundos
    if (position.inMilliseconds != state.currentPosition.inMilliseconds) {
      state = state.copyWith(currentPosition: position);
      
      // 🎵 BACKUP: Si estamos en modo fixedQueue y la posición alcanzó o superó la duración total
      // (con un pequeño margen de 100ms para compensar latencias), avanzar a siguiente canción
      if (state.playbackMode == PlaybackMode.fixedQueue && 
          state.totalDuration.inMilliseconds > 0 &&
          !_isSearchingNextSong &&
          state.isPlaying &&
          position.inMilliseconds > 0 &&
          position.inMilliseconds >= (state.totalDuration.inMilliseconds - 100)) {
        // Marcar inmediatamente para evitar múltiples llamadas
        _isSearchingNextSong = true;
        AppLogger.info('[UnifiedAudioNotifier] 🎵 Canción completada por posición (backup) - posición: ${position.inMilliseconds}ms, duración: ${state.totalDuration.inMilliseconds}ms');
        
        // Llamar inmediatamente (sin delay) pero en un microtask para no bloquear
        Future.microtask(() async {
          try {
            await _handlePlaylistSongCompletion();
          } catch (e) {
            AppLogger.error('[UnifiedAudioNotifier] ❌ Error en backup completion: $e');
          } finally {
            // Solo resetear si seguimos en fixedQueue (puede haber cambiado durante la navegación)
            if (state.playbackMode == PlaybackMode.fixedQueue) {
              _isSearchingNextSong = false;
            }
          }
        });
      }
      
      // 🎵 STREAMS TRACKING: Trackear progreso cada 5 segundos de reproducción
      // Guardar valores antes de actualizar state para evitar problemas de estado
      final currentSong = state.currentSong;
      final isPlaying = state.isPlaying;
      final totalDuration = state.totalDuration;
      final progressMs = position.inMilliseconds;
      
      if (currentSong != null && 
          isPlaying && 
          totalDuration.inMilliseconds > 0) {
        final durationMs = totalDuration.inMilliseconds;
        final progressDelta = progressMs - _lastTrackedProgressMs;
        
        // Trackear si han pasado al menos 5 segundos de progreso
        if (progressDelta >= _streamTrackIntervalMs) {
          _lastTrackedProgressMs = progressMs;
          
          // Trackear en background (no bloquear UI) - sin logs verbosos
          _trackStreamProgress(
            songId: currentSong.id,
            progressMs: progressMs,
            durationMs: durationMs,
            volume: state.volume,
          );
        }
      }
      
      // ⚡ OPTIMIZACIÓN SPOTIFY: Precarga más temprana (20-25 segundos antes del final)
      if (state.playbackMode == PlaybackMode.algorithm &&
          state.currentSong != null && 
          state.totalDuration.inMilliseconds > 0 &&
          !_isPreloadingNext && 
          !_hasTriggeredPreload) {
        final remaining = state.totalDuration - position;
        // Precargar cuando queden 20-25 segundos (más temprano que antes)
        if (remaining.inSeconds <= 25 && remaining.inSeconds >= 20) {
          _hasTriggeredPreload = true;
          _preloadNextSong();
        }
      }
    }
  }
  
  /// 🎵 Trackear progreso de stream en background
  void _trackStreamProgress({
    required String songId,
    required int progressMs,
    required int durationMs,
    required double volume,
  }) {
    // Ejecutar en background sin bloquear
    Future.microtask(() async {
      try {
        // Detectar si la app está en foreground (aproximado)
        final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        
        await _streamsApi.trackProgress(
          songId: songId,
          progressMs: progressMs,
          durationMs: durationMs,
          volume: volume,
          isForeground: isForeground,
        );
      } catch (e) {
        // Ignorar errores silenciosamente
      }
    });
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
    
    // 🎵 LOG: Debug para detectar cuando cambia el processingState
    if (playerState.processingState == ProcessingState.completed) {
      AppLogger.info('[UnifiedAudioNotifier] ✅ ProcessingState.completed detectado - playbackMode: ${state.playbackMode}, isSearching: $_isSearchingNextSong');
    }

    // 🛡️ PROTECCIÓN: Si acabamos de hacer un seek, proteger el estado de playing
    // durante los primeros 1000ms para evitar que el stream lo sobrescriba
    final now = DateTime.now();
    if (_lastSeekTime != null && _lastSeekPlayingState != null) {
      final seekElapsed = now.difference(_lastSeekTime!).inMilliseconds;
      
      if (seekElapsed < 1000) {
        // Durante los primeros 1000ms después de un seek, mantener el estado de playing que había antes
        // Solo actualizar buffering si cambió
        if (state.isBuffering != newIsBuffering || state.isPlaying != _lastSeekPlayingState) {
          state = state.copyWith(
            isPlaying: _lastSeekPlayingState!,
            isBuffering: newIsBuffering,
          );
        }
        
        // ✅ Si el stream confirma el estado protegido después de 500ms, limpiar protección temprana
        if (newIsPlaying == _lastSeekPlayingState && seekElapsed >= 500) {
          _lastSeekTime = null;
          _lastSeekPlayingState = null;
          // Continuar con el flujo normal
        } else {
          return; // Salir temprano para evitar procesar más lógica
        }
      } else {
        // Período de protección terminado - verificación final
        if (_lastSeekPlayingState == true && !newIsPlaying) {
          final player = _activePlayer;
          if (player != null && !player.playerState.playing) {
            // Reanudar en background sin bloquear
            player.play().catchError((e) {
              AppLogger.error('[UnifiedAudioNotifier] ❌ Error al reanudar después de seek: $e');
            });
            // Mantener el estado como playing mientras se reanuda
            state = state.copyWith(isPlaying: true, isBuffering: newIsBuffering);
          }
        }
        
        // Limpiar flags
        _lastSeekTime = null;
        _lastSeekPlayingState = null;
      }
    }

    // 🛡️ PROTECCIÓN: Si acabamos de hacer una operación manual de toggle/play,
    // ignorar actualizaciones del stream durante los primeros 1000ms para evitar
    // que sobrescriba el estado optimista antes de que la operación se complete
    if (_lastManualToggleTime != null && 
        _lastManualToggleState != null) {
      final toggleElapsed = now.difference(_lastManualToggleTime!).inMilliseconds;
      
      if (toggleElapsed < 1000) {
        // Durante los primeros 1000ms después de un toggle/play manual, usar el estado manual
      // Solo actualizar buffering, pero mantener el estado de playing del toggle manual
        if (state.isBuffering != newIsBuffering || state.isPlaying != _lastManualToggleState) {
        state = state.copyWith(
          isPlaying: _lastManualToggleState!,
          isBuffering: newIsBuffering,
        );
      }
        
        // Si el stream confirma el estado protegido después de 500ms, limpiar protección temprana
        if (newIsPlaying == _lastManualToggleState && toggleElapsed >= 500) {
          _lastManualToggleTime = null;
          _lastManualToggleState = null;
          // Continuar con el flujo normal
    } else {
          return; // Salir temprano para evitar procesar más lógica
        }
      } else {
        // Período de protección terminado - verificación final
        if (_lastManualToggleState == true && !newIsPlaying) {
          final player = _activePlayer;
          if (player != null && !player.playerState.playing) {
            // Reanudar en background sin bloquear
            player.play().catchError((e) {
              AppLogger.error('[UnifiedAudioNotifier] ❌ Error al reanudar después de play: $e');
            });
            // Mantener el estado como playing mientras se reanuda
            state = state.copyWith(isPlaying: true, isBuffering: newIsBuffering);
          }
        }
        
        // Limpiar flags
        _lastManualToggleTime = null;
        _lastManualToggleState = null;
      }
    }
    
    // Actualizar normalmente desde el stream si no hay protección activa
    if (_lastManualToggleTime == null) {
      if (state.isPlaying != newIsPlaying || state.isBuffering != newIsBuffering) {
        AppLogger.info('[UnifiedAudioNotifier] 🔄 [UPDATE_STATE] Actualizando estado: playing=$newIsPlaying, buffering=$newIsBuffering');
        state = state.copyWith(
          isPlaying: newIsPlaying,
          isBuffering: newIsBuffering,
        );
      }
    }

    // ✅ MANEJAR COMPLETACIÓN DE CANCIÓN
    if (playerState.processingState == ProcessingState.completed) {
      AppLogger.info('[UnifiedAudioNotifier] 🎵 ProcessingState.completed detectado - modo: ${state.playbackMode}, isSearching: $_isSearchingNextSong, algoritmo flag: $_shouldActivateAlgorithmOnCompletion');
      
      // ✅ CORREGIDO: Si el flag está en true pero no se está buscando realmente, resetearlo
      // Esto puede pasar si el flag se quedó activo de una búsqueda anterior o del backup de posición
      if (_isSearchingNextSong) {
        AppLogger.warning('[UnifiedAudioNotifier] ⚠️ Flag _isSearchingNextSong está en true, pero se detectó completed. Reseteando para permitir búsqueda...');
        _isSearchingNextSong = false;
      }
      
      // 🛡️ Protección: Marcar que estamos buscando siguiente canción
      _isSearchingNextSong = true;
      
      // ✅ CORREGIDO: Si viene de playFromCard y el flag está activo, asegurar que estamos en modo algoritmo
      // IMPORTANTE: Guardar el flag antes de resetearlo para usarlo después
      final shouldActivateAlgorithm = _shouldActivateAlgorithmOnCompletion;
      
      if (_shouldActivateAlgorithmOnCompletion) {
        if (state.playbackMode != PlaybackMode.algorithm) {
          AppLogger.info('[UnifiedAudioNotifier] 🎵 Activando modo algoritmo desde flag');
          // Cambiar a modo algoritmo
          state = state.copyWith(playbackMode: PlaybackMode.algorithm);
          _pauseInactivePlayer();
          _setupListenersForActivePlayer();
        }
        // ✅ Resetear flag después de usarlo
        _shouldActivateAlgorithmOnCompletion = false;
      }
      
      // Buscar siguiente canción según el modo activo
      // ✅ CORREGIDO: Si el flag estaba activo, forzar modo algoritmo incluso si no se cambió correctamente
      if (state.playbackMode == PlaybackMode.algorithm || shouldActivateAlgorithm) {
        // Si el flag estaba activo pero el modo no es algorithm, cambiarlo ahora
        if (shouldActivateAlgorithm && state.playbackMode != PlaybackMode.algorithm) {
          AppLogger.info('[UnifiedAudioNotifier] 🎵 Forzando modo algoritmo desde flag (backup)');
          state = state.copyWith(playbackMode: PlaybackMode.algorithm);
          _pauseInactivePlayer();
          _setupListenersForActivePlayer();
        }
        AppLogger.info('[UnifiedAudioNotifier] 🎵 Activando algoritmo para siguiente canción');
        _handleSongCompletion();
      } else if (state.playbackMode == PlaybackMode.fixedQueue) {
        // ✅ Avanzar a la siguiente canción en la playlist
        AppLogger.info('[UnifiedAudioNotifier] 🎵 Canción completada en modo fixedQueue, avanzando a siguiente...');
        _handlePlaylistSongCompletion().then((_) {
          _isSearchingNextSong = false; // Resetear después de avanzar
          AppLogger.info('[UnifiedAudioNotifier] ✅ Avanzó correctamente a siguiente canción');
        }).catchError((e) {
          AppLogger.error('[UnifiedAudioNotifier] ❌ Error en _handlePlaylistSongCompletion: $e');
          _isSearchingNextSong = false; // Resetear en caso de error
        });
      } else {
        AppLogger.info('[UnifiedAudioNotifier] ⚠️ Sin modo activo, pausando');
        _isSearchingNextSong = false; // Resetear si no hay modo activo
      }
    }
  }

  /// ✅ Manejar cuando una canción termina en modo PLAYLIST (fixedQueue)
  Future<void> _handlePlaylistSongCompletion() async {
    AppLogger.info('[UnifiedAudioNotifier] 🎵 _handlePlaylistSongCompletion llamado');
    AppLogger.info('[UnifiedAudioNotifier] 📋 _fixedQueueSongs.length: ${_fixedQueueSongs.length}');
    AppLogger.info('[UnifiedAudioNotifier] 🎵 currentSong: ${state.currentSong?.title}');
    AppLogger.info('[UnifiedAudioNotifier] 🎛️ playbackMode: ${state.playbackMode}');
    
    if (_fixedQueueSongs.isEmpty || state.currentSong == null) {
      AppLogger.info('[UnifiedAudioNotifier] ⏸️ No hay más canciones en la playlist');
      state = state.copyWith(isPlaying: false);
      return;
    }

    try {
      // Encontrar índice de la canción actual
      final currentIndex = _fixedQueueSongs.indexWhere((s) => s.id == state.currentSong?.id);
      
      AppLogger.info('[UnifiedAudioNotifier] 📍 currentIndex: $currentIndex de ${_fixedQueueSongs.length}');
      
      if (currentIndex == -1) {
        AppLogger.error('[UnifiedAudioNotifier] ⚠️ Canción actual no encontrada en playlist');
        AppLogger.error('[UnifiedAudioNotifier] ⚠️ Buscando: ${state.currentSong?.id}');
        AppLogger.error('[UnifiedAudioNotifier] ⚠️ Disponibles: ${_fixedQueueSongs.map((s) => s.id).join(", ")}');
        return;
      }

      // Determinar siguiente canción según modo de repetición
      Song? nextSong;
      
      if (state.repeatMode == RepeatMode.one) {
        // Repetir la misma canción
        nextSong = state.currentSong;
      } else if (currentIndex < _fixedQueueSongs.length - 1) {
        // Siguiente canción en la lista
        nextSong = _fixedQueueSongs[currentIndex + 1];
      } else if (state.repeatMode == RepeatMode.all) {
        // Repetir desde el inicio
        nextSong = _fixedQueueSongs.first;
      } else {
        // Sin repetición, pausar
        AppLogger.info('[UnifiedAudioNotifier] ⏸️ Fin de playlist');
        state = state.copyWith(isPlaying: false);
        return;
      }

      if (nextSong == null || nextSong.fileUrl == null || nextSong.fileUrl!.isEmpty) {
        AppLogger.error('[UnifiedAudioNotifier] ⚠️ Siguiente canción no válida');
        state = state.copyWith(isPlaying: false);
        return;
      }

      // Reproducir siguiente canción
      final player = _fixedQueuePlayer;
      if (player == null) {
        AppLogger.error('[UnifiedAudioNotifier] ❌ fixedQueuePlayer no inicializado');
        return;
      }

      // ⚡ CRÍTICO: Guardar canción actual ANTES de actualizar el estado
      final currentSongBeforeChange = state.currentSong;
      
      // ⚡ HISTORIAL PARA PREVIOUS: Guardar canción actual en historial
      // ✅ ARREGLADO: Guardar ANTES de cambiar el estado para capturar la canción correcta
      if (currentSongBeforeChange != null && currentSongBeforeChange.id != nextSong.id) {
        // Verificar que no esté ya en el historial (evitar duplicados consecutivos)
        if (_historyStack.isEmpty || (_historyStack.isNotEmpty && _historyStack.last.id != currentSongBeforeChange.id)) {
          _historyStack.add(currentSongBeforeChange);
          if (_historyStack.length > _maxHistorySize) {
            _historyStack.removeAt(0);
          }
          AppLogger.info('[UnifiedAudioNotifier] 📝 Guardada en historial (playlist next): ${currentSongBeforeChange.title}');
        }
      }

      // Actualizar estado
      state = state.copyWith(
        currentSong: nextSong,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
        isPlaying: true,
      );

      // Agregar al historial de canciones recientes
      _recentSongIds.add(nextSong.id);
      if (_recentSongIds.length > _maxRecentSongs) {
        _recentSongIds.removeAt(0);
      }

      // 🛡️ PROTECCIÓN: Activar flag de cambio de canción y cancelar listeners
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _playerStateSubscription?.cancel();
      _positionSubscription = null;
      _durationSubscription = null;
      _playerStateSubscription = null;
      
      _isChangingSong = true;
      _songChangeStartTime = DateTime.now();
      
      // Cargar y reproducir INMEDIATAMENTE
      final normalizedUrl = UrlNormalizer.normalizeUrl(nextSong.fileUrl!);
      await player.setUrl(normalizedUrl);
      
      final duration = player.duration ?? Duration.zero;
      state = state.copyWith(totalDuration: duration);
      
      await player.play();
      player.setVolume(1.0);

      // Resetear tracking de streams
      _lastTrackedProgressMs = 0;
      _streamsApi.resetRateLimit();
      
      // ⚡ CONFIGURACIÓN INMEDIATA: Configurar listeners SIN DELAY
      _setupListenersForActivePlayerSync();
      
      // ⚡ Resetear flag muy rápido (50ms)
      Future.microtask(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        _isChangingSong = false;
        _songChangeStartTime = null;
      });

      AppLogger.info('[UnifiedAudioNotifier] ⏭️ Reproduciendo siguiente: ${nextSong.title}');
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error en _handlePlaylistSongCompletion: $e');
      state = state.copyWith(isPlaying: false);
    }
  }

  /// ⚡ SPOTIFY-STYLE: Manejar cuando una canción termina con sistema de colas duales
  void _handleSongCompletion() {
    // 🛡️ PROTECCIÓN: Evitar múltiples llamadas simultáneas
    if (_isSearchingNextSong) {
      _isSearchingNextSong = false;
    }

    final currentSong = state.currentSong;
    if (currentSong == null) {
      _isSearchingNextSong = false;
      return;
    }

    // ✅ MARCAR COMO EN PROCESO
    _isSearchingNextSong = true;

    // ✅ TRANSICIÓN FLUIDA: Mantener estado visual mientras busca siguiente
    state = state.copyWith(currentPosition: state.totalDuration);
    
    // ⚡ SPOTIFY-STYLE: Usar sistema de colas duales
    _triggerNextSongFromQueues();
  }

  /// ⚡ SPOTIFY-STYLE: Activar siguiente canción desde colas
  void _triggerNextSongFromQueues() async {
    try {
      // Solo funciona en modo algoritmo
      if (state.playbackMode != PlaybackMode.algorithm) {
        _resetSearchState();
        return;
      }

      // ⚡ LÓGICA SPOTIFY: userQueue tiene prioridad sobre algorithmQueue
      if (_userQueue.isNotEmpty) {
        // Reproducir desde userQueue
        await playFromUserQueue();
      } else if (_algorithmQueue.isNotEmpty) {
        // Reproducir desde algorithmQueue
        await playFromAlgorithmQueue();
      } else {
        // Si ambas están vacías, regenerar
        AppLogger.warning('[SPOTIFY-ALGORITHM] ⚠️ Ambas colas vacías en completion, regenerando...');
        final currentSong = state.currentSong;
        if (currentSong != null) {
          await regenerateRecommendations(currentSong);
          if (_algorithmQueue.isNotEmpty) {
            await playFromAlgorithmQueue();
          } else {
            state = state.copyWith(isPlaying: false);
          }
        } else {
          state = state.copyWith(isPlaying: false);
        }
      }
      
    } catch (e) {
      AppLogger.error('[SPOTIFY-ALGORITHM] ❌ Error en completion: $e');
      _resetSearchState();
      state = state.copyWith(isPlaying: false);
    } finally {
      _isSearchingNextSong = false;
    }
  }

  /// ⚡ OPTIMIZACIÓN SPOTIFY: Búsqueda paralela y reproducción instantánea
  Future<void> _findAndPlayNextSong(Song currentSong) async {
    try {
      Song? nextSong;
      
      // ⚡ Estrategia 0 - Usar canción precargada (MÁS RÁPIDO)
      if (_preloadedNextSong != null && _isValidNextSong(_preloadedNextSong!, currentSong)) {
        nextSong = _preloadedNextSong;
        _preloadedNextSong = null;
        _hasTriggeredPreload = false;
      }
      
      // ⚡ Si no hay precarga, buscar con timeout ultra-agresivo
      if (nextSong == null) {
          final recommendationService = SpotifyRecommendationService(HttpClientService());
          
        // ⚡ ESTRATEGIA 1: Intentar algoritmo principal primero (timeout 600ms)
        try {
          nextSong = await recommendationService.getSmartRecommendation(
            currentSongId: currentSong.id,
            genres: currentSong.genres,
            user: null,
          ).timeout(
            const Duration(milliseconds: 600),
            onTimeout: () => null,
          );
          
          if (nextSong != null && !_isValidNextSong(nextSong, currentSong, allowRecent: false)) {
            nextSong = null;
          }
        } catch (e) {
          nextSong = null;
        }
        
        // ⚡ ESTRATEGIA 2: Si no se encontró, buscar fallbacks en paralelo con timeout corto (400ms)
        if (nextSong == null) {
          final fallbackFutures = <Future<Song?>>[];
          
          if (currentSong.genres != null && currentSong.genres!.isNotEmpty) {
            fallbackFutures.add(
              _getGenreFallback(currentSong)
                  .timeout(const Duration(milliseconds: 400), onTimeout: () => null)
                  .catchError((_) => null),
            );
          }
          
          if (currentSong.artistId != null) {
            fallbackFutures.add(
              _getArtistFallback(currentSong)
                  .timeout(const Duration(milliseconds: 400), onTimeout: () => null)
                  .catchError((_) => null),
            );
          }
          
          fallbackFutures.add(
            _getFeaturedFallback(currentSong)
                .timeout(const Duration(milliseconds: 400), onTimeout: () => null)
                .catchError((_) => null),
          );
          
          // ⚡ RACE: Tomar la primera que responda válida
          if (fallbackFutures.isNotEmpty) {
            try {
              final firstResult = await Future.any(fallbackFutures)
                  .timeout(const Duration(milliseconds: 400), onTimeout: () => null);
              
              if (firstResult != null && _isValidNextSong(firstResult, currentSong)) {
                nextSong = firstResult;
          }
        } catch (e) {
              // Si falla, intentar obtener cualquier resultado disponible
              final results = await Future.wait(fallbackFutures, eagerError: false)
                  .timeout(const Duration(milliseconds: 300), onTimeout: () => <Song?>[]);
              
              for (final result in results) {
                if (result != null && _isValidNextSong(result, currentSong)) {
                  nextSong = result;
                  break;
                }
              }
            }
          }
        }
      }

      // ⚡ REPRODUCIR SIGUIENTE CANCIÓN - OPTIMIZADO PARA VELOCIDAD
          if (nextSong != null) {
        
        // ⚡ Si el audio ya está precargado, usar ese player directamente
        if (_preloadedPlayer != null && 
            _preloadedSongId == nextSong.id &&
            _preloadedPlayer!.playerState.processingState != ProcessingState.idle) {
          // Cambiar a modo algoritmo si es necesario
          if (state.playbackMode != PlaybackMode.algorithm) {
            state = state.copyWith(playbackMode: PlaybackMode.algorithm);
            _pauseInactivePlayer();
          }
          
          // ⚡ REPRODUCCIÓN INSTANTÁNEA: El audio ya está cargado en _algorithmPlayer
          final currentPlayer = _activePlayer;
          if (currentPlayer != null && currentPlayer != _preloadedPlayer) {
            await currentPlayer.stop();
          }
          
          // ⚡ CRÍTICO: Guardar canción actual ANTES de actualizar el estado
          final currentSongBeforeChange = state.currentSong;
          final preloadedDuration = _preloadedPlayer!.duration ?? Duration.zero;
          
          // ⚡ HISTORIAL PARA PREVIOUS: Guardar canción actual en historial
          // ✅ ARREGLADO: Guardar ANTES de cambiar el estado para capturar la canción correcta
          if (currentSongBeforeChange != null && currentSongBeforeChange.id != nextSong.id) {
            // Verificar que no esté ya en el historial (evitar duplicados consecutivos)
            if (_historyStack.isEmpty || (_historyStack.isNotEmpty && _historyStack.last.id != currentSongBeforeChange.id)) {
              _historyStack.add(currentSongBeforeChange);
              if (_historyStack.length > _maxHistorySize) {
                _historyStack.removeAt(0);
              }
              AppLogger.info('[UnifiedAudioNotifier] 📝 Guardada en historial (algorithm precargada): ${currentSongBeforeChange.title}');
            }
          }
          
          // Agregar al historial de canciones recientes
          _recentSongIds.add(nextSong.id);
          if (_recentSongIds.length > _maxRecentSongs) {
            _recentSongIds.removeAt(0);
          }
          
          // Resetear tracking
          _lastTrackedProgressMs = 0;
          _streamsApi.resetRateLimit();
          
        state = state.copyWith(
            currentSong: nextSong,
            isPlaying: true,
            currentPosition: Duration.zero,
            totalDuration: preloadedDuration,
          );
          
          // ⚡ Reproducir inmediatamente (el audio ya está cargado - 0ms de delay)
          await _preloadedPlayer!.play();
          _preloadedPlayer!.setVolume(1.0);
          
          // Configurar listeners
          _setupListenersForActivePlayer();
          
          // Limpiar precarga
          _preloadedPlayer = null;
          _preloadedSongId = null;
          
          // ✅ CONECTADO: Activar precarga de la siguiente canción después de cambiar
          _schedulePrefetch();
        } else {
          // Si no hay precarga, usar método normal (pero optimizado)
          // playSong() ya llama a _schedulePrefetch() internamente
          await playSong(nextSong, useAlgorithm: true);
        }
      } else {
        // ⏸️ MANTENER PAUSADO SI NO HAY SIGUIENTE
        state = state.copyWith(isPlaying: false);
      }

    } catch (e) {
      // ⏸️ MANTENER PAUSADO EN CASO DE ERROR
      state = state.copyWith(isPlaying: false);
    } finally {
      // 🛡️ SIEMPRE RESETEAR ESTADO DE BÚSQUEDA Y PRECARGA
      _resetSearchState();
      _preloadedNextSong = null;
      _hasTriggeredPreload = false;
      _preloadedPlayer = null;
      _preloadedSongId = null;
    }
  }
  
  /// ⚡ OPTIMIZACIÓN SPOTIFY: Precargar siguiente canción y su audio
  Future<void> _preloadNextSong() async {
    if (_isPreloadingNext || state.currentSong == null) return;
    
    _isPreloadingNext = true;
    
    try {
      final currentSong = state.currentSong!;
      final nextSong = await _findNextSong(currentSong);
      
      if (nextSong != null && _isValidNextSong(nextSong, currentSong)) {
        _preloadedNextSong = nextSong;
        
        // ⚡ PRECARGAR AUDIO EN EL PLAYER DE ALGORITMO (técnica de Spotify)
        // Esto hace que el cambio de canción sea instantáneo
        if (nextSong.fileUrl != null && nextSong.fileUrl!.isNotEmpty) {
          try {
            // Siempre precargar en el player de algoritmo (el que usaremos)
            if (_algorithmPlayer != null) {
              final normalizedUrl = UrlNormalizer.normalizeUrl(nextSong.fileUrl!);
              // Precargar el audio sin reproducir
              await _algorithmPlayer!.setUrl(normalizedUrl);
              // Pausar inmediatamente (ya está cargado en memoria)
              await _algorithmPlayer!.pause();
              
              // Guardar referencia del player precargado
              _preloadedPlayer = _algorithmPlayer;
              _preloadedSongId = nextSong.id;
      }
    } catch (e) {
            // Ignorar errores de precarga de audio (no crítico)
          }
        }
      }
    } catch (e) {
      // Ignorar errores silenciosamente
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
  bool _isValidNextSong(Song nextSong, Song currentSong, {bool allowRecent = false}) {
    // Evitar la misma canción (siempre)
    if (nextSong.id == currentSong.id) {
      return false;
    }
    
    // 🆕 VALIDACIÓN PERMISIVA: Solo evitar la última canción reproducida
    if (!allowRecent && _recentSongIds.isNotEmpty) {
      // Solo rechazar si es la canción inmediatamente anterior (más reciente)
      if (_recentSongIds.first == nextSong.id) {
        return false;
      }
      // Permitir cualquier otra canción, incluso si está en el historial
    }
    
    // No validar última recomendada (muy restrictivo)
    
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
  /// ⚡ OPTIMIZACIÓN: También limpia precarga de audio
  void _resetSearchState() {
    _isSearchingNextSong = false;
    _isPreloadingNext = false;
    _hasTriggeredPreload = false;
    _preloadedPlayer = null;
    _preloadedSongId = null;
  }

  // ============================================================================
  // ⚡ SISTEMA SPOTIFY-STYLE: MODO ALGORITMO CON COLAS DUALES
  // ============================================================================

  /// 🎯 Limpiar todas las colas (userQueue, algorithmQueue, fixedQueue)
  void clearAllQueues() {
    _userQueue.clear();
    _algorithmQueue.clear();
    _fixedQueueSongs.clear();
    _prefetchedNextSong = null;
    _isPrefetching = false;
    AppLogger.info('[SPOTIFY-ALGORITHM] 🧹 Todas las colas limpiadas');
  }

  /// 🎯 Configurar modo algoritmo con canción seed - OPTIMIZADO
  /// Limpia colas previas y configura el sistema para modo algoritmo
  Future<void> setAlgorithmMode(Song songSeed) async {
    // ⚡ OPTIMIZACIÓN: Limpiar colas rápidamente (sin logs verbosos)
    _userQueue.clear();
    _algorithmQueue.clear();
    _upcomingQueue.clear();
    _prefetchedNextSong = null;
    _isPrefetching = false;
    
    // Asegurar que el reproductor de algoritmo esté inicializado
    if (_algorithmPlayer == null) {
      _initializePlayer();
    }
    
    // Limpiar modo playlist si estaba activo (sin await para no bloquear)
    if (state.playbackMode == PlaybackMode.fixedQueue) {
      _fixedQueuePlayer?.stop().catchError((_) {});
    }
    
    // Configurar PlaySession
    _currentIndex = 0;
    _lastArtistId = null;
    _recentAlgorithmSongs.clear();
    
    // Establecer userQueue con la canción seleccionada
    _userQueue.add(songSeed);
    
    // Cambiar a modo algoritmo
    state = state.copyWith(
      playbackMode: PlaybackMode.algorithm,
      contextId: null,
    );
    
    // Pausar reproductor inactivo y configurar listeners
    _pauseInactivePlayer();
    _setupListenersForActivePlayer();
    
    // ⚡ OPTIMIZACIÓN: Generar algorithmQueue en background DESPUÉS de un delay
    // Esto permite que la reproducción inicie primero
    Future.delayed(const Duration(milliseconds: 500), () {
      generateAlgorithmQueue(songSeed).catchError((_) {});
    });
  }

  /// 🎯 Generar cola de algoritmo con recomendaciones OPTIMIZADA
  /// Genera canciones recomendadas de forma más eficiente
  Future<void> generateAlgorithmQueue(Song seedSong) async {
    // Evitar múltiples generaciones simultáneas
    if (_isGeneratingQueue) return;
    
    _isGeneratingQueue = true;
    
    try {
      final recommendationService = SpotifyRecommendationService(HttpClientService());
      
      // ⚡ OPTIMIZACIÓN: Reducir de 20 a _maxConcurrentRequests llamadas concurrentes (más eficiente)
      // Calcular cuántas necesitamos realmente
      final needed = _minAlgorithmQueueSize - _algorithmQueue.length;
      final requestsToMake = needed > _maxConcurrentRequests ? _maxConcurrentRequests : (needed > 0 ? needed : _maxConcurrentRequests);
      
      // ⚡ OPTIMIZACIÓN: Usar Sets para validaciones O(1) en lugar de O(n)
      final existingIds = <String>{
        ..._algorithmQueue.map((s) => s.id),
        ..._userQueue.map((s) => s.id),
        ..._upcomingQueue.map((s) => s.id),
        seedSong.id,
      };
      
      final futures = <Future<Song?>>[];
      for (int i = 0; i < requestsToMake; i++) {
        futures.add(
          recommendationService.getSmartRecommendation(
            currentSongId: seedSong.id,
            genres: seedSong.genres,
            user: null,
            useCache: true,
          ).timeout(
            const Duration(milliseconds: 1500), // Timeout ligeramente aumentado para mejor éxito
            onTimeout: () => null,
          ).catchError((_) => null),
        );
      }
      
      // Esperar todas las recomendaciones en paralelo
      final results = await Future.wait(futures, eagerError: false);
      
      // Filtrar y agregar canciones válidas (optimizado con Sets)
      for (final song in results) {
        if (song != null && 
            !existingIds.contains(song.id) &&
            _isValidAlgorithmSongOptimized(song, seedSong, existingIds)) {
          _algorithmQueue.add(song);
          existingIds.add(song.id); // Actualizar Set para evitar duplicados
          _recentAlgorithmSongs.add(song.id);
          
          // También agregar a upcomingQueue para el nuevo sistema
          _upcomingQueue.add(song);
          
          if (_recentAlgorithmSongs.length > _maxRecentAlgorithmSongs) {
            final oldest = _recentAlgorithmSongs.first;
            _recentAlgorithmSongs.remove(oldest);
          }
        }
      }
      
      // Si no se generaron suficientes, usar fallbacks
      if (_algorithmQueue.length < _minAlgorithmQueueSize) {
        await _fillAlgorithmQueueWithFallbacks(seedSong, existingIds);
      }
      
      // Precargar la siguiente canción
      prefetchNext();
      
    } catch (e) {
      // Intentar fallbacks como último recurso
      await _fillAlgorithmQueueWithFallbacks(seedSong, <String>{});
    } finally {
      _isGeneratingQueue = false;
    }
  }

  /// 🎯 Regenerar recomendaciones de forma inteligente - OPTIMIZADA
  /// Solo regenera cuando realmente se necesita
  Future<void> regenerateRecommendations(Song lastSong) async {
    // ⚡ OPTIMIZACIÓN: Solo regenerar si realmente se necesita
    // Si ya hay suficientes canciones en las colas, no regenerar
    final totalAvailable = _algorithmQueue.length + _upcomingQueue.length + _userQueue.length;
    if (totalAvailable >= _batchRegenerationThreshold) {
      return; // Ya hay suficientes canciones
    }
    
    // Limpiar cooldown solo si no hay más opciones
    if (_algorithmQueue.isEmpty && _upcomingQueue.isEmpty) {
      _lastArtistId = null;
      // No limpiar completamente, solo reducir el tamaño
      if (_recentAlgorithmSongs.length > 10) {
        final toRemove = _recentAlgorithmSongs.length - 10;
        for (int i = 0; i < toRemove; i++) {
          _recentAlgorithmSongs.remove(_recentAlgorithmSongs.first);
        }
      }
    }
    
    // Generar nuevas recomendaciones en background (no bloqueante)
    generateAlgorithmQueue(lastSong).catchError((_) {
      // Error silencioso - se reintentará cuando se necesite
    });
  }

  /// 🎯 Validar si una canción es válida para el algoritmo (con cooldowns) - OPTIMIZADA
  bool _isValidAlgorithmSongOptimized(Song song, Song currentSong, Set<String> existingIds) {
    // No puede ser la misma canción
    if (song.id == currentSong.id) return false;
    
    // No puede estar en colas existentes (ya verificado con existingIds, pero doble check)
    if (existingIds.contains(song.id)) return false;
    
    // Cooldown de artista: no repetir artista consecutivo (1 canción de cooldown)
    if (_lastArtistId != null && 
        song.artistId == _lastArtistId && 
        currentSong.artistId == _lastArtistId) {
      return false;
    }
    
    // ⚡ MEJORADO: Evitar las últimas 6 canciones para reducir repeticiones
    final recentList = _recentAlgorithmSongs.toList();
    if (recentList.length >= 6 && recentList.take(6).contains(song.id)) {
      return false;
    } else if (recentList.length < 6 && recentList.contains(song.id)) {
      return false; // Si hay menos de 6, evitar todas
    }
    
    // Debe tener URL válida
    if (song.fileUrl == null || song.fileUrl!.isEmpty) return false;
    
    return true;
  }
  
  /// 🎯 Validar si una canción es válida para el algoritmo (método legacy para compatibilidad)
  bool _isValidAlgorithmSong(Song song, Song currentSong) {
    final existingIds = <String>{
      ..._algorithmQueue.map((s) => s.id),
      ..._userQueue.map((s) => s.id),
      ..._upcomingQueue.map((s) => s.id),
      currentSong.id,
    };
    return _isValidAlgorithmSongOptimized(song, currentSong, existingIds);
  }

  /// 🎯 Llenar algorithmQueue con fallbacks cuando no hay suficientes recomendaciones - OPTIMIZADA
  Future<void> _fillAlgorithmQueueWithFallbacks(Song seedSong, Set<String> existingIds) async {
    final fallbackFutures = <Future<Song?>>[];
    
    // ⚡ OPTIMIZACIÓN: Timeouts reducidos para fallbacks más rápidos
    if (seedSong.genres != null && seedSong.genres!.isNotEmpty) {
      fallbackFutures.add(
        _getGenreFallback(seedSong)
            .timeout(const Duration(milliseconds: 300), onTimeout: () => null)
            .catchError((_) => null),
      );
    }
    
    if (seedSong.artistId != null) {
      fallbackFutures.add(
        _getArtistFallback(seedSong)
            .timeout(const Duration(milliseconds: 300), onTimeout: () => null)
            .catchError((_) => null),
      );
    }
    
    fallbackFutures.add(
      _getFeaturedFallback(seedSong)
          .timeout(const Duration(milliseconds: 300), onTimeout: () => null)
          .catchError((_) => null),
    );
    
    final results = await Future.wait(fallbackFutures, eagerError: false);
    
    // ⚡ MEJORADO: Validación optimizada con Sets - evitar últimas 6 canciones
    final recentList = _recentAlgorithmSongs.toList();
    final recentSet = recentList.length >= 6 
        ? recentList.take(6).toSet() 
        : recentList.toSet();
    
    for (final song in results) {
      if (song != null && 
          !existingIds.contains(song.id) &&
          song.id != seedSong.id &&
          song.fileUrl != null && 
          song.fileUrl!.isNotEmpty &&
          !recentSet.contains(song.id)) {
        _algorithmQueue.add(song);
        _upcomingQueue.add(song);
        existingIds.add(song.id);
        _recentAlgorithmSongs.add(song.id);
        if (_recentAlgorithmSongs.length > _maxRecentAlgorithmSongs) {
          final oldest = _recentAlgorithmSongs.first;
          _recentAlgorithmSongs.remove(oldest);
        }
      }
    }
  }

  /// 🎯 Precargar siguiente canción (prefetch OPTIMIZADO)
  /// ⚡ OPTIMIZACIÓN MÁXIMA: Cooldown reducido para precargas más frecuentes
  Future<void> prefetchNext() async {
    // ⚡ Cooldown reducido de 2s a 500ms para más velocidad
    final now = DateTime.now();
    if (_lastPrefetchTime != null && 
        now.difference(_lastPrefetchTime!) < const Duration(milliseconds: 500)) {
      return;
    }
    
    if (_isPrefetching) return;
    
    // Determinar cuál será la siguiente canción
    Song? nextSong;
    
    if (_userQueue.isNotEmpty) {
      // Si hay canciones en userQueue, la siguiente es la primera
      nextSong = _userQueue.first;
    } else if (_algorithmQueue.isNotEmpty) {
      // Si userQueue está vacía, la siguiente es de algorithmQueue
      nextSong = _algorithmQueue.first;
    }
    
    // ✅ Si no hay siguiente canción en las colas, intentar generar una primero
    if (nextSong == null && state.currentSong != null && state.playbackMode == PlaybackMode.algorithm) {
      // Si las colas están vacías, regenerar recomendaciones primero
      if (_algorithmQueue.isEmpty) {
        await regenerateRecommendations(state.currentSong!).catchError((_) {});
        // Después de regenerar, intentar obtener la siguiente canción de nuevo
        if (_algorithmQueue.isNotEmpty) {
          nextSong = _algorithmQueue.first;
        }
      }
      
      // Si aún no hay canción, buscar una directamente
      if (nextSong == null) {
        final recommendationService = SpotifyRecommendationService(HttpClientService());
        nextSong = await recommendationService.getSmartRecommendation(
          currentSongId: state.currentSong!.id,
          genres: state.currentSong!.genres,
          user: null,
        ).catchError((_) => null);
        
        // Si encontramos una, agregarla a la cola
        if (nextSong != null && !_algorithmQueue.any((s) => s.id == nextSong!.id)) {
          _algorithmQueue.add(nextSong);
        }
      }
    }
    
    if (nextSong == null || nextSong.fileUrl == null || nextSong.fileUrl!.isEmpty) {
      return; // No hay siguiente canción para precargar
    }
    
    // Si ya está precargada, no hacer nada
    if (_prefetchedNextSong?.id == nextSong.id) {
      return;
    }
    
    _isPrefetching = true;
    _lastPrefetchTime = now;
    
    try {
      // ⚠️ CRÍTICO: Usar el player INACTIVO para precargar, NO el activo
      final inactivePlayer = state.playbackMode == PlaybackMode.algorithm
          ? _fixedQueuePlayer
          : _algorithmPlayer;
      
      if (inactivePlayer != null) {
        final normalizedUrl = UrlNormalizer.normalizeUrl(nextSong.fileUrl!);
        
        // ✅ OPTIMIZACIÓN: Precargar de forma asíncrona sin bloquear
        // Usar un timeout más corto y manejar errores mejor
        final nextSongId = nextSong.id;
        unawaited(
          inactivePlayer.setUrl(normalizedUrl)
              .timeout(const Duration(seconds: 3))
              .then((_) {
                if (_prefetchedNextSong?.id == nextSongId) {
                  _preloadedPlayer = inactivePlayer;
                  _preloadedSongId = nextSongId;
                  // Precarga completada silenciosamente
                }
              })
              .catchError((e) {
                // Error no crítico - la canción se cargará cuando se necesite
              }),
        );
        
        // ✅ Guardar referencia inmediatamente (optimista)
        _prefetchedNextSong = nextSong;
        _preloadedSongId = nextSong.id;
        
      } else {
        // Si no hay player inactivo, solo guardar la referencia
        _prefetchedNextSong = nextSong;
        _preloadedPlayer = null;
        _preloadedSongId = nextSong.id;
      }
    } catch (e) {
      // En caso de error, al menos guardar la referencia
      _prefetchedNextSong = nextSong;
      _preloadedSongId = nextSong.id;
    } finally {
      _isPrefetching = false;
    }
    
    // ✅ OPTIMIZACIÓN: Regenerar cola en background si está baja (más temprano)
    // Regenerar cuando queden 2 o menos canciones (más proactivo)
    if (_algorithmQueue.length <= 2 && state.currentSong != null) {
      unawaited(
        regenerateRecommendations(state.currentSong!).catchError((e) {
          // Error silencioso
        }),
      );
    }
  }
  
  /// ✅ OPTIMIZACIÓN: Precargar inmediatamente después de iniciar una canción
  void _schedulePrefetch() {
    // ✅ OPTIMIZACIÓN: Precargar INMEDIATAMENTE (sin delay) para transiciones más fluidas
    // Esto asegura que la siguiente canción esté lista lo antes posible
    Future.microtask(() {
      if (state.isPlaying && state.currentSong != null) {
        prefetchNext().catchError((_) {});
        
        // ✅ También regenerar recomendaciones si la cola está baja (más proactivo)
        if (state.playbackMode == PlaybackMode.algorithm && 
            (_algorithmQueue.isEmpty || _algorithmQueue.length <= 2)) {
          unawaited(
            regenerateRecommendations(state.currentSong!).then((_) {
              // ✅ Después de regenerar, precargar inmediatamente
              prefetchNext().catchError((_) {});
            }).catchError((_) {}),
          );
        }
      }
    });
  }

  /// 🎯 Reproducir desde userQueue
  Future<void> playFromUserQueue() async {
    if (_userQueue.isEmpty) {
      AppLogger.warning('[SPOTIFY-ALGORITHM] ⚠️ userQueue vacía');
      return;
    }
    
    final song = _userQueue.removeAt(0);
    
    // ⚡ OPTIMIZACIÓN: Reproducir directamente sin llamadas innecesarias
    await playSong(song, useAlgorithm: true);
    
    // Precargar siguiente en background (sin bloquear)
    prefetchNext();
  }

  /// 🎯 Reproducir desde algorithmQueue
  Future<void> playFromAlgorithmQueue() async {
    if (_algorithmQueue.isEmpty) {
      AppLogger.warning('[SPOTIFY-ALGORITHM] ⚠️ algorithmQueue vacía, regenerando...');
      
      // Regenerar si está vacía
      if (state.currentSong != null) {
        await regenerateRecommendations(state.currentSong!);
      }
      
      if (_algorithmQueue.isEmpty) {
        AppLogger.error('[SPOTIFY-ALGORITHM] ❌ No se pudo regenerar algorithmQueue');
        state = state.copyWith(isPlaying: false);
        return;
      }
    }
    
    final song = _algorithmQueue.removeAt(0);
    AppLogger.info('[SPOTIFY-ALGORITHM] 🎵 Reproduciendo desde algorithmQueue: ${song.title}');
    
    // Actualizar PlaySession
    updatePlaySession(song);
    
    // Actualizar cooldowns
    _lastArtistId = song.artistId;
    
    // Reproducir
    await playSong(song, useAlgorithm: true);
    
    // Regenerar si se está quedando vacía
    if (_algorithmQueue.length < _minAlgorithmQueueSize && state.currentSong != null) {
      regenerateRecommendations(state.currentSong!).catchError((e) {
        AppLogger.error('[SPOTIFY-ALGORITHM] ❌ Error regenerando: $e');
      });
    }
    
    // Precargar siguiente
    prefetchNext();
  }

  /// 🎯 Actualizar PlaySession
  /// ⚠️ NOTA: El guardado del historial se hace en playSong() para evitar duplicados
  void updatePlaySession(Song song) {
    _currentIndex++;
    // ✅ El historial se guarda en playSong() para asegurar coherencia
  }

  /// ✅ Forzar inicialización del player (método público)
  void ensureInitialized() {
    if (!_isInitialized) {
      _initializePlayer();
    }
  }

  /// ⚡ SPOTIFY-STYLE: Reproducción desde tarjeta - OPTIMIZADA para respuesta inmediata
  /// Las tarjetas individuales siempre usan el algoritmo de recomendaciones
  Future<void> playFromCard(Song song, {bool activateAlgorithm = true}) async {
    // ✅ VALIDACIÓN TEMPRANA
    if (song.fileUrl == null || song.fileUrl!.isEmpty) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ URL inválida: ${song.title}');
      return;
    }

    try {
      // ⚡ OPTIMIZACIÓN: Reproducir INMEDIATAMENTE sin esperar configuración
      // 1. Cambiar a modo algoritmo rápidamente (sin generar cola aún)
      final needsModeChange = state.playbackMode != PlaybackMode.algorithm;
      
      if (needsModeChange) {
        // ⚡ CRÍTICO: Detener reproductor activo ANTES de cambiar de modo
        // Esto evita que dos reproductores suenen al mismo tiempo
        // Guardar el modo actual ANTES de cambiarlo para saber qué reproductor detener
        final currentModeBeforeChange = state.playbackMode;
        await _stopActivePlayerBeforeModeChange(currentMode: currentModeBeforeChange);
        
        // Limpiar colas rápidamente
        _userQueue.clear();
        _algorithmQueue.clear();
        _upcomingQueue.clear();
        
        // Cambiar modo inmediatamente
        state = state.copyWith(
          playbackMode: PlaybackMode.algorithm,
          contextId: null,
        );
        
        // Pausar reproductor inactivo y configurar listeners
        _pauseInactivePlayer();
        _setupListenersForActivePlayer();
      } else {
        // Si ya está en modo algoritmo, solo limpiar colas
        _userQueue.clear();
        _algorithmQueue.clear();
        _upcomingQueue.clear();
      }
      
      // 2. Reproducir canción INMEDIATAMENTE (sin esperar recomendaciones)
      await playSong(song, useAlgorithm: true);
      
      // 3. Generar recomendaciones en background DESPUÉS de iniciar reproducción
      // Esto hace que la reproducción se sienta instantánea
      Future.delayed(const Duration(milliseconds: 500), () {
        generateAlgorithmQueue(song).catchError((_) {});
      });
      
      // 4. Precargar siguiente canción en background (después de que se generen recomendaciones)
      Future.delayed(const Duration(seconds: 1), () {
        prefetchNext();
      });

    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error playFromCard: $e');
      state = state.copyWith(isPlaying: false);
      _lastManualToggleTime = null;
      _lastManualToggleState = null;
    }
  }

  /// ⚡ Cargar y reproducir canción rápidamente (sin bloquear UI)
  /// ✅ MEJORADO: Método unificado para cargar y reproducir canciones
  Future<void> _loadAndPlaySong(AudioPlayer player, String url, Song song) async {
    try {
      // ✅ Asegurar que el reproductor esté en el modo correcto
      if (state.playbackMode == PlaybackMode.algorithm && player != _algorithmPlayer) {
        AppLogger.warning('[UnifiedAudioNotifier] ⚠️ Reproductor incorrecto, usando algorithmPlayer');
        final correctPlayer = _algorithmPlayer;
        if (correctPlayer != null) {
          await _loadAndPlaySong(correctPlayer, url, song);
          return;
        } else {
          AppLogger.error('[UnifiedAudioNotifier] ❌ algorithmPlayer no disponible');
          state = state.copyWith(isPlaying: false);
          return;
        }
      } else if (state.playbackMode == PlaybackMode.fixedQueue && player != _fixedQueuePlayer) {
        AppLogger.warning('[UnifiedAudioNotifier] ⚠️ Reproductor incorrecto, usando fixedQueuePlayer');
        final correctPlayer = _fixedQueuePlayer;
        if (correctPlayer != null) {
          await _loadAndPlaySong(correctPlayer, url, song);
          return;
        } else {
          AppLogger.error('[UnifiedAudioNotifier] ❌ fixedQueuePlayer no disponible');
          state = state.copyWith(isPlaying: false);
          return;
        }
      }
      
      // ⚠️ CRÍTICO: Detener TODOS los players antes de cargar nueva URL
      // Esto previene reproducción simultánea
      await _stopAllPlayers(except: player);
      
      // Pequeño delay para asegurar que el stop se complete
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Asegurar que el player tenga volumen correcto
      await player.setVolume(1.0);
      
      // ⚡ OPTIMIZACIÓN SPOTIFY: Cargar y reproducir en paralelo
      // Cargar URL
      final loadFuture = player.setUrl(url);
      
      // ⚡ Reproducir inmediatamente sin esperar (optimistic play)
      await loadFuture;
      player.setVolume(1.0);
      
      // Obtener duración y reproducir en paralelo
      final duration = player.duration ?? Duration.zero;
      if (duration.inMilliseconds > 0) {
        state = state.copyWith(totalDuration: duration);
      }
      
      // ⚡ Reproducir sin delay
      await player.play();
      
      // ⚡ Verificar en background (no bloquear)
      Future.microtask(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      final playerState = player.playerState;
      if (!playerState.playing) {
        await player.play();
      }
      
        // Actualizar duración final si cambió
      final finalDuration = player.duration ?? duration;
      if (finalDuration != duration && finalDuration.inMilliseconds > 0) {
        state = state.copyWith(totalDuration: finalDuration);
      }
      });
    } catch (e, stackTrace) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error _loadAndPlaySong: $e', stackTrace);
      try {
        state = state.copyWith(isPlaying: false);
      } catch (_) {}
      _lastManualToggleTime = null;
      _lastManualToggleState = null;
    }
  }
  


  /// ✅ Reproducir una canción - Optimizado para respuesta inmediata sin parpadeo
  /// Cambia automáticamente entre reproductores según useAlgorithm
  /// [skipHistory]: Si es true, no guarda la canción actual en el historial (útil para retroceso)
  /// [forcePlay]: Si es true, fuerza la reproducción incluso si es la misma canción (útil para retroceso)
  Future<void> playSong(Song song, {bool useAlgorithm = false, bool skipHistory = false, bool forcePlay = false}) async {
    // ✅ VALIDACIÓN TEMPRANA: Verificar fileUrl ANTES de actualizar cualquier estado
    if (song.fileUrl == null || song.fileUrl!.isEmpty) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ URL de canción inválida para: ${song.title} (ID: ${song.id})');
      return;
    }

    try {
      final newMode = useAlgorithm ? PlaybackMode.algorithm : PlaybackMode.fixedQueue;
      final needsModeChange = state.playbackMode != newMode;
      
      // ⚠️ CRÍTICO: Si useAlgorithm = true, SIEMPRE limpiar contextId (incluso si no hay cambio de modo)
      // Esto previene que se active el botón "reproducir todo" cuando se reproduce desde tarjetas
      final shouldClearContextId = useAlgorithm;
      final newContextId = shouldClearContextId ? null : (needsModeChange ? null : state.contextId);
      
      // 🎯 CAMBIO DE MODO INMEDIATO: Actualizar estado ANTES de cambiar reproductores
      if (needsModeChange || shouldClearContextId) {
        // ✅ ACTUALIZACIÓN INMEDIATA DEL ESTADO (sin await)
        state = state.copyWith(
          playbackMode: newMode,
          contextId: newContextId,
        );
        
        // ✅ Pausar reproductor inactivo (no bloqueante)
        _pauseInactivePlayer();
        
        // ✅ Configurar listeners para el nuevo reproductor activo (debe ser después de cambiar el modo)
        _setupListenersForActivePlayer();
      } else if (state.contextId != null && useAlgorithm) {
        // Si ya está en modo algoritmo pero tiene contextId, limpiarlo
        state = state.copyWith(contextId: null);
      }
      
      final player = _activePlayer;
      if (player == null) {
        AppLogger.error('[UnifiedAudioNotifier] ❌ AudioPlayer no inicializado');
        return;
      }
      
      // ⚠️ CRÍTICO: Verificar si es la misma canción ANTES de hacer cambios
      final isSameSong = state.currentSong?.id == song.id;
      
      // Si es la misma canción Y está reproduciéndose, NO hacer nada (evitar reinicio)
      // Pero si está pausada o detenida, sí reproducirla
      // Si forcePlay es true, forzar la reproducción incluso si es la misma canción
      if (isSameSong && state.isPlaying && !forcePlay) {
        AppLogger.info('[playSong] ⚠️ Es la misma canción y está reproduciéndose, no haciendo nada para evitar reinicio');
        return;
      }
      
      if (forcePlay && isSameSong) {
        AppLogger.info('[playSong] 🔄 Forzando reproducción de la misma canción (forcePlay=true)');
      }
      
      // 🛡️ PROTECCIÓN: Cancelar listeners ANTES de cambiar de canción
      // Esto previene que los listeners antiguos capturen eventos de posición cero
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _playerStateSubscription?.cancel();
      _positionSubscription = null;
      _durationSubscription = null;
      _playerStateSubscription = null;
      
      // 🛡️ PROTECCIÓN: Activar flag de cambio de canción
      _isChangingSong = true;
      _songChangeStartTime = DateTime.now();
      
      // ⚡ SPOTIFY-STYLE: Si es una canción diferente, preparar transición suave
      // Guardar referencia al player actual antes de cambiar
      final previousPlayer = (_activePlayer != null && _activePlayer != player) 
          ? _activePlayer 
          : null;
      
      // Asegurar que el player que vamos a usar tenga volumen correcto
      await player.setVolume(1.0);
      
      // ⚡ CRÍTICO: Guardar historial ANTES de actualizar state.currentSong
      // Solo si skipHistory es false (por defecto se guarda)
      if (!skipHistory) {
        // ⚠️ CRÍTICO: Capturar currentSong ANTES de cualquier cambio de estado
        final currentSongBeforeChange = state.currentSong;
        final currentSongId = currentSongBeforeChange?.id;
        final newSongId = song.id;
        
        // ✅ ARREGLADO: SIEMPRE guardar la canción actual si es diferente a la nueva
        // ⚡ CRÍTICO: Incluso si el historial está vacío, SI hay una canción actual, DEBE guardarse
        // Esto permite que la primera canción se guarde cuando se reproduce la segunda
        if (currentSongBeforeChange != null && currentSongId != newSongId) {
          // ✅ CRÍTICO: Guardar la canción actual (que será la anterior después del cambio)
          // Verificar que no esté ya en el historial (evitar duplicados consecutivos)
          // 🎯 SPOTIFY-STYLE: Agregar al history stack (LIFO)
          final shouldAddToHistory = _historyStack.isEmpty || (_historyStack.isNotEmpty && _historyStack.last.id != currentSongId);
          
          if (shouldAddToHistory) {
            _historyStack.add(currentSongBeforeChange);
            // Limitar tamaño del historial (eliminar del inicio si es muy grande)
            if (_historyStack.length > _maxHistorySize) {
              _historyStack.removeAt(0);
            }
          }
        }
      }
      
      // Agregar al historial de canciones recientes
      _recentSongIds.add(song.id);
      if (_recentSongIds.length > _maxRecentSongs) {
        _recentSongIds.removeAt(0);
      }
      
      // Resetear tracking cuando cambia de canción
      _lastTrackedProgressMs = 0;
      _streamsApi.resetRateLimit();
      
      // Registrar que estamos iniciando una reproducción manual
      _lastManualToggleTime = DateTime.now();
      _lastManualToggleState = true;
      
      // Resetear flags de precarga
      _preloadedNextSong = null;
      _hasTriggeredPreload = false;
      
      // ✅ ACTUALIZACIÓN INMEDIATA DEL ESTADO (después de guardar historial)
      state = state.copyWith(
        currentSong: song,
        isPlaying: true,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
        isPlayerExpanded: false,
      );
      
      // Normalizar URL
      final normalizedUrl = UrlNormalizer.normalizeUrl(song.fileUrl!);

      // ✅ Cargar y reproducir en el reproductor activo
      try {
        // Cargar URL
        await player.setUrl(normalizedUrl);
        
        // Obtener duración (puede ser 0 inicialmente)
        final duration = player.duration ?? Duration.zero;
        
        // Actualizar duración si está disponible
        if (duration.inMilliseconds > 0) {
          state = state.copyWith(totalDuration: duration);
        }
        
        // ⚠️ CRÍTICO: Detener la canción anterior PRIMERO
        if (previousPlayer != null) {
          try {
            await previousPlayer.setVolume(0.0);
            await previousPlayer.stop();
            await previousPlayer.pause();
          } catch (e) {
            AppLogger.error('[playSong] ❌ Error deteniendo player anterior: $e');
          }
        }
        
        // Detener todos los demás players
        await _stopAllPlayers(except: player);
        
        // Reproducir la nueva canción INMEDIATAMENTE
        await player.setVolume(1.0);
        await player.play();
        
        // ⚡ CONFIGURACIÓN INMEDIATA: Configurar listeners SIN DELAY
        // Para cambio instantáneo, configuramos listeners inmediatamente
        _setupListenersForActivePlayerSync();
        
        // ⚡ Resetear flag inmediatamente (la protección sigue activa por tiempo corto)
        // Resetear flag después de muy poco tiempo (50ms) para permitir actualizaciones rápidas
        Future.microtask(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          _isChangingSong = false;
          _songChangeStartTime = null;
          
          // Verificar reproducción en background (no bloquear)
          final playerState = player.playerState;
          if (!playerState.playing) {
            AppLogger.warning('[UnifiedAudioNotifier] ⚠️ Player no está reproduciendo después de play, reintentando...');
            await player.play();
          }
          
          // Actualizar duración final si cambió
          final finalDuration = player.duration ?? duration;
          if (finalDuration != duration && finalDuration.inMilliseconds > 0) {
            state = state.copyWith(totalDuration: finalDuration);
          }
        });
        
        // 🛡️ PROTECCIÓN ADICIONAL: Resetear flag automáticamente después de 500ms como respaldo
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isChangingSong) {
            AppLogger.warning('[playSong] ⚠️ Reset automático del flag _isChangingSong (respaldo)');
            _isChangingSong = false;
            _songChangeStartTime = null;
          }
        });
      } catch (e) {
        AppLogger.error('[UnifiedAudioNotifier] ❌ Error en playSong: $e');
        try {
          state = state.copyWith(isPlaying: false);
        } catch (_) {
          // Ignorar errores de estado si el widget está desmontado
        }
        _lastManualToggleTime = null;
        _lastManualToggleState = null;
        // 🛡️ PROTECCIÓN: Resetear flag de cambio de canción en caso de error
        _isChangingSong = false;
        _songChangeStartTime = null;
      }
      
      // ✅ OPTIMIZACIÓN: Precargar siguiente canción después de iniciar reproducción
      _schedulePrefetch();
      
      // ✅ CONECTADO: Si es modo algoritmo, generar recomendaciones INMEDIATAMENTE y de forma PRIORITARIA
      if (useAlgorithm && state.currentSong != null) {
        // ✅ Generar inmediatamente si la cola está vacía o tiene pocas canciones
        if (_algorithmQueue.isEmpty || _algorithmQueue.length <= 2) {
          // ✅ PRIORIDAD: Generar recomendaciones de forma más agresiva cuando se reproduce desde tarjeta
          // Usar Future.microtask para ejecutar inmediatamente después del frame actual
          Future.microtask(() {
            regenerateRecommendations(state.currentSong!).then((_) {
              // ✅ Después de generar, precargar inmediatamente la siguiente canción
              prefetchNext().catchError((_) {});
            }).catchError((e) {
              AppLogger.error('[playSong] ❌ Error generando recomendaciones: $e');
            });
          });
        } else {
          // ✅ Si ya hay canciones, precargar la siguiente inmediatamente
          Future.microtask(() {
            prefetchNext().catchError((_) {});
          });
        }
      }
      
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error reproduciendo: $e');
      // Solo actualizar estado si el notifier sigue activo
      try {
        state = state.copyWith(
          isLoading: false,
          isPlaying: false,
        );
      } catch (_) {
        // Ignorar errores de estado si el widget está desmontado
      }
      _lastManualToggleTime = null;
      _lastManualToggleState = null;
      // 🛡️ PROTECCIÓN: Resetear flag de cambio de canción en caso de error
      _isChangingSong = false;
      _songChangeStartTime = null;
    }
  }

  /// Toggle play/pause en el reproductor activo
  Future<void> togglePlayPause() async {
    final player = _activePlayer;
    if (player == null || state.currentSong == null) return;

    try {
      final newIsPlaying = !state.isPlaying;
      state = state.copyWith(isPlaying: newIsPlaying);
      
      if (newIsPlaying) {
        await player.play();
      } else {
        await player.pause();
      }
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] Error toggle: $e');
      state = state.copyWith(isPlaying: !state.isPlaying);
    }
  }

  /// ⚡ OPTIMIZADO: Reproducir playlist/artista completo - Respuesta inmediata
  /// 🎯 Reproducir todo - SIEMPRE activa modo PLAYLIST (fixedQueue)
  /// Usado por botones "Reproducir todo" en playlists y artistas
  Future<void> onPressPlayAll(Song firstSong, String contextId, {List<Song>? allSongs}) async {
    if (firstSong.fileUrl == null || firstSong.fileUrl!.isEmpty) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ URL inválida: ${firstSong.title}');
      return;
    }

    try {
      // ⚡ Verificar si es la misma playlist/artista y está reproduciendo
      final isSameContext = state.contextId == contextId && 
                           state.playbackMode == PlaybackMode.fixedQueue;
      
      if (isSameContext && state.isPlaying) {
        togglePlayPause(); // Sin await para no bloquear
        return;
      }
      
      // ⚡ PASO 1: Guardar lista de canciones inmediatamente
      if (allSongs != null && allSongs.isNotEmpty) {
        _fixedQueueSongs = List<Song>.from(allSongs);
      } else {
        _fixedQueueSongs = [firstSong];
      }
      
      // Guardar canción anterior en historial ANTES de cambiar
      final currentSongBeforeChange = state.currentSong;
      if (currentSongBeforeChange != null && currentSongBeforeChange.id != firstSong.id) {
        if (_historyStack.isEmpty || (_historyStack.isNotEmpty && _historyStack.last.id != currentSongBeforeChange.id)) {
          _historyStack.add(currentSongBeforeChange);
          if (_historyStack.length > _maxHistorySize) {
            _historyStack.removeAt(0);
          }
        }
      }
      
      // ⚡ CRÍTICO PASO 2: Detener reproductor activo ANTES de cambiar de modo
      // Esto evita que dos reproductores suenen al mismo tiempo
      // Guardar el modo actual ANTES de cambiarlo para saber qué reproductor detener
      final currentModeBeforeChange = state.playbackMode;
      await _stopActivePlayerBeforeModeChange(currentMode: currentModeBeforeChange);
      
      // ⚡ PASO 3: Cambiar estado INMEDIATAMENTE (actualización optimista)
      state = state.copyWith(
        playbackMode: PlaybackMode.fixedQueue,
        contextId: contextId,
        isPlaying: true,
        currentSong: firstSong,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
      );
      
      // ⚡ PASO 4: Limpiar modo algoritmo (rápido)
      _userQueue.clear();
      _algorithmQueue.clear();
      _upcomingQueue.clear();
      _shouldActivateAlgorithmOnCompletion = false;
      
      // ⚡ PASO 5: Asegurar que el reproductor inactivo también esté pausado
      _pauseInactivePlayer();
      
      // Asegurar que fixedQueuePlayer esté inicializado
      if (_fixedQueuePlayer == null) {
        _initializePlayer();
      }
      
      // Configurar listeners
      _setupListenersForActivePlayer();
      
      final player = _fixedQueuePlayer;
      if (player == null) {
        AppLogger.error('[UnifiedAudioNotifier] ❌ fixedQueuePlayer no disponible');
        return;
      }
      
      // ⚡ PASO 5: Cargar y reproducir en background (sin bloquear UI)
      final normalizedUrl = UrlNormalizer.normalizeUrl(firstSong.fileUrl!);
      
      // Cargar URL en background (sin bloquear)
      player.setUrl(normalizedUrl).then((_) {
        final duration = player.duration ?? Duration.zero;
        if (duration.inMilliseconds > 0) {
          state = state.copyWith(totalDuration: duration);
        }
        
        // Reproducir después de cargar
        return player.play();
      }).then((_) {
        player.setVolume(1.0);
      }).catchError((e) {
        // ✅ Filtrar errores no críticos (interrupciones esperadas al cambiar de canción)
        final errorStr = e.toString().toLowerCase();
        final isInterruptionError = errorStr.contains('loading interrupted') ||
                                   errorStr.contains('interrupted') ||
                                   errorStr.contains('cancelled') ||
                                   errorStr.contains('abort');
        
        // Solo loggear errores críticos (no interrupciones normales)
        if (!isInterruptionError) {
          AppLogger.error('[UnifiedAudioNotifier] Error en onPressPlayAll: $e');
          state = state.copyWith(isPlaying: false);
        }
        // Si es una interrupción, es normal y no hacer nada (la nueva canción ya está cargando)
      });
      
      // Actualizar historial de canciones recientes
      _recentSongIds.add(firstSong.id);
      if (_recentSongIds.length > _maxRecentSongs) {
        _recentSongIds.removeAt(0);
      }
      
      // Resetear tracking
      _lastTrackedProgressMs = 0;
      _streamsApi.resetRateLimit();
      
    } catch (e) {
      // ✅ Filtrar errores no críticos (interrupciones esperadas al cambiar de canción)
      final errorStr = e.toString().toLowerCase();
      final isInterruptionError = errorStr.contains('loading interrupted') ||
                                 errorStr.contains('interrupted') ||
                                 errorStr.contains('cancelled') ||
                                 errorStr.contains('abort');
      
      // Solo loggear errores críticos (no interrupciones normales)
      if (!isInterruptionError) {
        AppLogger.error('[UnifiedAudioNotifier] ❌ Error en onPressPlayAll: $e');
        state = state.copyWith(isPlaying: false);
      }
      // Si es una interrupción, es normal y no hacer nada (la nueva canción ya está cargando)
    }
  }

  /// Toggle play/pause con lógica inteligente estilo Spotify
  /// Lógica:
  /// 1. Si no hay canción → reproducir nueva
  /// 2. Si es otra canción → cambiar a esa
  /// 3. Si es la misma → toggle play/pause
  Future<void> togglePlay([Song? song]) async {
    final player = _activePlayer;
    if (player == null) {
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

      // ⚡ PROTECCIÓN: Evitar múltiples toques simultáneos
      if (_isToggling) return;
      _isToggling = true;

      // ⚡ ACTUALIZACIÓN OPTIMISTA INMEDIATA
      final newIsPlaying = !state.isPlaying;
      _lastManualToggleTime = DateTime.now();
      _lastManualToggleState = newIsPlaying;
      state = state.copyWith(isPlaying: newIsPlaying);

      // Ejecutar operación en background (sin bloquear)
      if (newIsPlaying) {
        player.play().catchError((e) {
          AppLogger.error('[UnifiedAudioNotifier] Error play: $e');
          state = state.copyWith(isPlaying: false);
          _lastManualToggleTime = null;
          _lastManualToggleState = null;
        });
      } else {
        // Pausar en background sin bloquear
        player.pause().catchError((e) {
          AppLogger.error('[UnifiedAudioNotifier] Error pause: $e');
          state = state.copyWith(isPlaying: true);
          _lastManualToggleTime = null;
          _lastManualToggleState = null;
        });
      }
      
      // Resetear flag después de un breve delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _isToggling = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('[UnifiedAudioNotifier] Error en togglePlay: $e', stackTrace);
    }
  }

  /// ⚡ OPTIMIZADO: Pausar con respuesta inmediata
  Future<void> pause() async {
    final player = _activePlayer;
    if (player == null) return;
    
    // ⚡ PROTECCIÓN: Evitar múltiples toques simultáneos
    if (_isToggling) return;
    _isToggling = true;
    
    try {
      // ⚡ ACTUALIZACIÓN OPTIMISTA: Cambiar estado INMEDIATAMENTE
      state = state.copyWith(isPlaying: false);
      _lastManualToggleTime = DateTime.now();
      _lastManualToggleState = false;
      
      // Pausar en background sin bloquear
      player.pause().catchError((e) {
        AppLogger.error('[UnifiedAudioNotifier] Error pause: $e');
        state = state.copyWith(isPlaying: true);
      });
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] Error pause: $e');
      state = state.copyWith(isPlaying: true);
    } finally {
      // Resetear flag después de un breve delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _isToggling = false;
      });
    }
  }

  /// Reanudar
  Future<void> play() async {
    final player = _activePlayer;
    if (player == null) return;
    
    try {
      state = state.copyWith(
        isPlaying: true,
        isPlayerExpanded: false,
      );
      
      await player.play();
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] Error play: $e');
      state = state.copyWith(isPlaying: false);
    }
  }

  /// ✅ Buscar posición - OPTIMIZADO
  Future<void> seek(Duration position) async {
    final player = _activePlayer;
    if (player == null) return;
    
    // ✅ Guardar estado antes del seek
    final wasPlaying = state.isPlaying;
    
    // 🛡️ PROTECCIÓN: Registrar que estamos haciendo un seek
    _lastSeekTime = DateTime.now();
    _lastSeekPlayingState = wasPlaying;
    
    try {
      // ✅ Actualizar posición optimista antes del seek
      state = state.copyWith(currentPosition: position);
      
      // ✅ Ejecutar seek
      await player.seek(position);
      
      // ✅ Si estaba reproduciendo, verificar y reanudar si es necesario
      if (wasPlaying) {
        // Esperar un momento para que el player se actualice
        await Future.delayed(const Duration(milliseconds: 50));
        final playerStateAfter = player.playerState;
        
        if (!playerStateAfter.playing) {
          // Reanudar si se detuvo
          await player.play();
        }
        
        // Actualizar estado y extender protección
        state = state.copyWith(isPlaying: true);
        _lastSeekTime = DateTime.now();
        _lastSeekPlayingState = true;
      }
      
      // ✅ Actualizar posición final
      final finalPosition = player.position;
      state = state.copyWith(currentPosition: finalPosition);
      
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error en seek: $e');
      
      // ✅ Restaurar posición anterior en caso de error
      state = state.copyWith(currentPosition: state.currentPosition);
      
      // ✅ Si estaba reproduciendo, intentar mantener el estado
      if (wasPlaying && player.playerState.playing == false) {
        player.play().catchError((e2) {
          AppLogger.error('[UnifiedAudioNotifier] ❌ Error al reanudar después de error: $e2');
        });
      }
    }
  }

  /// ✅ Cambiar volumen
  Future<void> setVolume(double volume) async {
    final player = _activePlayer;
    if (player == null) return;
    
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await player.setVolume(clampedVolume);
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

  /// ⚡ OPTIMIZADO: Abrir reproductor completo - Respuesta inmediata
  /// Diferir operaciones pesadas hasta después de la animación
  void openFullPlayer() {
    // ⚡ Actualizar estado INMEDIATAMENTE (sin bloqueos)
    state = state.copyWith(isPlayerExpanded: true);
    
    // ⚡ DIFERIR operaciones pesadas: esperar a que termine la animación de expansión
    // Usar un delay más largo para que la animación termine primero
    Future.delayed(const Duration(milliseconds: 400), () {
      // Si no hay siguiente canción, intentar precargar/generar una
      if (peekNextSong() == null && state.currentSong != null) {
        // Intentar precargar la siguiente canción (en background)
        prefetchNext().catchError((_) {});
        // Si no hay cola, regenerar recomendaciones (en background)
        if (_algorithmQueue.isEmpty && state.playbackMode == PlaybackMode.algorithm) {
          regenerateRecommendations(state.currentSong!).catchError((_) {});
        }
      } else {
        // Si ya hay una siguiente canción, asegurarse de que esté precargada (en background)
        prefetchNext().catchError((_) {});
      }
    });
  }

  /// ✅ Cerrar reproductor completo
  /// IMPORTANTE: Solo cierra la UI, NO afecta la reproducción
  void closeFullPlayer() {
    state = state.copyWith(isPlayerExpanded: false);
    AppLogger.info('[UnifiedAudioNotifier] 🎬 Cerrando reproductor completo (la reproducción continúa)');
  }

  /// ✅ Toggle expandir/colapsar reproductor
  void toggleExpandedPlayer() {
    final newState = !state.isPlayerExpanded;
    state = state.copyWith(isPlayerExpanded: newState);
    AppLogger.info('[UnifiedAudioNotifier] 🎬 Toggle player expanded: $newState');
  }

  /// ✅ Detener completamente
  Future<void> stop() async {
    final player = _activePlayer;
    if (player == null) return;
    
    try {
      await player.stop();
      state = state.copyWith(
        isPlaying: false,
        currentPosition: Duration.zero,
      );
      AppLogger.info('[UnifiedAudioNotifier] ⏹️ Detenido');
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error stop: $e');
    }
  }

  /// ⚡ Helper: Detener TODOS los players (FORZADO - asegura que realmente se detengan)
  Future<void> _stopAllPlayers({AudioPlayer? except}) async {
    final allPlayers = [_algorithmPlayer, _fixedQueuePlayer]
        .whereType<AudioPlayer>()
        .toList();
    
    await Future.wait(
      allPlayers.map((player) async {
        if (player == except) return; // Saltar el player que vamos a usar
        
        try {
          // ⚠️ CRÍTICO: Bajar volumen a 0 primero (evita sonido residual)
          await player.setVolume(0.0);
          // Detener completamente
          await player.stop();
          // Pausar también por si acaso
          await player.pause();
          AppLogger.info('[STOP-ALL] 🛑 Player detenido: ${player == _algorithmPlayer ? "algorithm" : "fixedQueue"}');
        } catch (e) {
          AppLogger.error('[STOP-ALL] ❌ Error deteniendo player: $e');
        }
      }),
      eagerError: false,
    );
  }

  /// 🎵 Siguiente canción - NUEVA IMPLEMENTACIÓN SIMPLE Y DIRECTA
  /// [specificSong] - Si se proporciona, usa esta canción específica (para garantizar consistencia con el preview)
  Future<void> next({Song? specificSong}) async {
    // ✅ Método público que mantiene compatibilidad
    return _nextInternal(specificSong: specificSong);
  }
  
  /// Método público para next() con canción específica (para garantizar consistencia)
  Future<void> nextWithSong(Song song) async {
    return _nextInternal(specificSong: song);
  }
  
  /// 🎯 SPOTIFY-STYLE NEXT: Método interno para next() 
  Future<void> _nextInternal({Song? specificSong}) async {
    if (state.currentSong == null) return;
    
    _isSearchingNextSong = false;
    _isChangingSong = false;
    _songChangeStartTime = null;
    
    try {
      // Modo Playlist
      if (state.playbackMode == PlaybackMode.fixedQueue) {
        await _handlePlaylistSongCompletion();
        return;
      }
      
      Song? nextSong;
      
      // Si se proporciona canción específica (swipe), usarla
      if (specificSong != null) {
        nextSong = specificSong;
        // Remover de todas las colas para evitar duplicados
        _upcomingQueue.removeWhere((s) => s.id == nextSong!.id);
        _userQueue.removeWhere((s) => s.id == nextSong!.id);
        _algorithmQueue.removeWhere((s) => s.id == nextSong!.id);
      }
      // 🎯 SPOTIFY-STYLE: Obtener de upcoming queue
      else if (_upcomingQueue.isNotEmpty) {
        nextSong = _upcomingQueue.removeAt(0);
      }
      // COMPATIBILIDAD: Usar colas legacy si upcoming está vacía
      else if (_userQueue.isNotEmpty) {
        nextSong = _userQueue.removeAt(0);
      }
      else if (_algorithmQueue.isNotEmpty) {
        nextSong = _algorithmQueue.removeAt(0);
        // Regenerar si quedan pocas
        if (_algorithmQueue.length < 5 && state.currentSong != null) {
          regenerateRecommendations(state.currentSong!).catchError((_) {});
        }
      }
      // Si no hay cola, regenerar
      else if (state.currentSong != null) {
        await regenerateRecommendations(state.currentSong!);
        if (_algorithmQueue.isNotEmpty) {
          nextSong = _algorithmQueue.removeAt(0);
        }
      }
      
      if (nextSong != null) {
        final currentSong = state.currentSong;
        
        // 🎯 SPOTIFY-STYLE NEXT:
        // 1. La canción actual va al history stack
        if (currentSong != null && currentSong.id != nextSong.id) {
          _historyStack.add(currentSong);
          // Limitar tamaño
          if (_historyStack.length > _maxHistorySize) {
            _historyStack.removeAt(0);
          }
        }
        
        // 2. Reproducir siguiente canción (sin guardar en historial - ya lo manejamos)
        await playSong(nextSong, useAlgorithm: true, skipHistory: true);
        
        // Regenerar upcoming queue si está vacía
        if (_upcomingQueue.isEmpty && _algorithmQueue.isEmpty && state.currentSong != null) {
          regenerateRecommendations(state.currentSong!).catchError((_) {});
        }
      }
    } catch (e) {
      AppLogger.error('[NEXT] ❌ Error: $e');
    } finally {
      _isSearchingNextSong = false;
      _isChangingSong = false;
      _songChangeStartTime = null;
    }
  }

  /// Obtener la siguiente canción sin removerla de la cola (para preview)
  Song? peekNextSong() {
    // 🎯 SPOTIFY-STYLE: Prioridad: Upcoming Queue > User Queue > Algorithm Queue
    if (_upcomingQueue.isNotEmpty) {
      return _upcomingQueue.first;
    } else if (_userQueue.isNotEmpty) {
      return _userQueue.first;
    } else if (_algorithmQueue.isNotEmpty) {
      return _algorithmQueue.first;
    }
    return null;
  }

  /// Obtener la canción anterior sin removerla del historial (para preview)
  Song? peekPreviousSong() {
    if (state.playbackMode == PlaybackMode.fixedQueue) {
      // En modo playlist, buscar en la lista
      if (_fixedQueueSongs.isEmpty) return null;
      final currentIndex = _fixedQueueSongs.indexWhere((s) => s.id == state.currentSong?.id);
      if (currentIndex == -1) return null;
      
      if (currentIndex > 0) {
        return _fixedQueueSongs[currentIndex - 1];
      } else if (state.repeatMode == RepeatMode.all) {
        return _fixedQueueSongs.last;
      }
      return null;
    } else {
      // En modo algoritmo, usar el historial
      if (_historyStack.isEmpty) return null;
      // Devolver la última canción del historial sin removerla (más reciente)
      return _historyStack.last;
    }
  }

  /// ⚡ Canción anterior - PRIMERO reinicia, LUEGO retrocede
  Future<void> previous() async {
    if (state.currentSong == null) return;
    
    try {
      final player = _activePlayer;
      if (player == null) return;
      
      // ⚡ PASO 1: Si la canción NO está en cero (más de 3 segundos), reiniciarla primero
      final currentPosition = state.currentPosition;
      if (currentPosition.inSeconds > 3) {
        await player.seek(Duration.zero);
        state = state.copyWith(currentPosition: Duration.zero);
        return; // Solo reiniciar, esperar siguiente presión para retroceder
      }
      
      // ⚡ PASO 2: Si ya está en cero (menos de 3 segundos), cambiar a canción anterior
      if (state.playbackMode == PlaybackMode.fixedQueue) {
        // MODO PLAYLIST: Ir a canción anterior en la lista
        if (_fixedQueueSongs.isEmpty) return;

        final currentIndex = _fixedQueueSongs.indexWhere((s) => s.id == state.currentSong?.id);
        if (currentIndex == -1) return;

        Song? previousSong;
        
        if (currentIndex > 0) {
          previousSong = _fixedQueueSongs[currentIndex - 1];
        } else if (state.repeatMode == RepeatMode.all) {
          previousSong = _fixedQueueSongs.last;
        } else {
          return; // Ya está en la primera, no hacer nada
        }

        if (previousSong.fileUrl == null || previousSong.fileUrl!.isEmpty) {
          return;
        }

        final fixedPlayer = _fixedQueuePlayer;
        if (fixedPlayer == null) return;

        state = state.copyWith(
          currentSong: previousSong,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          isPlaying: true,
        );

        final normalizedUrl = UrlNormalizer.normalizeUrl(previousSong.fileUrl!);
        await fixedPlayer.setUrl(normalizedUrl);
        
        final duration = fixedPlayer.duration ?? Duration.zero;
        state = state.copyWith(totalDuration: duration);
        
        await fixedPlayer.play();
        fixedPlayer.setVolume(1.0);

        _lastTrackedProgressMs = 0;
        _streamsApi.resetRateLimit();

      } else if (state.playbackMode == PlaybackMode.algorithm) {
        // MODO ALGORITMO: Ir a canción anterior del historial
        
        // 🎯 SPOTIFY-STYLE PREVIOUS: 
        // 1. Si no hay historial, ya estamos en la primera canción
        if (_historyStack.isEmpty) {
          return; // Ya estamos en la primera canción
        }
        
        // 2. Obtener canción anterior del history stack (LIFO - última es la más reciente)
        final previousSong = _historyStack.removeLast();
        
        // Validar canción anterior
        if (previousSong.fileUrl == null || previousSong.fileUrl!.isEmpty) {
          return;
        }
        
        // 3. SPOTIFY-STYLE: La canción actual va al INICIO del upcoming queue
        // ⚡ CRÍTICO: Guardar la canción actual ANTES de reproducir la anterior
        // Esto asegura que cuando avances después, vuelvas a la canción que estaba sonando
        final currentSong = state.currentSong;
        if (currentSong != null && currentSong.id != previousSong.id) {
          // Verificar que no esté ya en upcomingQueue para evitar duplicados
          if (!_upcomingQueue.any((s) => s.id == currentSong.id)) {
            _upcomingQueue.insert(0, currentSong);
          }
        }
        
        // 4. Reproducir canción anterior (sin guardar en historial - ya lo manejamos)
        await playSong(previousSong, useAlgorithm: true, skipHistory: true, forcePlay: true);
        
        // Resetear tracking
        _lastTrackedProgressMs = 0;
        _streamsApi.resetRateLimit();
      } else {
        // Si no hay modo de reproducción activo, intentar usar el historial si existe
        if (_historyStack.isEmpty) {
          return;
        }
        
        // SPOTIFY-STYLE PREVIOUS
        final previousSong = _historyStack.removeLast();
        final currentSong = state.currentSong;
        
        // ⚡ CRÍTICO: Guardar canción actual en upcomingQueue antes de reproducir anterior
        if (currentSong != null && currentSong.id != previousSong.id) {
          if (!_upcomingQueue.any((s) => s.id == currentSong.id)) {
            _upcomingQueue.insert(0, currentSong);
          }
        }
        
        if (previousSong.fileUrl == null || previousSong.fileUrl!.isEmpty) {
          return;
        }
        
        await playSong(previousSong, useAlgorithm: true, skipHistory: true);
      }
    } catch (e, stackTrace) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error en previous(): $e', stackTrace);
    }
  }

  /// Toggle shuffle
  void toggleShuffle() {
    state = state.copyWith(isShuffled: !state.isShuffled);
    AppLogger.info('[UnifiedAudioNotifier] 🔀 Shuffle: ${state.isShuffled}');
  }

  /// Toggle repeat mode
  void toggleRepeat() {
    final nextMode = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
    AppLogger.info('[UnifiedAudioNotifier] 🔁 Repeat mode: $nextMode');
  }

  /// ✅ Limpiar recursos
  /// 🆕 MEJORA 1 y 3: Limpia también precarga e historial
  void _dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    
    _algorithmPlayer?.dispose();
    _fixedQueuePlayer?.dispose();
    
    _positionSubscription = null;
    _durationSubscription = null;
    _playerStateSubscription = null;
    _algorithmPlayer = null;
    _fixedQueuePlayer = null;
    _isInitialized = false;
    
    // 🆕 Limpiar precarga e historial
    _preloadedNextSong = null;
    _isPreloadingNext = false;
    _hasTriggeredPreload = false;
    _recentSongIds.clear();
    _historyStack.clear();
    _preloadedPlayer = null;
    _preloadedSongId = null;
    _shouldActivateAlgorithmOnCompletion = false;
    
    // ⚡ SPOTIFY-STYLE: Limpiar colas duales
    _userQueue.clear();
    _algorithmQueue.clear();
    _prefetchedNextSong = null;
    _isPrefetching = false;
    _isGeneratingQueue = false;
    _currentIndex = 0;
    _lastArtistId = null;
    _recentAlgorithmSongs.clear();
    
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
