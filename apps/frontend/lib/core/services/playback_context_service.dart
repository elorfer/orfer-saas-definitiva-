import 'dart:async';
import '../models/playback_context.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';

/// Servicio para manejar contextos de reproducción
/// Gestiona diferentes tipos de reproducción (playlist, artista, destacadas, etc.)
class PlaybackContextService {
  static final PlaybackContextService _instance = PlaybackContextService._internal();
  factory PlaybackContextService() => _instance;
  PlaybackContextService._internal();

  PlaybackContext? _currentContext;
  final StreamController<PlaybackContext?> _contextController = StreamController<PlaybackContext?>.broadcast();

  /// Stream del contexto actual
  Stream<PlaybackContext?> get contextStream => _contextController.stream;

  /// Contexto actual
  PlaybackContext? get currentContext => _currentContext;

  /// Callback para obtener siguiente canción destacada
  Future<Song?> Function(Song currentSong)? _onGetNextFeaturedSong;

  /// Callback para obtener canciones de un artista (reservado para futuro uso)
  // Future<List<Song>> Function(String artistId)? _onGetArtistSongs;

  /// Configurar callbacks
  void setCallbacks({
    Future<Song?> Function(Song currentSong)? onGetNextFeaturedSong,
    // Future<List<Song>> Function(String artistId)? onGetArtistSongs,
  }) {
    _onGetNextFeaturedSong = onGetNextFeaturedSong;
    // _onGetArtistSongs = onGetArtistSongs;
  }

  /// Establecer contexto de canciones destacadas
  void setFeaturedSongsContext(Song currentSong) {
    AppLogger.info('[PlaybackContextService] 🎵 Estableciendo contexto de canciones destacadas');
    AppLogger.info('[PlaybackContextService] 📝 Canción: ${currentSong.title} (${currentSong.id})');
    AppLogger.info('[PlaybackContextService] 🏷️ Géneros: ${currentSong.genres?.join(', ') ?? 'ninguno'}');
    
    final context = PlaybackContext.featuredSongs(
      currentSongId: currentSong.id,
      name: 'Canciones Destacadas',
    );
    
    _setContext(context);
    AppLogger.info('[PlaybackContextService] ✅ Contexto establecido: Canciones destacadas - ${currentSong.title}');
  }

  /// Establecer contexto de playlist
  void setPlaylistContext({
    required String playlistId,
    required String playlistName,
    String? description,
    String? imageUrl,
    required List<Song> songs,
    int startIndex = 0,
    bool shuffle = false,
    bool repeat = false,
  }) {
    final songIds = songs.map((s) => s.id).toList();
    final context = PlaybackContext.playlist(
      playlistId: playlistId,
      name: playlistName,
      description: description,
      imageUrl: imageUrl,
      songIds: songIds,
      startIndex: startIndex,
      shuffle: shuffle,
      repeat: repeat,
    );
    
    _setContext(context);
    AppLogger.info('[PlaybackContextService] Contexto establecido: Playlist "$playlistName" (${songs.length} canciones, índice: $startIndex)');
  }

  /// Establecer contexto de artista destacado
  void setFeaturedArtistContext({
    required String artistId,
    required String artistName,
    String? imageUrl,
    required List<Song> songs,
    int startIndex = 0,
    bool shuffle = false,
  }) {
    final songIds = songs.map((s) => s.id).toList();
    final context = PlaybackContext.featuredArtist(
      artistId: artistId,
      artistName: artistName,
      imageUrl: imageUrl,
      songIds: songIds,
      startIndex: startIndex,
      shuffle: shuffle,
    );
    
    _setContext(context);
    AppLogger.info('[PlaybackContextService] Contexto establecido: Artista "$artistName" (${songs.length} canciones, índice: $startIndex)');
  }

  /// Establecer contexto de álbum
  void setAlbumContext({
    required String albumId,
    required String albumName,
    String? artistName,
    String? imageUrl,
    required List<Song> songs,
    int startIndex = 0,
  }) {
    final songIds = songs.map((s) => s.id).toList();
    final context = PlaybackContext.album(
      albumId: albumId,
      albumName: albumName,
      artistName: artistName,
      imageUrl: imageUrl,
      songIds: songIds,
      startIndex: startIndex,
    );
    
    _setContext(context);
    AppLogger.info('[PlaybackContextService] Contexto establecido: Álbum "$albumName" (${songs.length} canciones, índice: $startIndex)');
  }

  /// Avanzar al siguiente índice en el contexto actual
  void moveToNext() {
    if (_currentContext == null) return;
    
    final nextIndex = _currentContext!.getNextIndex();
    if (nextIndex != null) {
      final newContext = _currentContext!.copyWith(currentIndex: nextIndex);
      _setContext(newContext);
      AppLogger.info('[PlaybackContextService] Avanzado al siguiente: índice $nextIndex');
    } else {
      AppLogger.info('[PlaybackContextService] No hay siguiente canción en el contexto actual');
    }
  }

  /// Retroceder al índice anterior en el contexto actual
  void moveToPrevious() {
    if (_currentContext == null) return;
    
    final prevIndex = _currentContext!.getPreviousIndex();
    if (prevIndex != null) {
      final newContext = _currentContext!.copyWith(currentIndex: prevIndex);
      _setContext(newContext);
      AppLogger.info('[PlaybackContextService] Retrocedido al anterior: índice $prevIndex');
    } else {
      AppLogger.info('[PlaybackContextService] No hay canción anterior en el contexto actual');
    }
  }

  /// Saltar a un índice específico
  void jumpToIndex(int index) {
    if (_currentContext == null) return;
    
    if (index >= 0 && index < _currentContext!.songIds.length) {
      final newContext = _currentContext!.copyWith(currentIndex: index);
      _setContext(newContext);
      AppLogger.info('[PlaybackContextService] Saltado al índice: $index');
    } else {
      AppLogger.warning('[PlaybackContextService] Índice fuera de rango: $index (máximo: ${_currentContext!.songIds.length - 1})');
    }
  }

  /// Alternar shuffle
  void toggleShuffle() {
    if (_currentContext == null) return;
    
    final newShuffle = !_currentContext!.shuffle;
    final newContext = _currentContext!.copyWith(shuffle: newShuffle);
    _setContext(newContext);
    AppLogger.info('[PlaybackContextService] Shuffle ${newShuffle ? "activado" : "desactivado"}');
  }

  /// Alternar repeat
  void toggleRepeat() {
    if (_currentContext == null) return;
    
    final newRepeat = !_currentContext!.repeat;
    final newContext = _currentContext!.copyWith(repeat: newRepeat);
    _setContext(newContext);
    AppLogger.info('[PlaybackContextService] Repeat ${newRepeat ? "activado" : "desactivado"}');
  }

  /// Obtener siguiente canción según el contexto
  Future<Song?> getNextSong(List<Song> availableSongs, Song currentSong) async {
    if (_currentContext == null) {
      AppLogger.warning('[PlaybackContextService] No hay contexto establecido');
      return null;
    }

    switch (_currentContext!.type) {
      case PlaybackContextType.featuredSongs:
        AppLogger.info('[PlaybackContextService] 🎵 Procesando contexto de canciones destacadas');
        // Para canciones destacadas, usar el callback
        if (_onGetNextFeaturedSong != null) {
          try {
            AppLogger.info('[PlaybackContextService] 🔄 Llamando callback para obtener siguiente canción destacada');
            final nextSong = await _onGetNextFeaturedSong!(currentSong);
            if (nextSong != null) {
              AppLogger.info('[PlaybackContextService] ✅ Siguiente canción destacada obtenida: ${nextSong.title} (géneros: ${nextSong.genres?.join(', ') ?? 'ninguno'})');
              // Actualizar contexto con la nueva canción
              setFeaturedSongsContext(nextSong);
            } else {
              AppLogger.warning('[PlaybackContextService] ⚠️ Callback devolvió null - no hay siguiente canción destacada');
            }
            return nextSong;
          } catch (e) {
            AppLogger.error('[PlaybackContextService] ❌ Error obteniendo siguiente canción destacada: $e');
            return null;
          }
        } else {
          AppLogger.warning('[PlaybackContextService] ⚠️ Callback _onGetNextFeaturedSong no está configurado');
        }
        return null;

      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        // Para contextos con lista fija, usar el siguiente índice
        final nextIndex = _currentContext!.getNextIndex();
        if (nextIndex != null && nextIndex < availableSongs.length) {
          // Actualizar contexto al siguiente índice
          moveToNext();
          return availableSongs[nextIndex];
        }
        return null;
    }
  }

  /// Obtener canción anterior según el contexto
  Song? getPreviousSong(List<Song> availableSongs) {
    if (_currentContext == null) {
      AppLogger.warning('[PlaybackContextService] No hay contexto establecido');
      return null;
    }

    switch (_currentContext!.type) {
      case PlaybackContextType.featuredSongs:
        // Para canciones destacadas, no hay anterior
        return null;

      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        final prevIndex = _currentContext!.getPreviousIndex();
        if (prevIndex != null && prevIndex < availableSongs.length) {
          moveToPrevious();
          return availableSongs[prevIndex];
        }
        return null;
    }
  }

  /// Verificar si puede avanzar automáticamente
  bool get canAutoAdvance => _currentContext?.canAutoAdvance ?? false;

  /// Obtener ID de la canción actual según el contexto
  String? get currentSongId {
    if (_currentContext == null) return null;
    
    final index = _currentContext!.currentIndex;
    if (index >= 0 && index < _currentContext!.songIds.length) {
      return _currentContext!.songIds[index];
    }
    return null;
  }

  /// Limpiar contexto
  void clearContext() {
    _currentContext = null;
    _contextController.add(null);
    AppLogger.info('[PlaybackContextService] Contexto limpiado');
  }

  /// Método privado para establecer contexto
  void _setContext(PlaybackContext context) {
    _currentContext = context;
    _contextController.add(context);
    AppLogger.info('[PlaybackContextService] 🔄 Contexto actualizado: ${context.type}');
  }

  /// Reproducir canciones destacadas con contexto automático
  Future<void> playFeaturedSongsContext({
    required Song startingSong,
    required dynamic audioManager, // AudioManager instance
  }) async {
    try {
      AppLogger.info('[PlaybackContextService] 🌟 Creando contexto de canciones destacadas');
      
      // Por ahora, crear un contexto simple con la canción actual
      // TODO: Obtener todas las canciones destacadas del HomeService
      final context = PlaybackContext.featuredSongs(
        currentSongId: startingSong.id,
        name: 'Canciones Destacadas',
      );
      
      _setContext(context);
      AppLogger.info('[PlaybackContextService] ✅ Contexto de destacadas creado');
      
      // Iniciar la reproducción de la canción actual
      AppLogger.info('[PlaybackContextService] 🎵 Iniciando reproducción de: ${startingSong.title}');
      await audioManager.playFeaturedSong(startingSong);
      AppLogger.info('[PlaybackContextService] ✅ Reproducción iniciada');
      
    } catch (e) {
      AppLogger.error('[PlaybackContextService] ❌ Error creando contexto de destacadas: $e');
      rethrow;
    }
  }

  /// Liberar recursos
  void dispose() {
    _contextController.close();
  }
}
