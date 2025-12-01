import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/image_placeholder.dart';
import '../../../core/theme/neumorphism_theme.dart';

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
            // Imagen del artista (redonda)
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle, // ✅ Forma circular completa
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval( // ✅ ClipOval para recortar en círculo
                child: _buildImageOrPlaceholder(),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Información del artista mejorada
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del artista
                  Text(
                    artist.stageName ?? 'Artista Desconocido',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NeumorphismTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Seguidores con icono
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 12,
                        color: NeumorphismTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${NumberFormatter.format(artist.totalFollowers)} seguidores',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: NeumorphismTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Badge destacado mejorado (si existe)
                  if (featuredArtist.featuredReason != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            NeumorphismTheme.coffeeMedium,
                            NeumorphismTheme.coffeeDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              featuredArtist.featuredReason!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Badge "Destacado" por defecto si no hay razón específica
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            NeumorphismTheme.coffeeMedium,
                            NeumorphismTheme.coffeeDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Destacado',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
          // Log del error solo en modo debug (no en producción)
          if (kDebugMode) {
            debugPrint('[FeaturedArtistCard] Error cargando imagen para artista ${featuredArtist.artist.id}: $error');
          }
          return const ImagePlaceholder.artistRound(); // ✅ Placeholder redondo
        },
        placeholder: (context, url) {
          return const ImagePlaceholder.shimmer();
        },
        // Key estable para evitar reconstrucciones innecesarias
        key: ValueKey('artist_image_${featuredArtist.artist.id}_$normalizedUrl'),
      );
    }
    
    // Si no hay URL, usar placeholder (sin log - es normal que algunos artistas no tengan imagen)
    return const ImagePlaceholder.artistRound(); // ✅ Placeholder redondo
  }

}
