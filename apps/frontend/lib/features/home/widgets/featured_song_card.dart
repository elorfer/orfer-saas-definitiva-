import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/song_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/number_formatter.dart';

class FeaturedSongCard extends StatelessWidget {
  final FeaturedSong featuredSong;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const FeaturedSongCard({
    super.key,
    required this.featuredSong,
    this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final song = featuredSong.song;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
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
                    color: Color(0x1A000000), // Colors.black.withValues(alpha: 0.1) como const
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
                  placeholderColor: const Color(0xFF667eea).withValues(alpha: 0.3),
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
                      color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.7),
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
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${NumberFormatter.format(song.totalStreams)} • ${song.durationFormatted}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Botón de play
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
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
