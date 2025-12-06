import 'dart:async';
import '../models/playback_context.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';

/// Servicio para manejar el contexto de reproducción
/// Similar al sistema de Spotify para manejar diferentes fuentes de música
class PlaybackContextService {
  PlaybackContext? _currentContext;
  final _contextController = StreamController<PlaybackContext?>.broadcast();
  
  // Callback para obtener la siguiente canción destacada
  Future<Song?> Function(Song currentSong)? _onGetNextFeaturedSong;

  /// Obtener el contexto actual
  PlaybackContext? get currentContext => _currentContext;

  /// Stream del contexto actual
  Stream<PlaybackContext?> get contextStream => _contextController.stream;

  /// Configurar callbacks
  void setCallbacks({
    Future<Song?> Function(Song currentSong)? onGetNextFeaturedSong,
  }) {
    _onGetNextFeaturedSong = onGetNextFeaturedSong;
  }

  /// Establecer un nuevo contexto de reproducción
  void setContext(PlaybackContext context) {
    _currentContext = context;
    _contextController.add(context);
    AppLogger.info('[PlaybackContextService] Contexto establecido: ${context.type.displayName} - ${context.name}');
  }

  /// Establecer contexto de canciones destacadas
  void setFeaturedSongsContext(Song currentSong) {
    final context = PlaybackContext.featuredSongs(
      currentSongId: currentSong.id,
    );
    setContext(context);
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
    setContext(context);
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
    setContext(context);
  }

  /// Limpiar el contexto actual
  void clearContext() {
    _currentContext = null;
    _contextController.add(null);
    AppLogger.info('[PlaybackContextService] Contexto limpiado');
  }

  /// Obtener la siguiente canción basada en el contexto actual
  Future<Song?> getNextSong(Song currentSong) async {
    if (_currentContext == null) {
      // Si no hay contexto, usar el callback de canciones destacadas
      if (_onGetNextFeaturedSong != null) {
        return await _onGetNextFeaturedSong!(currentSong);
      }
      return null;
    }

    // Implementar lógica según el tipo de contexto
    switch (_currentContext!.type) {
      case PlaybackContextType.featuredSongs:
        // Usar algoritmo de recomendación
        if (_onGetNextFeaturedSong != null) {
          return await _onGetNextFeaturedSong!(currentSong);
        }
        return null;
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        // Lógica para otros tipos de contexto
        // Por ahora, retornar null (se implementará según necesidad)
        return null;
    }
  }

  /// Liberar recursos
  void dispose() {
    _contextController.close();
  }
}

