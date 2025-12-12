import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/image_placeholder.dart';
import '../../../core/widgets/verified_badge.dart';
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
        width: 112,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del artista (redonda)
            Container(
              width: 112,
              height: 112,
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
            
            const SizedBox(height: 10),
            
            // Información del artista mejorada
            // ✅ CORRECCIÓN: Eliminado Expanded - no es necesario aquí ya que el Column se ajusta naturalmente
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre del artista con badge de verificación
                ArtistNameWithBadge(
                  artistName: artist.stageName ?? 'Artista Desconocido',
                  isVerified: artist.isVerifiedValue,
                  textStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NeumorphismTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  badgeSize: 12.0,
                ),
                
                const SizedBox(height: 4),
                
                // Seguidores con icono
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 11,
                      color: NeumorphismTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${NumberFormatter.format(artist.totalFollowers)} seguidores',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
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
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NeumorphismTheme.coffeeMedium,
                          NeumorphismTheme.coffeeDark,
                        ],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      boxShadow: [
                        BoxShadow(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      // ✅ CORRECCIÓN: No usar mainAxisSize.min cuando hay Flexible
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            featuredArtist.featuredReason!,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
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
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NeumorphismTheme.coffeeMedium,
                          NeumorphismTheme.coffeeDark,
                        ],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Destacado',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
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
        memCacheWidth: 240, // 🔥 OPTIMIZACIÓN: Tamaño optimizado (240px para imagen de 120px)
        memCacheHeight: 240,
        maxWidthDiskCache: 600,
        maxHeightDiskCache: 600,
        fadeInDuration: Duration.zero, // 🔥 Cero animaciones innecesarias
        fadeOutDuration: Duration.zero,
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
