import 'package:flutter/material.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/theme/neumorphism_theme.dart';

class FeaturedPlaylistCard extends StatelessWidget {
  final FeaturedPlaylist featuredPlaylist;
  final VoidCallback? onTap;

  // Estilos cacheados
  // Estilos constantes para evitar resolución dinámica de GoogleFonts en cada frame
  static TextStyle get _userStyle => TextStyle(
    fontSize: 13,
    height: 1.2,
    color: NeumorphismTheme.textSecondary,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
  );
  static TextStyle get _tracksStyle => TextStyle(
    fontSize: 12,
    color: NeumorphismTheme.textSecondary,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.none,
  );
  static TextStyle get _badgeStyle => TextStyle(
    fontSize: 11,
    height: 1.0,
    color: NeumorphismTheme.accent,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  const FeaturedPlaylistCard({
    super.key,
    required this.featuredPlaylist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final playlist = featuredPlaylist.playlist;
    
    return GestureDetector(
      behavior: HitTestBehavior.translucent, // 🚀 GESTURE ARENA PRO: Evita delays en el scroll
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // ✅ Usar solo el espacio necesario
          children: [
            // Imagen de la playlist
            SizedBox(
              width: 160,
              height: 160,
              // 🚀 OPTIMIZATION: Removed redundant ClipRRect.
              // OptimizedImage handles borderRadius.
              child: OptimizedImage(
                imageUrl: playlist.coverArtUrl,
                fit: BoxFit.cover,
                width: 160,
                height: 160,
                borderRadius: 16,
                placeholderColor: NeumorphismTheme.accentLight,
                maxCacheWidth: 400, 
                maxCacheHeight: 400,
                skipFade: true, 
              ),
            ),
            const SizedBox(height: 4),
            
            // Información adicional
            SizedBox(
              width: 160, // ✅ Ancho fijo para evitar overflow
              height: 16, // ✅ Altura fija para controlar overflow
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // ✅ Centrar verticalmente
                children: [
                  if (playlist.user != null) ...[
                    Expanded(
                      child: Text(
                        playlist.user?.firstName ?? 'Usuario',
                        style: _userStyle,
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
                          style: _tracksStyle,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Badge destacada
            if (featuredPlaylist.featuredReason != null) ...[
              const SizedBox(height: 6), // ✅ Reducido de 8 a 6 para evitar overflow
              Container(
                width: 160, // ✅ Ancho fijo para evitar overflow
                constraints: const BoxConstraints(maxHeight: 22), // ✅ Limitar altura máxima
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), // ✅ Reducido aún más
                decoration: BoxDecoration(
                  color: NeumorphismTheme.accent.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(
                    color: NeumorphismTheme.accent.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  // ✅ CORRECCIÓN: No usar mainAxisSize.min cuando hay Expanded
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 13, // ✅ Reducido de 14 a 13 para evitar overflow
                      color: NeumorphismTheme.accent,
                    ),
                    const SizedBox(width: 4),
                    Expanded( // ✅ Expanded para evitar overflow del texto
                      child: Text(
                        featuredPlaylist.featuredReason!,
                        style: _badgeStyle,
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

