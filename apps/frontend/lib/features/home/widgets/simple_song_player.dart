import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/song_model.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/utils/logger.dart';

/// Widget SÚPER SIMPLE para probar recomendaciones por género
class SimpleSongPlayer extends ConsumerWidget {
  final Song song;

  const SimpleSongPlayer({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(realCurrentSongProvider);
    final isPlaying = ref.watch(isPlayingProviderFixed);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              song.title ?? 'Título desconocido',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              song.artist?.stageName ?? 'Artista desconocido',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Géneros: ${song.genres?.join(', ') ?? 'Sin géneros'}',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    AppLogger.info('[SimpleSongPlayer] 🎵 Reproduciendo: ${song.title}');
                    await ref.read(unifiedAudioProviderFixed.notifier).playSpecificSong(song);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Reproducir'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
                  },
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(isPlaying ? 'Pausar' : 'Reanudar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentSong != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reproduciendo ahora:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${currentSong.title} - ${currentSong.artist?.stageName}'),
                    Text('Géneros: ${currentSong.genres?.join(', ') ?? 'Sin géneros'}'),
                  ],
                ),
              )
            else
              const Text('No hay canción reproduciéndose'),
          ],
        ),
      ),
    );
  }
}
