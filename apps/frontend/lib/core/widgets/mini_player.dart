import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rxdart/rxdart.dart';
import '../audio/audio_manager.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/url_normalizer.dart';
import '../utils/full_player_tracker.dart';
import 'professional_audio_player.dart';
import 'mini_player_constants.dart';

/// Mini reproductor global estilo Spotify/YouTube Music
/// Aparece cuando hay una canción cargada y se posiciona sobre la barra de navegación
/// 
/// CARACTERÍSTICAS:
/// - Solo llama togglePlayPause() - NUNCA cambia la canción
/// - Siempre muestra la canción actual del AudioManager
/// - Se reconstruye sin saltos ni delays
/// - NO duplica listeners (usa streams del AudioManager)
/// - NO causa jank
/// - Mantiene estado entre pantallas (persistente)
class MiniPlayer extends ConsumerStatefulWidget {
  /// Función callback cuando se hace click en el mini player
  /// Si es null, no hace nada al hacer click
  final VoidCallback? onTap;

  const MiniPlayer({
    super.key,
    this.onTap,
  });

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  double _previousProgressValue = 0.0;
  
  // Cache para evitar recálculos innecesarios
  String? _cachedSongId;
  String? _cachedCoverUrl;
  String? _cachedArtistName;

  @override
  void initState() {
    super.initState();
    
    // Animación de deslizamiento desde abajo
    _slideController = AnimationController(
      vsync: this,
      duration: MiniPlayerConstants.slideAnimationDuration,
      reverseDuration: MiniPlayerConstants.slideAnimationReverseDuration,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  /// Maneja el botón de play/pause del mini reproductor
  /// SOLO hace toggle play/pause - NUNCA cambia la canción
  void _handlePlayPause() async {
    try {
      final audioManager = ref.read(audioManagerProvider);
      await audioManager.togglePlayPause();
    } catch (e) {
      if (mounted) {
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

  /// Abrir el reproductor completo
  void _openFullPlayer() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    // Verificar si ya hay un reproductor abierto
    if (FullPlayerTracker.isOpen) {
      return;
    }

    final audioManager = ref.read(audioManagerProvider);
    final currentSong = audioManager.currentSong;
    if (currentSong == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay ninguna canción reproduciéndose'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Marcar como abierto
    FullPlayerTracker.setOpen(true);

    // Abrir modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      routeSettings: const RouteSettings(name: '/full_player'),
      builder: (context) => RepaintBoundary(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: DraggableScrollableSheet(
            initialChildSize: 0.98,
            minChildSize: 0.6,
            maxChildSize: 0.98,
            snap: true,
            snapSizes: const [0.98],
            builder: (context, scrollController) => RepaintBoundary(
              child: const SafeArea(
                child: ProfessionalAudioPlayer(),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      FullPlayerTracker.setOpen(false);
    });
  }

  void _handleTap() {
    _openFullPlayer();
  }

  /// Calcular progreso de forma eficiente
  double _calculateProgress(Duration position, Duration duration) {
    if (duration.inSeconds <= 0 || position.inSeconds < 0) {
      return 0.0;
    }
    final clampedPosition = position.inSeconds.clamp(0, duration.inSeconds);
    return (clampedPosition / duration.inSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Usar watch para que se reconstruya cuando cambie el AudioManager
    final audioManager = ref.watch(audioManagerProvider);
    
    // Stream de canción actual - NO duplica listeners
    return StreamBuilder<Song?>(
      stream: audioManager.currentSongStream,
      initialData: audioManager.currentSong,
      builder: (context, songSnapshot) {
        final currentSong = songSnapshot.data;
        
        // Si no hay canción, ocultar el mini player
        if (currentSong == null) {
          if (_slideController.isCompleted) {
            _slideController.reverse();
          }
          return const SizedBox.shrink();
        }

        // Mostrar animación
        if (!_slideController.isCompleted && !_slideController.isAnimating ||
            _slideController.isDismissed) {
          _slideController.forward();
        }
        
        // Actualizar cache solo si cambió la canción
        if (_cachedSongId != currentSong.id) {
          _cachedSongId = currentSong.id;
          _cachedCoverUrl = currentSong.coverArtUrl != null && currentSong.coverArtUrl!.isNotEmpty
              ? UrlNormalizer.normalizeImageUrl(currentSong.coverArtUrl)
              : null;
          _cachedArtistName = currentSong.artist?.displayName ?? 'Artista desconocido';
        }
        
        // Combinar streams para evitar múltiples StreamBuilders anidados
        return StreamBuilder<List<dynamic>>(
          stream: CombineLatestStream.list([
            audioManager.isPlayingStream.startWith(audioManager.isPlaying),
            audioManager.positionStream.startWith(audioManager.position),
            audioManager.durationStream.startWith(audioManager.duration),
          ]).debounceTime(MiniPlayerConstants.streamDebounceDuration),
          builder: (context, snapshot) {
            // Si no hay datos, usar valores actuales
            bool isPlaying = audioManager.isPlaying;
            Duration position = audioManager.position;
            Duration duration = audioManager.duration;
            
            if (snapshot.hasData) {
              final values = snapshot.data!;
              isPlaying = values[0] as bool;
              position = values[1] as Duration;
              duration = values[2] as Duration;
            }
            
            // Calcular progreso
            final progressValue = _calculateProgress(position, duration);
            final previousValue = _previousProgressValue;
            
            // Actualizar previousValue si cambió significativamente
            if ((progressValue - _previousProgressValue).abs() > MiniPlayerConstants.progressChangeThreshold) {
              _previousProgressValue = progressValue;
            }

            return _buildMiniPlayerContent(
              currentSong: currentSong,
              isPlaying: isPlaying,
              progressValue: progressValue,
              previousValue: previousValue,
            );
          },
        );
      },
    );
  }
  
  Widget _buildMiniPlayerContent({
    required Song currentSong,
    required bool isPlaying,
    required double progressValue,
    required double previousValue,
  }) {
    // Usar valores cacheados
    final coverUrl = _cachedCoverUrl;
    final artistName = _cachedArtistName ?? 'Artista desconocido';

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: NeumorphismTheme.beigeLight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de progreso
            _AnimatedProgressBar(
              progressValue: progressValue,
              previousValue: previousValue,
            ),
            // Contenido principal
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MiniPlayerConstants.horizontalPadding,
                vertical: MiniPlayerConstants.verticalPadding,
              ),
              child: Row(
                children: [
                  // Portada
                  RepaintBoundary(
                    child: Hero(
                      tag: 'album_cover_${currentSong.id}',
                      child: Container(
                        width: MiniPlayerConstants.albumCoverSize,
                        height: MiniPlayerConstants.albumCoverSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(MiniPlayerConstants.borderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: MiniPlayerConstants.shadowOpacity),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(MiniPlayerConstants.borderRadius),
                          child: coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const _AlbumCoverPlaceholder(),
                                  errorWidget: (context, url, error) => const _AlbumCoverError(),
                                )
                              : const _AlbumCoverError(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: MiniPlayerConstants.spacingBetweenElements),
                  // Información
                  Expanded(
                    child: RepaintBoundary(
                      child: _SongInfoText(
                        songTitle: currentSong.title ?? 'Sin título',
                        artistName: artistName,
                      ),
                    ),
                  ),
                  const SizedBox(width: MiniPlayerConstants.spacingBeforeButton),
                  // Botón play/pause
                  RepaintBoundary(
                    child: _PlayPauseButton(
                      isPlaying: isPlaying,
                      onTap: _handlePlayPause,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progreso animada
class _AnimatedProgressBar extends StatefulWidget {
  final double progressValue;
  final double previousValue;

  const _AnimatedProgressBar({
    required this.progressValue,
    required this.previousValue,
  });

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar> {
  double _lastAnimatedValue = 0.0;

  @override
  void initState() {
    super.initState();
    _lastAnimatedValue = widget.previousValue.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(_AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.progressValue - oldWidget.progressValue).abs() > MiniPlayerConstants.progressChangeThreshold) {
      _lastAnimatedValue = oldWidget.previousValue.clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetValue = widget.progressValue.clamp(0.0, 1.0);
    final startValue = _lastAnimatedValue;
    
    return SizedBox(
      height: MiniPlayerConstants.progressBarHeight,
      child: Stack(
        children: [
          // Fondo
          SizedBox(
            width: double.infinity,
            height: MiniPlayerConstants.progressBarHeight,
            child: ColoredBox(
              color: NeumorphismTheme.coffeeMedium.withValues(alpha: MiniPlayerConstants.backgroundProgressOpacity),
            ),
          ),
          // Barra animada
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: startValue, end: targetValue),
            duration: MiniPlayerConstants.progressAnimationDuration,
            curve: Curves.easeOut,
            builder: (context, animatedValue, child) {
              if ((animatedValue - _lastAnimatedValue).abs() > MiniPlayerConstants.progressChangeThreshold) {
                _lastAnimatedValue = animatedValue;
              }
              
              return Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: animatedValue.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: MiniPlayerConstants.progressBarHeight,
                    decoration: const BoxDecoration(
                      color: NeumorphismTheme.coffeeMedium,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Placeholder para portada
class _AlbumCoverPlaceholder extends StatelessWidget {
  const _AlbumCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NeumorphismTheme.coffeeMedium,
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Error widget para portada
class _AlbumCoverError extends StatelessWidget {
  const _AlbumCoverError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NeumorphismTheme.coffeeMedium,
      child: const Icon(
        Icons.music_note,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

/// Información de la canción
class _SongInfoText extends StatelessWidget {
  final String songTitle;
  final String artistName;

  const _SongInfoText({
    required this.songTitle,
    required this.artistName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          songTitle,
          style: const TextStyle(
            color: NeumorphismTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: MiniPlayerConstants.textSpacing),
        Text(
          artistName,
          style: TextStyle(
            color: NeumorphismTheme.textSecondary.withValues(alpha: MiniPlayerConstants.secondaryTextOpacity),
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Botón play/pause
class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: MiniPlayerConstants.buttonSize,
        height: MiniPlayerConstants.buttonSize,
        decoration: const BoxDecoration(
          color: NeumorphismTheme.coffeeMedium,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: MiniPlayerConstants.iconAnimationDuration,
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey<bool>(isPlaying),
              color: Colors.white,
              size: MiniPlayerConstants.iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
