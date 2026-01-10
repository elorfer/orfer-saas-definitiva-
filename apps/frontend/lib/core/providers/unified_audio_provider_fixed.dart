import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../services/audio_service.dart';
import 'playback_notifier.dart';

/// Provider unificado del reproductor de audio
/// Usa el nuevo sistema de AudioService único
final unifiedAudioProviderFixed = playbackNotifierProvider;

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎯 SOLUCIÓN PROFESIONAL: Provider que garantiza consistencia entre estado y stream
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// PROBLEMA ORIGINAL:
/// - Durante transiciones Ad→Song, el estado y el stream pueden estar desincronizados
/// - El estado puede tener la canción anterior mientras el stream tiene la nueva
/// - Esto causaba parpadeo del cover incorrecto
///
/// SOLUCIÓN:
/// - Verificar que el stream y el estado coincidan (mismo songId)
/// - Si no coinciden, mantener la última canción confirmada hasta estabilizar
/// - Usar cache inteligente con detección de transiciones
/// ═══════════════════════════════════════════════════════════════════════════

Song? _lastConfirmedSong; // Cache de la última canción que fue confirmada

final realCurrentSongProvider = Provider<Song?>((ref) {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 1. PROTECCIÓN BÁSICA: Si hay inserción en curso, mantener última conocida
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  final isInserting = ref.watch(unifiedAudioProviderFixed.select((s) => s.isInsertingAd));
  if (isInserting && _lastConfirmedSong != null) {
    return _lastConfirmedSong;
  }
  
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 2. OBTENER DATOS DE AMBAS FUENTES
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Canción del estado (Riverpod)
  final stateSong = ref.watch(unifiedAudioProviderFixed.select((s) => s.lastConfirmedSong ?? s.currentSong));
  
  // Verificar si hay anuncio activo (el MiniPlayer no debe mostrarse durante anuncios)
  final isPlayingAd = ref.watch(unifiedAudioProviderFixed.select((s) => s.isPlayingAd));
  final currentAd = ref.watch(unifiedAudioProviderFixed.select((s) => s.currentAd));
  
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 3. PROTECCIÓN DURANTE ANUNCIO: Mantener última canción (no es transitoria)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  if (isPlayingAd || currentAd != null) {
    // Durante anuncio, el MiniPlayer se oculta de todos modos
    // Pero retornamos la última canción confirmada para cuando el anuncio termine
    return _lastConfirmedSong ?? stateSong;
  }
  
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 4. VERIFICACIÓN DE STREAM (PROFESIONAL)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  final audioService = ref.watch(audioServiceProvider);
  final sequenceState = audioService.player.sequenceState;
  
  Song? streamSong;
  if (sequenceState != null && sequenceState.currentSource != null) {
    final tag = sequenceState.currentSource!.tag;
    if (tag is Song) {
      streamSong = tag;
    }
  }
  
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 5. LÓGICA DE RECONCILIACIÓN 🎯
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Si ambas fuentes coinciden (mismo ID), usar esa canción
  if (streamSong != null && stateSong != null && streamSong.id == stateSong.id) {
    // ✅ MATCH: Estado y stream coinciden - canción confirmada
    _lastConfirmedSong = stateSong;
    return stateSong;
  }
  
  // Si solo el stream tiene canción (estado aún no actualizado)
  if (streamSong != null && (stateSong == null || streamSong.id != stateSong.id)) {
    // Stream adelantado: usar stream pero verificar si es transición válida
    // (no queremos mostrar canciones random del stream)
    if (_lastConfirmedSong != null) {
      // Verificar si es la canción "siguiente" lógica o si es aleatorio
      // Por seguridad, mantener la última confirmada hasta que el estado se actualice
      return _lastConfirmedSong;
    }
    // Si no hay cache, usar el stream
    return streamSong;
  }
  
  // Si solo el estado tiene canción
  if (stateSong != null && streamSong == null) {
    _lastConfirmedSong = stateSong;
    return stateSong;
  }
  
  // Si ninguno tiene canción, retornar cache o null
  return _lastConfirmedSong;
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
