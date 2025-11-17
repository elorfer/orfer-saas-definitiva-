import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/utils/number_formatter.dart';

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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
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
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
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
    final url = featuredArtist.imageUrl 
        ?? featuredArtist.artist.profilePhotoUrl 
        ?? featuredArtist.artist.coverPhotoUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 280, // 2x para pantallas de alta densidad
        memCacheHeight: 280,
        maxWidthDiskCache: 560, // Cache en disco más grande
        maxHeightDiskCache: 560,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        errorWidget: (context, url, error) {
          // Si falla, intentar con el placeholder
          return _placeholder();
        },
        placeholder: (context, url) {
          return _loadingShimmer();
        },
        // Key estable para evitar reconstrucciones innecesarias
        key: ValueKey('artist_image_${featuredArtist.artist.id}_$url'),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2740B),
            Color(0xFFE35A01),
          ],
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _loadingShimmer() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
    );
  }

}
