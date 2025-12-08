import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
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
    // ⚡ OPTIMIZACIÓN: Solo escuchar currentSong, los demás widgets escuchan sus propias partes
    final currentSong = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong),
    );
    
    // Si no hay canción, no mostrar nada
    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final song = currentSong;

    return Builder(
      builder: (builderContext) {
        return GestureDetector(
          onTap: onTap ?? () {
            // Si no hay callback personalizado, abrir reproductor completo
            // ⚡ OPTIMIZADO: Verificar estado antes de navegar para evitar múltiples llamadas
            try {
              final audioState = ref.read(unifiedAudioProviderFixed);
              if (audioState.currentSong != null && !audioState.isPlayerExpanded) {
                // Actualizar estado primero
                ref.read(unifiedAudioProviderFixed.notifier).openFullPlayer();
                
                // ⚡ CORRECCIÓN: Pequeño delay para permitir que la animación se vea
                // Usar SchedulerBinding para asegurar que la animación comience correctamente
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (builderContext.mounted) {
                    // Navegar después del frame para que la animación se ejecute correctamente
                    Future.microtask(() {
                      if (builderContext.mounted) {
                        builderContext.push('/player');
                      }
                    });
                  }
                });
              }
            } catch (e) {
              AppLogger.error('[FinalMiniPlayer] Error al abrir reproductor: $e');
            }
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
            // Sombra exterior más prominente
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
            // Sombra interior para efecto neumórfico
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(-2, -2),
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
