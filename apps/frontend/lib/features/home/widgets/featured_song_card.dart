import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/song_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/services/audio_cache_service.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';

/// 🚀 TARJETA OPTIMIZADA DE CANCIÓN DESTACADA
/// Implementa optimizaciones de rendimiento:
/// - Const constructors donde sea posible
/// - Widgets inmutables para mejor caché
/// - Lazy loading de imágenes
class FeaturedSongCard extends ConsumerStatefulWidget {
  final FeaturedSong featuredSong;
  final VoidCallback? onTap;
  final bool precacheAudio;

  const FeaturedSongCard({
    super.key,
    required this.featuredSong,
    this.onTap,
    this.precacheAudio = false,
  });

  @override
  ConsumerState<FeaturedSongCard> createState() => _FeaturedSongCardState();
}

class _FeaturedSongCardState extends ConsumerState<FeaturedSongCard> {
  static const TextStyle _titleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle _metaStyle = TextStyle(
    fontSize: 12,
    color: Color(0xCC8B7A6A),
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  @override
  void initState() {
    super.initState();
    _handlePrecache();
  }

  void _handlePrecache() {
    final song = widget.featuredSong.song;
    if (widget.precacheAudio && song.fileUrl != null && song.fileUrl!.isNotEmpty) {
      final normalizedUrl = UrlNormalizer.normalizeUrl(song.fileUrl!);
      AudioCacheManager.precacheAudio(normalizedUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle artistStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: NeumorphismTheme.textSecondary) ??
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF756860));
    final song = widget.featuredSong.song;

    // Granularidad: solo repintar el botón de play si cambia el estado de reproducción de esta canción
    final isPlaying = ref.watch(
      unifiedAudioProviderFixed.select(
        (s) => s.currentSong?.id == song.id && s.isPlaying,
      ),
    );
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(
            color: NeumorphismTheme.accent.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!();
              }
            },
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: OptimizedImage(
                        imageUrl: song.coverArtUrl,
                        fit: BoxFit.cover,
                        width: 56,
                        height: 56,
                        borderRadius: 12,
                        placeholderColor: NeumorphismTheme.accentLight,
                        maxCacheWidth: 140,
                        maxCacheHeight: 140,
                        skipFade: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title ?? 'Canción Sin Título',
                          style: _titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (song.artist != null)
                          ArtistNameWithBadge(
                            artistName: _getArtistName(song),
                            isVerified: song.artist!.isVerifiedValue,
                            textStyle: artistStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            badgeSize: 12.0,
                          )
                        else
                          Text(
                            _getArtistName(song),
                            style: artistStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 16,
                                  color: NeumorphismTheme.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${NumberFormatter.format(song.totalStreams)} • ${song.durationFormatted}',
                                  style: _metaStyle,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botón de play granular
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isPlaying
                        ? Icon(Icons.pause_rounded, color: NeumorphismTheme.accent, size: 32)
                        : Icon(Icons.play_arrow_rounded, color: NeumorphismTheme.accent, size: 32),
                  ),
                ],
              ),
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
