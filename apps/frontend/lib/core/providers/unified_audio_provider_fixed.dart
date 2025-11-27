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

/// Notifier unificado que maneja TODO el estado del audio
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
  
  // ✅ Timer para actualizaciones de progreso en tiempo real
  Timer? _progressTimer;
  
  // ✅ Flag de inicialización
  bool _isInitialized = false;
  
  // 🛡️ PROTECCIÓN CONTRA MÚLTIPLES LLAMADAS Y LOOPS
  bool _isSearchingNextSong = false;
  String? _lastRecommendedSongId;
  DateTime? _lastRecommendationTime;

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
    _positionSubscription = _player!.positionStream.listen((position) {
      // Sin logs para máximo rendimiento
      _updatePosition(position); // Siempre actualizar posición
    });

    // 🎯 LISTENER DE DURACIÓN - CRÍTICO PARA BARRA DE PROGRESO
    _durationSubscription = _player!.durationStream.listen((duration) {
      if (duration != null) {
        _updateDuration(duration); // Siempre actualizar duración
      }
    });

    // 🎯 LISTENER DE ESTADO DEL PLAYER - CRÍTICO PARA PLAY/PAUSE
    _playerStateSubscription = _player!.playerStateStream.listen((playerState) {
      _updatePlayerState(playerState); // Siempre actualizar estado del player
    });

    // 🎯 Timer para actualizaciones fluidas de progreso (60 FPS)
    _startProgressTimer();

    AppLogger.info('[UnifiedAudioNotifier] ✅ Listeners configurados correctamente');
  }

  /// ✅ Iniciar timer para actualizaciones fluidas de progreso a 60 FPS
  void _startProgressTimer() {
    _progressTimer?.cancel();
    // 60 FPS = 16.67ms por frame, usar 16ms para mejor rendimiento
    _progressTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_player != null && _player!.playerState.playing) {
        final position = _player!.position;
        if (position != state.currentPosition) {
          _updatePosition(position);
        }
      }
    });
    // Timer de progreso iniciado sin log para mejor rendimiento
  }

  /// ✅ Actualizar posición - LLAMAR notifyListeners()
  void _updatePosition(Duration position) {
    if (state.currentPosition != position) {
      state = state.copyWith(currentPosition: position);
      // Sin logs para máximo rendimiento a 60 FPS
    }
  }

  /// ✅ Actualizar duración - LLAMAR notifyListeners()
  void _updateDuration(Duration duration) {
    if (state.totalDuration != duration) {
      state = state.copyWith(totalDuration: duration);
      // Duración actualizada sin log para mejor rendimiento
    }
  }

  /// ✅ Actualizar estado del player - LLAMAR notifyListeners()
  void _updatePlayerState(PlayerState playerState) {
    final newIsPlaying = playerState.playing;
    final newIsBuffering = playerState.processingState == ProcessingState.loading ||
                          playerState.processingState == ProcessingState.buffering;

    if (state.isPlaying != newIsPlaying || state.isBuffering != newIsBuffering) {
      state = state.copyWith(
        isPlaying: newIsPlaying,
        isBuffering: newIsBuffering,
      );
      
      // Estado actualizado sin log para mejor rendimiento
    }

    // 🎯 DETECCIÓN OPTIMIZADA DE FINALIZACIÓN
    // CORRECCIÓN: No requerir !playing porque puede seguir en true al completarse
    if (playerState.processingState == ProcessingState.completed && 
        !_isSearchingNextSong) {
      AppLogger.info('[UnifiedAudioNotifier] 🏁 Canción completada');
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
  Future<void> _findAndPlayNextSong(Song currentSong) async {
    try {

      // 🧠 LLAMADA A TU ALGORITMO DE RECOMENDACIONES
      Song? nextSong;
      
      try {
        final recommendationService = SpotifyRecommendationService(HttpClientService());
        
        nextSong = await recommendationService.getSmartRecommendation(
          currentSongId: currentSong.id,
          genres: currentSong.genres,
          user: null, // TODO: Pasar usuario cuando esté disponible
        );
        
        if (nextSong != null) {
          // 🛡️ PROTECCIÓN: Evitar loop infinito con la misma canción
          if (nextSong.id == currentSong.id) {
            nextSong = null;
          } else if (nextSong.id == _lastRecommendedSongId) {
            nextSong = null;
          }
        }
      } catch (e) {
        nextSong = null;
      }

      // ▶️ REPRODUCIR SIGUIENTE CANCIÓN SI ES VÁLIDA
      if (nextSong != null) {
        // 🎯 GUARDAR ID PARA EVITAR REPETICIONES
        _lastRecommendedSongId = nextSong.id;
        
        // 🎵 REPRODUCIR AUTOMÁTICAMENTE
        await playSong(nextSong);
        
      } else {
        // ⏸️ MANTENER PAUSADO SI NO HAY SIGUIENTE (solo si realmente no hay canción)
        state = state.copyWith(
          isPlaying: false,
        );
      }

    } catch (e) {
      // ⏸️ MANTENER PAUSADO EN CASO DE ERROR
      state = state.copyWith(
        isPlaying: false,
      );
    } finally {
      // 🛡️ SIEMPRE RESETEAR ESTADO DE BÚSQUEDA
      _resetSearchState();
    }
  }

  /// 🛡️ Resetear estado de búsqueda de siguiente canción
  void _resetSearchState() {
    _isSearchingNextSong = false;
    // Estado de búsqueda reseteado sin log para mejor rendimiento
  }

  /// ✅ Forzar inicialización del player (método público)
  void ensureInitialized() {
    if (!_isInitialized) {
      _initializePlayer();
    }
  }

  /// ✅ Reproducir una canción
  Future<void> playSong(Song song) async {
    if (_player == null) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ AudioPlayer no inicializado');
      return;
    }

    try {
      
      // ✅ TRANSICIÓN OPTIMIZADA: Cambiar canción sin interrumpir flujo visual
      state = state.copyWith(
        currentSong: song,
        // NO mostrar isLoading para evitar fondo gris durante transición
        // Mantener isPlaying true durante la carga para transición fluida
        isPlaying: true,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero, // ✅ CRÍTICO: Resetear duración para forzar progreso a 0
      );
      // Sin logs para mejor rendimiento

      AppLogger.info('[UnifiedAudioNotifier] 🎵 Cargando: ${song.title}');

      // Verificar que la URL no sea null
      if (song.fileUrl == null || song.fileUrl!.isEmpty) {
        throw Exception('URL de canción inválida: ${song.fileUrl}');
      }
      
      // Normalizar URL
      final normalizedUrl = UrlNormalizer.normalizeUrl(song.fileUrl!);
      // Sin logs para mejor rendimiento

      // Cargar canción
      // Sin logs para mejor rendimiento
      await _player!.setUrl(normalizedUrl);
      // Sin logs para mejor rendimiento
      
      // Obtener duración inmediatamente después de cargar
      final duration = _player!.duration ?? Duration.zero;
      // Sin logs para mejor rendimiento
      
      // ✅ REPRODUCIR INMEDIATAMENTE para transición fluida
      await _player!.play();
      
      // ✅ ACTUALIZAR ESTADO DESPUÉS DE INICIAR REPRODUCCIÓN
      state = state.copyWith(
        isPlaying: true, // Confirmar que está reproduciendo
        totalDuration: duration,
        // isLoading ya no se usa para evitar fondo gris
      );
      
      // 🎵 RESTAURAR VOLUMEN COMPLETO INMEDIATAMENTE
      await _player!.setVolume(1.0);
      
      // Sin logs para mejor rendimiento
      // Sin logs para mejor rendimiento
      
      // Sin logs para mejor rendimiento
      
    } catch (e) {
      // Sin logs para mejor rendimiento
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error reproduciendo: $e');
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
      );
    }
  }

  /// ✅ Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player == null || state.currentSong == null) return;

    try {
      if (state.isPlaying) {
        await _player!.pause();
      } else {
        await _player!.play();
      }
      AppLogger.info('[UnifiedAudioNotifier] ⏯️ Toggle: ${state.isPlaying ? 'pause' : 'play'}');
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error toggle: $e');
    }
  }

  /// ✅ Pausar
  Future<void> pause() async {
    if (_player == null) return;
    
    try {
      await _player!.pause();
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error pause: $e');
    }
  }

  /// ✅ Reanudar
  Future<void> play() async {
    if (_player == null) return;
    
    try {
      await _player!.play();
    } catch (e) {
      AppLogger.error('[UnifiedAudioNotifier] ❌ Error play: $e');
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
    // TODO: Implementar cuando se agregue soporte para playlists
  }

  /// ✅ Canción anterior (placeholder para futura implementación)
  Future<void> previous() async {
    AppLogger.info('[UnifiedAudioNotifier] ⏮️ Previous - Por implementar con playlist');
    // TODO: Implementar cuando se agregue soporte para playlists
  }

  /// ✅ Limpiar recursos
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
    _isInitialized = false;
    
    AppLogger.info('[UnifiedAudioNotifier] 🧹 Recursos limpiados');
  }
}

/// ✅ Provider unificado del reproductor de audio
/// ESTA ES LA ÚNICA FUENTE DE VERDAD para todo el estado del audio
final unifiedAudioProviderFixed = NotifierProvider<UnifiedAudioNotifier, UnifiedAudioState>(() {
  return UnifiedAudioNotifier();
});

/// ✅ Providers de conveniencia para acceso rápido a partes específicas del estado
final currentSongProviderFixed = Provider<Song?>((ref) {
  return ref.watch(unifiedAudioProviderFixed).currentSong;
});

final isPlayingProviderFixed = Provider<bool>((ref) {
  return ref.watch(unifiedAudioProviderFixed).isPlaying;
});

final audioProgressProviderFixed = Provider<double>((ref) {
  return ref.watch(unifiedAudioProviderFixed).progress;
});

final audioPositionProviderFixed = Provider<Duration>((ref) {
  return ref.watch(unifiedAudioProviderFixed).currentPosition;
});

final audioDurationProviderFixed = Provider<Duration>((ref) {
  return ref.watch(unifiedAudioProviderFixed).totalDuration;
});

final isBufferingProviderFixed = Provider<bool>((ref) {
  return ref.watch(unifiedAudioProviderFixed).isBuffering;
});

final audioVolumeProviderFixed = Provider<double>((ref) {
  return ref.watch(unifiedAudioProviderFixed).volume;
});
