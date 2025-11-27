import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import 'stable_image_widget.dart';

/// Mini reproductor ULTRA SIMPLE - Solo muestra el progreso del provider
/// Sin timers, sin complicaciones, solo datos directos
class UltraSimpleMiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;

  const UltraSimpleMiniPlayer({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SOLO usar el provider - nada más
    final audioState = ref.watch(unifiedAudioProviderFixed);
    
    // Si no hay canción, no mostrar nada
    if (audioState.currentSong == null) {
      return const SizedBox.shrink();
    }

    final song = audioState.currentSong!;
    final isPlaying = audioState.isPlaying;
    final progress = audioState.progress; // Directamente del provider

    // Sin logs para máximo rendimiento

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: NeumorphismTheme.background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Contenido principal
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Imagen del álbum
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: NeumorphismTheme.coffeeMedium,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: song.coverArtUrl != null
                          ? StableImageWidget(
                              imageUrl: song.coverArtUrl,
                              fit: BoxFit.cover,
                              errorWidget: const Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Información de la canción
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title ?? 'Sin título',
                          style: GoogleFonts.inter(
                            color: NeumorphismTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist?.displayName ?? 'Artista desconocido',
                          style: GoogleFonts.inter(
                            color: NeumorphismTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Botón play/pause
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.coffeeMedium,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          try {
                            await ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
                          } catch (e) {
                            AppLogger.error('[UltraSimpleMiniPlayer] Error toggle: $e');
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 🚀 BARRA DE PROGRESO - FUNCIONA PERFECTAMENTE
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
