import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import '../audio/audio_manager.dart';
import 'stable_image_widget.dart';
import 'dart:async';

/// Mini reproductor completamente nuevo y simplificado
/// Garantiza que la barra de progreso funcione correctamente desde 0%
class SimpleMiniPlayer extends ConsumerStatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const SimpleMiniPlayer({
    super.key,
    this.onTap,
    this.onNext,
    this.onPrevious,
  });

  @override
  ConsumerState<SimpleMiniPlayer> createState() => _SimpleMiniPlayerState();
}

class _SimpleMiniPlayerState extends ConsumerState<SimpleMiniPlayer> {
  // Control directo del progreso para evitar problemas
  double _currentProgress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentSongId;
  
  // Timer para actualizar el progreso manualmente
  Timer? _progressTimer;
  
  @override
  void initState() {
    super.initState();
    _startProgressTimer();
  }
  
  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
  
  /// Timer que actualiza el progreso cada 100ms de forma confiable
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      
      try {
        final audioManager = AudioManager();
        final position = audioManager.position;
        final duration = audioManager.duration;
        final currentSong = audioManager.currentSong;
        
        debugPrint('🔍 [SimpleMiniPlayer] Timer - Position: ${position.inSeconds}s, Duration: ${duration.inSeconds}s, Song: ${currentSong?.title}');
        
        // Si cambió la canción, resetear progreso
        if (currentSong?.id != _currentSongId) {
          _currentSongId = currentSong?.id;
          _currentProgress = 0.0;
          _currentPosition = Duration.zero;
          _totalDuration = Duration.zero;
          debugPrint('🔄 [SimpleMiniPlayer] Nueva canción: ${currentSong?.title} - Progreso reseteado');
        }
        
        // Actualizar valores siempre
        _currentPosition = position;
        _totalDuration = duration;
        
        // Calcular progreso de forma segura
        double newProgress = 0.0;
        if (duration.inMilliseconds > 0) {
          newProgress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
          // Sin logs para mejor rendimiento
        }
        
        // Actualizar siempre para asegurar que se muestre
        if (mounted) {
          setState(() {
            _currentProgress = newProgress;
          });
        }
      } catch (e) {
        debugPrint('❌ [SimpleMiniPlayer] Error actualizando progreso: $e');
      }
    });
    
    debugPrint('✅ [SimpleMiniPlayer] Timer iniciado correctamente');
  }

  @override
  Widget build(BuildContext context) {
    // Usar el provider solo para obtener la canción actual y estado de reproducción
    final audioState = ref.watch(unifiedAudioProviderFixed);
    
    // Si no hay canción, no mostrar nada
    if (audioState.currentSong == null) {
      return const SizedBox.shrink();
    }

    final song = audioState.currentSong!;
    final isPlaying = audioState.isPlaying;
    
    // FALLBACK: Si nuestro progreso es 0, usar el del provider
    double displayProgress = _currentProgress;
    if (_currentProgress <= 0.0 && audioState.progress > 0.0) {
      displayProgress = audioState.progress;
      // Sin logs para mejor rendimiento
    }

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
                                AppLogger.error('[SimpleMiniPlayer] Error toggle: $e');
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
            
            // 🚀 BARRA DE PROGRESO SIMPLE Y CONFIABLE
            Container(
              height: 4, // Más alta para ser más visible
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.grey.withValues(alpha: 0.3), // Fondo más visible
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: displayProgress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
                ),
              ),
            ),
            
            // 🔍 INFORMACIÓN DE DEBUG (solo en modo debug)
            if (kDebugMode)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_currentPosition.inSeconds}s / ${_totalDuration.inSeconds}s',
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

/// Widget de progreso detallado para el reproductor completo (reutilizable)
class SimpleDetailedProgressWidget extends ConsumerStatefulWidget {
  const SimpleDetailedProgressWidget({super.key});

  @override
  ConsumerState<SimpleDetailedProgressWidget> createState() => _SimpleDetailedProgressWidgetState();
}

class _SimpleDetailedProgressWidgetState extends ConsumerState<SimpleDetailedProgressWidget> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                AppLogger.error('[SimpleDetailedProgressWidget] Error seek: $e');
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
