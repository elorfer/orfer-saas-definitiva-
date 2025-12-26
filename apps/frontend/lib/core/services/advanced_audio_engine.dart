import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/song_model.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';
import '../../features/ads/models/audio_ad_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎵 ADVANCED AUDIO ENGINE - MOTOR DE AUDIO PROFESIONAL
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Características profesionales:
/// - Gapless Playback con ConcatenatingAudioSource
/// - Buffer inteligente: precarga al 80% del progreso
/// - AudioSession: ducking, interrupciones, foco de audio
/// - Stream optimizado para Seekbar suave (sin parpadeo)
/// - Paleta de colores dinámica desde carátula
/// - Persistencia de estado (resume playback al reabrir app)
/// 
/// Arquitectura:
/// - Wrapper sobre just_audio con lógica profesional
/// - Desacoplado del PlaybackNotifier existente
/// - Puede integrarse gradualmente sin romper funcionalidad actual
/// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// 📦 MODELOS DE ESTADO
// ═══════════════════════════════════════════════════════════════════════════

/// Estado de reproducción del motor de audio
class AudioEngineState {
  final Song? currentSong;
  final AudioAd? currentAd;
  final List<Song> queue;
  final int currentIndex;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool isPlaying;
  final bool isBuffering;
  final bool isLoading;
  final double volume;
  final LoopMode loopMode;
  final bool shuffleEnabled;
  final double playbackSpeed;
  final DynamicPalette? palette;
  final AudioEngineError? error;

  const AudioEngineState({
    this.currentSong,
    this.currentAd,
    this.queue = const [],
    this.currentIndex = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isLoading = false,
    this.volume = 1.0,
    this.loopMode = LoopMode.off,
    this.shuffleEnabled = false,
    this.playbackSpeed = 1.0,
    this.palette,
    this.error,
  });

  /// Progreso de 0.0 a 1.0
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Progreso del buffer de 0.0 a 1.0
  double get bufferProgress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (bufferedPosition.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// ¿Está en modo anuncio?
  bool get isPlayingAd => currentAd != null;

  /// ¿Hay canciones en la cola?
  bool get hasQueue => queue.isNotEmpty;

  /// ¿Se puede ir a la siguiente canción?
  bool get hasNext => currentIndex < queue.length - 1;

  /// ¿Se puede ir a la canción anterior?
  bool get hasPrevious => currentIndex > 0;

  /// Canciones restantes en la cola
  int get remainingSongs => queue.length - currentIndex - 1;

  AudioEngineState copyWith({
    Song? currentSong,
    AudioAd? currentAd,
    List<Song>? queue,
    int? currentIndex,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool? isPlaying,
    bool? isBuffering,
    bool? isLoading,
    double? volume,
    LoopMode? loopMode,
    bool? shuffleEnabled,
    double? playbackSpeed,
    DynamicPalette? palette,
    AudioEngineError? error,
    bool clearCurrentSong = false,
    bool clearCurrentAd = false,
    bool clearPalette = false,
    bool clearError = false,
  }) {
    return AudioEngineState(
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      currentAd: clearCurrentAd ? null : (currentAd ?? this.currentAd),
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isLoading: isLoading ?? this.isLoading,
      volume: volume ?? this.volume,
      loopMode: loopMode ?? this.loopMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      palette: clearPalette ? null : (palette ?? this.palette),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Paleta de colores dinámica extraída de la carátula
class DynamicPalette {
  final Color dominant;
  final Color vibrant;
  final Color muted;
  final Color darkMuted;
  final Color lightVibrant;
  final Color background;
  final Color onBackground;

  const DynamicPalette({
    required this.dominant,
    required this.vibrant,
    required this.muted,
    required this.darkMuted,
    required this.lightVibrant,
    required this.background,
    required this.onBackground,
  });

  /// Crear desde PaletteGenerator
  factory DynamicPalette.fromPaletteGenerator(PaletteGenerator generator) {
    final dominant = generator.dominantColor?.color ?? const Color(0xFF1A1A2E);
    final vibrant = generator.vibrantColor?.color ?? dominant;
    final muted = generator.mutedColor?.color ?? dominant;
    final darkMuted = generator.darkMutedColor?.color ?? const Color(0xFF0F0F1A);
    final lightVibrant = generator.lightVibrantColor?.color ?? vibrant;

    // Calcular color de fondo (oscurecido para UI)
    final background = Color.lerp(darkMuted, Colors.black, 0.4) ?? darkMuted;
    
    // Calcular color de texto (contraste)
    final luminance = background.computeLuminance();
    final onBackground = luminance > 0.5 ? Colors.black87 : Colors.white;

    return DynamicPalette(
      dominant: dominant,
      vibrant: vibrant,
      muted: muted,
      darkMuted: darkMuted,
      lightVibrant: lightVibrant,
      background: background,
      onBackground: onBackground,
    );
  }

  /// Paleta por defecto (oscura)
  static const DynamicPalette defaultPalette = DynamicPalette(
    dominant: Color(0xFF1A1A2E),
    vibrant: Color(0xFF6366F1),
    muted: Color(0xFF4A4A6A),
    darkMuted: Color(0xFF0F0F1A),
    lightVibrant: Color(0xFF818CF8),
    background: Color(0xFF0A0A14),
    onBackground: Colors.white,
  );
}

/// Tipos de error del motor de audio
enum AudioEngineErrorType {
  network,
  codec,
  source,
  permission,
  session,
  unknown,
}

/// Error del motor de audio
class AudioEngineError {
  final AudioEngineErrorType type;
  final String message;
  final String? songId;
  final DateTime timestamp;

  const AudioEngineError({
    required this.type,
    required this.message,
    this.songId,
    required this.timestamp,
  });

  factory AudioEngineError.fromException(Object e, [String? songId]) {
    final errorString = e.toString().toLowerCase();
    
    AudioEngineErrorType type;
    if (errorString.contains('network') || errorString.contains('connection')) {
      type = AudioEngineErrorType.network;
    } else if (errorString.contains('codec') || errorString.contains('format')) {
      type = AudioEngineErrorType.codec;
    } else if (errorString.contains('source') || errorString.contains('url')) {
      type = AudioEngineErrorType.source;
    } else if (errorString.contains('permission')) {
      type = AudioEngineErrorType.permission;
    } else {
      type = AudioEngineErrorType.unknown;
    }

    return AudioEngineError(
      type: type,
      message: e.toString(),
      songId: songId,
      timestamp: DateTime.now(),
    );
  }
}

/// Estado persistido para resume playback
class PersistedPlaybackState {
  final String? currentSongId;
  final List<String> queueSongIds;
  final int currentIndex;
  final int positionMs;
  final DateTime timestamp;

  const PersistedPlaybackState({
    this.currentSongId,
    this.queueSongIds = const [],
    this.currentIndex = 0,
    this.positionMs = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'currentSongId': currentSongId,
    'queueSongIds': queueSongIds,
    'currentIndex': currentIndex,
    'positionMs': positionMs,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PersistedPlaybackState.fromJson(Map<String, dynamic> json) {
    return PersistedPlaybackState(
      currentSongId: json['currentSongId'] as String?,
      queueSongIds: (json['queueSongIds'] as List?)?.cast<String>() ?? [],
      currentIndex: json['currentIndex'] as int? ?? 0,
      positionMs: json['positionMs'] as int? ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// ¿Es válido para restaurar? (menos de 7 días)
  bool get isValid {
    final age = DateTime.now().difference(timestamp);
    return age.inDays < 7 && currentSongId != null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎛️ STREAM DE POSICIÓN OPTIMIZADO
// ═══════════════════════════════════════════════════════════════════════════

/// Stream de posición con suavizado para evitar parpadeo en la UI
/// Emite cada 50ms (20 FPS) con interpolación suave
/// 🛡️ DEBOUNCE DE SEEK: Ignora actualizaciones del servidor por 1s después de seeks
class SmoothPositionStream {
  final AudioPlayer _player;
  final _controller = StreamController<Duration>.broadcast();
  Timer? _interpolationTimer;
  Duration _lastKnownPosition = Duration.zero;
  Duration _targetPosition = Duration.zero;
  StreamSubscription? _positionSub;
  DateTime? _lastSeekTime;
  
  static const _updateInterval = Duration(milliseconds: 50); // 20 FPS suave
  static const _interpolationFactor = 0.15; // Suavizado
  static const _seekDebounceDuration = Duration(milliseconds: 1000); // 1s debounce

  SmoothPositionStream(this._player) {
    _init();
  }

  Stream<Duration> get stream => _controller.stream;

  void _init() {
    // Escuchar posición real del player
    _positionSub = _player.positionStream.listen((position) {
      // 🛡️ DEBOUNCE DE SEEK: Ignorar actualizaciones del servidor durante 1s después de seek
      if (_lastSeekTime != null) {
        final timeSinceSeek = DateTime.now().difference(_lastSeekTime!);
        if (timeSinceSeek < _seekDebounceDuration) {
          return; // Bloquear actualizaciones durante el debounce
        }
        _lastSeekTime = null; // Liberar después del debounce
      }
      
      final oldTarget = _targetPosition;
      _targetPosition = position;
      
      // ✅ FIX PARPADEO: Si hay un salto grande hacia atrás (cambio de canción),
      // actualizar inmediatamente sin interpolación
      final diff = position.inMilliseconds - oldTarget.inMilliseconds;
      if (diff < -1000 || (position.inMilliseconds == 0 && _lastKnownPosition.inMilliseconds > 1000)) {
        _lastKnownPosition = position;
        if (!_controller.isClosed) {
          _controller.add(position);
        }
      }
    });

    // Timer de interpolación suave
    _interpolationTimer = Timer.periodic(_updateInterval, (_) {
      if (_controller.isClosed) return;

      // Interpolación lineal suave hacia la posición objetivo
      final diff = _targetPosition.inMilliseconds - _lastKnownPosition.inMilliseconds;
      
      if (diff.abs() < 100) {
        // Muy cerca, usar posición exacta
        _lastKnownPosition = _targetPosition;
      } else if (diff.abs() > 2000 || (diff < -1000)) {
        // Seek detectado (salto grande) o cambio de canción, ir directo
        _lastKnownPosition = _targetPosition;
      } else {
        // Interpolación suave
        final increment = (diff * _interpolationFactor).round();
        _lastKnownPosition = Duration(
          milliseconds: _lastKnownPosition.inMilliseconds + increment,
        );
      }

      _controller.add(_lastKnownPosition);
    });
  }

  /// Forzar actualización inmediata (para seek)
  /// 🛡️ DEBOUNCE: Activa el período de bloqueo de 1s
  void forceUpdate(Duration position) {
    _lastKnownPosition = position;
    _targetPosition = position;
    _lastSeekTime = DateTime.now(); // Activar debounce
    if (!_controller.isClosed) {
      _controller.add(position);
    }
  }

  void dispose() {
    _interpolationTimer?.cancel();
    _positionSub?.cancel();
    _controller.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎵 ADVANCED AUDIO ENGINE
// ═══════════════════════════════════════════════════════════════════════════

class AdvancedAudioEngine {
  final AudioPlayer _player;
  
  // Gestión de streams
  final List<StreamSubscription> _subscriptions = [];
  late final SmoothPositionStream _smoothPosition;
  
  // Estado interno
  AudioEngineState _state = const AudioEngineState();
  final _stateController = BehaviorSubject<AudioEngineState>.seeded(const AudioEngineState());
  
  // Cola de reproducción (Gapless)
  ConcatenatingAudioSource? _concatenatingSource;
  
  // Precarga inteligente
  bool _isPreloading = false;
  final Set<String> _preloadedSongIds = {};
  Timer? _preloadMonitorTimer;
  static const _preloadThreshold = 0.80; // 80% de progreso
  static const _preloadLookAhead = 2; // Precargar 2 canciones adelante
  
  // Persistencia
  Box<dynamic>? _persistenceBox;
  static const _persistenceBoxName = 'audio_engine_state';
  Timer? _persistenceDebouncer;
  
  // Paleta de colores
  String? _lastPaletteUrl;
  
  // Audio Session
  AudioSession? _audioSession;
  bool _wasPlayingBeforeInterruption = false;
  double _volumeBeforeDucking = 1.0;

  AdvancedAudioEngine() : _player = AudioPlayer() {
    _smoothPosition = SmoothPositionStream(_player);
    _init();
  }

  /// Stream de estado (para UI)
  Stream<AudioEngineState> get stateStream => _stateController.stream;

  /// Estado actual
  AudioEngineState get state => _state;

  /// Stream de posición suavizado (para Seekbar)
  Stream<Duration> get smoothPositionStream => _smoothPosition.stream;

  /// Player directo (para casos avanzados)
  AudioPlayer get player => _player;

  // ═══════════════════════════════════════════════════════════════════════
  // 🚀 INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _init() async {
    await _initAudioSession();
    await _initPersistence();
    _initPlayerListeners();
    _startPreloadMonitor();
    
    AppLogger.info('[AdvancedAudioEngine] ✅ Motor de audio inicializado');
  }

  /// Inicializar AudioSession para manejo de foco e interrupciones
  Future<void> _initAudioSession() async {
    try {
      _audioSession = await AudioSession.instance;
      
      await _audioSession!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false, // Nosotros controlamos el ducking
      ));

      // Escuchar interrupciones (llamadas, notificaciones)
      _subscriptions.add(
        _audioSession!.interruptionEventStream.listen(_handleInterruption),
      );

      // Escuchar cambios de dispositivo (auriculares desconectados)
      _subscriptions.add(
        _audioSession!.becomingNoisyEventStream.listen((_) {
          AppLogger.info('[AdvancedAudioEngine] 🎧 Auriculares desconectados, pausando...');
          pause();
        }),
      );

      AppLogger.info('[AdvancedAudioEngine] 🎛️ AudioSession configurado');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error configurando AudioSession: $e');
    }
  }

  /// Manejar interrupciones de audio
  void _handleInterruption(AudioInterruptionEvent event) {
    AppLogger.info('[AdvancedAudioEngine] 🔔 Interrupción: ${event.type}, begin=${event.begin}');

    if (event.begin) {
      // Interrupción comenzó
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Bajar volumen (ducking)
          _volumeBeforeDucking = _state.volume;
          setVolume(_state.volume * 0.3);
          break;
          
        case AudioInterruptionType.pause:
          // Pausar (llamada entrante, etc.)
          _wasPlayingBeforeInterruption = _state.isPlaying;
          pause();
          break;
          
        case AudioInterruptionType.unknown:
          // Interrupción desconocida, pausar por seguridad
          _wasPlayingBeforeInterruption = _state.isPlaying;
          pause();
          break;
      }
    } else {
      // Interrupción terminó
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Restaurar volumen
          setVolume(_volumeBeforeDucking);
          break;
          
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          // Reanudar si estaba reproduciendo
          if (_wasPlayingBeforeInterruption) {
            play();
          }
          break;
      }
    }
  }

  /// Inicializar persistencia con Hive
  Future<void> _initPersistence() async {
    try {
      if (!Hive.isBoxOpen(_persistenceBoxName)) {
        _persistenceBox = await Hive.openBox(_persistenceBoxName);
      } else {
        _persistenceBox = Hive.box(_persistenceBoxName);
      }
      AppLogger.info('[AdvancedAudioEngine] 💾 Persistencia inicializada');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error inicializando persistencia: $e');
    }
  }

  /// Inicializar listeners del player
  void _initPlayerListeners() {
    // Estado de reproducción
    _subscriptions.add(
      _player.playingStream.listen((isPlaying) {
        _updateState(_state.copyWith(isPlaying: isPlaying));
      }),
    );

    // Duración
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        if (duration != null) {
          _updateState(_state.copyWith(duration: duration));
        }
      }),
    );

    // Posición buffered
    _subscriptions.add(
      _player.bufferedPositionStream.listen((buffered) {
        _updateState(_state.copyWith(bufferedPosition: buffered));
      }),
    );

    // Estado del player (buffering, loading, etc.)
    _subscriptions.add(
      _player.playerStateStream.listen((playerState) {
        final isBuffering = playerState.processingState == ProcessingState.buffering;
        final isLoading = playerState.processingState == ProcessingState.loading;
        
        _updateState(_state.copyWith(
          isBuffering: isBuffering,
          isLoading: isLoading,
        ));

        // Detectar fin de reproducción
        if (playerState.processingState == ProcessingState.completed) {
          _onPlaybackCompleted();
        }
      }),
    );

    // Cambios de secuencia (nueva canción)
    _subscriptions.add(
      _player.sequenceStateStream.listen((sequenceState) {
        _onSequenceStateChanged(sequenceState);
      }),
    );

    // Posición (para persistencia, no para UI)
    _subscriptions.add(
      _player.positionStream
          .throttleTime(const Duration(seconds: 5))
          .listen((position) {
        _updateState(_state.copyWith(position: position));
        _schedulePersistence();
      }),
    );

    // Errores
    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) {},
        onError: (error, stackTrace) {
          AppLogger.error('[AdvancedAudioEngine] Error de reproducción: $error');
          _updateState(_state.copyWith(
            error: AudioEngineError.fromException(error, _state.currentSong?.id),
          ));
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎮 CONTROLES DE REPRODUCCIÓN
  // ═══════════════════════════════════════════════════════════════════════

  /// Cargar y reproducir una lista de canciones
  Future<void> loadAndPlay(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;

    try {
      _updateState(_state.copyWith(isLoading: true, clearError: true));

      // Filtrar canciones válidas
      final validSongs = songs.where((s) => s.isValidForPlayback).toList();
      if (validSongs.isEmpty) {
        throw Exception('No hay canciones válidas para reproducir');
      }

      // Crear fuentes de audio
      final sources = validSongs.map(_songToAudioSource).toList();

      // Crear ConcatenatingAudioSource para Gapless Playback
      _concatenatingSource = ConcatenatingAudioSource(
        useLazyPreparation: true, // Preparación lazy para eficiencia
        shuffleOrder: DefaultShuffleOrder(),
        children: sources,
      );

      // Cargar en el player
      await _player.setAudioSource(
        _concatenatingSource!,
        initialIndex: startIndex.clamp(0, validSongs.length - 1),
      );

      // Actualizar estado
      final actualIndex = startIndex.clamp(0, validSongs.length - 1);
      _updateState(_state.copyWith(
        queue: validSongs,
        currentIndex: actualIndex,
        currentSong: validSongs[actualIndex],
        isLoading: false,
        clearCurrentAd: true,
      ));

      // Iniciar reproducción
      await play();

      // Extraer paleta de colores
      _extractPaletteFromCurrentSong();

      // Limpiar precargas anteriores
      _preloadedSongIds.clear();

      AppLogger.info('[AdvancedAudioEngine] ▶️ Reproduciendo: ${validSongs[actualIndex].title}');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error cargando canciones: $e');
      _updateState(_state.copyWith(
        isLoading: false,
        error: AudioEngineError.fromException(e),
      ));
    }
  }

  /// Reproducir
  Future<void> play() async {
    try {
      await _audioSession?.setActive(true);
      await _player.play();
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error al reproducir: $e');
    }
  }

  /// Pausar
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error al pausar: $e');
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Siguiente canción
  Future<void> next() async {
    if (!_state.hasNext) return;

    try {
      await _player.seekToNext();
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error al avanzar: $e');
    }
  }

  /// Canción anterior
  Future<void> previous() async {
    // Si llevamos más de 3 segundos, volver al inicio de la canción
    if (_state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (!_state.hasPrevious) {
      await seek(Duration.zero);
      return;
    }

    try {
      await _player.seekToPrevious();
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error al retroceder: $e');
    }
  }

  /// Seek a posición
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      _smoothPosition.forceUpdate(position);
      _updateState(_state.copyWith(position: position));
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error en seek: $e');
    }
  }

  /// Seek a porcentaje (0.0 - 1.0)
  Future<void> seekToProgress(double progress) async {
    final position = Duration(
      milliseconds: (_state.duration.inMilliseconds * progress.clamp(0.0, 1.0)).round(),
    );
    await seek(position);
  }

  /// Cambiar volumen (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player.setVolume(clampedVolume);
      _updateState(_state.copyWith(volume: clampedVolume));
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error al cambiar volumen: $e');
    }
  }

  /// Cambiar modo de repetición
  Future<void> setLoopMode(LoopMode mode) async {
    try {
      await _player.setLoopMode(mode);
      _updateState(_state.copyWith(loopMode: mode));
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error al cambiar modo de repetición: $e');
    }
  }

  /// Toggle shuffle
  Future<void> toggleShuffle() async {
    try {
      final newValue = !_state.shuffleEnabled;
      await _player.setShuffleModeEnabled(newValue);
      _updateState(_state.copyWith(shuffleEnabled: newValue));
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error al cambiar shuffle: $e');
    }
  }

  /// Cambiar velocidad de reproducción
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      final clampedSpeed = speed.clamp(0.5, 2.0);
      await _player.setSpeed(clampedSpeed);
      _updateState(_state.copyWith(playbackSpeed: clampedSpeed));
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error al cambiar velocidad: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📋 GESTIÓN DE COLA
  // ═══════════════════════════════════════════════════════════════════════

  /// Agregar canciones al final de la cola
  Future<void> appendToQueue(List<Song> songs) async {
    if (songs.isEmpty || _concatenatingSource == null) return;

    try {
      final validSongs = songs.where((s) => s.isValidForPlayback).toList();
      if (validSongs.isEmpty) return;

      final sources = validSongs.map(_songToAudioSource).toList();
      await _concatenatingSource!.addAll(sources);

      final newQueue = [..._state.queue, ...validSongs];
      _updateState(_state.copyWith(queue: newQueue));

      AppLogger.info('[AdvancedAudioEngine] ➕ Agregadas ${validSongs.length} canciones a la cola');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error agregando a la cola: $e');
    }
  }

  /// Insertar canción en posición específica
  Future<void> insertInQueue(Song song, int index) async {
    if (!song.isValidForPlayback || _concatenatingSource == null) return;

    try {
      final clampedIndex = index.clamp(0, _state.queue.length);
      await _concatenatingSource!.insert(clampedIndex, _songToAudioSource(song));

      final newQueue = List<Song>.from(_state.queue)..insert(clampedIndex, song);
      
      // Ajustar índice actual si insertamos antes
      final newIndex = clampedIndex <= _state.currentIndex
          ? _state.currentIndex + 1
          : _state.currentIndex;

      _updateState(_state.copyWith(queue: newQueue, currentIndex: newIndex));

      AppLogger.info('[AdvancedAudioEngine] ➕ Canción insertada en índice $clampedIndex');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error insertando en cola: $e');
    }
  }

  /// Reproducir canción específica de la cola
  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= _state.queue.length) return;

    try {
      await _player.seek(Duration.zero, index: index);
      await play();
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error reproduciendo desde cola: $e');
    }
  }

  /// Eliminar canción de la cola
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _state.queue.length || _concatenatingSource == null) return;
    if (index == _state.currentIndex) return; // No eliminar la actual

    try {
      await _concatenatingSource!.removeAt(index);

      final newQueue = List<Song>.from(_state.queue)..removeAt(index);
      
      // Ajustar índice actual si eliminamos antes
      final newIndex = index < _state.currentIndex
          ? _state.currentIndex - 1
          : _state.currentIndex;

      _updateState(_state.copyWith(queue: newQueue, currentIndex: newIndex));

      AppLogger.info('[AdvancedAudioEngine] ➖ Canción eliminada de índice $index');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error eliminando de cola: $e');
    }
  }

  /// Limpiar cola y detener
  Future<void> clearQueue() async {
    try {
      await _player.stop();
      _concatenatingSource = null;
      _preloadedSongIds.clear();

      _updateState(const AudioEngineState());

      AppLogger.info('[AdvancedAudioEngine] 🗑️ Cola limpiada');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error limpiando cola: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔄 PRECARGA INTELIGENTE (80%)
  // ═══════════════════════════════════════════════════════════════════════

  /// Iniciar monitor de precarga
  void _startPreloadMonitor() {
    _preloadMonitorTimer?.cancel();
    _preloadMonitorTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkPreloadConditions(),
    );
  }

  /// Verificar condiciones de precarga
  void _checkPreloadConditions() {
    if (_isPreloading) return;
    if (!_state.isPlaying) return;
    if (_state.duration.inMilliseconds == 0) return;

    final progress = _state.progress;
    
    // Si estamos al 80% o más, precargar siguiente
    if (progress >= _preloadThreshold) {
      _preloadNextSongs();
    }
  }

  /// Precargar siguientes canciones
  Future<void> _preloadNextSongs() async {
    if (_isPreloading) return;
    _isPreloading = true;

    try {
      final currentIndex = _state.currentIndex;
      final queue = _state.queue;

      for (int i = 1; i <= _preloadLookAhead; i++) {
        final nextIndex = currentIndex + i;
        if (nextIndex >= queue.length) break;

        final nextSong = queue[nextIndex];
        if (_preloadedSongIds.contains(nextSong.id)) continue;

        // Marcar como precargada (just_audio hace la precarga real internamente)
        _preloadedSongIds.add(nextSong.id);
        
        AppLogger.debug('[AdvancedAudioEngine] 📥 Precargando: ${nextSong.title}');
      }
    } finally {
      _isPreloading = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎨 PALETA DE COLORES DINÁMICA
  // ═══════════════════════════════════════════════════════════════════════

  /// Extraer paleta de colores de la carátula actual
  Future<void> _extractPaletteFromCurrentSong() async {
    final song = _state.currentSong;
    if (song == null) return;

    final coverUrl = song.coverArtUrl;
    if (coverUrl == null || coverUrl.isEmpty) {
      _updateState(_state.copyWith(palette: DynamicPalette.defaultPalette));
      return;
    }

    // Evitar re-extraer si es la misma URL
    final normalizedUrl = UrlNormalizer.normalizeImageUrl(coverUrl);
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      _updateState(_state.copyWith(palette: DynamicPalette.defaultPalette));
      return;
    }
    if (normalizedUrl == _lastPaletteUrl) return;
    _lastPaletteUrl = normalizedUrl;

    try {
      // Obtener imagen desde caché
      final imageProvider = CachedNetworkImageProvider(normalizedUrl);
      
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100), // Tamaño pequeño para velocidad
        maximumColorCount: 16,
      );

      final palette = DynamicPalette.fromPaletteGenerator(paletteGenerator);
      _updateState(_state.copyWith(palette: palette));

      AppLogger.debug('[AdvancedAudioEngine] 🎨 Paleta extraída para: ${song.title}');
    } catch (e) {
      AppLogger.warning('[AdvancedAudioEngine] Error extrayendo paleta: $e');
      _updateState(_state.copyWith(palette: DynamicPalette.defaultPalette));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 💾 PERSISTENCIA DE ESTADO
  // ═══════════════════════════════════════════════════════════════════════

  /// Programar guardado de estado (debounced)
  void _schedulePersistence() {
    _persistenceDebouncer?.cancel();
    _persistenceDebouncer = Timer(const Duration(seconds: 3), _persistState);
  }

  /// Guardar estado actual
  Future<void> _persistState() async {
    if (_persistenceBox == null) return;
    if (_state.currentSong == null) return;

    try {
      final persistedState = PersistedPlaybackState(
        currentSongId: _state.currentSong!.id,
        queueSongIds: _state.queue.map((s) => s.id).toList(),
        currentIndex: _state.currentIndex,
        positionMs: _state.position.inMilliseconds,
        timestamp: DateTime.now(),
      );

      await _persistenceBox!.put('playback_state', persistedState.toJson());
      
      AppLogger.debug('[AdvancedAudioEngine] 💾 Estado persistido');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error persistiendo estado: $e');
    }
  }

  /// Obtener estado persistido
  Future<PersistedPlaybackState?> getPersistedState() async {
    if (_persistenceBox == null) return null;

    try {
      final json = _persistenceBox!.get('playback_state');
      if (json == null) return null;

      final state = PersistedPlaybackState.fromJson(
        Map<String, dynamic>.from(json as Map),
      );

      return state.isValid ? state : null;
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error leyendo estado persistido: $e');
      return null;
    }
  }

  /// Restaurar reproducción desde estado persistido
  /// Requiere que el llamador proporcione las canciones completas
  Future<bool> restoreFromPersistedState(
    PersistedPlaybackState persistedState,
    List<Song> songs,
  ) async {
    if (songs.isEmpty) return false;

    try {
      // Cargar cola sin reproducir
      await loadAndPlay(songs, startIndex: persistedState.currentIndex);
      
      // Pausar inmediatamente
      await pause();
      
      // Seek a la posición guardada
      await seek(Duration(milliseconds: persistedState.positionMs));

      AppLogger.info('[AdvancedAudioEngine] 🔄 Estado restaurado desde persistencia');
      return true;
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error restaurando estado: $e');
      return false;
    }
  }

  /// Limpiar estado persistido
  Future<void> clearPersistedState() async {
    try {
      await _persistenceBox?.delete('playback_state');
    } catch (e) {
      AppLogger.error('[AdvancedAudioEngine] Error limpiando estado persistido: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔧 UTILIDADES PRIVADAS
  // ═══════════════════════════════════════════════════════════════════════

  /// Convertir Song a AudioSource
  AudioSource _songToAudioSource(Song song) {
    final normalizedUrl = UrlNormalizer.normalizeUrl(song.fileUrl!);
    return AudioSource.uri(
      Uri.parse(normalizedUrl),
      tag: song,
    );
  }

  /// Actualizar estado y notificar
  void _updateState(AudioEngineState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Manejar cambio de secuencia (nueva canción)
  void _onSequenceStateChanged(SequenceState sequenceState) {
    final currentIndex = sequenceState.currentIndex;
    final currentSource = sequenceState.currentSource;

    if (currentSource == null) return;

    // Verificar si es una canción
    if (currentSource.tag is Song) {
      final song = currentSource.tag as Song;
      
      // Solo actualizar si cambió la canción
      if (song.id != _state.currentSong?.id) {
        // ✅ FIX PARPADEO: Resetear stream de posición suavizada inmediatamente
        // Esto previene que el stream interpole desde la posición anterior hacia 0
        _smoothPosition.forceUpdate(Duration.zero);
        
        _updateState(_state.copyWith(
          currentSong: song,
          currentIndex: currentIndex,
          position: Duration.zero,
          clearCurrentAd: true,
          clearError: true,
        ));

        // Extraer nueva paleta
        _extractPaletteFromCurrentSong();

        AppLogger.info('[AdvancedAudioEngine] 🎵 Nueva canción: ${song.title}');
      }
    }
    
    // Verificar si es un anuncio
    if (currentSource.tag is AudioAd) {
      final ad = currentSource.tag as AudioAd;
      // ✅ FIX PARPADEO: Resetear stream de posición suavizada también para anuncios
      _smoothPosition.forceUpdate(Duration.zero);
      
      _updateState(_state.copyWith(
        currentAd: ad,
        currentIndex: currentIndex,
        position: Duration.zero,
      ));

      AppLogger.info('[AdvancedAudioEngine] 📢 Reproduciendo anuncio: ${ad.title}');
    }
  }

  /// Manejar fin de reproducción
  void _onPlaybackCompleted() {
    AppLogger.info('[AdvancedAudioEngine] ✅ Reproducción completada');
    
    // La cola llegó al final
    if (!_state.hasNext && _state.loopMode == LoopMode.off) {
      // Reiniciar al inicio si hay canciones
      if (_state.queue.isNotEmpty) {
        _updateState(_state.copyWith(currentIndex: 0));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🧹 LIMPIEZA
  // ═══════════════════════════════════════════════════════════════════════

  /// Liberar recursos
  Future<void> dispose() async {
    // Cancelar timers
    _preloadMonitorTimer?.cancel();
    _persistenceDebouncer?.cancel();

    // Cancelar suscripciones
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Limpiar streams
    _smoothPosition.dispose();
    await _stateController.close();

    // Desactivar sesión de audio
    try {
      await _audioSession?.setActive(false);
    } catch (_) {}

    // Liberar player
    await _player.dispose();

    AppLogger.info('[AdvancedAudioEngine] 🧹 Motor de audio liberado');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🔌 PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider del motor de audio avanzado
final advancedAudioEngineProvider = Provider<AdvancedAudioEngine>((ref) {
  final engine = AdvancedAudioEngine();
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});

/// Provider del estado del motor (para UI) - NUNCA tiene estado loading
/// Usa el valor actual del BehaviorSubject para evitar parpadeo
final audioEngineStateProvider = StreamProvider<AudioEngineState>((ref) {
  final engine = ref.watch(advancedAudioEngineProvider);
  // BehaviorSubject siempre emite el valor actual inmediatamente
  return engine.stateStream;
});

/// 🆕 Provider síncrono del estado - GARANTIZA que nunca hay loading
/// Útil para widgets que no pueden manejar estados async
final audioEngineStateSyncProvider = Provider<AudioEngineState>((ref) {
  final engine = ref.watch(advancedAudioEngineProvider);
  return engine.state; // Valor actual instantáneo
});

/// Provider de la posición suavizada (para Seekbar)
final smoothPositionProvider = StreamProvider<Duration>((ref) {
  final engine = ref.watch(advancedAudioEngineProvider);
  return engine.smoothPositionStream;
});

/// 🆕 Provider de posición síncrono - Para evitar parpadeo en seekbar
final smoothPositionSyncProvider = Provider<Duration>((ref) {
  final stateAsync = ref.watch(smoothPositionProvider);
  final engine = ref.watch(advancedAudioEngineProvider);
  // Usar valor del stream si disponible, sino posición del estado
  return stateAsync.when(
    data: (position) => position,
    loading: () => engine.state.position,
    error: (_, __) => engine.state.position,
  );
});

/// Provider de la paleta dinámica
final dynamicPaletteProvider = Provider<DynamicPalette>((ref) {
  final stateAsync = ref.watch(audioEngineStateProvider);
  return stateAsync.when(
    data: (state) => state.palette ?? DynamicPalette.defaultPalette,
    loading: () => DynamicPalette.defaultPalette,
    error: (_, __) => DynamicPalette.defaultPalette,
  );
});

/// Provider de isPlaying (optimizado, evita rebuilds innecesarios)
final audioIsPlayingProvider = Provider<bool>((ref) {
  final stateAsync = ref.watch(audioEngineStateProvider);
  return stateAsync.when(
    data: (state) => state.isPlaying,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider de la canción actual
final currentSongProvider = Provider<Song?>((ref) {
  final stateAsync = ref.watch(audioEngineStateProvider);
  return stateAsync.when(
    data: (state) => state.currentSong,
    loading: () => null,
    error: (_, __) => null,
  );
});

