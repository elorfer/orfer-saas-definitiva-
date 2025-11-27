import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../services/professional_audio_service.dart';
import '../utils/logger.dart';

/// Estado unificado del reproductor de audio
@immutable
class AudioState {
  final Song? currentSong;
  final bool isPlaying;
  final bool isBuffering;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlayerExpanded;
  final double volume;

  const AudioState({
    this.currentSong,
    this.isPlaying = false,
    this.isBuffering = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isPlayerExpanded = false,
    this.volume = 0.85,
  });

  AudioState copyWith({
    Song? currentSong,
    bool? isPlaying,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isPlayerExpanded,
    double? volume,
  }) {
    return AudioState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isPlayerExpanded: isPlayerExpanded ?? this.isPlayerExpanded,
      volume: volume ?? this.volume,
    );
  }

  /// Calcular progreso de 0.0 a 1.0
  double get progress {
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    return (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioState &&
        other.currentSong?.id == currentSong?.id &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.currentPosition == currentPosition &&
        other.totalDuration == totalDuration &&
        other.isPlayerExpanded == isPlayerExpanded &&
        other.volume == volume;
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
    );
  }
}

/// Notifier unificado que maneja TODO el estado del audio
class UnifiedAudioNotifier extends Notifier<AudioState> {
  @override
  AudioState build() {
    // Inicializar inmediatamente cuando se crea el provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
    return const AudioState();
  }

  // UN SOLO AudioPlayer para toda la aplicación
  AudioPlayer? _audioPlayer;
  ProfessionalAudioService? _audioService;
  
  // Subscripciones a streams del AudioPlayer
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // Timer para actualizaciones fluidas
  Timer? _progressTimer;
  
  bool _isInitialized = false;

  /// Inicializar el servicio de audio unificado
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      AppLogger.info('[UnifiedAudioNotifier] 🔄 Inicializando...');
      
      // Usar el ProfessionalAudioService existente (singleton)
      _audioService = ProfessionalAudioService();
      
      // Si no está inicializado, inicializarlo
      if (!_audioService!.isInitialized) {
        await _audioService!.initialize(enableBackground: true);
      }
      
      // Obtener el AudioPlayer compartido
      _audioPlayer = _audioService!.controller?.player;
      
      if (_audioPlayer != null) {
        AppLogger.info('[UnifiedAudioNotifier] 🎵 AudioPlayer obtenido correctamente');
        _setupStreamListeners();
        _startProgressTimer();
        _isInitialized = true;
        
        AppLogger.info('[UnifiedAudioNotifier] ✅ Inicializado correctamente');
      } else {
        AppLogger.error('[UnifiedAudioNotifier] ❌ No se pudo obtener AudioPlayer');
      }
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error al inicializar: $e');
    }
  }

  /// Configurar listeners para los streams del AudioPlayer
  void _setupStreamListeners() {
    if (_audioPlayer == null) return;

    // Escuchar cambios de posición
    _positionSubscription = _audioPlayer!.positionStream.listen((position) {
      state = state.copyWith(currentPosition: position);
      AppLogger.info('[UnifiedAudioNotifier] ⏱️ Posición actualizada: ${position.inSeconds}s');
    });

    // Escuchar cambios de duración
    _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(totalDuration: duration);
        AppLogger.info('[UnifiedAudioNotifier] ⏱️ Duración actualizada: ${duration.inSeconds}s');
      }
    });

    // Escuchar cambios de estado del player
    _playerStateSubscription = _audioPlayer!.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final isBuffering = playerState.processingState == ProcessingState.buffering ||
                         playerState.processingState == ProcessingState.loading;
      
      state = state.copyWith(
        isPlaying: isPlaying,
        isBuffering: isBuffering,
      );
      
      AppLogger.info('[UnifiedAudioNotifier] 🎵 Estado: playing=$isPlaying, buffering=$isBuffering');
    });

    // Escuchar cambios de canción actual desde el controller
    if (_audioService?.controller != null) {
      _audioService!.controller!.currentSongStream.listen((song) {
        if (song != null) {
          state = state.copyWith(currentSong: song);
          AppLogger.info('[UnifiedAudioNotifier] 🎵 Nueva canción: ${song.title}');
        }
      });
    }
  }

  /// Timer para actualizaciones fluidas de progreso (60 FPS)
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Solo actualizar si está reproduciendo y hay un player
      if (state.isPlaying && _audioPlayer != null) {
        final currentPos = _audioPlayer!.position;
        final currentDur = _audioPlayer!.duration;
        
        // Actualizar posición y duración
        state = state.copyWith(
          currentPosition: currentPos,
          totalDuration: currentDur ?? state.totalDuration,
        );
        
        // Log cada 5 segundos para debug
        if (currentPos.inSeconds % 5 == 0 && currentPos.inMilliseconds % 1000 < 200) {
          AppLogger.info('[UnifiedAudioNotifier] ⏱️ Timer - Pos: ${currentPos.inSeconds}s, Dur: ${currentDur?.inSeconds ?? 0}s, Progress: ${(state.progress * 100).toStringAsFixed(1)}%');
        }
      }
    });
  }

  /// Reproducir una canción
  Future<void> playSong(Song song) async {
    try {
      AppLogger.info('[UnifiedAudioNotifier] 🎵 Reproduciendo: ${song.title}');
      
      // Asegurar inicialización
      if (!_isInitialized || _audioService == null) {
        AppLogger.info('[UnifiedAudioNotifier] 🔄 Inicializando servicio...');
        await _initialize();
      }
      
      if (_audioService == null) {
        throw Exception('No se pudo inicializar el servicio de audio');
      }
      
      // Actualizar estado inmediatamente
      state = state.copyWith(
        currentSong: song,
        isPlaying: false, // Será true cuando realmente empiece
        currentPosition: Duration.zero,
        totalDuration: Duration(seconds: song.duration ?? 0),
      );
      
      // Usar el servicio profesional para cargar y reproducir
      await _audioService!.loadSong(song);
      await _audioService!.play();
      
      // Forzar re-conexión con el AudioPlayer después de cargar
      await _reconnectToAudioPlayer();
      
      AppLogger.info('[UnifiedAudioNotifier] ✅ Canción cargada y reproduciendo');
      
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error reproduciendo: $e');
      state = state.copyWith(isPlaying: false);
    }
  }
  
  /// Reconectar con el AudioPlayer después de cargar una canción
  Future<void> _reconnectToAudioPlayer() async {
    try {
      // Cancelar listeners existentes
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _playerStateSubscription?.cancel();
      
      // Obtener el AudioPlayer actualizado
      _audioPlayer = _audioService?.controller?.player;
      
      if (_audioPlayer != null) {
        AppLogger.info('[UnifiedAudioNotifier] 🔄 Reconectando con AudioPlayer...');
        
        // Re-configurar listeners
        _setupStreamListeners();
        
        // Obtener estado actual inmediatamente
        final currentPos = _audioPlayer!.position;
        final currentDur = _audioPlayer!.duration;
        final playerState = _audioPlayer!.playerState;
        
        state = state.copyWith(
          currentPosition: currentPos,
          totalDuration: currentDur ?? state.totalDuration,
          isPlaying: playerState.playing,
          isBuffering: playerState.processingState == ProcessingState.loading ||
                      playerState.processingState == ProcessingState.buffering,
        );
        
        AppLogger.info('[UnifiedAudioNotifier] ✅ Reconectado - Pos: ${currentPos.inSeconds}s, Dur: ${currentDur?.inSeconds ?? 0}s');
      }
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error reconectando: $e');
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (!_isInitialized || _audioService == null) return;

    try {
      if (state.isPlaying) {
        await _audioService!.pause();
      } else {
        await _audioService!.play();
      }
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error en toggle: $e');
    }
  }

  /// Buscar a una posición específica
  Future<void> seekTo(Duration position) async {
    if (!_isInitialized || _audioService == null) return;

    try {
      await _audioService!.seek(position);
      state = state.copyWith(currentPosition: position);
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error en seek: $e');
    }
  }

  /// Cambiar volumen
  Future<void> setVolume(double volume) async {
    if (!_isInitialized || _audioPlayer == null) return;

    try {
      await _audioPlayer!.setVolume(volume.clamp(0.0, 1.0));
      state = state.copyWith(volume: volume);
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error cambiando volumen: $e');
    }
  }

  /// Expandir/colapsar reproductor
  void setPlayerExpanded(bool expanded) {
    state = state.copyWith(isPlayerExpanded: expanded);
    AppLogger.info('[UnifiedAudioNotifier] 🎬 Player expanded: $expanded');
  }

  /// Detener reproducción
  Future<void> stop() async {
    if (!_isInitialized || _audioService == null) return;

    try {
      await _audioService!.stop();
      state = state.copyWith(
        currentSong: null,
        isPlaying: false,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
      );
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error deteniendo: $e');
    }
  }

  void cleanup() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _progressTimer?.cancel();
  }
}

/// Provider principal del audio unificado
final unifiedAudioProvider = NotifierProvider<UnifiedAudioNotifier, AudioState>(() {
  return UnifiedAudioNotifier();
});

/// Providers de conveniencia para acceso rápido
final currentSongProvider = Provider<Song?>((ref) {
  return ref.watch(unifiedAudioProvider).currentSong;
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(unifiedAudioProvider).isPlaying;
});

final audioProgressProvider = Provider<double>((ref) {
  return ref.watch(unifiedAudioProvider).progress;
});

final currentPositionProvider = Provider<Duration>((ref) {
  return ref.watch(unifiedAudioProvider).currentPosition;
});

final totalDurationProvider = Provider<Duration>((ref) {
  return ref.watch(unifiedAudioProvider).totalDuration;
});
