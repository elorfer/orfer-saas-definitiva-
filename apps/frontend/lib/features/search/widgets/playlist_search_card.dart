import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // ⚡ GAMA BAJA: Reducido
      decoration: BoxDecoration(
        // ⚡ GAMA BAJA: Color sólido en lugar de gradiente + sombras
        color: NeumorphismTheme.surface.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(16)), // ⚡ Reducido de 20
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)), // ⚡ Reducido
          onTap: () {
            context.push('/playlist/${playlist.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ⚡ Reducido
            child: Row(
              children: [
                // Portada
                Container(
                    width: 56, // ⚡ GAMA BAJA: Reducido de 64
                    height: 56,
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      maxWidth: 56,
                      minHeight: 56,
                      maxHeight: 56,
                    ),
                    // ⚡ GAMA BAJA: Sin boxShadow
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)), // ⚡ Reducido
                      clipBehavior: Clip.antiAlias,
                      child: coverUrl != null
                          ? OptimizedImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                              maxCacheWidth: 112, // ⚡ Reducido
                              maxCacheHeight: 112,
                              lazyLoad: true,
                              visibilityThreshold: 0.1,
                              skipFade: true,
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: NeumorphismTheme.imagePlaceholderGradient,
                              ),
                              child: const Icon(
                                Icons.playlist_play,
                                color: Colors.white,
                                size: 24,
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

