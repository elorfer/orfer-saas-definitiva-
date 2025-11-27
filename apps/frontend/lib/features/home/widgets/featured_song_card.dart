import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/song_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// 🚀 TARJETA OPTIMIZADA DE CANCIÓN DESTACADA
/// Implementa optimizaciones de rendimiento:
/// - Const constructors donde sea posible
/// - Widgets inmutables para mejor caché
/// - Lazy loading de imágenes
class FeaturedSongCard extends StatelessWidget {
  final FeaturedSong featuredSong;
  final VoidCallback? onTap;

  const FeaturedSongCard({
    super.key,
    required this.featuredSong,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final song = featuredSong.song;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(
          color: NeumorphismTheme.accent.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: NeumorphismTheme.accent.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap!();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Portada de la canción
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                    child: OptimizedImage(
                      imageUrl: song.coverArtUrl,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      borderRadius: 12,
                      placeholderColor: NeumorphismTheme.accentLight,
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Información de la canción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title ?? 'Canción Sin Título',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: NeumorphismTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        _getArtistName(song),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: NeumorphismTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: NeumorphismTheme.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${NumberFormatter.format(song.totalStreams)} • ${song.durationFormatted}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: NeumorphismTheme.textSecondary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  String _getArtistName(Song song) {
    if (song.artist != null) {
      final stageName = song.artist!.stageName;
      if (stageName != null && stageName.isNotEmpty && stageName.trim().isNotEmpty) {
        return stageName;
      }
      
      final displayName = song.artist!.displayName;
      if (displayName.isNotEmpty && displayName != 'Artista Desconocido' && displayName.trim().isNotEmpty) {
        return displayName;
      }
    }
    
    return 'Artista desconocido';
  }
}
