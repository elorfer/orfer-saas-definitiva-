import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import 'stable_image_widget.dart';

/// Mini reproductor de emergencia ultra simple
/// Solo usa el provider, sin timers complicados
class EmergencyMiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const EmergencyMiniPlayer({
    super.key,
    this.onTap,
    this.onNext,
    this.onPrevious,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usar SOLO el provider unificado
    final audioState = ref.watch(unifiedAudioProviderFixed);
    
    // Si no hay canción, no mostrar nada
    if (audioState.currentSong == null) {
      return const SizedBox.shrink();
    }

    final song = audioState.currentSong!;
    final isPlaying = audioState.isPlaying;
    final progress = audioState.progress;
    final position = audioState.currentPosition;
    final duration = audioState.totalDuration;

    // Debug SIEMPRE activo para diagnosticar
    // Sin logs para mejor rendimiento
    debugPrint('🚨 [EmergencyMiniPlayer] Position: ${position.inSeconds}s / ${duration.inSeconds}s');

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
                            AppLogger.error('[EmergencyMiniPlayer] Error toggle: $e');
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
            
            // 🚨 BARRA DE PROGRESO DE EMERGENCIA - MUY VISIBLE
            Container(
              height: 6, // Más alta
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.red.withValues(alpha: 0.2), // Rojo para debug
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red), // Rojo para debug
                ),
              ),
            ),
            
            // 🔍 INFORMACIÓN DE DEBUG SIEMPRE VISIBLE
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'EMERGENCY: ${position.inSeconds}s / ${duration.inSeconds}s (${(progress * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
