import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_service.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎚️ SMOOTH SEEKBAR - BARRA DE PROGRESO SIN PARPADEO
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Características:
/// - 🌐 Single Source of Truth: ValueNotifier global compartido
/// - Sincronización perfecta entre Mini Player y Reproductor Extendido
/// - Buffer progress visualizado
/// - Gestos de drag suaves con feedback háptico
/// - Animaciones de entrada/hover
/// - Compatible con el sistema de reproducción existente
/// ═══════════════════════════════════════════════════════════════════════════

class SmoothSeekbar extends ConsumerStatefulWidget {
  /// Altura total del widget (incluyendo área de toque)
  final double height;
  
  /// Altura de la barra de progreso
  final double trackHeight;
  
  /// Radio del thumb
  final double thumbRadius;
  
  /// Mostrar tiempos (posición / duración)
  final bool showTimes;
  
  /// Estilo de tiempo
  final TextStyle? timeStyle;
  
  /// Color de la barra de progreso activa
  final Color? activeColor;
  
  /// Color del buffer
  final Color? bufferedColor;
  
  /// Color del fondo (track inactivo)
  final Color? inactiveColor;
  
  /// Color del thumb
  final Color? thumbColor;
  
  /// Mostrar tooltip al arrastrar
  final bool showTooltip;
  
  /// Estilo del tooltip
  final TextStyle? tooltipStyle;
  
  /// Habilitado o deshabilitado
  final bool enabled;
  
  /// Callback cuando empieza el drag
  final VoidCallback? onSeekStart;
  
  /// Callback cuando termina el drag
  final void Function(Duration position)? onSeekEnd;
  
  /// Callback cuando cambia la posición durante el drag
  final void Function(Duration position)? onSeekChange;
  
  /// Callback legacy (mantener compatibilidad)
  final void Function(Duration position)? onSeek;

  const SmoothSeekbar({
    super.key,
    this.height = 40.0,
    this.trackHeight = 4.0,
    this.thumbRadius = 8.0,
    this.showTimes = true,
    this.timeStyle,
    this.activeColor,
    this.bufferedColor,
    this.inactiveColor,
    this.thumbColor,
    this.showTooltip = false,
    this.tooltipStyle,
    this.enabled = true,
    this.onSeekStart,
    this.onSeekEnd,
    this.onSeekChange,
    this.onSeek,
  });

  @override
  ConsumerState<SmoothSeekbar> createState() => _SmoothSeekbarState();
}

class _SmoothSeekbarState extends ConsumerState<SmoothSeekbar>
    with SingleTickerProviderStateMixin {
  // Estado de drag
  bool _isDragging = false;
  double _dragProgress = 0.0;
  
  //  FIX PARPADEO: Detectar saltos grandes (cambio de canción)
  double _lastProgress = 0.0;
  String? _lastSongId; // 🛠️ FIX: Tracking de song ID para detectar cambios
  
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
    // 🌐 SINGLE SOURCE OF TRUTH: Usar ValueNotifiers globales (sin buffer)
    final positionNotifier = ref.watch(globalPositionNotifierProvider);
    final durationNotifier = ref.watch(globalDurationNotifierProvider);
    
    // ValueListenableBuilder es más rápido que StreamProvider
    // 🆕 FIX PARPADEO: Eliminado AnimatedOpacity/fade-in que causaba parpadeo al reconstruir
    return ValueListenableBuilder<Duration>(
      valueListenable: positionNotifier,
      builder: (context, position, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: durationNotifier,
          builder: (context, duration, _) {
            return _buildSeekbar(context, position, duration);
          },
        );
      },
    );
  }

  Widget _buildSeekbar(
    BuildContext context,
    Duration position,
    Duration duration,
  ) {
    // Calcular progreso
    double progress = 0.0;
    
    if (duration.inMilliseconds > 0) {
      progress = _isDragging
          ? _dragProgress
          : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    }

    // 🆕 FIX PARPADEO: Detectar cambio de canción o salto grande
    // 🛠️ FIX CRÍTICO: Usar ref.watch para detectar cambios reactivamente
    final currentSongId = ref.watch(unifiedAudioProviderFixed.select((state) => state.currentSong?.id));
    final songChanged = currentSongId != _lastSongId && _lastSongId != null;
    
    // 🛠️ FIX CRÍTICO: Resetear _lastProgress cuando cambia la canción
    // Esto fuerza que la barra empiece desde 0% en la nueva canción
    if (songChanged) {
      _lastProgress = 0.0;
    }
    
    // Si hay un salto > 30% hacia atrás hacia el inicio, NO animar
    final bigJump = (_lastProgress - progress).abs() > 0.3 && progress < 0.1;
    final skipAnimation = (songChanged || bigJump) && !_isDragging;
    
    // Actualizar estado para próxima comparación
    _lastProgress = progress;
    _lastSongId = currentSongId;

    // Duración de animación: 0 si hay salto grande
    final animDuration = (skipAnimation || _isDragging) 
        ? Duration.zero 
        : const Duration(milliseconds: 50);

    // 🆕 FIX PERFORMANCE: Simular opacidad con alpha directamente en los colores
    final double opacityFactor = widget.enabled ? 1.0 : 0.5;

    // Colores (sin buffer)
    final progressColor = (widget.activeColor ?? NeumorphismTheme.coffeeMedium)
        .withValues(alpha: (widget.activeColor?.a ?? 1.0) * opacityFactor);
        
    final baseBgColor = widget.inactiveColor ?? NeumorphismTheme.textSecondary.withValues(alpha: 0.2);
    final bgColor = baseBgColor.withValues(alpha: baseBgColor.a * opacityFactor);
    
    final thumbColorBase = widget.thumbColor ?? progressColor;
    // El thumbColor ya tiene la opacidad aplicada si usa progressColor, si no, aplicarla
    final effectiveThumbColor = widget.thumbColor != null 
        ? thumbColorBase.withValues(alpha: thumbColorBase.a * opacityFactor)
        : progressColor; // Ya tiene el factor aplicado

    // Posición para mostrar
    final displayPosition = _isDragging
        ? Duration(milliseconds: (duration.inMilliseconds * _dragProgress).round())
        : position;

    // OPTIMIZACIÓN: Opacidad simulada con alpha en los colores del SliderTheme
    // Evita crear un layer costoso para el widget Opacity
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Barra de progreso
        GestureDetector(
          behavior: widget.enabled ? HitTestBehavior.opaque : HitTestBehavior.translucent,
          onHorizontalDragStart: widget.enabled ? (details) => _onDragStart(details, context) : null,
          onHorizontalDragUpdate: widget.enabled ? (details) => _onDragUpdate(details, context) : null,
          onHorizontalDragEnd: widget.enabled ? (details) => _onDragEnd(details, duration) : null,
          onTapDown: widget.enabled ? (details) => _onTap(details, context, duration) : null,
          child: MouseRegion(
            onEnter: (_) => _thumbController.forward(),
            onExit: (_) {
              if (!_isDragging) _thumbController.reverse();
            },
            child: Container(
              height: widget.height, // Altura total del widget (área táctil)
              alignment: Alignment.center,
              child: SizedBox(
                height: math.max(widget.trackHeight, widget.thumbRadius * 2),
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
                          height: widget.trackHeight,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(widget.trackHeight / 2),
                          ),
                        ),

                        // Progreso (sin barra de buffer) - 🆕 usa animDuration dinámico
                        AnimatedContainer(
                          duration: animDuration,
                          height: widget.trackHeight,
                          width: width * progress,
                          decoration: BoxDecoration(
                            color: progressColor,
                            borderRadius: BorderRadius.circular(widget.trackHeight / 2),
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
                                  color: effectiveThumbColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: effectiveThumbColor.withValues(alpha: 0.5 * opacityFactor),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Tooltip durante drag
                        if (_isDragging && widget.showTooltip)
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
                                style: widget.tooltipStyle ?? const TextStyle(
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
        if (widget.showTimes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(displayPosition),
                  style: widget.timeStyle ?? TextStyle(
                    fontSize: 12,
                    color: NeumorphismTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: widget.timeStyle ?? TextStyle(
                    fontSize: 12,
                    color: NeumorphismTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    ); // Cierre de Opacity
  }

  void _onDragStart(DragStartDetails details, BuildContext context) {
    if (!widget.enabled) return;
    
    // 🛡️ SEEKING GUARD: Activar bloqueo de stream
    final audioService = ref.read(audioServiceProvider);
    final duration = ref.read(unifiedAudioProviderFixed).totalDuration;
    
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final localX = details.localPosition.dx.clamp(0.0, width);
    final startProgress = localX / width;
    final startPosition = Duration(
      milliseconds: (duration.inMilliseconds * startProgress).round(),
    );
    
    audioService.startSeekingGuard(startPosition);
    
    setState(() {
      _isDragging = true;
      _dragProgress = startProgress;
    });
    _thumbController.forward();
    HapticFeedback.lightImpact();
    widget.onSeekStart?.call();
  }

  void _onDragUpdate(DragUpdateDetails details, BuildContext context) {
    if (!widget.enabled) return;
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final localX = details.localPosition.dx.clamp(0.0, width);
    
    setState(() {
      _dragProgress = localX / width;
    });
    
    // 🛡️ SEEKING GUARD: Actualizar posición del usuario en tiempo real
    final duration = ref.read(unifiedAudioProviderFixed).totalDuration;
    final dragPosition = Duration(
      milliseconds: (duration.inMilliseconds * _dragProgress).round(),
    );
    
    // Actualizar posición suavizada con la posición del drag
    final audioService = ref.read(audioServiceProvider);
    audioService.forceSmoothPositionUpdate(dragPosition);
    
    widget.onSeekChange?.call(dragPosition);
  }

  void _onDragEnd(DragEndDetails details, Duration duration) {
    if (!widget.enabled) return;
    final seekPosition = Duration(
      milliseconds: (duration.inMilliseconds * _dragProgress).round(),
    );
    
    // 🛡️ SEEKING GUARD: Finalizar bloqueo ANTES del seek real
    final audioService = ref.read(audioServiceProvider);
    
    // Ejecutar seek usando el sistema existente
    audioService.seek(seekPosition);
    
    // Finalizar guard con delay (mantiene bloqueo 500ms más)
    audioService.endSeekingGuard(seekPosition);
    
    widget.onSeek?.call(seekPosition);
    widget.onSeekEnd?.call(seekPosition);
    
    setState(() => _isDragging = false);
    _thumbController.reverse();
    HapticFeedback.lightImpact();
  }

  void _onTap(TapDownDetails details, BuildContext context, Duration duration) {
    if (!widget.enabled) return;
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final localX = details.localPosition.dx.clamp(0.0, width);
    final progress = localX / width;
    
    final seekPosition = Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    );
    
    // 🛡️ SEEKING GUARD: Para tap también activar/desactivar guard
    final audioService = ref.read(audioServiceProvider);
    audioService.startSeekingGuard(seekPosition);
    
    widget.onSeekStart?.call();
    audioService.seek(seekPosition);
    
    // Finalizar guard con delay
    audioService.endSeekingGuard(seekPosition);
    
    widget.onSeek?.call(seekPosition);
    widget.onSeekEnd?.call(seekPosition);
    HapticFeedback.selectionClick();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎛️ MINI SMOOTH SEEKBAR - Versión compacta para mini player
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// 🌐 SINGLE SOURCE OF TRUTH: Usa el mismo ValueNotifier que el Seekbar grande
/// Esto garantiza sincronización perfecta entre Mini y Extendido
/// ═══════════════════════════════════════════════════════════════════════════

class MiniSmoothSeekbar extends ConsumerStatefulWidget {
  final double height;
  final Color? progressColor;
  final Color? backgroundColor;

  const MiniSmoothSeekbar({
    super.key,
    this.height = 3.0,
    this.progressColor,
    this.backgroundColor,
  });

  @override
  ConsumerState<MiniSmoothSeekbar> createState() => _MiniSmoothSeekbarState();
}

class _MiniSmoothSeekbarState extends ConsumerState<MiniSmoothSeekbar> {
  // 🆕 FIX PARPADEO: Detectar saltos grandes
  double _lastProgress = 0.0;
  bool _skipNextAnimation = false;

  @override
  Widget build(BuildContext context) {
    // 🌐 SINGLE SOURCE OF TRUTH: Mismo ValueNotifier que el Seekbar grande
    final positionNotifier = ref.watch(globalPositionNotifierProvider);
    final durationNotifier = ref.watch(globalDurationNotifierProvider);
    
    return ValueListenableBuilder<Duration>(
      valueListenable: positionNotifier,
      builder: (context, position, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: durationNotifier,
          builder: (context, duration, _) {
            double progress = 0.0;
            if (duration.inMilliseconds > 0) {
              progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
            }
            
            // 🆕 FIX PARPADEO: Detectar salto grande hacia atrás
            final bigJump = (_lastProgress - progress).abs() > 0.3 && progress < 0.1;
            _skipNextAnimation = bigJump;
            _lastProgress = progress;
            
            return _buildMiniBar(progress);
          },
        );
      },
    );
  }
  
  Widget _buildMiniBar(double progress) {
    final progColor = widget.progressColor ?? NeumorphismTheme.coffeeMedium;
    final bgColor = widget.backgroundColor ?? NeumorphismTheme.textSecondary.withValues(alpha: 0.2);

    // 🆕 Usar AnimatedContainer con duración 0 cuando hay salto
    final animDuration = _skipNextAnimation ? Duration.zero : const Duration(milliseconds: 100);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: AnimatedAlign(
        duration: animDuration,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          child: AnimatedContainer(
            duration: animDuration,
            decoration: BoxDecoration(
              color: progColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
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
