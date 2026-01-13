import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/offline_manager_provider.dart';
import '../../../core/providers/playback_notifier.dart'; // ✅ Importar PlaybackNotifier
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/logger.dart'; // ✅ Importar AppLogger

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  // 🔒 Lock de navegación para prevenir doble-taps y crashes por navegación duplicada
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
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
              icon: Icon(Icons.delete_sweep_rounded, color: _isNavigating ? Colors.grey : Colors.red),
              tooltip: 'Eliminar todo',
              onPressed: _isNavigating 
                ? null 
                : () async {
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
                                  // ▶️ Botón Play/Pause (Dinámico)
                                  IconButton(
                                    // Feedback visual: Si es la canción actual y está sonando, mostrar Pausa
                                    icon: Icon(
                                      (ref.watch(playbackNotifierProvider).isPlaying && ref.watch(playbackNotifierProvider).currentSong?.id == song.id)
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                      color: NeumorphismTheme.accent,
                                      size: 32,
                                    ),
                                    tooltip: (ref.watch(playbackNotifierProvider).isPlaying && ref.watch(playbackNotifierProvider).currentSong?.id == song.id)
                                        ? 'Pausar'
                                        : 'Reproducir ahora',
                                    // 🛡️ Prevenir doble tap
                                    onPressed: () async {
                                      if (_isNavigating) return;
                                      
                                      final notifier = ref.read(playbackNotifierProvider.notifier);
                                      final isPlayingCurrent = ref.read(playbackNotifierProvider).isPlaying && 
                                                              ref.read(playbackNotifierProvider).currentSong?.id == song.id;

                                      if (isPlayingCurrent) {
                                        notifier.play();
                                      } else {
                                        await notifier.playOfflineQueue(
                                          songs,
                                          initialIndex: index,
                                          autoPlay: true, 
                                        );
                                      }
                                    },
                                  ),
                                // 🗑️ Botón Eliminar
                                IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                    tooltip: 'Eliminar descarga',
                                    onPressed: () {
                                      if (_isNavigating) return;
                                      ref.read(offlineManagerProvider.notifier).removeDownload(song.id);
                                    },
                                ),
                              ],
                            ),
                            onTap: () async {
                              if (_isNavigating) return;
                              // Tocar el item abre la info (Preview) sin reproducir automáticamente
                              setState(() => _isNavigating = true);
                              try {
                                await ref.read(playbackNotifierProvider.notifier).playOfflineQueue(
                                  songs,
                                  initialIndex: index,
                                  autoPlay: false, // ✅ NO reproducir automáticamente (Preview Mode)
                                );
                                if (mounted) {
                                  // 🚀 Navegar SIN esperar
                                  context.push('/downloads/song/${song.id}', extra: song);
                                }
                              } catch (e) {
                                AppLogger.error('Error opening song detail: $e');
                                if (mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                   );
                                }
                              } finally {
                                if (mounted) {
                                  // 🔓 Liberar lock INMEDIATAMENTE para permitir interacción rápida
                                  // Ya no esperamos a que termine la animación de navegación
                                  setState(() => _isNavigating = false);
                                }
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
