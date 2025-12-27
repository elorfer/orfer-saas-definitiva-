import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/song_model.dart';
import '../../../../core/widgets/optimized_image.dart';
import '../../../../core/theme/neumorphism_theme.dart';
import '../providers/song_detail_provider.dart';

/// Widget que muestra una lista horizontal de canciones de un artista
/// ✅ OPTIMIZADO: Usa provider con select, OptimizedImage, y RepaintBoundary
class ArtistSongsHorizontalList extends ConsumerWidget {
  final String artistId;
  final String? currentSongId;
  final void Function(Song song)? onSongTap;

  const ArtistSongsHorizontalList({
    super.key,
    required this.artistId,
    this.currentSongId,
    this.onSongTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ OPTIMIZACIÓN: Usar provider para obtener canciones del artista
    final songsAsync = ref.watch(songsByArtistProvider(artistId));

    return songsAsync.when(
      data: (songs) {
        // ✅ Filtrar la canción actual para no mostrarla en la lista
        final filteredSongs = currentSongId != null
            ? songs.where((song) => song.id != currentSongId).toList()
            : songs;

        if (filteredSongs.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: filteredSongs.length,
          itemExtent: 152.0, // ✅ OPTIMIZACIÓN: itemExtent ajustado (140px card + 12px margin) para que la imagen sea cuadrada
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ), // ✅ Scroll estilo iPhone
          itemBuilder: (context, index) {
            final song = filteredSongs[index];
            return RepaintBoundary(
              child: _ArtistSongCard(
                song: song,
                onTap: () => onSongTap?.call(song),
              ),
            );
          },
        );
      },
      loading: () => SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          itemExtent: 152.0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) => const _SongCardSkeleton(),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

/// Tarjeta de canción horizontal optimizada
class _ArtistSongCard extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;

  const _ArtistSongCard({
    required this.song,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de la canción
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: OptimizedImage(
                  imageUrl: song.coverArtUrl,
                  fit: BoxFit.cover,
                  width: 140,
                  height: 140,
                  borderRadius: 12,
                  placeholderColor: NeumorphismTheme.accentLight,
                  maxCacheWidth: 280, // ✅ OPTIMIZACIÓN: Tamaño optimizado
                  maxCacheHeight: 280,
                  skipFade: true, // ✅ Sin fade para mejor rendimiento
                  lazyLoad: true, // ✅ Lazy loading
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Título de la canción
            Text(
              song.title ?? 'Sin título',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NeumorphismTheme.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 2),
            
            // Nombre del artista
            Text(
              song.artist?.displayName ?? 'Artista desconocido',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: NeumorphismTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader para tarjetas de canciones
class _SongCardSkeleton extends StatelessWidget {
  const _SongCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: NeumorphismTheme.surface.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: NeumorphismTheme.textPrimary.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: NeumorphismTheme.textSecondary.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }
}
