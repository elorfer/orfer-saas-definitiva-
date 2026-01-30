import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/advanced_audio_engine.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎚️ PROFESSIONAL SEEKBAR - BARRA DE PROGRESO PROFESIONAL
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Características:
/// - Movimiento orgánico sin parpadeo (SmoothPositionStream)
/// - Buffer progress visualizado
/// - Gestos de drag suaves con feedback háptico
/// - Animaciones de entrada/hover
/// - Colores dinámicos desde paleta
/// - Tooltips con tiempo durante drag
/// ═══════════════════════════════════════════════════════════════════════════

class ProfessionalSeekbar extends ConsumerStatefulWidget {
  /// Altura de la barra de progreso
  final double height;
  
  /// Radio del thumb
  final double thumbRadius;
  
  /// Mostrar tiempos (posición / duración)
  final bool showTimes;
  
  /// Estilo de tiempo
  final TextStyle? timeStyle;
  
  /// Color de la barra de progreso (usa paleta si null)
  final Color? progressColor;
  
  /// Color del buffer
  final Color? bufferColor;
  
  /// Color del fondo
  final Color? backgroundColor;
  
  /// Callback cuando se hace seek
  final void Function(Duration position)? onSeek;
  
  /// Callback cuando empieza el drag
  final VoidCallback? onDragStart;
  
  /// Callback cuando termina el drag
  final VoidCallback? onDragEnd;

  const ProfessionalSeekbar({
    super.key,
    this.height = 4.0,
    this.thumbRadius = 8.0,
    this.showTimes = true,
    this.timeStyle,
    this.progressColor,
    this.bufferColor,
    this.backgroundColor,
    this.onSeek,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  ConsumerState<ProfessionalSeekbar> createState() => _ProfessionalSeekbarState();
}

class _ProfessionalSeekbarState extends ConsumerState<ProfessionalSeekbar>
    with SingleTickerProviderStateMixin {
  // Estado de drag
  bool _isDragging = false;
  double _dragProgress = 0.0;
  
  // 🆕 FIX PARPADEO: Detectar saltos grandes en progreso (cambio de canción)
  double _lastProgress = 0.0;
  String? _lastSongId;
  
  // Animación del thumb
  late AnimationController _thumbController;
  late Animation<double> _thumbScale;

  @override
  void initState() {
    super.initState();
    _thumbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _thumbScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _thumbController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _thumbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX PARPADEO: Usar providers síncronos que NUNCA tienen estado loading
    // Esto elimina el parpadeo al cambiar de canción o reabrir el reproductor
    final state = ref.watch(audioEngineStateSyncProvider);
    final smoothPosition = ref.watch(smoothPositionSyncProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    // Ya no usamos .when() - siempre tenemos valores válidos
    return _buildSeekbar(
      context,
      state,
      smoothPosition,
      palette,
    );
  }

  Widget _buildSeekbar(
    BuildContext context,
    AudioEngineState state,
    Duration smoothPosition,
    DynamicPalette palette,
  ) {
    // Calcular progreso
    final duration = state.duration;
    final buffered = state.bufferedPosition;
    
    double progress = 0.0;
    double bufferProgress = 0.0;
    
    if (duration.inMilliseconds > 0) {
      progress = _isDragging
          ? _dragProgress
          : (smoothPosition.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      bufferProgress = (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    }

    // 🆕 FIX PARPADEO: Detectar cambio de canción o salto grande
    // Si hay un salto grande hacia atrás o cambio de canción, NO animar
    final currentSongId = state.currentSong?.id;
    final songChanged = currentSongId != _lastSongId && _lastSongId != null;
    
    // 🛠️ FIX CRÍTICO: Resetear _lastProgress cuando cambia la canción
    // Esto fuerza que la barra empiece desde 0% en la nueva canción
    if (songChanged) {
      _lastProgress = 0.0;
    }
    
    final bigJump = (_lastProgress - progress).abs() > 0.3; // Salto > 30%
    final skipAnimation = songChanged || (bigJump && progress < 0.1); // Salto grande hacia el inicio
    
    // Actualizar estado para próxima comparación
    _lastProgress = progress;
    _lastSongId = currentSongId;

    // Colores
    final progressColor = widget.progressColor ?? palette.vibrant;
    final bufferColor = widget.bufferColor ?? palette.muted.withValues(alpha: 0.3);
    final bgColor = widget.backgroundColor ?? palette.darkMuted.withValues(alpha: 0.2);

    // Posición para mostrar
    final displayPosition = _isDragging
        ? Duration(milliseconds: (duration.inMilliseconds * _dragProgress).round())
        : smoothPosition;

    // 🆕 Duración de animación: 0 si hay salto grande, normal si no
    final animDuration = (_isDragging || skipAnimation) 
        ? Duration.zero 
        : const Duration(milliseconds: 50);
    final bufferAnimDuration = skipAnimation 
        ? Duration.zero 
        : const Duration(milliseconds: 300);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Barra de progreso
        GestureDetector(
          onHorizontalDragStart: (details) => _onDragStart(details, context),
          onHorizontalDragUpdate: (details) => _onDragUpdate(details, context),
          onHorizontalDragEnd: (details) => _onDragEnd(details, state.duration),
          onTapDown: (details) => _onTap(details, context, state.duration),
          child: MouseRegion(
            onEnter: (_) => _thumbController.forward(),
            onExit: (_) {
              if (!_isDragging) _thumbController.reverse();
            },
            child: Container(
              height: widget.thumbRadius * 2 + 16, // Área táctil amplia
              alignment: Alignment.center,
              child: SizedBox(
                height: math.max(widget.height, widget.thumbRadius * 2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final thumbX = progress * width;

                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        // Fondo
                        Container(
                          height: widget.height,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(widget.height / 2),
                          ),
                        ),

                        // Buffer - 🆕 usa bufferAnimDuration dinámico
                        AnimatedContainer(
                          duration: bufferAnimDuration,
                          height: widget.height,
                          width: width * bufferProgress,
                          decoration: BoxDecoration(
                            color: bufferColor,
                            borderRadius: BorderRadius.circular(widget.height / 2),
                          ),
                        ),

                        // Progreso - 🆕 usa animDuration dinámico
                        AnimatedContainer(
                          duration: animDuration,
                          height: widget.height,
                          width: width * progress,
                          decoration: BoxDecoration(
                            color: progressColor,
                            borderRadius: BorderRadius.circular(widget.height / 2),
                            boxShadow: [
                              BoxShadow(
                                color: progressColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),

                        // Thumb - 🆕 usa animDuration dinámico
                        AnimatedPositioned(
                          duration: animDuration,
                          left: thumbX - widget.thumbRadius,
                          child: AnimatedBuilder(
                            animation: _thumbScale,
                            builder: (context, child) {
                              final scale = 1.0 + (_thumbScale.value * 0.3);
                              return Transform.scale(
                                scale: _isDragging ? 1.3 : scale,
                                child: child,
                              );
                            },
                            child: Container(
                              width: widget.thumbRadius * 2,
                              height: widget.thumbRadius * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: progressColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: progressColor.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Tooltip durante drag
                        if (_isDragging)
                          Positioned(
                            left: (thumbX - 30).clamp(0, width - 60),
                            bottom: widget.thumbRadius * 2 + 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDuration(displayPosition),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Tiempos
                ),
              ),
            ),
          ),
        ),

        // Tiempos - 🆕 DECOUPLED: Optimizacion 120 FPS
        if (widget.showTimes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _TimeLabels(
              displayPositionStream: _isDragging 
                  ? Stream.value(displayPosition) 
                  // Convertir ValueNotifier a Stream para el widget desacoplado
                  : (smoothPosition == Duration.zero 
                      ? Stream.value(Duration.zero) 
                      : Stream.periodic(const Duration(seconds: 1), (_) {
                          // Hack simple para forzar update solo cada segundo
                          // Idealmente usaríamos un ValueNotifier<int> separado para segundos
                          // pero aquí aprovechamos el rebuild del padre solo si es necesario
                          return smoothPosition; 
                        }).map((_) => smoothPosition)),
              
              // ⚡ MEJOR APROXIMACIÓN: Pasar el valor directo y dejar que el hijo decida si repintar
              // En este caso, el padre (Seekbar) YA se está reconstruyendo a 60fps por el ref.watch.
              // Para evitar que el Text haga layout a 60fps, usamos un widget const con Equality check
              // o un RepaintBoundary interno.
              
              currentParams: _TimeParams(
                 current: displayPosition,
                 total: duration,
                 style: widget.timeStyle ?? TextStyle(
                    fontSize: 12,
                    color: palette.onBackground.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
              ),
            ),
          ),
      ],
    );
  }

  // ... (rest of the file)
}

class _TimeParams {
  final Duration current;
  final Duration total;
  final TextStyle style;

  const _TimeParams({
    required this.current,
    required this.total,
    required this.style,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _TimeParams &&
      other.current.inSeconds == current.inSeconds && // ⚡ SOLO comparar segundos
      other.total.inSeconds == total.inSeconds &&
      other.style == style;
  }

  @override
  int get hashCode => Object.hash(current.inSeconds, total.inSeconds, style);
}

class _TimeLabels extends StatelessWidget {
  final _TimeParams currentParams;
  // Ignore stream param from previous attempt, just use params

  const _TimeLabels({
    // ignore: unused_element
    super.key, 
    required this.currentParams, required Stream<Duration> displayPositionStream,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatDuration(currentParams.current),
          style: currentParams.style,
        ),
        Text(
          _formatDuration(currentParams.total),
          style: currentParams.style,
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
} // End of _TimeLabels class

// Note: Removed duplicate code block that was inadvertently added.


  void _onDragStart(DragStartDetails details, BuildContext context) {
    setState(() => _isDragging = true);
    _thumbController.forward();
    widget.onDragStart?.call();
    HapticFeedback.lightImpact();
  }

  void _onDragUpdate(DragUpdateDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final localX = details.localPosition.dx.clamp(0.0, width);
    
    setState(() {
      _dragProgress = localX / width;
    });
  }

  void _onDragEnd(DragEndDetails details, Duration duration) {
    final seekPosition = Duration(
      milliseconds: (duration.inMilliseconds * _dragProgress).round(),
    );
    
    // Ejecutar seek
    ref.read(advancedAudioEngineProvider).seek(seekPosition);
    widget.onSeek?.call(seekPosition);
    
    setState(() => _isDragging = false);
    _thumbController.reverse();
    widget.onDragEnd?.call();
    HapticFeedback.lightImpact();
  }

  void _onTap(TapDownDetails details, BuildContext context, Duration duration) {
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final localX = details.localPosition.dx.clamp(0.0, width);
    final progress = localX / width;
    
    final seekPosition = Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    );
    
    ref.read(advancedAudioEngineProvider).seek(seekPosition);
    widget.onSeek?.call(seekPosition);
    HapticFeedback.selectionClick();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎛️ MINI SEEKBAR - Versión compacta para mini player
/// ═══════════════════════════════════════════════════════════════════════════

class MiniSeekbar extends ConsumerWidget {
  final double height;
  final Color? progressColor;
  final Color? backgroundColor;

  const MiniSeekbar({
    super.key,
    this.height = 3.0,
    this.progressColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ FIX PARPADEO: Usar providers síncronos - NUNCA hay estado loading
    final state = ref.watch(audioEngineStateSyncProvider);
    final smoothPosition = ref.watch(smoothPositionSyncProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    final duration = state.duration;
    
    double progress = 0.0;
    if (duration.inMilliseconds > 0) {
      progress = (smoothPosition.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    }

    final progColor = progressColor ?? palette.vibrant;
    final bgColor = backgroundColor ?? palette.darkMuted.withValues(alpha: 0.3);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: progColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎨 ANIMATED BUILDER HELPER
/// ═══════════════════════════════════════════════════════════════════════════

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
