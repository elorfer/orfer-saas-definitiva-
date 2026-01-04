import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/offline_manager_provider.dart';
import '../../../core/providers/playback_notifier.dart'; // ✅ Importar PlaybackNotifier
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/logger.dart'; // ✅ Importar AppLogger

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineState = ref.watch(offlineManagerProvider);
    final songs = offlineState.downloadedSongs.values.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
            'Mis Descargas',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => context.pop(),
        ),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              tooltip: 'Eliminar todo',
              onPressed: () async {
                 final confirm = await showDialog<bool>(
                   context: context,
                   builder: (context) => AlertDialog(
                     backgroundColor: Colors.white,
                     title: const Text('¿Eliminar todo?'),
                     content: const Text('Se borrarán todas las canciones descargadas.'),
                     actions: [
                       TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                       TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                     ],
                   ),
                 );
                 if (confirm == true) {
                   ref.read(offlineManagerProvider.notifier).removeAllDownloads();
                 }
              },
            ),
        ],
      ),
      body: songs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay descargas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Descarga música para escuchar sin conexión',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
            : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100), // ✅ Padding bottom para MiniPlayer
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: NeumorphismTheme.softShadow,
                        ),
                        child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: OptimizedImage(
                                    imageUrl: song.coverArtUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                ),
                            ),
                            title: Text(
                                song.title ?? 'Sin título',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                                song.artist?.displayName ?? 'Desconocido',
                                maxLines: 1,
                                style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ▶️ Botón Play Directo (Junto al item)
                                IconButton(
                                  icon: Icon(Icons.play_circle_fill, color: NeumorphismTheme.accent, size: 32),
                                  tooltip: 'Reproducir ahora',
                                  onPressed: () async {
                                    try {
                                      await ref.read(playbackNotifierProvider.notifier).playOfflineQueue(
                                        songs,
                                        initialIndex: index,
                                        autoPlay: true, // ✅ Reproducir inmediatamente
                                      );
                                      if (context.mounted) {
                                        context.push('/downloads/song/${song.id}', extra: song);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  },
                                ),
                                // 🗑️ Botón Eliminar
                                IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                    tooltip: 'Eliminar descarga',
                                    onPressed: () {
                                    ref.read(offlineManagerProvider.notifier).removeDownload(song.id);
                                },
                                ),
                              ],
                            ),
                            onTap: () async {
                              // Tocar el item abre la info (Preview) sin reproducir automáticamente
                              try {
                                await ref.read(playbackNotifierProvider.notifier).playOfflineQueue(
                                  songs,
                                  initialIndex: index,
                                  autoPlay: false, // ✅ NO reproducir automáticamente (Preview Mode)
                                );
                                if (context.mounted) {
                                  context.push('/downloads/song/${song.id}', extra: song);
                                }
                              } catch (e) {
                                AppLogger.error('Error opening song detail: $e');
                              }
                            },
                        ),
                    ),
                );
              },
            ),
    );
  }
}
