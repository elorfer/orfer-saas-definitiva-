import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../providers/theme_provider.dart'; // 🚀 Importar para reactividad de colores
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import 'stable_image_widget.dart';
import '../services/audio_service.dart';
import 'package:just_audio/just_audio.dart'; // Para PlayerState
// Para Song.coverArtUrl
import 'package:marquee/marquee.dart'; // ⚡ PREMIUM: Efecto de desplazamiento

/// ⚡ OPTIMIZACIÓN: Widget separado para la imagen del álbum
/// Solo se reconstruye si cambia la URL de la imagen
class _MiniPlayerAlbumImage extends ConsumerWidget {
  final String? coverArtUrl;
  final String? songId; 
  
  const _MiniPlayerAlbumImage({
    required this.coverArtUrl,
    this.songId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎨 FIX: Observar el tema
    ref.watch(themeProvider);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NeumorphismTheme.coffeeMedium,
      ),
      child: ClipOval(
        child: coverArtUrl != null && coverArtUrl!.isNotEmpty
            ? StableImageWidget(
                key: ValueKey('mini_${songId ?? 'unknown'}'),
                imageUrl: coverArtUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorWidget: const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 20,
                ),
              )
            : const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }
}



/// ⚡ OPTIMIZACIÓN: Widget separado para la información de la canción
/// Solo se reconstruye si cambia el título o artista
class _MiniPlayerSongInfo extends ConsumerWidget {
  final String title;
  final String artist;
  
  const _MiniPlayerSongInfo({
    required this.title,
    required this.artist,
  });

  // ... (buildScrollingText method remains the same)

  Widget _buildScrollingText(String text, TextStyle style) {
    // ⚡ LÓGICA MIXTA: "Oro Puro" de UX
    // Si el texto es corto, no animamos (ahorro CPU).
    // Si es largo, Marquee profesional con pausas y fading edges.
    if (text.length <= 25) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    return SizedBox(
      height: 20, // Altura fija necesaria para Marquee
      child: Marquee(
        text: text,
        style: style,
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        blankSpace: 30.0,
        velocity: 30.0, // ⚡ Ajustado a 30 para más fluidez
        pauseAfterRound: const Duration(seconds: 2),
        startPadding: 0.0,
        accelerationDuration: const Duration(seconds: 1),
        accelerationCurve: Curves.easeInOut, // ⚡ Curva más natural
        decelerationDuration: const Duration(milliseconds: 500),
        decelerationCurve: Curves.easeInOut,
        fadingEdgeStartFraction: 0.1, // ⚡ TOQUE DE DISEÑO PRO
        fadingEdgeEndFraction: 0.1,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎨 FIX: Observar el tema
    ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Título con lógica inteligente
        _buildScrollingText(
          title,
          GoogleFonts.inter(
            color: NeumorphismTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2), // Un poco más de aire
        
        // Artista (generalmente más corto, pero aplicamos la misma lógica por consistencia)
        _buildScrollingText(
           artist,
           GoogleFonts.inter(
            color: NeumorphismTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// ⚡ OPTIMIZACIÓN: Widget separado para el botón play/pause
/// Solo se reconstruye si cambia isPlaying
class _MiniPlayerPlayButton extends ConsumerWidget {
  const _MiniPlayerPlayButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎨 FIX: Observar el tema
    ref.watch(themeProvider);

    // ✅ MIRROR PATTERN: Acceso directo al servicio de audio (Single Instance)
    final audioService = ref.watch(audioServiceProvider);

    return StreamBuilder<PlayerState>(
      stream: audioService.player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;
        final processingState = playerState?.processingState;
        
        // ⚡ DETERMINAR ESTADO REAL:
        // Si está "playing" (intención de usuario), mostramos Pause.
        // Excepto si ya terminó (completed), donde mostramos Play (ya cubierto por el fix anterior, 
        // pero aquí confirmamos visualmente).
        final showPause = playing && processingState != ProcessingState.completed;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: NeumorphismTheme.isDark ? NeumorphismTheme.accent : NeumorphismTheme.coffeeMedium,
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                HapticFeedback.lightImpact();
                try {
                  if (playing) {
                    await audioService.player.pause();
                  } else {
                    await ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
                  }
                } catch (e) {
                  AppLogger.error('[MiniPlayerPlayButton] Error toggle: $e');
                }
              },
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              child: Center(
                child: Icon(
                  showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: NeumorphismTheme.isDark ? NeumorphismTheme.coffeeDark : Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ⚡ BARRA DE PROGRESO PROFESIONAL
/// ✅ SOLUCIÓN PROFESIONAL: TweenAnimationBuilder para interpolación suave
/// ✅ Anti-retroceso: Solo permite avance, nunca retroceso
/// ✅ Detecta cambio de canción para resetear correctamente
class _MiniPlayerProgressBar extends ConsumerStatefulWidget {
  const _MiniPlayerProgressBar();

  @override
  ConsumerState<_MiniPlayerProgressBar> createState() => _MiniPlayerProgressBarState();
}

/// ✅ SOLUCIÓN PROFESIONAL: Control manual del stream con pausa/reanudación
class _MiniPlayerProgressBarState extends ConsumerState<_MiniPlayerProgressBar> {
  double _maxProgress = 0.0;
  String? _currentSongId;
  bool? _wasPlayingAd;
  bool _isFrozen = false; // ✅ Flag de freeze simple y directo
  
  @override
  Widget build(BuildContext context) {
    // 🎨 FIX: Observar el tema
    ref.watch(themeProvider);

    final currentSong = ref.watch(realCurrentSongProvider);
    final currentSongId = currentSong?.id;
    final isPlayingAd = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
    );
    
    // ✅ DETECCIÓN PROFESIONAL: Transición Ad→Song
    if (_wasPlayingAd == true && isPlayingAd == false) {
      AppLogger.info('[MiniProgressBar] 🔄 Ad→Song: CONGELANDO por 1s');
      _isFrozen = true;
      _maxProgress = 0.0;
      _currentSongId = currentSongId;
      
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _isFrozen = false;
            AppLogger.debug('[MiniProgressBar] 🔓 Descongelado');
          });
        }
      });
    }
    _wasPlayingAd = isPlayingAd;
    
    // ✅ DETECCIÓN PROFESIONAL: Cambio abrupto de canción
    if (currentSongId != _currentSongId) {
      if (_maxProgress > 0.05 && !isPlayingAd) {
        AppLogger.info('[MiniProgressBar] 🔄 Cambio abrupto: CONGELANDO por 1s');
        _isFrozen = true;
        
        // ✅ FIX CRÍTICO: Programar descongelamiento (faltaba esto)
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _isFrozen = false;
              AppLogger.debug('[MiniProgressBar] 🔓 Descongelado (Cambio Canción)');
            });
          }
        });
      }
      _currentSongId = currentSongId;
      _maxProgress = 0.0;
    }
    
    // ✅ SOLUCIÓN PROFESIONAL: Barra simple sin StreamBuilder
    final audioService = ref.watch(audioServiceProvider);
    
    // Si está congelado, retornar LinearProgressIndicator directo en 0
    if (_isFrozen) {
      return SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          value: 0.0,
          backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
          borderRadius: const BorderRadius.all(Radius.circular(1.0)),
        ),
      );
    }
    
    // ✅ MODO NORMAL: StreamBuilder simple SIN TweenAnimationBuilder
    return StreamBuilder<Duration?>(
      stream: audioService.durationStream,
      builder: (context, durationSnapshot) {
        final totalDuration = durationSnapshot.data ?? Duration.zero;
        
        return StreamBuilder<Duration>(
          stream: audioService.smoothPositionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            
            double currentProgress = 0.0;
            if (totalDuration.inMilliseconds > 0) {
              currentProgress = (position.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
            }
            
            // Anti-retroceso simple
            final likelyNewSong = currentProgress < 0.05 && _maxProgress > 0.2;
            if (likelyNewSong) {
              _maxProgress = currentProgress;
            }
            
            // 🏆 PRO-LEVEL JITTER FILTER: Time-Based (not percentage-based)
            // Esto garantiza precisión absoluta en canciones de cualquier duración.
            
            // Convertir a milisegundos para comparación precisa
            final currentMs = position.inMilliseconds;
            final maxMs = (_maxProgress * totalDuration.inMilliseconds).round();
            
            // 1. Si avanzamos, siempre actualizamos
            if (currentMs >= maxMs) {
              _maxProgress = currentProgress;
            } 
            // 2. Si retrocedemos, usamos umbral de tiempo (250ms)
            else {
              final diffMs = maxMs - currentMs;
              
              // Si el salto es mayor a 250ms, es un SEEK intencional (o loop).
              // Si es menor, es JITTER técnico del stream y lo ignoramos.
              if (diffMs > 250) {
                 _maxProgress = currentProgress;
              }
              // else: ignorar jitter, mantener _maxProgress anterior
            }
            
            // ✅ OPTIMIZACIÓN EXTREMA: Eliminar TweenAnimationBuilder
            // El stream de smoothPositionStream ya emite 20 veces por segundo (50ms).
            // Tratar de animar iteraciones de 50ms de forma continua encola miles de
            // animaciones superpuestas del AnimationController, estrangulando el hilo UI y causando ANR.
            // Para audio, pintar directamente a 20 FPS es suficientemente suave e infinitamente más ligero.
            return SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: _maxProgress,
                backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
                borderRadius: const BorderRadius.all(Radius.circular(1.0)),
              ),
            );
          },
        );
      },
    );
  }
}

/// ⚡ EXPORT: Componentes optimizados para uso en MiniPlayer
class MiniPlayerComponents {
  static Widget albumImage(String? coverArtUrl, {String? songId}) => _MiniPlayerAlbumImage(coverArtUrl: coverArtUrl, songId: songId);
  static Widget songInfo(String title, String artist) => _MiniPlayerSongInfo(title: title, artist: artist);
  static Widget playButton() => const _MiniPlayerPlayButton();
  static Widget progressBar() => const _MiniPlayerProgressBar();
}

