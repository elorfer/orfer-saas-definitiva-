import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/song_model.dart';
import '../services/song_detail_service.dart';

/// Provider para el servicio de detalle de canción
final songDetailServiceProvider = Provider<SongDetailService>((ref) {
  final service = SongDetailService();
  service.initialize();
  return service;
});

/// Provider para obtener canciones por artista
final songsByArtistProvider = FutureProvider.family<List<Song>, String>((ref, artistId) async {
  final service = ref.read(songDetailServiceProvider);
  final songs = await service.getSongsByArtist(artistId);
  // Filtrar la canción actual si se pasa como parámetro
  return songs;
});

/// Provider para obtener una canción por ID
final songByIdProvider = FutureProvider.family<Song?, String>((ref, songId) async {
  final service = ref.read(songDetailServiceProvider);
  return await service.getSongById(songId);
});



