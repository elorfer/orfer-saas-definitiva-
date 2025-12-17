import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../services/player_navigation_service.dart';
import '../theme/neumorphism_theme.dart';
import 'mini_player_components.dart';

/// Mini reproductor final - Diseño neumórfico con funcionalidad perfecta
/// Usa directamente el provider unificado para máxima confiabilidad
class FinalMiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const FinalMiniPlayer({
    super.key,
    this.onTap,
    this.onNext,
    this.onPrevious,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ ÚNICA FUENTE DE VERDAD: Usar el provider que siempre devuelve la canción que realmente se está reproduciendo
    final currentSong = ref.watch(realCurrentSongProvider);
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    final isPlayingAd = playbackState.isPlayingAd;
    
    // ✅ FIX: Si hay un anuncio reproduciéndose, no mostrar el mini reproductor de canción
    // El AdsMiniPlayer se mostrará en su lugar
    if (isPlayingAd) {
      return const SizedBox.shrink();
    }
    
    // Si no hay canción, no mostrar nada
    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final song = currentSong;

    return Builder(
      builder: (builderContext) {
        return GestureDetector(
          onTap: onTap ?? () {
            // ✅ MEJOR PRÁCTICA: Usar servicio centralizado para navegación
            PlayerNavigationService.openFullPlayer(
              context: builderContext,
              ref: ref,
            );
          },
          child: Container(
        height: 72, // Altura ajustada para incluir la barra de progreso
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: NeumorphismTheme.background, // ⚡ Color original del tema
          borderRadius: const BorderRadius.all(Radius.circular(32)), // Bordes redondeados
          border: Border.all(
            color: NeumorphismTheme.background, // Borde del mismo color para solidez
            width: 2,
          ),
          boxShadow: [
            // Sombra exterior suavizada para menor overdraw
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚡ OPTIMIZACIÓN: Contenido principal usando widgets separados
            Row(
              children: [
                // ⚡ Widget optimizado: solo se reconstruye si cambia coverArtUrl
                MiniPlayerComponents.albumImage(song.coverArtUrl),
                
                const SizedBox(width: 12),
                
                // ⚡ Widget optimizado: solo se reconstruye si cambia título o artista
                Expanded(
                  child: MiniPlayerComponents.songInfo(
                    song.title ?? 'Sin título',
                    song.artist?.displayName ?? 'Artista desconocido',
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // ⚡ Widget optimizado: solo se reconstruye si cambia isPlaying
                MiniPlayerComponents.playButton(),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // ⚡ Widget optimizado: solo se reconstruye si cambia progress
            MiniPlayerComponents.progressBar(),
          ],
        ),
          ),
        );
      },
    );
  }
}
