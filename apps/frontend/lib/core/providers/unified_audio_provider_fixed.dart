import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart'; // ✅ Importar para SequenceState
import '../models/song_model.dart';
import '../services/audio_service.dart';
import 'playback_notifier.dart';

/// Provider unificado del reproductor de audio
/// Usa el nuevo sistema de AudioService único
final unifiedAudioProviderFixed = playbackNotifierProvider;

/// ✅ ÚNICA FUENTE DE VERDAD: Provider que siempre devuelve la canción que REALMENTE se está reproduciendo
/// ✅ FIX FLICKER: Solo usa el estado del Notifier, NO lee del player.sequenceState
/// El sequenceState puede contener datos transitorios durante skips que causan parpadeo
final realCurrentSongProvider = Provider<Song?>((ref) {
  // ✅ FUENTE ÚNICA: Usar select para evitar rebuilds por cambios de posición/volumen
  // Priorizar lastConfirmedSong (set optimísticamente) sobre currentSong
  final currentSong = ref.watch(unifiedAudioProviderFixed.select((s) => s.lastConfirmedSong ?? s.currentSong));
  return currentSong;
});

/// Provider para obtener solo la canción actual (optimización)
/// ✅ DEPRECATED: Usar realCurrentSongProvider en su lugar para garantizar consistencia
@Deprecated('Usar realCurrentSongProvider en su lugar')
final currentSongProviderFixed = Provider<Song?>((ref) {
  return ref.watch(realCurrentSongProvider);
});

/// Provider para obtener solo el estado de reproducción (optimización)
final isPlayingProviderFixed = Provider<bool>((ref) {
  return ref.watch(unifiedAudioProviderFixed).isPlaying;
});

/// ✅ RAW SOURCE OF TRUTH: Stream directo del player (Misma fuente que ProfessionalAudioPlayer)
/// Usar esto en el MiniPlayer para garantizar sincronización exacta con el Player Grande (ProfessionalAudioPlayer)
final rawSequenceStateProvider = StreamProvider<SequenceState?>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.player.sequenceStateStream;
});
