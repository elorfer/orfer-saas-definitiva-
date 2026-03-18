import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/offline_manager_provider.dart';
import '../../../core/providers/playback_notifier.dart'; // ✅ Importar PlaybackNotifier
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/logger.dart'; // ✅ Importar AppLogger

import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';

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
    // Verificar estado Premium
    final user = ref.watch(authStateProvider.select((state) => state.user));
    final isPremium = user != null &&
        (user.subscriptionStatus == SubscriptionStatus.premium ||
            user.subscriptionStatus == SubscriptionStatus.vip);

    final offlineState = ref.watch(offlineManagerProvider);
    final songs = offlineState.downloadedSongs.values.toList();

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      appBar: AppBar(
        title: Text(
          'Mis Descargas',
          style: TextStyle(
              color: NeumorphismTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: NeumorphismTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: NeumorphismTheme.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded,
                  color: _isNavigating ? Colors.grey : Colors.red),
              tooltip: 'Eliminar todo',
              onPressed: _isNavigating
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: NeumorphismTheme.background,
                          title: Text('¿Eliminar todo?',
                              style: TextStyle(
                                  color: NeumorphismTheme.textPrimary)),
                          content: Text(
                              'Se borrarán todas las canciones descargadas.',
                              style: TextStyle(
                                  color: NeumorphismTheme.textSecondary)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Cancelar',
                                    style: TextStyle(
                                        color:
                                            NeumorphismTheme.textSecondary))),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref
                            .read(offlineManagerProvider.notifier)
                            .removeAllDownloads();
                      }
                    },
            ),
        ],
      ),
      body: Column(
        children: [
          // 📢 Banner Premium (Solo si NO es premium)
          if (!isPremium) _buildPremiumBanner(),

          Expanded(
            child: songs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_done_rounded,
                            size: 64,
                            color: NeumorphismTheme.textSecondary
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No hay descargas',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: NeumorphismTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Descarga música para escuchar sin conexión',
                          style: TextStyle(
                              fontSize: 14,
                              color: NeumorphismTheme.textSecondary
                                  .withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 100), // ✅ Padding bottom para MiniPlayer
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: NeumorphismTheme.softShadow,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
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
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: NeumorphismTheme.textPrimary),
                            ),
                            subtitle: Text(
                              song.artist?.displayName ?? 'Desconocido',
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: NeumorphismTheme.textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ▶️ Botón Play/Pause (Dinámico)
                                IconButton(
                                  // Feedback visual: Si es la canción actual y está sonando, mostrar Pausa
                                  icon: Icon(
                                    (ref
                                                .watch(playbackNotifierProvider)
                                                .isPlaying &&
                                            ref
                                                    .watch(
                                                        playbackNotifierProvider)
                                                    .currentSong
                                                    ?.id ==
                                                song.id)
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    color: NeumorphismTheme.accent,
                                    size: 32,
                                  ),
                                  tooltip: (ref
                                              .watch(playbackNotifierProvider)
                                              .isPlaying &&
                                          ref
                                                  .watch(
                                                      playbackNotifierProvider)
                                                  .currentSong
                                                  ?.id ==
                                              song.id)
                                      ? 'Pausar'
                                      : 'Reproducir ahora',
                                  // 🛡️ Prevenir doble tap
                                  onPressed: () async {
                                    if (_isNavigating) return;

                                    final notifier = ref.read(
                                        playbackNotifierProvider.notifier);
                                    final isPlayingCurrent = ref
                                            .read(playbackNotifierProvider)
                                            .isPlaying &&
                                        ref
                                                .read(playbackNotifierProvider)
                                                .currentSong
                                                ?.id ==
                                            song.id;

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
                                  icon: Icon(Icons.delete_outline,
                                      color: NeumorphismTheme.textSecondary),
                                  tooltip: 'Eliminar descarga',
                                  onPressed: () {
                                    if (_isNavigating) return;
                                    ref
                                        .read(offlineManagerProvider.notifier)
                                        .removeDownload(song.id);
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              if (_isNavigating) return;
                              // Tocar el item abre la info (Preview) sin reproducir automáticamente
                              setState(() => _isNavigating = true);
                              try {
                                await ref
                                    .read(playbackNotifierProvider.notifier)
                                    .playOfflineQueue(
                                      songs,
                                      initialIndex: index,
                                      autoPlay:
                                          false, // ✅ NO reproducir automáticamente (Preview Mode)
                                    );
                                if (mounted) {
                                  // 🚀 Navegar SIN esperar
                                  context.push('/downloads/song/${song.id}',
                                      extra: song);
                                }
                              } catch (e) {
                                AppLogger.error(
                                    'Error opening song detail: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red),
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
          ),
        ],
      ),
    );
  }

  // Banner Premium
  Widget _buildPremiumBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeumorphismTheme.accentDark,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modo Offline Premium',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14),
                ),
                Text(
                  'Suscríbete para descargar música ilimitada.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/premium'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              'Ver Planes',
              style: TextStyle(
                  color: NeumorphismTheme.accentDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
