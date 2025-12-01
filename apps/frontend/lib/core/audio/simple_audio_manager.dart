import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../services/professional_audio_service.dart';
import '../providers/unified_audio_provider.dart';
import '../utils/logger.dart';
import 'audio_manager.dart';

/// AudioManager SÚPER SIMPLE - Solo para recomendaciones por género
class SimpleAudioManager extends ChangeNotifier {
  static final SimpleAudioManager _instance = SimpleAudioManager._internal();
  factory SimpleAudioManager() => _instance;
  SimpleAudioManager._internal();
  
  // Referencia al ProviderContainer para actualizar el StateProvider
  ProviderContainer? _container;

  // Servicios
  ProfessionalAudioService? _audioService;
  
  // Estado actual
  bool _isInitialized = false;
  
  // Variables para compatibilidad con código existente
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Song? _currentSong;
  bool _isPlaying = false;

  // Streams para UI
  final _currentSongController = StreamController<Song?>.broadcast();
  final _isPlayingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  // Callback para siguiente canción
  Future<Song?> Function(Song currentSong)? _onGetNextSong;


  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isInitialized => _isInitialized;
  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<bool> get isPlayingStream => _isPlayingController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  /// Inicializar el audio manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _audioService = ProfessionalAudioService();
      await _audioService!.initialize();
      
      // Escuchar cuando termine una canción para reproducir la siguiente automáticamente
      _setupAutoPlayNext();
      
      _isInitialized = true;
      AppLogger.info('[SimpleAudioManager] ✅ Inicializado correctamente');
    } catch (e) {
      AppLogger.error('[SimpleAudioManager] ❌ Error al inicializar: $e');
    }
  }

  /// Configurar callback para siguiente canción
  void setOnGetNextSongCallback(Future<Song?> Function(Song currentSong)? callback) {
    _onGetNextSong = callback;
    AppLogger.info('[SimpleAudioManager] Callback configurado: ${callback != null}');
  }

  /// Configurar el container para actualizar el StateProvider
  void setContainer(ProviderContainer container) {
    _container = container;
  }

  /// Reproducir una canción
  Future<void> playSong(Song song) async {
    if (!_isInitialized || _audioService == null) {
      AppLogger.error('[SimpleAudioManager] No inicializado');
      return;
    }

    try {
      AppLogger.info('[SimpleAudioManager] 🎵 Reproduciendo: ${song.title}');
      
      // Actualizar variables locales
      _currentSong = song;
      _isPlaying = true;
      _position = Duration.zero;
      _duration = Duration(seconds: song.duration ?? 0);
      
      // 🔥 NOTIFICAR CAMBIOS INMEDIATAMENTE
      notifyListeners();
      
      // 🔥 USAR EL PROVIDER UNIFICADO DIRECTAMENTE
      if (_container != null) {
        await _container!.read(unifiedAudioProvider.notifier).playSong(song);
        AppLogger.info('[SimpleAudioManager] 🔔 Provider unificado - reproduciendo canción');
        return; // El provider unificado maneja todo
      }
      
      AppLogger.info('[SimpleAudioManager] 🔔 notifyListeners() ejecutado - Mini-player debe aparecer AHORA');
      
      // Notificar cambios a streams (para compatibilidad)
      _currentSongController.add(song);
      _isPlayingController.add(true);
      _positionController.add(_position);
      _durationController.add(_duration);
      
      // Reproducir
      await _audioService!.loadSong(song);
      await _audioService!.play();
      
      // Configurar listeners para posición
      _setupPositionListeners();
      
      AppLogger.info('[SimpleAudioManager] ✅ Reproducción iniciada');
    } catch (e) {
      AppLogger.error('[SimpleAudioManager] ❌ Error reproduciendo: $e');
    }
  }

  /// Reproducir canción destacada (alias para playSong)
  Future<void> playFeaturedSong(Song song) async {
    AppLogger.info('[SimpleAudioManager] 🌟 Reproduciendo canción destacada: ${song.title}');
    await playSong(song);
  }

  /// Abrir reproductor completo (método de compatibilidad)
  void openFullPlayer() {
    AppLogger.info('[SimpleAudioManager] 🎬 Abriendo reproductor completo');
    // Este método es llamado por otros componentes pero la lógica de abrir
    // el reproductor completo está en MainNavigation
  }

  /// Obtener siguiente canción usando el callback configurado
  Future<Song?> getNextSong(Song currentSong) async {
    if (_onGetNextSong != null) {
      return await _onGetNextSong!(currentSong);
    }
    return null;
  }

  /// Pausar/reanudar
  Future<void> togglePlayPause() async {
    if (!_isInitialized || _audioService == null) return;

    try {
      if (_isPlaying) {
        await _audioService!.pause();
        _isPlaying = false;
      } else {
        await _audioService!.play();
        _isPlaying = true;
      }
      
      // 🔥 NOTIFICAR CAMBIOS INMEDIATAMENTE
      notifyListeners();
      _isPlayingController.add(_isPlaying);
      
      // 🔥 ACTUALIZAR NOTIFIER UNIFICADO PARA RIVERPOD
      if (_container != null) {
        _container!.read(unifiedPlayerProvider.notifier).updateState(
          currentSong: _currentSong,
          isPlaying: _isPlaying,
        );
        AppLogger.info('[SimpleAudioManager] 🔔 UnifiedPlayerNotifier actualizado en toggle');
      }
      
      AppLogger.info('[SimpleAudioManager] ${_isPlaying ? "▶️" : "⏸️"} Toggle play/pause');
    } catch (e) {
      AppLogger.error('[SimpleAudioManager] ❌ Error toggle: $e');
    }
  }

  /// Detener completamente la reproducción y limpiar estado
  Future<void> stop() async {
    if (!_isInitialized || _audioService == null) return;

    try {
      await _audioService!.stop();
      
      // Limpiar variables locales
      _currentSong = null;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      
      // 🔥 NOTIFICAR CAMBIOS INMEDIATAMENTE
      notifyListeners();
      
      // 🔥 ACTUALIZAR NOTIFIER UNIFICADO PARA RIVERPOD
      if (_container != null) {
        _container!.read(unifiedPlayerProvider.notifier).updateState(
          currentSong: null,
          isPlaying: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
        );
        AppLogger.info('[SimpleAudioManager] 🔔 UnifiedPlayerNotifier limpiado en stop');
      }
      
      // Notificar cambios a streams (para compatibilidad)
      _currentSongController.add(null);
      _isPlayingController.add(false);
      _positionController.add(Duration.zero);
      _durationController.add(Duration.zero);
      
      AppLogger.info('[SimpleAudioManager] ⏹️ Reproducción detenida y estado limpiado');
    } catch (e) {
      AppLogger.error('[SimpleAudioManager] ❌ Error deteniendo: $e');
    }
  }

  /// Configurar reproducción automática de la siguiente canción
  void _setupAutoPlayNext() {
    try {
      final controller = _audioService?.controller;
      if (controller == null) {
        AppLogger.warning('[SimpleAudioManager] Controller no disponible para auto-play');
        return;
      }

      // Escuchar cambios en el estado del reproductor
      controller.stateStream.listen((state) async {
        // Detectar cuando una canción termina (processingState == completed y no está reproduciendo)
        if (state.processingState == ProcessingState.completed && !state.playing) {
          AppLogger.info('[SimpleAudioManager] 🎵 Canción terminada, buscando siguiente...');
          
          final currentSong = _currentSong;
          if (currentSong != null && _onGetNextSong != null) {
            try {
              final nextSong = await _onGetNextSong!(currentSong);
              if (nextSong != null) {
                AppLogger.info('[SimpleAudioManager] ▶️ Reproduciendo siguiente: ${nextSong.title}');
                await playSong(nextSong);
              } else {
                AppLogger.info('[SimpleAudioManager] ❌ No hay siguiente canción disponible');
              }
            } catch (e) {
              AppLogger.error('[SimpleAudioManager] ❌ Error obteniendo siguiente canción: $e');
            }
          } else {
            AppLogger.warning('[SimpleAudioManager] ❌ No hay canción actual o callback no configurado');
          }
        }
      });
      
      AppLogger.info('[SimpleAudioManager] ✅ Auto-play configurado correctamente');
    } catch (e) {
      AppLogger.error('[SimpleAudioManager] ❌ Error configurando auto-play: $e');
    }
  }

  /// Configurar listeners para posición y duración con actualización fluida
  void _setupPositionListeners() {
    if (_audioService == null) return;

    // 🚀 ACTUALIZACIÓN ULTRA FLUIDA - 60 FPS para progreso suave como mantequilla
    Timer.periodic(const Duration(milliseconds: 16), (timer) { // ~60 FPS
      if (!_isPlaying || _audioService == null) {
        timer.cancel();
        return;
      }
      
      // Incrementar posición con precisión de milisegundos
      _position = Duration(milliseconds: _position.inMilliseconds + 16);
      
      // Verificar si llegó al final
      if (_position >= _duration) {
        _position = _duration;
        _isPlaying = false;
        _isPlayingController.add(false);
        
        // 🔥 ACTUALIZAR NOTIFIER UNIFICADO
        if (_container != null) {
          _container!.read(unifiedPlayerProvider.notifier).updateState(
            currentSong: _currentSong,
            isPlaying: false,
            currentPosition: _position,
          );
        }
        
        timer.cancel();
        return;
      }
      
      // Actualizar streams y notifier unificado
      _positionController.add(_position);
      
      // 🚀 SINCRONIZACIÓN FLUIDA CON EL ESTADO UNIFICADO
      if (_container != null) {
        _container!.read(unifiedPlayerProvider.notifier).updateState(
          currentPosition: _position,
          totalDuration: _duration, // Asegurar que la duración también se actualice
        );
      }
    });
  }

  @override
  void dispose() {
    _currentSongController.close();
    _isPlayingController.close();
    _positionController.close();
    _durationController.close();
    _audioService?.dispose();
    _isInitialized = false;
    AppLogger.info('[SimpleAudioManager] 🧹 Recursos limpiados');
    
    // Llamar al dispose del padre
    super.dispose();
  }
}

/// Provider para el SimpleAudioManager
final simpleAudioManagerProvider = Provider<SimpleAudioManager>((ref) {
  return SimpleAudioManager();
});

/// Estado unificado completo del reproductor
class UnifiedPlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final bool isBuffering;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlayerExpanded;

  const UnifiedPlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.isBuffering = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isPlayerExpanded = false,
  });

  UnifiedPlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isPlayerExpanded,
  }) {
    return UnifiedPlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isPlayerExpanded: isPlayerExpanded ?? this.isPlayerExpanded,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedPlayerState &&
        other.currentSong?.id == currentSong?.id &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.currentPosition == currentPosition &&
        other.totalDuration == totalDuration &&
        other.isPlayerExpanded == isPlayerExpanded;
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
    );
  }
}

/// Notifier UNIFICADO para el estado completo del reproductor - escucha TODOS los sistemas
class UnifiedPlayerNotifier extends Notifier<UnifiedPlayerState> {
  StreamSubscription<Song?>? _audioManagerSongSubscription;
  StreamSubscription<bool>? _audioManagerPlayingSubscription;
  StreamSubscription<Duration>? _audioManagerPositionSubscription;
  StreamSubscription<Duration>? _audioManagerDurationSubscription;
  
  // Subscripciones para el sistema profesional
  StreamSubscription<Song?>? _professionalSongSubscription;
  StreamSubscription<PlayerState>? _professionalStateSubscription;
  StreamSubscription<Duration>? _professionalPositionSubscription;
  StreamSubscription<Duration?>? _professionalDurationSubscription;
  
  // Timer para forzar actualizaciones de progreso
  Timer? _progressUpdateTimer;
  
  @override
  UnifiedPlayerState build() {
    // Configurar listeners para TODOS los sistemas de audio
    _setupAudioManagerListeners();
    // _setupProfessionalListeners(); // Ya no es necesario
    _startProgressTimer();
    
    // Limpiar recursos cuando se dispose el provider
    ref.onDispose(() {
      cleanup();
    });
    
    return const UnifiedPlayerState();
  }
  
  /// Timer para forzar actualizaciones de progreso cada frame
  void _startProgressTimer() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Solo actualizar si hay una canción reproduciéndose
      if (state.currentSong != null && state.isPlaying) {
        // Intentar obtener la posición actual del AudioManager
        try {
          final audioManager = AudioManager();
          if (audioManager.currentSong != null) {
            final currentPos = audioManager.position;
            final totalDur = audioManager.duration;
            
            // Solo actualizar si los valores han cambiado significativamente
            if ((currentPos.inMilliseconds - state.currentPosition.inMilliseconds).abs() > 50) {
              debugPrint('[UnifiedPlayerNotifier] 🔄 Timer update - Pos: ${currentPos.inSeconds}s, Dur: ${totalDur.inSeconds}s');
              state = state.copyWith(
                currentPosition: currentPos,
                totalDuration: totalDur,
              );
            }
          }
        } catch (e) {
          // Ignorar errores del timer
        }
      }
    });
  }
  
  /// Configurar listeners para el AudioManager principal
  void _setupAudioManagerListeners() {
    try {
      final audioManager = AudioManager();
      
      // Escuchar cambios en la canción actual
      _audioManagerSongSubscription = audioManager.currentSongStream.listen((song) {
        debugPrint('[UnifiedPlayerNotifier] 🎵 AudioManager - Nueva canción: ${song?.title}');
        state = state.copyWith(currentSong: song);
      });
      
      // Escuchar cambios en el estado de reproducción
      _audioManagerPlayingSubscription = audioManager.isPlayingStream.listen((isPlaying) {
        debugPrint('[UnifiedPlayerNotifier] 🎵 AudioManager - Estado reproducción: $isPlaying');
        state = state.copyWith(isPlaying: isPlaying);
      });
      
      // Escuchar cambios en la posición
      _audioManagerPositionSubscription = audioManager.positionStream.listen((position) {
        state = state.copyWith(currentPosition: position);
      });
      
      // Escuchar cambios en la duración
      _audioManagerDurationSubscription = audioManager.durationStream.listen((duration) {
        state = state.copyWith(totalDuration: duration);
      });
      
      debugPrint('[UnifiedPlayerNotifier] ✅ Listeners del AudioManager configurados');
    } catch (e) {
      debugPrint('[UnifiedPlayerNotifier] ❌ Error configurando AudioManager listeners: $e');
    }
  }
  
  // Los listeners profesionales ya no son necesarios - el provider unificado maneja todo
  
  /// Método manual para actualizar estado (usado por SimpleAudioManager)
  void updateState({
    Song? currentSong,
    bool? isPlaying,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? totalDuration,
  }) {
    state = state.copyWith(
      currentSong: currentSong,
      isPlaying: isPlaying,
      isBuffering: isBuffering,
      currentPosition: currentPosition,
      totalDuration: totalDuration,
    );
    debugPrint('[UnifiedPlayerNotifier] 🔔 Estado actualizado manualmente');
  }
  
  /// Expandir/colapsar el reproductor
  void setPlayerExpanded(bool expanded) {
    state = state.copyWith(isPlayerExpanded: expanded);
    debugPrint('[UnifiedPlayerNotifier] 🎬 Player expanded: $expanded');
  }
  
  void cleanup() {
    _audioManagerSongSubscription?.cancel();
    _audioManagerPlayingSubscription?.cancel();
    _audioManagerPositionSubscription?.cancel();
    _audioManagerDurationSubscription?.cancel();
    _professionalSongSubscription?.cancel();
    _professionalStateSubscription?.cancel();
    _professionalPositionSubscription?.cancel();
    _professionalDurationSubscription?.cancel();
    _progressUpdateTimer?.cancel();
  }
}

/// Provider para el estado UNIFICADO del reproductor (reemplaza audioStateProvider)
final unifiedPlayerProvider = NotifierProvider<UnifiedPlayerNotifier, UnifiedPlayerState>(() {
  return UnifiedPlayerNotifier();
});

/// Provider de compatibilidad para el formato anterior (para transición gradual)
final audioStateProvider = Provider<({Song? currentSong, bool isPlaying})>((ref) {
  // Optimización: usar select para escuchar solo los campos necesarios
  final currentSong = ref.watch(
    unifiedPlayerProvider.select((state) => state.currentSong),
  );
  final isPlaying = ref.watch(
    unifiedPlayerProvider.select((state) => state.isPlaying),
  );
  return (currentSong: currentSong, isPlaying: isPlaying);
});
