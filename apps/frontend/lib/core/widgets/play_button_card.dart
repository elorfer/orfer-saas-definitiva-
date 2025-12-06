import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song_model.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/url_normalizer.dart';

/// ⚡ Botón de play optimizado para tarjetas de canción
/// Actualiza solo el ícono con AnimatedSwitcher (sin reconstruir toda la tarjeta)
/// Latencia mínima: <60ms
class PlayButtonCard extends ConsumerWidget {
  final Song song;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  const PlayButtonCard({
    super.key,
    required this.song,
    this.size = 40,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(unifiedAudioProviderFixed);
    final isCurrentSong = audioState.currentSong?.id == song.id;
    final isPlaying = isCurrentSong && audioState.isPlaying;

    return GestureDetector(
      onTap: () async {
        // 🖼️ PRECARGAR PORTADA ANTES DE REPRODUCIR
        // Esto asegura que la portada esté lista cuando comience el audio
        if (song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty) {
          try {
            final normalizedUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl!);
            if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
              // Precargar imagen con timeout para no bloquear demasiado
              await precacheImage(
                CachedNetworkImageProvider(
                  normalizedUrl,
                  cacheKey: normalizedUrl,
                  headers: const {
                    'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
                    'Cache-Control': 'max-age=86400',
                  },
                ),
                context,
              ).timeout(
                const Duration(milliseconds: 500), // Timeout de 500ms para no bloquear
                onTimeout: () {
                  debugPrint('⏱️ [PlayButtonCard] Timeout precargando portada, continuando...');
                },
              );
            }
          } catch (e) {
            debugPrint('⚠️ [PlayButtonCard] Error precargando portada: $e');
            // Continuar con la reproducción aunque falle la precarga
          }
        }
        
        // ⚡ Reproducción después de precargar portada
        final notifier = ref.read(unifiedAudioProviderFixed.notifier);
        notifier.playFromCard(song);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? NeumorphismTheme.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (backgroundColor ?? NeumorphismTheme.accent)
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          },
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            color: iconColor ?? Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}


