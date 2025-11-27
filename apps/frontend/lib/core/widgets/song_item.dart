import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../audio/audio_manager.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/url_normalizer.dart';
import 'optimized_image.dart';

/// Widget para mostrar un item de canción con diseño limpio
class SongItem extends ConsumerStatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final bool showPlayButton;
  final EdgeInsets? padding;
  final bool enablePreload; // Nueva opción para habilitar precarga

  const SongItem({
    super.key,
    required this.song,
    this.onTap,
    this.showPlayButton = true,
    this.padding,
    this.enablePreload = true, // Por defecto habilitada
  });

  @override
  ConsumerState<SongItem> createState() => _SongItemState();
}

class _SongItemState extends ConsumerState<SongItem> {
  bool _hasPreloaded = false;

  @override
  void initState() {
    super.initState();
    // 🚀 Precarga automática después de que el widget se construya
    if (widget.enablePreload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preloadSongIfNeeded();
      });
    }
  }

  /// Precarga la canción si no se ha hecho antes
  void _preloadSongIfNeeded() async {
    if (!_hasPreloaded && mounted) {
      final audioManager = ref.read(audioManagerProvider);
      await audioManager.preloadSong(widget.song);
      if (mounted) {
        _hasPreloaded = true;
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final audioManager = ref.read(audioManagerProvider);
    
    final coverUrl = widget.song.coverArtUrl != null && widget.song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(widget.song.coverArtUrl)
        : null;
    
    final artistName = widget.song.artist?.displayName ?? 'Artista desconocido';
    
    return StreamBuilder<Song?>(
      stream: audioManager.currentSongStream,
      initialData: audioManager.currentSong,
      builder: (context, currentSongSnapshot) {
        final currentSong = currentSongSnapshot.data;
        final isCurrentSong = currentSong?.id == widget.song.id;
        
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: isCurrentSong 
            ? BoxDecoration(
                color: NeumorphismTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
          child: Row(
            children: [
              // Portada
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: coverUrl != null
                      ? OptimizedImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          width: 56,
                          height: 56,
                          borderRadius: 12,
                        )
                      : Container(
                          color: NeumorphismTheme.accentLight,
                          child: Icon(
                            Icons.music_note,
                            color: NeumorphismTheme.accent,
                            size: 24,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.song.title ?? 'Sin título',
                      style: GoogleFonts.inter(
                        color: isCurrentSong ? NeumorphismTheme.accent : NeumorphismTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: isCurrentSong ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artistName,
                      style: GoogleFonts.inter(
                        color: NeumorphismTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Indicador de reproducción o botón play
              if (isCurrentSong)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                )
              else if (widget.showPlayButton)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NeumorphismTheme.accent.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: NeumorphismTheme.accent,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
