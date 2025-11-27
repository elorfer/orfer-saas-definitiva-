import 'package:flutter/material.dart';

/// Barra de reproducción flotante con glassmorphism
class BottomPlayer extends StatefulWidget {
  final String? songTitle;
  final String? artistName;
  final String? imageUrl;
  final bool isPlaying;
  final Duration? position;
  final Duration? duration;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTap;
  final ValueChanged<double>? onSeek;

  const BottomPlayer({
    super.key,
    this.songTitle,
    this.artistName,
    this.imageUrl,
    this.isPlaying = false,
    this.position,
    this.duration,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onTap,
    this.onSeek,
  });

  @override
  State<BottomPlayer> createState() => _BottomPlayerState();
}

class _BottomPlayerState extends State<BottomPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Siempre devolver widget vacío - este reproductor ha sido deshabilitado
    // El usuario quiere eliminar este reproductor que aparece cuando reproduce una canción
    return const SizedBox.shrink();
  }

  /* Código comentado - el BottomPlayer ha sido deshabilitado
  @override
  Widget build(BuildContext context) {
    if (widget.songTitle == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: NeumorphismTheme.floatingCardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: NeumorphismTheme.glassDecoration().copyWith(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
              child: Row(
                children: [
                  // Imagen del álbum
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      image: widget.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: widget.imageUrl == null
                          ? NeumorphismTheme.coffeeMedium
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: widget.imageUrl == null
                        ? const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 28,
                          )
                        : null,
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Información de la canción
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.songTitle ?? 'Sin título',
                          style: const TextStyle(
                            color: NeumorphismTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.artistName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.artistName!,
                            style: TextStyle(
                              color: NeumorphismTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Controles de reproducción
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón anterior
                      _ControlButton(
                        icon: Icons.skip_previous,
                        onTap: widget.onPrevious,
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Botón play/pause con neumorphism
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: NeumorphismTheme.coffeeMedium,
                              shape: BoxShape.circle,
                              boxShadow: widget.isPlaying
                                  ? [
                                      BoxShadow(
                                        color: NeumorphismTheme.coffeeMedium
                                            .withValues(alpha: 0.3 + (_pulseController.value * 0.2)),
                                        blurRadius: 12 + (_pulseController.value * 8),
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onPlayPause,
                                borderRadius: BorderRadius.circular(24),
                                child: Center(
                                  child: Icon(
                                    widget.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Botón siguiente
                      _ControlButton(
                        icon: Icons.skip_next,
                        onTap: widget.onNext,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  */
}

