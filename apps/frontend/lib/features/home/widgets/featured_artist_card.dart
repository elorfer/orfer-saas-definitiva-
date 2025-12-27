import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/widgets/verified_badge.dart'; // Import VerifiedBadge
import '../../../core/theme/neumorphism_theme.dart';
// import '../../../core/utils/url_normalizer.dart'; // No longer needed directly
// import '../../../core/services/http_cache_service.dart'; // No longer needed directly

/// ⚡ GAMA BAJA: Card ultra-liviana para compositores destacados
class FeaturedArtistCard extends StatelessWidget {
  final FeaturedArtist featuredArtist;
  final VoidCallback? onTap;

  // ⚡ GAMA BAJA: TextStyle const y cacheado
  static const TextStyle _nameStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: NeumorphismTheme.textPrimary,
  );

  const FeaturedArtistCard({
    super.key,
    required this.featuredArtist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 OPTIMIZACIÓN: Layout "Flat Design" ultra-liviano
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Eliminamos decoración para "Single Panel Design" (Transparent Child)
        padding: const EdgeInsets.symmetric(vertical: 4), 
        // decoration: removed for transparency
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚡ Imagen del artista optimizada
            OptimizedImage(
              imageUrl: featuredArtist.artist.profilePhotoUrl ?? featuredArtist.imageUrl,
              fit: BoxFit.cover,
              width: 90,
              height: 90,
              maxCacheWidth: 200,
              maxCacheHeight: 200,
              borderRadius: 45, // Circular
              placeholderColor: const Color(0xFFF3EBE3),
              lazyLoad: true,
            ),
            
            const SizedBox(height: 10),
            
            // ⚡ Nombre del artista con verificado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ArtistNameWithBadge(
                artistName: featuredArtist.artist.stageName ?? 'Artista',
                isVerified: featuredArtist.artist.isVerifiedValue,
                textStyle: _nameStyle,
                badgeSize: 14.0,
                badgeColor: NeumorphismTheme.coffeeMedium,
                alignment: MainAxisAlignment.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
