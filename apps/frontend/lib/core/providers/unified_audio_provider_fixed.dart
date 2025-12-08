import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import 'playback_notifier.dart';

/// Provider unificado del reproductor de audio
/// Usa el nuevo sistema de AudioService único
final unifiedAudioProviderFixed = playbackNotifierProviderFactory;

/// Provider para obtener solo la canción actual (optimización)
final currentSongProviderFixed = Provider<Song?>((ref) {
  return ref.watch(unifiedAudioProviderFixed).currentSong;
});

/// Provider para obtener solo el estado de reproducción (optimización)
final isPlayingProviderFixed = Provider<bool>((ref) {
  return ref.watch(unifiedAudioProviderFixed).isPlaying;
});
