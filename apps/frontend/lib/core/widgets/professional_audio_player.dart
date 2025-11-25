import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'dart:async';
import '../providers/professional_audio_provider.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';

/// Widget profesional de reproductor de audio con todas las funcionalidades
class ProfessionalAudioPlayer extends ConsumerStatefulWidget {
  const ProfessionalAudioPlayer({super.key});

  @override
  ConsumerState<ProfessionalAudioPlayer> createState() => _ProfessionalAudioPlayerState();
}

class _ProfessionalAudioPlayerState
    extends ConsumerState<ProfessionalAudioPlayer>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  bool _isDraggingSeek = false;
  Duration? _dragPosition;
  Timer? _progressTimer;
  // Removidas suscripciones no usadas - se usa Riverpod providers en su lugar

  @override
  void initState() {
    super.initState();
    
    // Animación de pulso para el botón de play/pause
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Animación de fade para transiciones suaves
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _progressTimer?.cancel();
    // Ya no hay suscripciones que cancelar - Riverpod maneja todo
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    try {
      final audioService = ref.watch(professionalAudioServiceProvider);
      final currentSongAsync = ref.watch(professionalCurrentSongProvider);
      final playerStateAsync = ref.watch(professionalPlayerStateProvider);

      // Obtener la canción actual
      Song? currentSong;
      try {
        currentSong = currentSongAsync.maybeWhen(
          data: (song) => song,
          orElse: () => null,
        );
      } catch (e) {
        AppLogger.error('[ProfessionalAudioPlayer] Error al obtener currentSong: $e');
      }
      
      // Respaldo: si el provider no tiene la canción, usar la del controller
      if (currentSong == null) {
        final controller = ref.watch(professionalAudioControllerProvider);
        currentSong = controller?.currentSong;
      }
      
      if (currentSong == null || !audioService.isInitialized || audioService.controller == null) {
        return const SizedBox.shrink();
      }

      final controller = audioService.controller!;
      final player = controller.player;
      final song = currentSong;
      
      // Obtener estado del reproductor
      final playerState = playerStateAsync.maybeWhen(
        data: (state) => state,
        orElse: () => null,
      );
      final isPlaying = playerState?.playing ?? false;
      
      // Usar StreamBuilder directo del player para actualización en tiempo real
      return StreamBuilder<Duration>(
        stream: player.positionStream,
        initialData: player.position,
        builder: (context, positionSnapshot) {
          return StreamBuilder<Duration?>(
            stream: player.durationStream,
            initialData: player.duration,
            builder: (context, durationSnapshot) {
              // Obtener posición y duración directamente del player
              Duration position;
              if (_isDraggingSeek && _dragPosition != null) {
                position = _dragPosition!;
              } else if (isPlaying) {
                // Cuando está reproduciendo, obtener directamente del player
                position = player.position;
              } else {
                position = positionSnapshot.data ?? Duration.zero;
              }
              
              final duration = durationSnapshot.data ?? Duration.zero;
              
              // Actualizar periódicamente cuando está reproduciendo
              if (isPlaying && !_isDraggingSeek && mounted) {
                _progressTimer?.cancel();
                _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
                  if (!mounted || !isPlaying || _isDraggingSeek) {
                    timer.cancel();
                    return;
                  }
                  if (mounted) {
                    setState(() {});
                  }
                });
              } else {
                _progressTimer?.cancel();
              }
              
              final currentPosition = position;
              final currentDuration = duration;
              
              final progress = currentDuration.inSeconds > 0
                  ? (currentPosition.inSeconds.clamp(0, currentDuration.inSeconds) / 
                     currentDuration.inSeconds).clamp(0.0, 1.0)
                  : 0.0;
              final clampedProgress = progress.clamp(0.0, 1.0);

              return FadeTransition(
                opacity: _fadeController,
                child: Container(
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.beigeLight, // Fondo beige para efecto flotante
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, -5),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      color: NeumorphismTheme.beigeLight, // Fondo beige para efecto flotante
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Carátula grande centrada arriba
                          Hero(
                            tag: 'album_cover_${song.id}',
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: (song.coverArtUrl != null &&
                                        song.coverArtUrl!.isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: song.coverArtUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: NeumorphismTheme.coffeeMedium,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: NeumorphismTheme.coffeeMedium,
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white,
                                            size: 80,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: NeumorphismTheme.coffeeMedium,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.white,
                                          size: 80,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          
                          // Información de la canción con botones al lado
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Información de la canción a la izquierda
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title ?? 'Sin título',
                                        style: const TextStyle(
                                          color: NeumorphismTheme.textPrimary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        song.artist?.displayName ?? 'Artista desconocido',
                                        style: TextStyle(
                                          color: NeumorphismTheme.textSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Botones de acción en horizontal
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botón agregar a playlist
                                    _ActionButton(
                                      icon: Icons.add_rounded,
                                      onTap: () {
                                        // TODO: Implementar agregar a playlist
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    // Botón descargar
                                    _ActionButton(
                                      icon: Icons.download_rounded,
                                      onTap: () {
                                        // TODO: Implementar descarga
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    // Botón más opciones
                                    _ActionButton(
                                      icon: Icons.more_vert_rounded,
                                      onTap: () {
                                        // TODO: Implementar menú de opciones
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    // Botón expandir/fullscreen
                                    _ActionButton(
                                      icon: Icons.open_in_full_rounded,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Barra de progreso (solo una, la de abajo)
                          Column(
                            children: [
                              // Slider de progreso
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                  activeTrackColor: NeumorphismTheme.coffeeMedium,
                                  inactiveTrackColor: NeumorphismTheme.coffeeMedium
                                      .withValues(alpha: 0.2),
                                  thumbColor: NeumorphismTheme.coffeeMedium,
                                  overlayColor: NeumorphismTheme.coffeeMedium
                                      .withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: clampedProgress,
                                  onChanged: (value) {
                                    if (currentDuration.inSeconds > 0) {
                                      setState(() {
                                        _isDraggingSeek = true;
                                        _dragPosition = Duration(
                                          seconds: (value * currentDuration.inSeconds).toInt(),
                                        );
                                      });
                                    }
                                  },
                                  onChangeEnd: (value) async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      if (!audioService.isInitialized) {
                                        await audioService.initialize(enableBackground: true);
                                      }
                                      if (currentDuration.inSeconds > 0) {
                                        final seekPosition = Duration(
                                          seconds: (value * currentDuration.inSeconds).toInt(),
                                        );
                                        await audioService.seek(seekPosition);
                                        if (!mounted) return;
                                        setState(() {
                                          _isDraggingSeek = false;
                                          _dragPosition = null;
                                        });
                                      }
                                    } catch (e) {
                                      if (!mounted) return;
                                      setState(() {
                                        _isDraggingSeek = false;
                                        _dragPosition = null;
                                      });
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              
                              // Tiempo transcurrido y total
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(currentPosition),
                                      style: TextStyle(
                                        color: NeumorphismTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(currentDuration),
                                      style: TextStyle(
                                        color: NeumorphismTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Controles de reproducción
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                        // Botón anterior
                        _ControlButton(
                          icon: Icons.skip_previous,
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (!audioService.isInitialized) {
                                await audioService.initialize(enableBackground: true);
                              }
                              await audioService.previous();
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          size: 36,
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Botón play/pause con animación
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: NeumorphismTheme.coffeeMedium,
                                shape: BoxShape.circle,
                                boxShadow: isPlaying
                                    ? [
                                        BoxShadow(
                                          color: NeumorphismTheme.coffeeMedium
                                              .withValues(alpha: 0.3 +
                                                  (_pulseController.value * 0.2)),
                                          blurRadius: 12 +
                                              (_pulseController.value * 8),
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
                                  onTap: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      if (!audioService.isInitialized) {
                                        await audioService.initialize(enableBackground: true);
                                      }
                                      if (isPlaying) {
                                        await audioService.pause();
                                      } else {
                                        await audioService.play();
                                      }
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(28),
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        isPlaying ? Icons.pause : Icons.play_arrow,
                                        key: ValueKey<bool>(isPlaying),
                                        color: Colors.white,
                                        size: 28,
                                      ),
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
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (!audioService.isInitialized) {
                                await audioService.initialize(enableBackground: true);
                              }
                              await audioService.next();
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          size: 36,
                        ),
                        ],
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    } catch (e, stackTrace) {
      AppLogger.error('[ProfessionalAudioPlayer] Error en build: $e', stackTrace);
      return const SizedBox.shrink();
    }
  }
}

/// Widget de botón de control con animación
class _ControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    this.onTap,
    this.size = 40,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(
          CurvedAnimation(
            parent: _scaleController,
            curve: Curves.easeInOut,
          ),
        ),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            color: NeumorphismTheme.textPrimary,
            size: widget.size * 0.55,
          ),
        ),
      ),
    );
  }
}

/// Botón de acción para el reproductor completo
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
              color: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: NeumorphismTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

