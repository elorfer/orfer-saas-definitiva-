import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/play_button_card.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/models/song_model.dart';
import '../../../core/widgets/verified_badge.dart';

class SongSearchCard extends ConsumerWidget {
  final Song song;

  const SongSearchCard({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;

    // ⚡ OPTIMIZACIÓN: No precargar audio automáticamente (reduce carga inicial)

    // ⚡ OPTIMIZADO: Tarjeta más pequeña y ligera sin botón de favorito
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // Minimal margin
      // ⚡ Sin decoración (fondo transparente) para estilo lista limpia
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: () {
            SongDetailScreen.navigateToSong(context, song);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ⚡ Reducido de 16 a 12/10
            child: Row(
              children: [
                // ⚡ Portada más pequeña (sin sombras pesadas)
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)), // ⚡ Reducido de 16 a 12
                  child: coverUrl != null
                      ? OptimizedImage(
                          imageUrl: coverUrl,
                          width: 48, // ⚡ Reducido de 64 a 48
                          height: 48, // ⚡ Reducido de 64 a 48
                          fit: BoxFit.cover,
                          maxCacheWidth: 96, // 2x el tamaño de visualización
                          maxCacheHeight: 96,
                          lazyLoad: true, // ✅ Lazy loading con IntersectionObserver
                          visibilityThreshold: 0.1, // Cargar cuando 10% visible
                          skipFade: true, // Sin fade para mejor rendimiento
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: NeumorphismTheme.imagePlaceholderGradient,
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                ),
                const SizedBox(width: 12), // ⚡ Reducido de 16 a 12
                // ⚡ Información simplificada
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title ?? 'Canción Desconocida',
                        style: AppTextStyles.songTitle.copyWith(fontSize: 14), // ⚡ Reducido
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4), // ⚡ Reducido de 6 a 4
                      // Nombre del artista con badge de verificación
                      if (song.artist != null)
                        ArtistNameWithBadge(
                          artistName: song.artist!.stageName ?? 
                              (song.artist!.displayName.isNotEmpty ? song.artist!.displayName : 'Artista Desconocido'),
                          isVerified: song.artist!.isVerifiedValue,
                          textStyle: AppTextStyles.artistName.copyWith(fontSize: 12), // ⚡ Reducido
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          badgeSize: 10.0,
                        )
                      else
                        Text(
                          'Artista Desconocido',
                          style: AppTextStyles.artistName.copyWith(fontSize: 12), // ⚡ Reducido
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8), // ⚡ Reducido de 12 a 8
                // ⚡ Solo botón de play (sin favorito ni menú)
                PlayButtonCard(
                  song: song,
                  size: 32, // ⚡ Reducido de 36 a 32
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

