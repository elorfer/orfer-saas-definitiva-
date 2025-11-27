import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'unified_audio_provider_fixed.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';

/// Helper para migrar de los providers antiguos al nuevo provider unificado
/// Este archivo facilita la transición sin romper el código existente

// ✅ MIGRACIÓN: Reemplazar globalAudioProvider
final globalAudioProvider = unifiedAudioProviderFixed;

// ✅ MIGRACIÓN: Reemplazar unifiedAudioProvider
final unifiedAudioProvider = unifiedAudioProviderFixed;

// ✅ MIGRACIÓN: Providers de conveniencia actualizados
final currentSongProvider = Provider<Song?>((ref) {
  return ref.watch(unifiedAudioProviderFixed).currentSong;
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(unifiedAudioProviderFixed).isPlaying;
});

final audioProgressProvider = Provider<double>((ref) {
  return ref.watch(unifiedAudioProviderFixed).progress;
});

final audioPositionProvider = Provider<Duration>((ref) {
  return ref.watch(unifiedAudioProviderFixed).currentPosition;
});

final audioDurationProvider = Provider<Duration>((ref) {
  return ref.watch(unifiedAudioProviderFixed).totalDuration;
});

final currentPositionProvider = Provider<Duration>((ref) {
  return ref.watch(unifiedAudioProviderFixed).currentPosition;
});

final totalDurationProvider = Provider<Duration>((ref) {
  return ref.watch(unifiedAudioProviderFixed).totalDuration;
});

final isBufferingProvider = Provider<bool>((ref) {
  return ref.watch(unifiedAudioProviderFixed).isBuffering;
});

final audioVolumeProvider = Provider<double>((ref) {
  return ref.watch(unifiedAudioProviderFixed).volume;
});

/// Función helper para reproducir canciones desde cualquier parte de la app
Future<void> playGlobalSong(WidgetRef ref, Song song) async {
  try {
    await ref.read(unifiedAudioProviderFixed.notifier).playSong(song);
  } catch (e) {
    AppLogger.error('[AudioMigrationHelper] Error reproduciendo canción: $e');
    rethrow;
  }
}

/// Función helper para toggle play/pause desde cualquier parte de la app
Future<void> toggleGlobalPlayPause(WidgetRef ref) async {
  try {
    await ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
  } catch (e) {
    AppLogger.error('[AudioMigrationHelper] Error toggle play/pause: $e');
    rethrow;
  }
}

/// Función helper para seek desde cualquier parte de la app
Future<void> seekGlobalAudio(WidgetRef ref, Duration position) async {
  try {
    await ref.read(unifiedAudioProviderFixed.notifier).seek(position);
  } catch (e) {
    AppLogger.error('[AudioMigrationHelper] Error seek: $e');
    rethrow;
  }
}
