import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';

class FeaturedPlaylistCard extends StatelessWidget {
  final FeaturedPlaylist featuredPlaylist;
  final VoidCallback? onTap;

  const FeaturedPlaylistCard({
    super.key,
    required this.featuredPlaylist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final playlist = featuredPlaylist.playlist;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de la playlist
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000), // Colors.black.withValues(alpha: 0.2) como const
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: OptimizedImage(
                  imageUrl: playlist.coverArtUrl,
                  fit: BoxFit.cover,
                  width: 160,
                  height: 160,
                  borderRadius: 12,
                  placeholderColor: const Color(0xFF667eea).withValues(alpha: 0.3),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Nombre de la playlist
            Text(
              (playlist.name?.isNotEmpty == true) ? playlist.name! : 'Playlist',
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
            
            // Información adicional
            Row(
              children: [
                if (playlist.user != null) ...[
                  Expanded(
                    child: Text(
                      playlist.user?.firstName ?? 'Usuario',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (playlist.totalTracks != null && playlist.totalTracks! > 0) ...[
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.queue_music,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${playlist.totalTracks}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            
            // Badge destacada
            if (featuredPlaylist.featuredReason != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0x33FF9800), // Colors.orange.withValues(alpha: 0.2) como const
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      featuredPlaylist.featuredReason!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

