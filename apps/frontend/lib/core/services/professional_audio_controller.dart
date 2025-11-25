import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';

/// Controlador profesional para el reproductor de audio
/// Maneja la lógica de reproducción, estado y streams
class AudioPlayerController {
  // AudioPlayer puede ser pasado desde fuera (compartido) o creado internamente
  final AudioPlayer _player;
  final bool _ownsPlayer;
  
  final _positionController = StreamController<Duration>.broadcast();
  final _stateController = StreamController<PlayerState>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _currentSongController = StreamController<Song?>.broadcast();
  
  // Suscripciones para evitar memory leaks
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  
  AudioSession? _audioSession;
  bool _isInitialized = false;
  Song? _currentSong;
  List<Song> _playlist = [];
  double _volume = 0.85; // Volumen inicial reducido para evitar clipping

  /// Constructor: puede recibir un AudioPlayer compartido o crear uno nuevo
  AudioPlayerController({AudioPlayer? sharedPlayer})
      : _player = sharedPlayer ?? AudioPlayer(),
        _ownsPlayer = sharedPlayer == null;

  // Streams públicos
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<Song?> get currentSongStream => _currentSongController.stream;

  // Getters
  AudioPlayer get player => _player;
  Song? get currentSong => _currentSong;
  double get volume => _volume;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  /// Inicializar el controlador con configuración de AudioSession
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configurar AudioSession para manejo profesional de audio y evitar clipping
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        // Configuración optimizada para Android para evitar clipping
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none, // Sin flags especiales para evitar distorsión
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      
      // Configurar volumen inicial del player para evitar clipping
      await _player.setVolume(_volume);
      // Asegurar que la velocidad esté en 1.0x para evitar distorsión
      await _player.setSpeed(1.0);
      
      // Activar el AudioSession explícitamente
      try {
        await _audioSession!.setActive(true);
      } catch (e) {
        // Continuar de todas formas, puede que ya esté activo
      }

      // Escuchar eventos de interrupciones (llamadas, notificaciones) - GUARDAR SUSCRIPCIÓN
      _interruptionSubscription = _audioSession!.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Reducir volumen temporalmente
              _player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Pausar automáticamente
              pause();
              break;
          }
        } else {
          // Restaurar reproducción
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_volume);
              break;
            case AudioInterruptionType.pause:
              // No reanudar automáticamente, dejar que el usuario decida
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // Escuchar cambios de dispositivo de audio - GUARDAR SUSCRIPCIÓN
      _becomingNoisySubscription = _audioSession!.becomingNoisyEventStream.listen((_) {
        // Si se desconecta el auricular, pausar
        pause();
      });

      // Configurar streams del player
      _setupStreams();

      _isInitialized = true;
      AppLogger.info('[AudioPlayerController] Inicializado correctamente');
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al inicializar: $e');
      rethrow;
    }
  }

  /// Configurar streams del reproductor - GUARDAR SUSCRIPCIONES
  void _setupStreams() {
    // Stream de posición - GUARDAR SUSCRIPCIÓN
    _positionSubscription = _player.positionStream.listen((position) {
      if (!_positionController.isClosed) {
        _positionController.add(position);
      }
    });

    // Stream de estado - GUARDAR SUSCRIPCIÓN
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (!_stateController.isClosed) {
        _stateController.add(state);
      }
    });

    // Stream de duración - GUARDAR SUSCRIPCIÓN
    _durationSubscription = _player.durationStream.listen((duration) {
      if (!_durationController.isClosed) {
        _durationController.add(duration);
      }
    });

    // Stream de índice actual (para detectar cambios de canción) - GUARDAR SUSCRIPCIÓN
    _currentIndexSubscription = _player.currentIndexStream.listen((index) {
      _updateCurrentSongFromIndex(index);
    });
  }

  /// Actualizar canción actual basándose en el índice del player
  void _updateCurrentSongFromIndex(int? index) {
    if (index != null && index >= 0 && index < _playlist.length) {
      final newSong = _playlist[index];
      if (_currentSong?.id != newSong.id) {
        _currentSong = newSong;
        if (!_currentSongController.isClosed) {
          _currentSongController.add(_currentSong);
        }
      }
    }
  }

  /// Cargar una canción desde URL - Guardar en playlist para consistencia
  /// Normaliza la URL para el emulador Android si es necesario
  /// Incluye retry logic para errores de red
  Future<void> loadSong(Song song, {int maxRetries = 2}) async {
    if (song.fileUrl == null || song.fileUrl!.isEmpty) {
      throw Exception('La canción no tiene URL de archivo');
    }

    int attempt = 0;
    Exception? lastError;

    while (attempt <= maxRetries) {
      try {
        // Log del intento
        if (attempt > 0) {
          AppLogger.info('[AudioPlayerController] Reintentando cargar canción (intento ${attempt + 1}/${maxRetries + 1}): ${song.title}');
          // Esperar antes de reintentar (exponencial backoff)
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }

        // Normalizar y validar URL para emulador Android (localhost -> 10.0.2.2)
        final normalizedUrl = UrlNormalizer.normalizeUrl(song.fileUrl!, enableLogging: true);
        
        // Validar que la URL sea parseable
        final uri = Uri.parse(normalizedUrl);
        if (uri.host.isEmpty) {
          throw Exception('URL sin host válido: $normalizedUrl');
        }

        // Validar que la URL normalizada sea correcta antes de cargar
        AppLogger.info('[AudioPlayerController] URL original: ${song.fileUrl}');
        AppLogger.info('[AudioPlayerController] URL normalizada: $normalizedUrl');
        
        // Validar que la URL normalizada no tenga typos
        final normalizedUri = Uri.parse(normalizedUrl);
        if (normalizedUri.path.isEmpty || !normalizedUri.path.endsWith('.mp3')) {
          AppLogger.info('[AudioPlayerController] ADVERTENCIA: URL normalizada puede ser incorrecta: $normalizedUrl');
        }
        
        // Detener cualquier reproducción anterior antes de cargar nueva canción
        try {
          await _player.stop();
        } catch (e) {
          // Ignorar errores al detener si no hay nada reproduciendo
        }
        
        // Cargar la URL en el reproductor (setUrl automáticamente carga y prepara)
        AppLogger.info('[AudioPlayerController] Cargando canción desde URL final: $normalizedUrl');
        await _player.setUrl(normalizedUrl);
        
        // Optimizaciones para evitar clipping después de cargar
        // Asegurar que el volumen esté configurado correctamente
        await _player.setVolume(_volume);
        // Asegurar que la velocidad esté en 1.0x para evitar distorsión
        await _player.setSpeed(1.0);
        
        // Guardar como playlist de una sola canción para consistencia
        _playlist.clear();
        _playlist.add(song);
        _currentSong = song;
        
        // Emitir la canción al stream INMEDIATAMENTE después de cargar
        // Esto es importante para que el reproductor se muestre
        if (!_currentSongController.isClosed) {
          _currentSongController.add(song);
          AppLogger.info('[AudioPlayerController] Canción emitida al stream: ${song.title}');
        } else {
          AppLogger.error('[AudioPlayerController] currentSongController está cerrado');
        }
        
        AppLogger.info('[AudioPlayerController] Canción cargada exitosamente: ${song.title}');
        return; // Éxito, salir del loop
      } on PlayerException catch (e) {
        final message = e.message ?? 'Error desconocido del reproductor';
        lastError = Exception('Error del reproductor: $message');
        AppLogger.error('[AudioPlayerController] Error del reproductor (intento ${attempt + 1}): $message');
        
        // Si es error de conexión (404, network, etc.), intentar de nuevo
        // e.code puede ser String o int, así que lo convertimos a String
        final codeStr = e.code.toString();
        if (codeStr == '0' || 
            (message.isNotEmpty && message.contains('404')) || 
            (message.isNotEmpty && message.contains('network')) || 
            (message.isNotEmpty && message.contains('Source error'))) {
          attempt++;
          if (attempt <= maxRetries) {
            continue; // Reintentar
          }
        } else {
          // Error no recuperable, lanzar inmediatamente
          rethrow;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        AppLogger.error('[AudioPlayerController] Error al cargar canción (intento ${attempt + 1}): $e');
        
        // Si es error de red, intentar de nuevo
        if (e.toString().contains('404') || 
            e.toString().contains('network') || 
            e.toString().contains('Connection') ||
            e.toString().contains('Source error')) {
          attempt++;
          if (attempt <= maxRetries) {
            continue; // Reintentar
          }
        } else {
          // Error no recuperable, lanzar inmediatamente
          rethrow;
        }
      }
    }

    // Si llegamos aquí, todos los intentos fallaron
    AppLogger.error('[AudioPlayerController] Error al cargar canción después de ${maxRetries + 1} intentos: $lastError');
    throw lastError ?? Exception('Error desconocido al cargar canción');
  }

  /// Reproducir - VALIDAR que haya canción cargada
  Future<void> play() async {
    if (_currentSong == null && _player.duration == null) {
      throw Exception('No hay canción cargada para reproducir');
    }
    
    try {
      // Asegurarse de que el AudioSession esté activo antes de reproducir
      if (_audioSession != null) {
        try {
          await _audioSession!.setActive(true);
        } catch (e) {
          // Continuar de todas formas
        }
      }
      
      // Asegurarse de que el volumen y velocidad estén configurados correctamente
      if (_player.volume != _volume) {
        await _player.setVolume(_volume);
      }
      // Asegurar que la velocidad esté en 1.0x para evitar distorsión
      if (_player.speed != 1.0) {
        await _player.setSpeed(1.0);
      }
      
      await _player.play();
      AppLogger.info('[AudioPlayerController] Reproducción iniciada');
    } catch (e, stack) {
      AppLogger.error('[AudioPlayerController] Error al reproducir: $e', stack);
      rethrow;
    }
  }

  /// Pausar
  Future<void> pause() async {
    try {
      await _player.pause();
      AppLogger.info('[AudioPlayerController] Reproducción pausada');
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al pausar: $e');
      rethrow;
    }
  }

  /// Detener
  Future<void> stop() async {
    try {
      await _player.stop();
      AppLogger.info('[AudioPlayerController] Reproducción detenida');
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al detener: $e');
      rethrow;
    }
  }

  /// Buscar a una posición específica - VALIDAR duración
  Future<void> seek(Duration position) async {
    final duration = _player.duration;
    if (duration == null) {
      throw Exception('No hay duración disponible para hacer seek');
    }
    
    if (position < Duration.zero || position > duration) {
      throw ArgumentError('Posición de seek fuera de rango');
    }
    
    try {
      await _player.seek(position);
      AppLogger.info('[AudioPlayerController] Buscando a: ${position.inSeconds}s');
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al buscar: $e');
      rethrow;
    }
  }

  /// Establecer volumen (0.0 - 1.0) - Limitado a 0.95 máximo para evitar clipping
  Future<void> setVolume(double volume) async {
    if (volume < 0.0 || volume > 1.0) {
      throw ArgumentError('El volumen debe estar entre 0.0 y 1.0');
    }

    try {
      // Limitar volumen máximo a 0.95 para prevenir clipping
      final safeVolume = volume > 0.95 ? 0.95 : volume;
      _volume = safeVolume;
      await _player.setVolume(safeVolume);
      AppLogger.info('[AudioPlayerController] Volumen establecido: ${(safeVolume * 100).toInt()}%');
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al establecer volumen: $e');
      rethrow;
    }
  }

  /// Cargar una playlist
  Future<void> loadPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) {
      throw Exception('La lista de canciones está vacía');
    }

    try {
      final validSongs = songs.where((s) => s.fileUrl != null && s.fileUrl!.isNotEmpty).toList();
      if (validSongs.isEmpty) {
        throw Exception('No hay canciones válidas en la lista');
      }

      // Normalizar URLs para emulador Android (localhost -> 10.0.2.2)
      final urls = validSongs.map((s) {
        final normalizedUrl = UrlNormalizer.normalizeUrl(s.fileUrl!);
        return AudioSource.uri(Uri.parse(normalizedUrl));
      }).toList();
      
      // Encontrar el índice válido
      int filteredIndex = 0;
      if (startIndex >= 0 && startIndex < songs.length) {
        for (int i = 0; i < startIndex; i++) {
          if (songs[i].fileUrl != null && songs[i].fileUrl!.isNotEmpty) {
            filteredIndex++;
          }
        }
      }

      await _player.setAudioSources(urls, initialIndex: filteredIndex);
      
      // Guardar playlist para actualizar currentSong cuando cambie el índice
      _playlist = validSongs;
      
      // Actualizar canción actual inmediatamente
      if (filteredIndex < validSongs.length) {
        _currentSong = validSongs[filteredIndex];
        if (!_currentSongController.isClosed) {
          _currentSongController.add(_currentSong);
        }
      }

      AppLogger.info('[AudioPlayerController] Playlist cargada: ${validSongs.length} canciones');
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al cargar playlist: $e');
      rethrow;
    }
  }

  /// Reproducir siguiente canción - ACTUALIZAR currentSong
  Future<void> next() async {
    try {
      final hasNext = _player.hasNext;
      if (hasNext) {
        await _player.seekToNext();
        // El currentIndexStream ya actualizará _currentSong automáticamente
        AppLogger.info('[AudioPlayerController] Siguiente canción');
      }
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al avanzar: $e');
      rethrow;
    }
  }

  /// Reproducir canción anterior - ACTUALIZAR currentSong
  Future<void> previous() async {
    try {
      final hasPrevious = _player.hasPrevious;
      if (hasPrevious) {
        await _player.seekToPrevious();
        // El currentIndexStream ya actualizará _currentSong automáticamente
        AppLogger.info('[AudioPlayerController] Canción anterior');
      } else {
        // Si no hay canción anterior, volver al inicio de la actual
        final duration = _player.duration;
        if (duration != null) {
          await _player.seek(Duration.zero);
        }
      }
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al retroceder: $e');
      rethrow;
    }
  }

  /// Liberar recursos - CANCELAR TODAS LAS SUSCRIPCIONES
  Future<void> dispose() async {
    try {
      // Cancelar todas las suscripciones primero
      await _interruptionSubscription?.cancel();
      await _becomingNoisySubscription?.cancel();
      await _positionSubscription?.cancel();
      await _stateSubscription?.cancel();
      await _durationSubscription?.cancel();
      await _currentIndexSubscription?.cancel();
      
      // Cerrar stream controllers
      await _positionController.close();
      await _stateController.close();
      await _durationController.close();
      await _currentSongController.close();
      
      // Solo dispose del player si lo creamos nosotros
      if (_ownsPlayer) {
        await _player.dispose();
      }
      
      _currentSong = null;
      _playlist.clear();
      _isInitialized = false;
      AppLogger.info('[AudioPlayerController] Recursos liberados');
    } catch (e) {
      AppLogger.error('[AudioPlayerController] Error al liberar recursos: $e');
    }
  }

  /// Getter para acceder a la playlist (para el handler)
  List<Song> get playlist => List.unmodifiable(_playlist);
}

