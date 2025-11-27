import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/theme/neumorphism_theme.dart';

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
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: OptimizedImage(
                  imageUrl: playlist.coverArtUrl,
                  fit: BoxFit.cover,
                  width: 160,
                  height: 160,
                  borderRadius: 16,
                  placeholderColor: NeumorphismTheme.accentLight,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Nombre de la playlist
            Text(
              (playlist.name?.isNotEmpty == true) ? playlist.name! : 'Playlist',
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
            
            // Información adicional
            SizedBox(
              width: 160, // ✅ Ancho fijo para evitar overflow
              child: Row(
                children: [
                  if (playlist.user != null) ...[
                    Expanded(
                      child: Text(
                        playlist.user?.firstName ?? 'Usuario',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: NeumorphismTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (playlist.totalTracks != null && playlist.totalTracks! > 0) ...[
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min, // ✅ Tamaño mínimo
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 14,
                          color: NeumorphismTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${playlist.totalTracks}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: NeumorphismTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Badge destacada
            if (featuredPlaylist.featuredReason != null) ...[
              const SizedBox(height: 8),
              Container(
                width: 160, // ✅ Ancho fijo para evitar overflow
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NeumorphismTheme.accent.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(
                    color: NeumorphismTheme.accent.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: NeumorphismTheme.accent,
                    ),
                    const SizedBox(width: 4),
                    Expanded( // ✅ Expanded para evitar overflow del texto
                      child: Text(
                        featuredPlaylist.featuredReason!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: NeumorphismTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1, // ✅ Máximo 1 línea
                        overflow: TextOverflow.ellipsis, // ✅ Ellipsis si es muy largo
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

