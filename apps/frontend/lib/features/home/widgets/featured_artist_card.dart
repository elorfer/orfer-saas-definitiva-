import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/image_placeholder.dart';

class FeaturedArtistCard extends StatelessWidget {
  final FeaturedArtist featuredArtist;
  final VoidCallback? onTap;

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
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del artista
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000), // Colors.black.withValues(alpha: 0.1) como const
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageOrPlaceholder(),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Nombre del artista
            Text(
              artist.stageName ?? 'Artista Desconocido',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            // Seguidores
            Text(
              '${NumberFormatter.format(artist.totalFollowers)} seguidores',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Razón destacada (si existe)
            if (featuredArtist.featuredReason != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0x33FF9800), // Colors.orange.withValues(alpha: 0.2) como const
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(
                  featuredArtist.featuredReason!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageOrPlaceholder() {
    final rawUrl = featuredArtist.imageUrl 
        ?? featuredArtist.artist.profilePhotoUrl 
        ?? featuredArtist.artist.coverPhotoUrl;
    
    // Normalizar la URL para logging (NetworkImageWithFallback también normaliza, pero queremos ver la URL original)
    final normalizedUrl = UrlNormalizer.normalizeImageUrl(rawUrl, enableLogging: true);
    
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: normalizedUrl,
        fit: BoxFit.cover,
        memCacheWidth: 280, // 2x para pantallas de alta densidad
        memCacheHeight: 280,
        maxWidthDiskCache: 560, // Cache en disco más grande
        maxHeightDiskCache: 560,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        errorWidget: (context, url, error) {
          // Log del error para debugging
          debugPrint('[FeaturedArtistCard] Error cargando imagen: $url - Error: $error');
          debugPrint('[FeaturedArtistCard] URL original: $rawUrl');
          return const ImagePlaceholder.artist();
        },
        placeholder: (context, url) {
          return const ImagePlaceholder.shimmer();
        },
        // Key estable para evitar reconstrucciones innecesarias
        key: ValueKey('artist_image_${featuredArtist.artist.id}_$normalizedUrl'),
      );
    }
    
    // Si no hay URL, log para debugging
    debugPrint('[FeaturedArtistCard] No hay URL de imagen para artista ${featuredArtist.artist.id}');
    return const ImagePlaceholder.artist();
  }

}
