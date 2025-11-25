import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/song_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/number_formatter.dart';

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
        color: const Color(0xFFE4D6C8).withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(
          color: const Color(0xFFC8B4A4).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C8C78).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Asegurar que el callback se ejecute
            if (onTap != null) {
              debugPrint('[FeaturedSongCard] Tap en canción: ${song.title}');
              onTap!();
            } else {
              debugPrint('[FeaturedSongCard] onTap es null');
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
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: OptimizedImage(
                      imageUrl: song.coverArtUrl,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      borderRadius: 8,
                      placeholderColor: const Color(0xFFB8A894).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Información de la canción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title ?? 'Canción Sin Título',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3D2E20),
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        _getArtistName(song),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF5C4A3A),
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        children: [
                          Icon(
                            Icons.play_arrow,
                            size: 14,
                            color: const Color(0xFF8B7A6A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${NumberFormatter.format(song.totalStreams)} • ${song.durationFormatted}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF8B7A6A),
                              decoration: TextDecoration.none,
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
    // Intentar obtener el nombre del artista de múltiples formas
    // Sin logs para evitar trabajo pesado en el main thread
    if (song.artist != null) {
      // Primero intentar stageName (nombre artístico)
      final stageName = song.artist!.stageName;
      if (stageName != null && stageName.isNotEmpty && stageName.trim().isNotEmpty) {
        return stageName;
      }
      
      // Si no hay stageName, usar displayName (que tiene fallback interno)
      final displayName = song.artist!.displayName;
      if (displayName.isNotEmpty && displayName != 'Artista Desconocido' && displayName.trim().isNotEmpty) {
        return displayName;
      }
    }
    
    // Fallback final si no hay artista o no tiene nombre
    return 'Artista desconocido';
  }
}
