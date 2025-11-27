import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import 'stable_image_widget.dart';

/// Ejemplo de cómo usar el provider unificado corregido en un card de canción
/// PROHIBIDO crear nuevos AudioPlayers aquí - solo usar el provider
class SongCardExample extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;

  const SongCardExample({
    super.key,
    required this.song,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 USAR EL PROVIDER UNIFICADO CORREGIDO - ÚNICA FUENTE DE VERDAD
    final audioState = ref.watch(unifiedAudioProviderFixed);
    
    // Verificar si esta canción es la que se está reproduciendo
    final isCurrentSong = audioState.currentSong?.id == song.id;
    final isPlaying = isCurrentSong && audioState.isPlaying;
    final progress = isCurrentSong ? audioState.progress : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentSong 
              ? NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1)
              : NeumorphismTheme.background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: isCurrentSong 
              ? Border.all(color: NeumorphismTheme.coffeeMedium, width: 1)
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Imagen del álbum
                Container(
                  width: 56,
                  height: 56,
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
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 28,
                          ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Información de la canción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title ?? 'Sin título',
                        style: GoogleFonts.inter(
                          color: isCurrentSong 
                              ? NeumorphismTheme.coffeeMedium
                              : NeumorphismTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist?.displayName ?? 'Artista desconocido',
                        style: GoogleFonts.inter(
                          color: NeumorphismTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song.duration != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDuration(Duration(seconds: song.duration!)),
                          style: GoogleFonts.inter(
                            color: NeumorphismTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Botón de reproducción
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCurrentSong 
                        ? NeumorphismTheme.coffeeMedium
                        : NeumorphismTheme.textSecondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        try {
                          if (isCurrentSong) {
                            // Si es la canción actual, toggle play/pause
                            await ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
                          } else {
                            // Si es una canción diferente, reproducirla
                            await ref.read(unifiedAudioProviderFixed.notifier).playSong(song);
                          }
                        } catch (e) {
                          AppLogger.error('[SongCardExample] Error: $e');
                        }
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Center(
                        child: Icon(
                          isCurrentSong && isPlaying 
                              ? Icons.pause 
                              : Icons.play_arrow,
                          color: isCurrentSong 
                              ? Colors.white 
                              : NeumorphismTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // 🚀 BARRA DE PROGRESO - Solo mostrar si es la canción actual
            if (isCurrentSong) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Ejemplo de lista de canciones que usa el provider correctamente
class SongListExample extends ConsumerWidget {
  final List<Song> songs;

  const SongListExample({
    super.key,
    required this.songs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        
        return SongCardExample(
          song: song,
          onTap: () async {
            try {
              // 🚀 USAR EL PROVIDER UNIFICADO CORREGIDO
              await ref.read(unifiedAudioProviderFixed.notifier).playSong(song);
              
              // Opcional: Navegar al reproductor completo
              // Navigator.of(context).pushNamed('/player');
            } catch (e) {
              AppLogger.error('[SongListExample] Error reproduciendo: $e');
              
              // Mostrar error al usuario
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al reproducir: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}
