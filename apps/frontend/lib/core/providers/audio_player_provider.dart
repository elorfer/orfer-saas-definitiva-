import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_player_service.dart';
import '../models/song_model.dart';
import 'package:just_audio/just_audio.dart';

/// Provider del servicio de reproductor de audio
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  
  // Inicializar el servicio cuando se crea el provider
  service.initialize().catchError((error) {
    // Error silencioso en inicialización
  });
  
  // Limpiar cuando se destruye el provider
  ref.onDispose(() {
    service.dispose().catchError((_) {});
  });
  
  return service;
});

/// Provider del estado del reproductor
final audioPlayerStateProvider = StreamProvider<PlayerState>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.player.playerStateStream;
});

/// Provider de la posición actual de reproducción
final audioPlayerPositionProvider = StreamProvider<Duration>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.player.positionStream;
});

/// Provider de la duración de la canción actual
final audioPlayerDurationProvider = StreamProvider<Duration?>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.player.durationStream;
});

/// Provider de la canción actual
final currentSongProvider = Provider<Song?>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.currentSong;
});

/// Provider de la cola actual
final currentQueueProvider = Provider<List<Song>>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.currentQueue;
});



