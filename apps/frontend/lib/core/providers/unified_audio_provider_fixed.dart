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
  // 1. Obtener solo la canción del estado (fuente principal)
  // ✅ OPTIMIZACIÓN: Usar select para evitar rebuilds por cambios de posición/volumen
  final currentSong = ref.watch(unifiedAudioProviderFixed.select((s) => s.lastConfirmedSong ?? s.currentSong));
  
  // 2. Verificar qué canción REALMENTE se está reproduciendo en el reproductor de audio
  final audioService = ref.watch(audioServiceProvider);
  final sequenceState = audioService.player.sequenceState;
  final realCurrentSource = sequenceState.currentSource;
  
    // 3. ✅ FUENTE DE VERDAD REAL: Priorizar el estado confirmado por el Notifier
    // El Notifier escucha el stream de eventos, que es más rápido y preciso que la propiedad sincrónica sequenceState.
    // Si tenemos una canción confirmada en el estado, LA USAMOS.
    if (currentSong != null) {
      return currentSong;
    }

    // Solo si el estado no tiene canción (o es null), intentamos recuperar desde el reproductor
    // Esto sirve como fallback en inicialización o casos extremos.
    if (realCurrentSource != null && realCurrentSource.tag is Song) {
      final realCurrentSong = realCurrentSource.tag as Song;
      return realCurrentSong;
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
