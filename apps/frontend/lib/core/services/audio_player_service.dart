import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';

/// Servicio para manejar la reproducción de audio
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  List<Song> _currentQueue = [];
  int _currentIndex = 0;
  bool _isInitialized = false;

  AudioPlayer get player => _player;
  List<Song> get currentQueue => List.unmodifiable(_currentQueue);
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _currentQueue.length 
      ? _currentQueue[_currentIndex] 
      : null;

  /// Inicializar el servicio de audio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configurar sesión de audio
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      _isInitialized = true;
    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al inicializar: $e');
      rethrow;
    }
  }

  /// Reproducir una canción individual
  Future<void> playSong(Song song) async {
    try {
      if (song.fileUrl == null || song.fileUrl!.isEmpty) {
        throw Exception('La canción no tiene URL de archivo');
      }

      await _player.setUrl(song.fileUrl!);
      await _player.play();
      
      _currentQueue = [song];
      _currentIndex = 0;
    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al reproducir canción: $e');
      rethrow;
    }
  }

  /// Reproducir una lista de canciones (playlist)
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    try {
      if (songs.isEmpty) {
        throw Exception('La lista de canciones está vacía');
      }

      if (startIndex < 0 || startIndex >= songs.length) {
        startIndex = 0;
      }

      final song = songs[startIndex];
      if (song.fileUrl == null || song.fileUrl!.isEmpty) {
        throw Exception('La canción no tiene URL de archivo');
      }

      // Crear lista de URLs para la cola
      final urls = songs
          .where((s) => s.fileUrl != null && s.fileUrl!.isNotEmpty)
          .map((s) => s.fileUrl!)
          .toList();

      if (urls.isEmpty) {
        throw Exception('No hay canciones válidas en la lista');
      }

      // Encontrar el índice de inicio en la lista filtrada
      int filteredIndex = 0;
      for (int i = 0; i <= startIndex; i++) {
        if (songs[i].fileUrl != null && songs[i].fileUrl!.isNotEmpty) {
          if (i == startIndex) break;
          filteredIndex++;
        }
      }

      // Configurar la cola usando el nuevo método setAudioSources
      await _player.setAudioSources(
        urls.map((url) => AudioSource.uri(Uri.parse(url))).toList(),
        initialIndex: filteredIndex,
      );

      await _player.play();

      _currentQueue = songs.where((s) => s.fileUrl != null && s.fileUrl!.isNotEmpty).toList();
      _currentIndex = filteredIndex;

    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al reproducir playlist: $e');
      rethrow;
    }
  }

  /// Pausar reproducción
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al pausar: $e');
    }
  }

  /// Reanudar reproducción
  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al reanudar: $e');
    }
  }

  /// Detener reproducción
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al detener: $e');
    }
  }

  /// Reproducir siguiente canción
  Future<void> next() async {
    try {
      await _player.seekToNext();
      if (_currentIndex < _currentQueue.length - 1) {
        _currentIndex++;
      }
    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al avanzar: $e');
    }
  }

  /// Reproducir canción anterior
  Future<void> previous() async {
    try {
      await _player.seekToPrevious();
      if (_currentIndex > 0) {
        _currentIndex--;
      }
    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al retroceder: $e');
    }
  }

  /// Limpiar recursos
  Future<void> dispose() async {
    try {
      await _player.dispose();
      _currentQueue = [];
      _currentIndex = 0;
      _isInitialized = false;
    } catch (e) {
      AppLogger.error('[AudioPlayerService] Error al limpiar: $e');
    }
  }
}



