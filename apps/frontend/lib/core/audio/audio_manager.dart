import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../services/professional_audio_service.dart';
import '../utils/logger.dart';

/// AudioManager - Controlador global de audio estilo Spotify
/// Singleton que maneja toda la reproducción de audio de la app
/// 
/// CARACTERÍSTICAS:
/// - Solo existe UNA instancia (singleton)
/// - playSong(): Reproduce una canción desde cualquier parte
/// - togglePlayPause(): Solo pausa/reproduce sin cambiar canción
/// - stop(): Detiene la reproducción
/// - Listeners para UI (currentSong, isPlaying, position, duration)
/// - Fade-in al iniciar reproducción (280ms)
/// - Manejo de eventos de cambio de canción
/// - NO duplica streams, listeners o players
class AudioManager {
  // Singleton - Solo una instancia global
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  // Servicio de audio profesional (singleton)
  ProfessionalAudioService? _audioService;
  
  // Streams para UI - Broadcast para múltiples listeners
  final _currentSongController = StreamController<Song?>.broadcast();
  final _isPlayingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  
  // Suscripciones - SOLO UNA POR TIPO
  StreamSubscription<Song?>? _currentSongSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  
  // Estado interno
  bool _isInitialized = false;
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  // Fade-in
  Timer? _fadeTimer;
  static const Duration _fadeDuration = Duration(milliseconds: 280);
  static const int _fadeSteps = 20;
  static const double _targetVolume = 0.85;
  
  // Callback para abrir el full player
  VoidCallback? _onOpenFullPlayer;
  
  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  
  // Streams públicos para UI
  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<bool> get isPlayingStream => _isPlayingController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  
  /// Inicializar el AudioManager
  /// Debe llamarse UNA VEZ al inicio de la app
  Future<void> initialize({bool enableBackground = true}) async {
    if (_isInitialized) {
      AppLogger.info('[AudioManager] Ya está inicializado');
      return;
    }
    
    try {
      // Obtener el servicio de audio (singleton)
      _audioService = ProfessionalAudioService();
      
      // Inicializar el servicio
      await _audioService!.initialize(enableBackground: enableBackground);
      
      // Configurar listeners UNA SOLA VEZ
      _setupListeners();
      
      _isInitialized = true;
      AppLogger.info('[AudioManager] Inicializado correctamente');
    } catch (e, stackTrace) {
      AppLogger.error('[AudioManager] Error al inicializar: $e', stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Configurar listeners para sincronizar estado
  /// Solo se llama UNA VEZ al inicializar
  void _setupListeners() {
    // Cancelar listeners anteriores si existen (protección)
    _disposeListeners();
    
    final controller = _audioService?.controller;
    if (controller == null) {
      AppLogger.warning('[AudioManager] Controller es null, no se pueden configurar listeners');
      return;
    }
    
    // Escuchar cambios en la canción actual - SOLO UNA SUSCRIPCIÓN
    _currentSongSubscription = controller.currentSongStream.listen(
      (song) {
        _currentSong = song;
        if (!_currentSongController.isClosed) {
          _currentSongController.add(song);
        }
        AppLogger.info('[AudioManager] Canción actualizada: ${song?.title ?? "ninguna"}');
      },
      onError: (error) {
        AppLogger.error('[AudioManager] Error en currentSongStream: $error');
      },
    );
    
    // Escuchar cambios en el estado del reproductor - SOLO UNA SUSCRIPCIÓN
    _stateSubscription = controller.stateStream.listen(
      (state) {
        final wasPlaying = _isPlaying;
        _isPlaying = state.playing;
        
        // Solo emitir si cambió el estado
        if (wasPlaying != _isPlaying && !_isPlayingController.isClosed) {
          _isPlayingController.add(_isPlaying);
          AppLogger.info('[AudioManager] Estado: ${_isPlaying ? "reproduciendo" : "pausado"}');
        }
      },
      onError: (error) {
        AppLogger.error('[AudioManager] Error en stateStream: $error');
      },
    );
    
    // Escuchar cambios en la posición - SOLO UNA SUSCRIPCIÓN
    _positionSubscription = controller.positionStream.listen(
      (position) {
        _position = position;
        if (!_positionController.isClosed) {
          _positionController.add(position);
        }
      },
      onError: (error) {
        AppLogger.error('[AudioManager] Error en positionStream: $error');
      },
    );
    
    // Escuchar cambios en la duración - SOLO UNA SUSCRIPCIÓN
    _durationSubscription = controller.durationStream.listen(
      (duration) {
        if (duration != null) {
          _duration = duration;
          if (!_durationController.isClosed) {
            _durationController.add(duration);
          }
        }
      },
      onError: (error) {
        AppLogger.error('[AudioManager] Error en durationStream: $error');
      },
    );
    
    // Emitir estado inicial
    _currentSong = controller.currentSong;
    _isPlaying = controller.isPlaying;
    _position = controller.position;
    _duration = controller.duration ?? Duration.zero;
    
    if (!_currentSongController.isClosed) {
      _currentSongController.add(_currentSong);
    }
    if (!_isPlayingController.isClosed) {
      _isPlayingController.add(_isPlaying);
    }
    if (!_positionController.isClosed) {
      _positionController.add(_position);
    }
    if (!_durationController.isClosed && _duration.inSeconds > 0) {
      _durationController.add(_duration);
    }
    
    AppLogger.info('[AudioManager] Listeners configurados correctamente');
  }
  
  /// Configurar callback para abrir el full player
  void setOnOpenFullPlayerCallback(VoidCallback? callback) {
    _onOpenFullPlayer = callback;
    AppLogger.info('[AudioManager] Callback de openFullPlayer configurado');
  }
  
  /// Abrir el reproductor completo
  /// Usa el callback configurado previamente
  void openFullPlayer() {
    if (_onOpenFullPlayer != null) {
      AppLogger.info('[AudioManager] Abriendo full player');
      _onOpenFullPlayer!();
    } else {
      AppLogger.warning('[AudioManager] No hay callback configurado para abrir full player');
    }
  }
  
  /// Reproducir una canción desde cualquier parte de la app
  /// 
  /// COMPORTAMIENTO:
  /// - Si NO hay canción reproduciéndose → reproducir inmediatamente
  /// - Si HAY canción reproduciéndose (misma o diferente) → expandir full player inmediatamente
  /// - Actualiza el mini reproductor automáticamente
  Future<void> playSong(Song song, {Map<String, dynamic>? metadata}) async {
    if (!_isInitialized || _audioService == null) {
      throw Exception('AudioManager no está inicializado. Llame a initialize() primero');
    }
    
    try {
      AppLogger.info('[AudioManager] playSong llamado para: ${song.title}');
      
      // Si NO hay canción reproduciéndose → reproducir normalmente
      if (_currentSong == null || !_isPlaying) {
        AppLogger.info('[AudioManager] No hay canción reproduciéndose, reproduciendo normalmente');
        await _loadAndPlaySong(song);
        return;
      }
      
      // Si HAY canción reproduciéndose (misma o diferente) → expandir full player inmediatamente
      if (_currentSong != null && _isPlaying) {
        // Si es la misma canción, solo abrir el full player
        if (_currentSong!.id == song.id) {
          AppLogger.info('[AudioManager] Misma canción reproduciéndose, abriendo full player');
          openFullPlayer();
          return;
        }
        
        // Si es diferente canción, cambiar la canción y abrir full player
        AppLogger.info('[AudioManager] Diferente canción reproduciéndose, cambiando y abriendo full player');
        await _loadAndPlaySong(song);
        // Pequeño delay para asegurar que se cargó correctamente
        await Future.delayed(const Duration(milliseconds: 200));
        openFullPlayer();
        return;
      }
      
      // Si no se cumple ninguna condición anterior, reproducir normalmente
      await _loadAndPlaySong(song);
    } catch (e, stackTrace) {
      AppLogger.error('[AudioManager] Error al reproducir canción: $e', stackTrace);
      rethrow;
    }
  }
  
  /// Método privado para cargar y reproducir una canción
  Future<void> _loadAndPlaySong(Song song) async {
    try {
      // Si es la misma canción y ya está reproduciéndose, no hacer nada
      if (_currentSong?.id == song.id && _isPlaying) {
        AppLogger.info('[AudioManager] La canción ya está reproduciéndose');
        return;
      }
      
      final controller = _audioService!.controller;
      if (controller == null) {
        throw Exception('Controller no está disponible');
      }
      
      // Si hay una canción diferente reproduciéndose, detener primero
      if (_currentSong != null && _currentSong!.id != song.id && _isPlaying) {
        AppLogger.info('[AudioManager] Deteniendo canción anterior: ${_currentSong!.title}');
        try {
          // Cancelar fade-in si existe
          _fadeTimer?.cancel();
          _fadeTimer = null;
          
          // Pausar la reproducción actual
          await _audioService!.pause();
          
          // Detener el player para limpiar recursos
          await controller.player.stop();
          
          // Pequeña pausa para que se limpie
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          AppLogger.warning('[AudioManager] Error al detener canción anterior: $e');
          // Continuar de todas formas
        }
      }
      
      // Cargar la nueva canción
      AppLogger.info('[AudioManager] Cargando nueva canción: ${song.title}');
      await _audioService!.loadSong(song);
      
      // Esperar un momento para que se cargue completamente
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Verificar que la canción se cargó correctamente
      if (controller.currentSong?.id != song.id) {
        throw Exception('Error: La canción no se cargó correctamente');
      }
      
      // Reproducir con fade-in
      await _playWithFadeIn();
      
      AppLogger.info('[AudioManager] Canción iniciada correctamente: ${song.title}');
    } catch (e, stackTrace) {
      AppLogger.error('[AudioManager] Error al cargar y reproducir canción: $e', stackTrace);
      rethrow;
    }
  }
  
  /// Reproducir con fade-in suave (280ms)
  Future<void> _playWithFadeIn() async {
    final controller = _audioService?.controller;
    if (controller == null) return;
    
    final player = controller.player;
    
    // Cancelar fade-in anterior si existe
    _fadeTimer?.cancel();
    
    // Iniciar con volumen 0
    await player.setVolume(0.0);
    
    // Iniciar reproducción
    await _audioService!.play();
    
    // Fade-in gradual
    int step = 0;
    final stepDuration = _fadeDuration ~/ _fadeSteps;
    final volumeStep = _targetVolume / _fadeSteps;
    
    _fadeTimer = Timer.periodic(stepDuration, (timer) {
      step++;
      if (step >= _fadeSteps) {
        // Último paso: volumen completo
        player.setVolume(_targetVolume).catchError((e) {
          AppLogger.warning('[AudioManager] Error al establecer volumen: $e');
        });
        timer.cancel();
        _fadeTimer = null;
      } else {
        // Volumen gradual
        player.setVolume(volumeStep * step).catchError((e) {
          AppLogger.warning('[AudioManager] Error al establecer volumen: $e');
        });
      }
    });
  }
  
  /// Toggle play/pause - Solo pausa/reproduce sin cambiar canción
  /// NUNCA cambia la canción actual
  Future<void> togglePlayPause() async {
    if (!_isInitialized || _audioService == null) {
      throw Exception('AudioManager no está inicializado. Llame a initialize() primero');
    }
    
    try {
      // Si no hay canción cargada, no hacer nada
      if (_currentSong == null) {
        AppLogger.info('[AudioManager] No hay canción para reproducir/pausar');
        return;
      }
      
      if (_isPlaying) {
        // Cancelar fade-in si existe
        _fadeTimer?.cancel();
        _fadeTimer = null;
        
        await _audioService!.pause();
        AppLogger.info('[AudioManager] Pausado');
      } else {
        await _audioService!.play();
        AppLogger.info('[AudioManager] Reproduciendo');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[AudioManager] Error en togglePlayPause: $e', stackTrace);
      rethrow;
    }
  }
  
  /// Detener la reproducción
  Future<void> stop() async {
    if (!_isInitialized || _audioService == null) return;
    
    try {
      // Cancelar fade-in si existe
      _fadeTimer?.cancel();
      _fadeTimer = null;
      
      await _audioService!.pause();
      
      final controller = _audioService!.controller;
      if (controller != null) {
        await controller.player.stop();
      }
      
      AppLogger.info('[AudioManager] Detenido');
    } catch (e) {
      AppLogger.error('[AudioManager] Error al detener: $e');
    }
  }
  
  /// Cancelar listeners sin cerrar streams (para reconfiguración)
  void _disposeListeners() {
    _currentSongSubscription?.cancel();
    _currentSongSubscription = null;
    
    _stateSubscription?.cancel();
    _stateSubscription = null;
    
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _durationSubscription?.cancel();
    _durationSubscription = null;
  }
  
  /// Limpiar recursos
  void dispose() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    
    _disposeListeners();
    
    // Cerrar streams
    _currentSongController.close();
    _isPlayingController.close();
    _positionController.close();
    _durationController.close();
    
    _isInitialized = false;
    _currentSong = null;
    _audioService = null;
    
    AppLogger.info('[AudioManager] Dispose completado');
  }
}

/// Provider de AudioManager (singleton)
/// Garantiza que solo existe UNA instancia
final audioManagerProvider = Provider<AudioManager>((ref) {
  // Siempre devolver la misma instancia singleton
  final manager = AudioManager();
  
  // No hacer dispose aquí porque es un singleton global
  // Se debe llamar manualmente al cerrar la app
  ref.onDispose(() {
    // Solo limpiar si es necesario, pero mantener el singleton
  });
  
  return manager;
});
