import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/models/playlist_model.dart';

class PlaylistSearchCard extends StatelessWidget {
  final Playlist playlist;

  const PlaylistSearchCard({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = playlist.coverArtUrl != null && playlist.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(playlist.coverArtUrl)
        : null;

    return RepaintBoundary(
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeumorphismTheme.surface.withValues(alpha: 0.8),
            NeumorphismTheme.beigeMedium.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            context.push('/playlist/${playlist.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Portada
                Container(
                    width: 64,
                    height: 64,
                    constraints: const BoxConstraints(
                      minWidth: 64,
                      maxWidth: 64,
                      minHeight: 64,
                      maxHeight: 64,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: coverUrl != null
                          ? Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              width: 64,
                              height: 64,
                              cacheWidth: 64, // OPTIMIZACIÓN: límite de memoria
                              cacheHeight: 64, // OPTIMIZACIÓN: límite de memoria
                              alignment: Alignment.center,
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) return child;
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 200),
                                  child: child,
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return Container(
                                  decoration: const BoxDecoration(
                                    gradient: NeumorphismTheme.imagePlaceholderGradient,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: const BoxDecoration(
                                    gradient: NeumorphismTheme.imagePlaceholderGradient,
                                  ),
                                  child: const Icon(
                                    Icons.playlist_play,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                );
                              },
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: NeumorphismTheme.imagePlaceholderGradient,
                              ),
                              child: const Icon(
                                Icons.playlist_play,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                const SizedBox(width: 16),
                // Información de la playlist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        playlist.name ?? 'Playlist sin nombre',
                        style: AppTextStyles.songTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.music_note,
                            size: 14,
                            color: NeumorphismTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              playlist.description ?? '${playlist.totalTracks ?? 0} canciones',
                              style: AppTextStyles.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Icono de flecha
                Icon(
                  Icons.chevron_right_rounded,
                  color: NeumorphismTheme.textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

