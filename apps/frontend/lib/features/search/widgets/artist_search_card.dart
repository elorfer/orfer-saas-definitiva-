import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../core/widgets/optimized_image.dart';

class ArtistSearchCard extends StatelessWidget {
  final Artist artist;

  const ArtistSearchCard({
    super.key,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final profileUrl = artist.profilePhotoUrl != null && artist.profilePhotoUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(artist.profilePhotoUrl)
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
            context.push('/artist/${artist.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ⚡ Reducido
            child: Row(
              children: [
                // Foto de perfil
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
                    child: ClipOval(
                      clipBehavior: Clip.antiAlias,
                      child: profileUrl != null
                          ? OptimizedImage(
                              imageUrl: profileUrl,
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
                                Icons.person,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                const SizedBox(width: 16),
                // Información del artista
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ArtistNameWithBadge(
                        artistName: artist.displayName,
                        isVerified: artist.isVerifiedValue,
                        textStyle: AppTextStyles.songTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        badgeSize: 16.0,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: NeumorphismTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${artist.totalFollowers} seguidores',
                            style: AppTextStyles.artistName,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Icono de flecha
                const Icon(
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

