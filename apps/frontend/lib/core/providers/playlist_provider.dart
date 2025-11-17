import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/playlist_service.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';

/// Provider para el servicio de playlists (singleton)
final playlistServiceProvider = Provider<PlaylistService>((ref) {
  final service = PlaylistService();
  // Inicializar una vez al crear el provider
  service.initialize().catchError((_) {});
  return service;
});

/// Provider para listar todas las playlists
final playlistsProvider = FutureProvider.family<List<Playlist>, ({int page, int limit})>((ref, params) async {
  try {
    final service = ref.read(playlistServiceProvider);
    return await service.getPlaylists(page: params.page, limit: params.limit);
  } catch (e) {
    return [];
  }
});

/// Provider para obtener una playlist por ID
final playlistProvider = FutureProvider.family<Playlist?, String>((ref, id) async {
  try {
    final service = ref.read(playlistServiceProvider);
    return await service.getPlaylistById(id);
  } catch (e) {
    return null;
  }
});

/// Provider para obtener playlists destacadas
final featuredPlaylistsProvider = FutureProvider<List<Playlist>>((ref) async {
  try {
    final service = ref.read(playlistServiceProvider);
    return await service.getFeaturedPlaylists(limit: 10);
  } catch (e) {
    return [];
  }
});

/// Provider para obtener canciones de una playlist
final playlistSongsProvider = FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  try {
    final service = ref.read(playlistServiceProvider);
    return await service.getPlaylistSongs(playlistId);
  } catch (e) {
    return [];
  }
});

