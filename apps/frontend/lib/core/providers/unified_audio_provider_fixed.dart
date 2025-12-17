import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../services/audio_service.dart';
import 'playback_notifier.dart';

/// Provider unificado del reproductor de audio
/// Usa el nuevo sistema de AudioService único
final unifiedAudioProviderFixed = playbackNotifierProviderFactory;

/// ✅ ÚNICA FUENTE DE VERDAD: Provider que siempre devuelve la canción que REALMENTE se está reproduciendo
/// Combina el estado de Riverpod con el reproductor de audio para máxima confiabilidad
/// Este provider debe ser usado por TODOS los reproductores (mini y grande) para garantizar consistencia
final realCurrentSongProvider = Provider<Song?>((ref) {
  // 1. Obtener estado de Riverpod (fuente principal)
  final playbackState = ref.watch(unifiedAudioProviderFixed);
  Song? currentSong = playbackState.lastConfirmedSong ?? playbackState.currentSong;
  
  // 2. Verificar qué canción REALMENTE se está reproduciendo en el reproductor de audio
  final audioService = ref.watch(audioServiceProvider);
  final sequenceState = audioService.player.sequenceState;
  final realCurrentSource = sequenceState.currentSource;
  
  // 3. ✅ FUENTE DE VERDAD REAL: Si el reproductor tiene una canción, usarla como fuente de verdad
  if (realCurrentSource != null && realCurrentSource.tag is Song) {
    final realCurrentSong = realCurrentSource.tag as Song;
    
    // Si la canción del reproductor es diferente a la del estado, usar la del reproductor (más confiable)
    if (currentSong == null || currentSong.id != realCurrentSong.id) {
      return realCurrentSong; // ✅ FUENTE DE VERDAD REAL
    }
  }
  
  // 4. Si no hay canción en el reproductor pero hay en el estado, usar la del estado
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
