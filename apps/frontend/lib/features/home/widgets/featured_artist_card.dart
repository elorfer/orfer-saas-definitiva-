import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/services/http_cache_service.dart';

/// ⚡ GAMA BAJA: Card ultra-liviana para compositores destacados
class FeaturedArtistCard extends StatelessWidget {
  final FeaturedArtist featuredArtist;
  final VoidCallback? onTap;

  // ⚡ GAMA BAJA: TextStyle const
  static const TextStyle _nameStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
  );

  const FeaturedArtistCard({
    super.key,
    required this.featuredArtist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final artist = featuredArtist.artist;
    
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚡ Imagen del artista
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: SizedBox(
                width: 100,
                height: 100,
                child: _buildImage(),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // ⚡ Nombre del artista con verificado
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    artist.stageName ?? 'Artista',
                    style: _nameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (artist.isVerifiedValue) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified,
                    size: 14,
                    color: NeumorphismTheme.coffeeMedium,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final rawUrl = featuredArtist.imageUrl 
        ?? featuredArtist.artist.profilePhotoUrl 
        ?? featuredArtist.artist.coverPhotoUrl;
    
    final normalizedUrl = UrlNormalizer.normalizeImageUrl(rawUrl);
    
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: normalizedUrl,
        cacheManager: AlbumArtCacheManager.instance,
        fit: BoxFit.cover,
        // memCacheWidth: 200, // Desactivado por conflicto con AlbumArtCacheManager (prioridad 90 días)
        // memCacheHeight: 200,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        errorWidget: (_, __, ___) => _buildPlaceholder(),
        placeholder: (_, __) => _buildPlaceholder(),
      );
    }
    
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFE4D6C8), // Color sólido similar al café claro con opacidad
      child: const Icon(
        Icons.person,
        color: Colors.white70,
        size: 32,
      ),
    );
  }
}
