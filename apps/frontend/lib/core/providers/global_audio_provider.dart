import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';

/// Estado global unificado del reproductor de audio
/// Esta es la ÚNICA fuente de verdad para todo el estado del audio
@immutable
class GlobalAudioState {
  final Song? currentSong;
  final bool isPlaying;
  final bool isBuffering;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlayerExpanded;
  final double volume;
  final bool isLoading;

  const GlobalAudioState({
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
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    return (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Verificar si hay una canción cargada
  bool get hasSong => currentSong != null;

  /// Verificar si se puede reproducir
  bool get canPlay => hasSong && !isLoading;

  GlobalAudioState copyWith({
    Song? currentSong,
    bool? isPlaying,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isPlayerExpanded,
    double? volume,
    bool? isLoading,
  }) {
    return GlobalAudioState(
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
    return other is GlobalAudioState &&
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
    return 'GlobalAudioState(song: ${currentSong?.title}, playing: $isPlaying, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}

/// Notifier global del reproductor de audio
/// ÚNICA instancia que maneja TODO el estado del audio
class GlobalAudioNotifier extends Notifier<GlobalAudioState> {
  // UN SOLO AudioPlayer para toda la aplicación
  AudioPlayer? _player;
  
  // Suscripciones a los streams del AudioPlayer
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // Timer para actualizaciones de progreso en tiempo real
  Timer? _progressTimer;
  
  // Flag para evitar loops infinitos
  bool _isUpdating = false;

  @override
  GlobalAudioState build() {
    // Inicializar el AudioPlayer cuando se crea el notifier
    _initializePlayer();
    
    // Limpiar recursos cuando se dispose
    ref.onDispose(() {
      _dispose();
    });
    
    return const GlobalAudioState();
  }

  /// Inicializar el AudioPlayer y configurar listeners
  void _initializePlayer() {
    if (_player != null) return;
    
    try {
      _player = AudioPlayer();
      _setupListeners();
      AppLogger.info('[GlobalAudioNotifier] ✅ AudioPlayer inicializado');
    } catch (e) {
      AppLogger.error('[GlobalAudioNotifier] ❌ Error inicializando AudioPlayer: $e');
    }
  }

  /// Configurar listeners del AudioPlayer
  void _setupListeners() {
    if (_player == null) return;

    // Listener de posición - actualización en tiempo real
    _positionSubscription = _player!.positionStream.listen((position) {
      if (!_isUpdating) {
        _updatePosition(position);
      }
    });

    // Listener de duración
    _durationSubscription = _player!.durationStream.listen((duration) {
      if (!_isUpdating && duration != null) {
        _updateDuration(duration);
      }
    });

    // Listener de estado del player
    _playerStateSubscription = _player!.playerStateStream.listen((playerState) {
      if (!_isUpdating) {
        _updatePlayerState(playerState);
      }
    });

    // Timer para actualizaciones fluidas de progreso
    _startProgressTimer();

    AppLogger.info('[GlobalAudioNotifier] ✅ Listeners configurados');
  }

  /// Iniciar timer para actualizaciones fluidas de progreso
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_player != null && state.isPlaying && !_isUpdating) {
        final position = _player!.position;
        if (position != state.currentPosition) {
          _updatePosition(position);
        }
      }
    });
    AppLogger.info('[GlobalAudioNotifier] ⏰ Timer de progreso iniciado');
  }

  /// Actualizar posición
  void _updatePosition(Duration position) {
    if (state.currentPosition != position) {
      state = state.copyWith(currentPosition: position);
      // 🔍 DEBUG: Log de actualización de posición
      if (position.inSeconds % 5 == 0 || position.inMilliseconds < 1000) {
        AppLogger.info('[GlobalAudioNotifier] 📍 Position updated: ${position.inSeconds}s');
      }
    }
  }

  /// Actualizar duración
  void _updateDuration(Duration duration) {
    if (state.totalDuration != duration) {
      state = state.copyWith(totalDuration: duration);
      AppLogger.info('[GlobalAudioNotifier] 📏 Duración actualizada: ${duration.inSeconds}s');
    }
  }

  /// Actualizar estado del player
  void _updatePlayerState(PlayerState playerState) {
    final newIsPlaying = playerState.playing;
    final newIsBuffering = playerState.processingState == ProcessingState.loading ||
                          playerState.processingState == ProcessingState.buffering;

    if (state.isPlaying != newIsPlaying || state.isBuffering != newIsBuffering) {
      state = state.copyWith(
        isPlaying: newIsPlaying,
        isBuffering: newIsBuffering,
      );
      
      AppLogger.info('[GlobalAudioNotifier] 🎵 Estado: playing=$newIsPlaying, buffering=$newIsBuffering');
    }

    // Detectar cuando una canción termina
    if (playerState.processingState == ProcessingState.completed) {
      AppLogger.info('[GlobalAudioNotifier] 🏁 Canción completada');
      _handleSongCompletion();
    }
  }

  /// Manejar cuando una canción termina
  void _handleSongCompletion() {
    // TODO: Implementar lógica de siguiente canción
    state = state.copyWith(
      isPlaying: false,
      currentPosition: state.totalDuration,
    );
  }

  /// Reproducir una canción
  Future<void> playSong(Song song) async {
    if (_player == null) {
      AppLogger.error('[GlobalAudioNotifier] ❌ AudioPlayer no inicializado');
      return;
    }

    try {
      _isUpdating = true;
      
      // Actualizar estado a loading
      state = state.copyWith(
        currentSong: song,
        isLoading: true,
        isPlaying: false,
        currentPosition: Duration.zero,
      );

      AppLogger.info('[GlobalAudioNotifier] 🎵 Cargando: ${song.title}');

      // Verificar que la URL no sea null
      if (song.fileUrl == null || song.fileUrl!.isEmpty) {
        throw Exception('URL de canción inválida: ${song.fileUrl}');
      }
      
      // Normalizar URL
      final normalizedUrl = UrlNormalizer.normalizeUrl(song.fileUrl!);

      // Cargar canción
      await _player!.setUrl(normalizedUrl);
      
      // Actualizar estado
      state = state.copyWith(
        isLoading: false,
        totalDuration: _player!.duration ?? Duration.zero,
      );

      // Reproducir
      await _player!.play();
      
      AppLogger.info('[GlobalAudioNotifier] ✅ Reproduciendo: ${song.title}');
      
    } catch (e) {
      AppLogger.error('[GlobalAudioNotifier] ❌ Error reproduciendo: $e');
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
      );
    } finally {
      _isUpdating = false;
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player == null || state.currentSong == null) return;

    try {
      if (state.isPlaying) {
        await _player!.pause();
      } else {
        await _player!.play();
      }
      AppLogger.info('[GlobalAudioNotifier] ⏯️ Toggle: ${state.isPlaying ? 'pause' : 'play'}');
    } catch (e) {
      AppLogger.error('[GlobalAudioNotifier] ❌ Error toggle: $e');
    }
  }

  /// Pausar
  Future<void> pause() async {
    if (_player == null) return;
    
    try {
      await _player!.pause();
    } catch (e) {
      AppLogger.error('[GlobalAudioNotifier] ❌ Error pause: $e');
    }
  }

  /// Reanudar
  Future<void> play() async {
    if (_player == null) return;
    
    try {
      await _player!.play();
    } catch (e) {
      AppLogger.error('[GlobalAudioNotifier] ❌ Error play: $e');
    }
  }

  /// Buscar posición
  Future<void> seek(Duration position) async {
    if (_player == null) return;
    
    try {
      await _player!.seek(position);
      AppLogger.info('[GlobalAudioNotifier] ⏭️ Seek: ${position.inSeconds}s');
    } catch (e) {
      AppLogger.error('[GlobalAudioNotifier] ❌ Error seek: $e');
    }
  }

  /// Cambiar volumen
  Future<void> setVolume(double volume) async {
    if (_player == null) return;
    
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player!.setVolume(clampedVolume);
      state = state.copyWith(volume: clampedVolume);
      AppLogger.info('[GlobalAudioNotifier] 🔊 Volumen: ${(clampedVolume * 100).toInt()}%');
    } catch (e) {
      AppLogger.error('[GlobalAudioNotifier] ❌ Error volumen: $e');
    }
  }

  /// Expandir/colapsar reproductor
  void setPlayerExpanded(bool expanded) {
    state = state.copyWith(isPlayerExpanded: expanded);
    AppLogger.info('[GlobalAudioNotifier] 🎬 Player expanded: $expanded');
  }

  /// Detener completamente
  Future<void> stop() async {
    if (_player == null) return;
    
    try {
      await _player!.stop();
      state = state.copyWith(
        isPlaying: false,
        currentPosition: Duration.zero,
      );
      AppLogger.info('[GlobalAudioNotifier] ⏹️ Detenido');
    } catch (e) {
      AppLogger.error('[GlobalAudioNotifier] ❌ Error stop: $e');
    }
  }

  /// Limpiar recursos
  void _dispose() {
    _progressTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player?.dispose();
    
    _progressTimer = null;
    _positionSubscription = null;
    _durationSubscription = null;
    _playerStateSubscription = null;
    _player = null;
    
    AppLogger.info('[GlobalAudioNotifier] 🧹 Recursos limpiados');
  }
}

/// Provider global del reproductor de audio
/// ESTA ES LA ÚNICA FUENTE DE VERDAD para todo el estado del audio
final globalAudioProvider = NotifierProvider<GlobalAudioNotifier, GlobalAudioState>(() {
  return GlobalAudioNotifier();
});

/// Providers de conveniencia para acceso rápido a partes específicas del estado
final currentSongProvider = Provider<Song?>((ref) {
  return ref.watch(globalAudioProvider).currentSong;
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(globalAudioProvider).isPlaying;
});

final audioProgressProvider = Provider<double>((ref) {
  return ref.watch(globalAudioProvider).progress;
});

final audioPositionProvider = Provider<Duration>((ref) {
  return ref.watch(globalAudioProvider).currentPosition;
});

final audioDurationProvider = Provider<Duration>((ref) {
  return ref.watch(globalAudioProvider).totalDuration;
});
