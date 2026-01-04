import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
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
  /// Nota: La precarga de audio se maneja automáticamente por PlaybackNotifier
  /// cuando las canciones se agregan a la cola. Esta precarga local es opcional
  /// y puede usarse para optimizaciones futuras (ej: precarga de metadatos).
  void _preloadSongIfNeeded() async {
    if (!_hasPreloaded && mounted) {
      // La precarga de audio real se maneja en PlaybackNotifier._preloadNextSongAudio()
      // Aquí solo marcamos como precargado para evitar llamadas repetidas
      if (mounted) {
        _hasPreloaded = true;
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // 🚀 OPTIMIZACIÓN: Watches granulares para evitar que todos los items se reconstruyan
    // Solo observar si esta canción es la actual
    final isCurrentSong = ref.watch(realCurrentSongProvider.select((s) => s?.id == widget.song.id));
    
    // Solo observar isPlaying si esta es la canción activa
    final isPlaying = isCurrentSong ? ref.watch(isPlayingProviderFixed) : false;
    
    // El coverUrl ya se normaliza internamente en OptimizedImage si se pasa el raw
    final coverUrl = widget.song.coverArtUrl;
    
    final artistName = widget.song.artist?.displayName ?? 'Artista desconocido';
    
    return RepaintBoundary(
      child: _buildSongItemContent(
        context: context,
        coverUrl: coverUrl,
        artistName: artistName,
        isCurrentSong: isCurrentSong,
        isPlaying: isPlaying,
      ),
    );
  }
  
  Widget _buildSongItemContent({
    required BuildContext context,
    required String? coverUrl,
    required String artistName,
    required bool isCurrentSong,
    required bool isPlaying,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Container(
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: isCurrentSong 
            ? BoxDecoration(
                color: NeumorphismTheme.accent.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              )
            : null,
          child: Row(
            children: [
              // Portada
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: OptimizedImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    borderRadius: 12,
                    maxCacheWidth: 120, // 🚀 Downscaling para RAM
                    maxCacheHeight: 120,
                    placeholderColor: NeumorphismTheme.accentLight,
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
                      style: TextStyle(
                        color: isCurrentSong ? NeumorphismTheme.accent : NeumorphismTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: isCurrentSong ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: -0.3,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artistName,
                      style: TextStyle(
                        color: NeumorphismTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        decoration: TextDecoration.none,
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
