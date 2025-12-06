import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import 'stable_image_widget.dart';

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
    // Usar directamente el provider unificado - ÚNICA FUENTE DE VERDAD
    final audioState = ref.watch(unifiedAudioProviderFixed);
    
    // Si no hay canción, no mostrar nada
    if (audioState.currentSong == null) {
      return const SizedBox.shrink();
    }

    final song = audioState.currentSong!;
    final isPlaying = audioState.isPlaying;
    final progress = audioState.progress; // Directamente del provider

    // Sin logs para máximo rendimiento

    return Builder(
      builder: (builderContext) {
        return GestureDetector(
          onTap: onTap ?? () {
            // Si no hay callback personalizado, abrir reproductor completo
            // ✅ OPTIMIZADO: Verificar estado antes de navegar para evitar múltiples llamadas
            try {
              final audioState = ref.read(unifiedAudioProviderFixed);
              if (audioState.currentSong != null && !audioState.isPlayerExpanded) {
                // Actualizar estado primero
                ref.read(unifiedAudioProviderFixed.notifier).openFullPlayer();
                
                // ✅ CORRECCIÓN: Pequeño delay para permitir que la animación se vea
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
          color: NeumorphismTheme.background, // ✅ Color original del tema
          borderRadius: BorderRadius.circular(32), // Bordes redondeados
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
            // Contenido principal
            Row(
              children: [
                // Imagen del álbum - más pequeña y circular
                // ✅ OPTIMIZACIÓN: RepaintBoundary para widget estático
                RepaintBoundary(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NeumorphismTheme.coffeeMedium,
                    ),
                    child: ClipOval(
                      child: song.coverArtUrl != null
                          ? StableImageWidget(
                              imageUrl: song.coverArtUrl,
                              fit: BoxFit.cover,
                              errorWidget: const Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 20,
                              ),
                            )
                          : const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Información de la canción - más compacta
                // ✅ OPTIMIZACIÓN: RepaintBoundary para widget estático
                Expanded(
                  child: RepaintBoundary(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title ?? 'Sin título',
                          style: GoogleFonts.inter(
                            color: NeumorphismTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          song.artist?.displayName ?? 'Artista desconocido',
                          style: GoogleFonts.inter(
                            color: NeumorphismTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Botón play/pause más compacto - Sincronizado con SongDetailScreen
                // ✅ OPTIMIZACIÓN: RepaintBoundary para widget dinámico (cambia con isPlaying)
                RepaintBoundary(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.coffeeMedium,
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          try {
                            await ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
                          } catch (e) {
                            AppLogger.error('[FinalMiniPlayer] Error toggle: $e');
                          }
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Center(
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 🚀 BARRA DE PROGRESO HORIZONTAL - Como estaba originalmente
            SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
          ),
        );
      },
    );
  }
}
