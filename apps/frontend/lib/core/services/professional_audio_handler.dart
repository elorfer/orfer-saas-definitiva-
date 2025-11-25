import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import 'professional_audio_controller.dart';

/// Handler para AudioService que permite reproducción en background
/// con controles del sistema y notificaciones persistentes
class ProfessionalAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // AudioPlayer compartido del controller (no crear uno nuevo)
  final AudioPlayer _player;
  final AudioPlayerController _controller;
  final List<Song> _playlist = [];
  int _currentIndex = 0;

  // BehaviorSubjects para playbackState y mediaItem - INICIALIZADOS CON VALORES
  final _playbackState = BehaviorSubject<PlaybackState>.seeded(
    PlaybackState(
      controls: [],
      systemActions: const {},
      androidCompactActionIndices: const [],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
      queueIndex: null,
    ),
  );
  
  final _mediaItem = BehaviorSubject<MediaItem?>.seeded(null);
  
  // BehaviorSubject para 'playing' para evitar errores de casting
  // audio_service internamente intenta extraer playing de playbackState,
  // lo que causa un error de casting. Este BehaviorSubject resuelve el problema.
  final _playingSubject = BehaviorSubject<bool>.seeded(false);

  // Suscripciones para evitar memory leaks
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  StreamSubscription<Song?>? _currentSongSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;

  /// Constructor: recibe AudioPlayer compartido y el controller
  ProfessionalAudioHandler({
    required AudioPlayer sharedPlayer,
    required AudioPlayerController controller,
  })  : _player = sharedPlayer,
        _controller = controller {
    // Sincronizar _playingSubject con playbackState para evitar errores de casting
    // audio_service internamente puede intentar extraer playing, y esto evita el error
    _playbackStateSubscription = _playbackState.listen((state) {
      if (!_playingSubject.isClosed && _playingSubject.value != state.playing) {
        _playingSubject.add(state.playing);
      }
    });
    _setupPlayerListeners();
    _syncWithController();
  }
  
  /// Sincronizar con el controller para recibir cambios de canción
  void _syncWithController() {
    _currentSongSubscription = _controller.currentSongStream.listen((song) {
      if (song != null) {
        _updateMediaItemFromSong(song);
      }
    });
    
    _currentIndexSubscription = _player.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        if (_currentIndex < _playlist.length) {
          _updateMediaItem();
        }
      }
    });
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
      AppLogger.info('[ProfessionalAudioHandler] Reproducción iniciada');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al reproducir: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      AppLogger.info('[ProfessionalAudioHandler] Reproducción pausada');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al pausar: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      AppLogger.info('[ProfessionalAudioHandler] Reproducción detenida');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al detener: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      AppLogger.info('[ProfessionalAudioHandler] Buscando a: ${position.inSeconds}s');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al buscar: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      final hasNext = _player.hasNext;
      if (hasNext) {
        await _player.seekToNext();
        // NO incrementar manualmente - el currentIndexStream ya lo actualiza
        AppLogger.info('[ProfessionalAudioHandler] Siguiente canción');
      }
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al avanzar: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      final hasPrevious = _player.hasPrevious;
      if (hasPrevious) {
        await _player.seekToPrevious();
        // NO decrementar manualmente - el currentIndexStream ya lo actualiza
        AppLogger.info('[ProfessionalAudioHandler] Canción anterior');
      } else {
        await _player.seek(Duration.zero);
      }
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al retroceder: $e');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      if (index >= 0 && index < _playlist.length) {
        await _player.seek(Duration.zero, index: index);
        _currentIndex = index;
        _updateMediaItem();
        AppLogger.info('[ProfessionalAudioHandler] Saltando a índice: $index');
      }
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al saltar a índice: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      AppLogger.info('[ProfessionalAudioHandler] Velocidad establecida: $speed');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al establecer velocidad: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
      AppLogger.info('[ProfessionalAudioHandler] Volumen establecido: ${(volume * 100).toInt()}%');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al establecer volumen: $e');
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    // Implementación opcional para remover canciones de la cola
    AppLogger.info('[ProfessionalAudioHandler] Remover canción en índice: $index');
  }

  // Getters para los streams (BehaviorSubject)
  @override
  BehaviorSubject<PlaybackState> get playbackState => _playbackState;

  @override
  BehaviorSubject<MediaItem?> get mediaItem => _mediaItem;
  
  // Getter explícito de 'playing' como ValueStream<bool>
  // Esto evita el error de casting que ocurre cuando audio_service
  // intenta extraer playing de playbackState internamente
  ValueStream<bool> get playing => _playingSubject;

  // Métodos propios
  AudioPlayer get player => _player;
  
  /// Obtener la playlist actual (sincronizada con controller)
  List<Song> get playlist => List.unmodifiable(_playlist);

  /// Cargar una canción individual - Sincronizar con controller
  Future<void> loadSong(Song song) async {
    // Ya está cargada en el controller, solo actualizar el MediaItem
    _playlist.clear();
    _playlist.add(song);
    _currentIndex = 0;
    _updateMediaItemFromSong(song);
    AppLogger.info('[ProfessionalAudioHandler] Canción sincronizada: ${song.title}');
  }

  /// Cargar una playlist - Ya está cargada en el controller, solo sincronizar
  Future<void> loadPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) {
      throw Exception('La lista de canciones está vacía');
    }

    try {
      final validSongs = songs
          .where((s) => s.fileUrl != null && s.fileUrl!.isNotEmpty)
          .toList();
      
      if (validSongs.isEmpty) {
        throw Exception('No hay canciones válidas en la lista');
      }

      // Calcular índice inicial válido
      int filteredIndex = 0;
      if (startIndex >= 0 && startIndex < songs.length) {
        for (int i = 0; i < startIndex; i++) {
          if (songs[i].fileUrl != null && songs[i].fileUrl!.isNotEmpty) {
            filteredIndex++;
          }
        }
      }

      // Ya está cargada en el controller, solo sincronizar
      _playlist.clear();
      _playlist.addAll(validSongs);
      _currentIndex = filteredIndex;
      if (_currentIndex < _playlist.length) {
        _updateMediaItem();
      }
      
      AppLogger.info('[ProfessionalAudioHandler] Playlist sincronizada: ${validSongs.length} canciones');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al sincronizar playlist: $e');
      rethrow;
    }
  }

  /// Configurar listeners del reproductor - GUARDAR SUSCRIPCIONES
  void _setupPlayerListeners() {
    // Escuchar cambios de estado de reproducción - GUARDAR SUSCRIPCIÓN
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!_playbackState.isClosed) {
        _playbackState.add(PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            if (state.playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: _convertProcessingState(state.processingState),
          playing: state.playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _player.currentIndex,
        ));
      }
    });

    // Escuchar cambios de posición - GUARDAR SUSCRIPCIÓN
    _positionSubscription = _player.positionStream.listen((position) {
      if (!_playbackState.isClosed) {
        _playbackState.add(PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            if (_player.playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: _convertProcessingState(_player.processingState),
          playing: _player.playing,
          updatePosition: position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _player.currentIndex,
        ));
      }
    });
  }

  /// Actualizar el MediaItem actual desde la playlist
  void _updateMediaItem() {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final song = _playlist[_currentIndex];
      _updateMediaItemFromSong(song);
      
      // También actualizar la cola para que los controles del sistema funcionen
      if (_playlist.isNotEmpty) {
        queue.add(_playlist.map((s) => _songToMediaItem(s, _playlist.indexOf(s))).toList());
      }
    }
  }
  
  /// Actualizar MediaItem desde una canción específica
  void _updateMediaItemFromSong(Song song) {
    final mediaItem = _songToMediaItem(song, _currentIndex);
    if (!_mediaItem.isClosed) {
      _mediaItem.add(mediaItem);
    }
  }

  /// Convertir Song a MediaItem
  MediaItem _songToMediaItem(Song song, int index) {
    return MediaItem(
      id: song.id,
      album: song.albumId ?? 'Sin álbum',
      title: song.title ?? 'Sin título',
      artist: song.artist?.displayName ?? 'Artista desconocido',
      duration: song.duration != null 
          ? Duration(seconds: song.duration!) 
          : null,
      artUri: song.coverArtUrl != null 
          ? Uri.parse(song.coverArtUrl!) 
          : null,
      extras: {
        'songId': song.id,
        'artistId': song.artistId,
        'albumId': song.albumId,
      },
      playable: true,
    );
  }

  /// Convertir ProcessingState de just_audio a AudioProcessingState
  AudioProcessingState _convertProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Liberar recursos - CANCELAR TODAS LAS SUSCRIPCIONES
  Future<void> dispose() async {
    try {
      // Cancelar todas las suscripciones primero
      await _playerStateSubscription?.cancel();
      await _positionSubscription?.cancel();
      await _currentIndexSubscription?.cancel();
      await _currentSongSubscription?.cancel();
      await _playbackStateSubscription?.cancel();
      
      // Cerrar BehaviorSubjects
      await _playbackState.close();
      await _mediaItem.close();
      await _playingSubject.close();
      
      // NO dispose del player - lo maneja el controller
      
      AppLogger.info('[ProfessionalAudioHandler] Recursos liberados');
    } catch (e) {
      AppLogger.error('[ProfessionalAudioHandler] Error al liberar recursos: $e');
    }
  }
}

