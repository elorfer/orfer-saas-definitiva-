import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import 'professional_audio_controller.dart';
import 'professional_audio_handler.dart';
import '../utils/logger.dart';

/// Servicio profesional que integra AudioPlayerController y AudioService
/// para reproducción en background con controles del sistema
class ProfessionalAudioService {
  static final ProfessionalAudioService _instance = 
      ProfessionalAudioService._internal();
  factory ProfessionalAudioService() => _instance;
  ProfessionalAudioService._internal();

  // UN SOLO AudioPlayer compartido entre Controller y Handler
  AudioPlayer? _sharedPlayer;
  AudioPlayerController? _controller;
  ProfessionalAudioHandler? _handler;
  bool _isInitialized = false;
  bool _backgroundModeEnabled = false;
  
  // Suscripciones para evitar listeners duplicados
  StreamSubscription<Song?>? _currentSongSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  AudioPlayerController? get controller => _controller;
  ProfessionalAudioHandler? get handler => _handler;
  bool get isInitialized => _isInitialized;
  bool get backgroundModeEnabled => _backgroundModeEnabled;
  
  /// Verificar si hay una playlist cargada (más de una canción)
  bool get hasPlaylist => _controller?.hasPlaylist ?? false;

  /// Inicializar el servicio completo - CREAR UN SOLO AudioPlayer
  Future<void> initialize({bool enableBackground = true}) async {
    if (_isInitialized) return;

    try {
      // Crear UN SOLO AudioPlayer compartido
      _sharedPlayer = AudioPlayer();
      
      // Inicializar AudioPlayerController con el AudioPlayer compartido
      _controller = AudioPlayerController(sharedPlayer: _sharedPlayer);
      await _controller!.initialize();

      // Si se requiere modo background, inicializar AudioService
      if (enableBackground) {
        await _initializeBackgroundMode();
      }

      _isInitialized = true;
      AppLogger.info('[ProfessionalAudioService] Inicializado correctamente');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al inicializar: $e');
      rethrow;
    }
  }

  /// Inicializar modo background con AudioService - USAR AudioPlayer COMPARTIDO
  /// EVITA INICIALIZAR DOS VECES para prevenir error del cacheManager
  Future<void> _initializeBackgroundMode() async {
    // Verificar si ya está inicializado para evitar doble inicialización
    if (_backgroundModeEnabled || _handler != null) {
      AppLogger.info('[ProfessionalAudioService] Modo background ya está habilitado, omitiendo inicialización');
      return;
    }
    
    if (_sharedPlayer == null || _controller == null) {
      throw Exception('Debe inicializar el controller primero');
    }
    
    try {
      // Verificar si el handler ya existe como indicador de que AudioService está corriendo
      // AudioService.running está deprecado, así que verificamos si ya tenemos handler
      if (_handler != null) {
        AppLogger.info('[ProfessionalAudioService] Handler ya existe, AudioService probablemente está corriendo');
        _backgroundModeEnabled = true;
        return;
      }
      
      // Crear Handler con el AudioPlayer compartido y el controller
      _handler = ProfessionalAudioHandler(
        sharedPlayer: _sharedPlayer!,
        controller: _controller!,
      );
      
      // Configurar AudioService
      // NOTA: Si androidNotificationOngoing es true, androidStopForegroundOnPause debe ser true
      // Capturar cualquier excepción para evitar que se propague y cause errores en la UI
      try {
        await AudioService.init(
          builder: () => _handler!,
          config: AudioServiceConfig(
            androidNotificationChannelId: 'com.vintagemusic.app.audio',
            androidNotificationChannelName: 'Vintage Music Player',
            androidNotificationChannelDescription: 'Reproductor de música Vintage Music',
            androidNotificationOngoing: true,
            androidNotificationIcon: 'mipmap/ic_launcher',
            androidShowNotificationBadge: true,
            androidStopForegroundOnPause: true, // Debe ser true si androidNotificationOngoing es true
            androidNotificationClickStartsActivity: true,
            androidResumeOnClick: true,
          ),
        );
        _backgroundModeEnabled = true;
        AppLogger.info('[ProfessionalAudioService] Modo background habilitado exitosamente');
      } catch (initError) {
        // Si falla AudioService.init, continuar sin modo background
        AppLogger.info('[ProfessionalAudioService] AudioService.init falló, continuando sin modo background: $initError');
        _backgroundModeEnabled = false;
        // Limpiar handler si falló la inicialización
        _handler = null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('[ProfessionalAudioService] Error al inicializar modo background: $e', stackTrace);
      // Continuar sin modo background si falla - NO PROPAGAR EL ERROR
      _backgroundModeEnabled = false;
      _handler = null;
      // Asegurar que el error no se propague para que el servicio funcione sin background mode
    }
  }

  // La sincronización ahora se maneja automáticamente porque:
  // - Ambos usan el mismo AudioPlayer compartido
  // - El Handler escucha directamente los streams del controller
  // - No necesitamos listeners duplicados

  /// Habilitar modo background después de la inicialización
  Future<void> enableBackgroundMode() async {
    if (_backgroundModeEnabled) return;

    try {
      await _initializeBackgroundMode();
      AppLogger.info('[ProfessionalAudioService] Modo background habilitado');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al habilitar modo background: $e');
      rethrow;
    }
  }

  /// Cargar una canción - VALIDAR inicialización
  Future<void> loadSong(Song song) async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      await _controller!.loadSong(song);
      
      // El handler se sincroniza automáticamente a través de currentSongStream
      if (_backgroundModeEnabled && _handler != null) {
        await _handler!.loadSong(song);
      }
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al cargar canción: $e');
      rethrow;
    }
  }

  /// Cargar una playlist - VALIDAR inicialización
  Future<void> loadPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      await _controller!.loadPlaylist(songs, startIndex: startIndex);
      
      // El handler se sincroniza automáticamente con la playlist del controller
      if (_backgroundModeEnabled && _handler != null) {
        await _handler!.loadPlaylist(songs, startIndex: startIndex);
      }
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al cargar playlist: $e');
      rethrow;
    }
  }

  /// Reproducir - VALIDAR inicialización
  Future<void> play() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      await _controller!.play();
    } catch (e, stack) {
      AppLogger.error('[ProfessionalAudioService] Error al reproducir: $e', stack);
      rethrow;
    }
  }

  /// Pausar - VALIDAR inicialización
  Future<void> pause() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      // Solo pausar en el controller - el AudioPlayer compartido se encarga del resto
      await _controller!.pause();
      // NO llamar handler.pause() - usan el mismo AudioPlayer
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al pausar: $e');
      rethrow;
    }
  }

  /// Detener - VALIDAR inicialización
  Future<void> stop() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      // Solo detener en el controller - el AudioPlayer compartido se encarga del resto
      await _controller!.stop();
      // NO llamar handler.stop() - usan el mismo AudioPlayer
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al detener: $e');
      rethrow;
    }
  }

  /// Buscar - VALIDAR inicialización
  Future<void> seek(Duration position) async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      // Solo hacer seek en el controller - el AudioPlayer compartido se encarga del resto
      await _controller!.seek(position);
      // NO llamar handler.seek() - usan el mismo AudioPlayer
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al buscar: $e');
      rethrow;
    }
  }

  /// Establecer volumen - VALIDAR inicialización
  Future<void> setVolume(double volume) async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      // Solo establecer volumen en el controller - el AudioPlayer compartido se encarga del resto
      await _controller!.setVolume(volume);
      // NO llamar handler.setVolume() - usan el mismo AudioPlayer
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al establecer volumen: $e');
      rethrow;
    }
  }

  /// Siguiente canción - VALIDAR inicialización
  Future<void> next() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      // Solo llamar al controller - el AudioPlayer compartido actualiza ambos
      await _controller!.next();
      // NO llamar handler.skipToNext() - usan el mismo AudioPlayer
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al avanzar: $e');
      rethrow;
    }
  }

  /// Canción anterior - VALIDAR inicialización
  Future<void> previous() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('El servicio no está inicializado. Llame a initialize() primero');
    }

    try {
      // Solo llamar al controller - el AudioPlayer compartido actualiza ambos
      await _controller!.previous();
      // NO llamar handler.skipToPrevious() - usan el mismo AudioPlayer
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al retroceder: $e');
      rethrow;
    }
  }

  /// Liberar recursos - CANCELAR TODAS LAS SUSCRIPCIONES
  Future<void> dispose() async {
    try {
      // Cancelar suscripciones de sincronización si existen
      await _currentSongSubscription?.cancel();
      await _stateSubscription?.cancel();
      
      // Dispose del controller (maneja el AudioPlayer si lo creó)
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      // Dispose del handler (NO dispose del player, lo maneja el controller)
      if (_handler != null) {
        await _handler!.dispose();
        _handler = null;
      }

      // Si creamos el AudioPlayer aquí, disposearlo
      if (_sharedPlayer != null && _controller == null) {
        await _sharedPlayer!.dispose();
      }
      
      _sharedPlayer = null;
      
      // AudioService.stop() está deprecado, usar handler.stop() si existe
      if (_backgroundModeEnabled && _handler != null) {
        try {
          await _handler!.stop();
        } catch (e) {
          AppLogger.error('[ProfessionalAudioService] Error al detener handler: $e');
        }
        _backgroundModeEnabled = false;
      }

      _isInitialized = false;
      AppLogger.info('[ProfessionalAudioService] Recursos liberados');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioService] Error al liberar recursos: $e');
    }
  }
}

