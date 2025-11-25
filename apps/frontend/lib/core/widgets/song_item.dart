import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/audio_manager.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/url_normalizer.dart';
import 'optimized_image.dart';
import 'play_button_icon.dart';

/// Widget para mostrar un item de canción con botón play
/// Estilo Spotify: muestra portada, título, artista y botón play
/// 
/// COMPORTAMIENTO:
/// - Botón play llama a AudioManager.playSong() para reproducir la canción
/// - Actualiza el estado global automáticamente (mini reproductor se actualiza)
/// - NO afecta la UI completa
/// - Muestra estado visual (play/pause) si es la canción actual
class SongItem extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final bool showPlayButton;
  final EdgeInsets? padding;

  const SongItem({
    super.key,
    required this.song,
    this.onTap,
    this.showPlayButton = true,
    this.padding,
  });

  /// Maneja el botón de play/expand
  /// Si NO hay canción reproduciéndose → reproduce normalmente
  /// Si HAY canción reproduciéndose → expande el full player
  Future<void> _handlePlay(BuildContext context, AudioManager audioManager) async {
    try {
      // Verificar si hay una canción reproduciéndose
      final currentSong = audioManager.currentSong;
      final isPlaying = audioManager.isPlaying;
      final isCurrentSong = currentSong?.id == song.id;
      
      // Si es la canción actual y está reproduciéndose → abrir full player
      if (isCurrentSong && isPlaying) {
        audioManager.openFullPlayer();
        return;
      }
      
      // Si hay otra canción reproduciéndose → playSong se encargará de abrir el full player
      // Si no hay canción reproduciéndose → reproduce normalmente
      await audioManager.playSong(song);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leer AudioManager
    final audioManager = ref.read(audioManagerProvider);
    
    // Memoizar valores calculados (no dependen del estado de reproducción)
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    final artistName = song.artist?.displayName ?? 'Artista desconocido';
    
    // Escuchar cambios en la canción actual y el estado de reproducción
    return StreamBuilder<Song?>(
      stream: audioManager.currentSongStream,
      initialData: audioManager.currentSong,
      builder: (context, currentSongSnapshot) {
        final currentSong = currentSongSnapshot.data;
        final isCurrentSong = currentSong?.id == song.id;
        
        // Si no es la canción actual, no necesitamos escuchar el estado de reproducción
        if (!isCurrentSong) {
          return _buildSongItemContent(
            context: context,
            audioManager: audioManager,
            coverUrl: coverUrl,
            artistName: artistName,
            isCurrentSong: false,
            isPlaying: false,
          );
        }
        
        // Si es la canción actual, escuchar el estado de reproducción
        return StreamBuilder<bool>(
          stream: audioManager.isPlayingStream,
          initialData: audioManager.isPlaying,
          builder: (context, isPlayingSnapshot) {
            final isPlaying = isPlayingSnapshot.data ?? false;
            return _buildSongItemContent(
              context: context,
              audioManager: audioManager,
              coverUrl: coverUrl,
              artistName: artistName,
              isCurrentSong: true,
              isPlaying: isPlaying,
            );
          },
        );
      },
    );
  }
  
  Widget _buildSongItemContent({
    required BuildContext context,
    required AudioManager audioManager,
    required String? coverUrl,
    required String artistName,
    required bool isCurrentSong,
    required bool isPlaying,
  }) {
    return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Portada de la canción - RepaintBoundary para optimizar repaints
                RepaintBoundary(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000), // Colors.black.withValues(alpha: 0.1) como const
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: coverUrl != null
                        ? OptimizedImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            borderRadius: 8,
                          )
                        : Container(
                            color: NeumorphismTheme.coffeeMedium,
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                      ),
                    ),
                  ),
                
                const SizedBox(width: 12),
                
                // Información de la canción - RepaintBoundary para optimizar repaints
                Expanded(
                  child: RepaintBoundary(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title ?? 'Sin título',
                          style: const TextStyle(
                            color: NeumorphismTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artistName,
                          style: TextStyle(
                            color: NeumorphismTheme.textSecondary.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Botón de play
                if (showPlayButton) ...[
                  const SizedBox(width: 8),
                  RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _handlePlay(context, audioManager),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCurrentSong && isPlaying
                              ? NeumorphismTheme.coffeeMedium
                              : NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: PlayButtonIcon(
                            isPlaying: isCurrentSong && isPlaying,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
  }
}
