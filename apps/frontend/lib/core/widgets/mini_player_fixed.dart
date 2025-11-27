import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import '../audio/audio_manager.dart';
import 'stable_image_widget.dart';

/// Mini reproductor que muestra la barra de progreso correctamente
/// Usa el provider unificado corregido como ÚNICA FUENTE DE VERDAD
class MiniPlayerFixed extends ConsumerStatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const MiniPlayerFixed({
    super.key,
    this.onTap,
    this.onNext,
    this.onPrevious,
  });

  @override
  ConsumerState<MiniPlayerFixed> createState() => _MiniPlayerFixedState();
}

class _MiniPlayerFixedState extends ConsumerState<MiniPlayerFixed> {
  // Fallback usando AudioManager directamente
  Duration _fallbackPosition = Duration.zero;
  Duration _fallbackDuration = Duration.zero;
  
  // Control de estado para detectar canciones nuevas
  String? _lastSongId;
  bool _isNewSong = false;
  
  @override
  void initState() {
    super.initState();
    // Forzar inicialización del provider al crear el widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureProviderInitialized();
      _setupFallbackListeners();
    });
  }

  void _ensureProviderInitialized() {
    try {
      // Forzar inicialización del provider
      final notifier = ref.read(unifiedAudioProviderFixed.notifier);
      notifier.ensureInitialized();
      debugPrint('🔍 [MiniPlayer] Provider inicializado correctamente');
    } catch (e) {
      debugPrint('🔍 [MiniPlayer] Error inicializando provider: $e');
    }
  }

  void _setupFallbackListeners() {
    try {
      // Listener de fallback usando AudioManager directamente
      final audioManager = AudioManager();
      
      audioManager.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _fallbackPosition = position;
          });
        }
      });
      
      audioManager.durationStream.listen((duration) {
        if (mounted) {
          setState(() {
            _fallbackDuration = duration;
          });
        }
      });
      
      debugPrint('🔍 [MiniPlayer] Listeners de fallback configurados');
    } catch (e) {
      debugPrint('🔍 [MiniPlayer] Error configurando fallback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 USAR EL PROVIDER UNIFICADO CORREGIDO - ÚNICA FUENTE DE VERDAD
    final audioState = ref.watch(unifiedAudioProviderFixed);
    
    // Debug: Verificar estado del audio
    debugPrint('🔍 [MiniPlayer] Estado: canción=${audioState.currentSong?.title}, playing=${audioState.isPlaying}, progress=${audioState.progress.toStringAsFixed(2)}');
    debugPrint('🔍 [MiniPlayer] Posiciones: current=${audioState.currentPosition.inMilliseconds}ms, total=${audioState.totalDuration.inMilliseconds}ms');
    
    // Si no hay canción, no mostrar nada
    if (audioState.currentSong == null) {
      return const SizedBox.shrink();
    }

    final song = audioState.currentSong!;
    final isPlaying = audioState.isPlaying;
    
    // Detectar si es una canción nueva
    if (_lastSongId != song.id) {
      _lastSongId = song.id;
      _isNewSong = true;
      debugPrint('🔍 [MiniPlayer] 🆕 Nueva canción detectada: ${song.title}');
      
      // Resetear fallback para nueva canción
      _fallbackPosition = Duration.zero;
      _fallbackDuration = Duration.zero;
    }
    
    // Calcular progreso con fallback y validaciones
    double progress = audioState.progress;
    Duration currentPosition = audioState.currentPosition;
    Duration totalDuration = audioState.totalDuration;
    
    // SOLUCIÓN CRÍTICA: Si es una canción nueva y el progreso es sospechosamente alto, forzar a 0
    if (_isNewSong && progress > 0.1 && currentPosition.inSeconds < 10) {
      debugPrint('🔍 [MiniPlayer] 🔧 CORRECCIÓN: Canción nueva con progreso alto (${(progress * 100).toStringAsFixed(1)}%) - forzando a 0%');
      progress = 0.0;
      currentPosition = Duration.zero;
    }
    
    // Marcar que ya no es nueva después de unos segundos
    if (_isNewSong && currentPosition.inSeconds > 5) {
      _isNewSong = false;
      debugPrint('🔍 [MiniPlayer] ✅ Canción ya no es nueva');
    }
    
    // VALIDACIÓN CRÍTICA: Si no hay duración total, el progreso debe ser 0
    if (totalDuration.inMilliseconds <= 0) {
      progress = 0.0;
      debugPrint('🔍 [MiniPlayer] ⚠️ Sin duración total - forzando progreso a 0%');
    }
    // VALIDACIÓN CRÍTICA: Si la posición es mayor que la duración, hay un error
    else if (currentPosition.inMilliseconds > totalDuration.inMilliseconds) {
      progress = 1.0;
      debugPrint('🔍 [MiniPlayer] ⚠️ Posición mayor que duración - forzando progreso a 100%');
    }
    // VALIDACIÓN CRÍTICA: Recalcular progreso manualmente para verificar
    else if (totalDuration.inMilliseconds > 0) {
      final calculatedProgress = (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
      if ((calculatedProgress - progress).abs() > 0.01) {
        debugPrint('🔍 [MiniPlayer] ⚠️ Discrepancia en progreso: provider=${(progress * 100).toStringAsFixed(1)}%, calculado=${(calculatedProgress * 100).toStringAsFixed(1)}%');
        progress = calculatedProgress; // Usar el calculado manualmente
      }
    }
    
    // Usar fallback si el provider no tiene datos válidos
    if (progress <= 0.0 && _fallbackDuration.inSeconds > 0) {
      currentPosition = _fallbackPosition;
      totalDuration = _fallbackDuration;
      progress = totalDuration.inMilliseconds > 0 
          ? (_fallbackPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;
      debugPrint('🔍 [MiniPlayer] Usando fallback - Progress: ${(progress * 100).toStringAsFixed(1)}%');
    }

    // Debug: Verificar progreso final
    debugPrint('🔍 [MiniPlayer] Progreso final: ${(progress * 100).toStringAsFixed(1)}% (${currentPosition.inSeconds}s / ${totalDuration.inSeconds}s)');

    return GestureDetector(
      onTap: widget.onTap,
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
                  
                  // Controles
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón anterior
                      if (widget.onPrevious != null)
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous,
                            color: NeumorphismTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: widget.onPrevious,
                        ),
                      
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
                                AppLogger.error('[MiniPlayerFixed] Error toggle: $e');
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
                      
                      // Botón siguiente
                      if (widget.onNext != null)
                        IconButton(
                          icon: const Icon(
                            Icons.skip_next,
                            color: NeumorphismTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: widget.onNext,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 🚀 BARRA DE PROGRESO - CRÍTICA PARA MOSTRAR EL AVANCE
            // Barra de progreso mejorada con fallback y debug
            _EnhancedProgressBar(
              progress: progress,
              currentPosition: currentPosition,
              totalDuration: totalDuration,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            
            // 🔧 BARRA DE PROGRESO ALTERNATIVA (para debug)
            if (progress <= 0.0 && totalDuration.inSeconds > 0)
              Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: LinearProgressIndicator(
                  backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium.withValues(alpha: 0.5)),
                ),
              ),
            
            // 🔍 INFORMACIÓN DE DEBUG (temporal)
            if (kDebugMode)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Debug: ${currentPosition.inSeconds}s / ${totalDuration.inSeconds}s (${(progress * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Barra de progreso mejorada que siempre funciona
class _EnhancedProgressBar extends StatelessWidget {
  final double progress;
  final Duration currentPosition;
  final Duration totalDuration;
  final double height;
  final EdgeInsets margin;

  const _EnhancedProgressBar({
    required this.progress,
    required this.currentPosition,
    required this.totalDuration,
    required this.height,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    // Clamp para seguridad
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    // Debug más frecuente para detectar el problema
    debugPrint('🔍 [ProgressBar] Renderizando con progress: ${(clampedProgress * 100).toStringAsFixed(1)}% (${currentPosition.inSeconds}s / ${totalDuration.inSeconds}s)');
    
    // VALIDACIÓN ADICIONAL: Si el progreso es sospechosamente alto al inicio
    if (clampedProgress > 0.9 && currentPosition.inSeconds < 5) {
      debugPrint('🔍 [ProgressBar] ⚠️ PROBLEMA DETECTADO: Progreso muy alto (${(clampedProgress * 100).toStringAsFixed(1)}%) con posición baja (${currentPosition.inSeconds}s)');
      debugPrint('🔍 [ProgressBar] ⚠️ Valores: position=${currentPosition.inMilliseconds}ms, duration=${totalDuration.inMilliseconds}ms');
    }

    return Container(
      height: height,
      margin: margin,
      child: CustomPaint(
        painter: _ProgressBarPainter(
          progress: clampedProgress,
          backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
          progressColor: NeumorphismTheme.coffeeMedium,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}


/// CustomPainter optimizado para mejor rendimiento que LinearProgressIndicator
class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _ProgressBarPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    
    final backgroundRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(backgroundRect, backgroundPaint);

    // Progreso
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      
      final progressWidth = size.width * progress;
      final progressRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, progressWidth, size.height),
        Radius.circular(size.height / 2),
      );
      canvas.drawRRect(progressRect, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Widget de progreso detallado para el reproductor completo
class DetailedProgressWidget extends ConsumerStatefulWidget {
  const DetailedProgressWidget({super.key});

  @override
  ConsumerState<DetailedProgressWidget> createState() => _DetailedProgressWidgetState();
}

class _DetailedProgressWidgetState extends ConsumerState<DetailedProgressWidget> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 USAR EL PROVIDER UNIFICADO CORREGIDO
    final audioState = ref.watch(unifiedAudioProviderFixed);
    
    final currentPosition = audioState.currentPosition;
    final totalDuration = audioState.totalDuration;
    final progress = _isDragging ? _dragValue : audioState.progress;

    return Column(
      children: [
        // Slider de progreso
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: NeumorphismTheme.coffeeMedium,
            inactiveTrackColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
            thumbColor: NeumorphismTheme.coffeeMedium,
            overlayColor: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) {
              setState(() {
                _isDragging = true;
                _dragValue = value;
              });
            },
            onChangeEnd: (value) async {
              try {
                if (totalDuration.inSeconds > 0) {
                  final seekPosition = Duration(
                    seconds: (value * totalDuration.inSeconds).toInt(),
                  );
                  await ref.read(unifiedAudioProviderFixed.notifier).seek(seekPosition);
                }
              } catch (e) {
                AppLogger.error('[DetailedProgressWidget] Error seek: $e');
              } finally {
                if (mounted) {
                  setState(() {
                    _isDragging = false;
                    _dragValue = 0.0;
                  });
                }
              }
            },
          ),
        ),
        
        // Tiempos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(currentPosition),
                style: GoogleFonts.inter(
                  color: NeumorphismTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(totalDuration),
                style: GoogleFonts.inter(
                  color: NeumorphismTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
