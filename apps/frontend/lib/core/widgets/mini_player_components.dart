import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import 'stable_image_widget.dart';
import '../services/audio_service.dart';
import 'package:just_audio/just_audio.dart'; // Para PlayerState
import '../models/song_model.dart'; // Para Song.coverArtUrl
import 'package:marquee/marquee.dart'; // ⚡ PREMIUM: Efecto de desplazamiento

/// ⚡ OPTIMIZACIÓN: Widget separado para la imagen del álbum
/// Solo se reconstruye si cambia la URL de la imagen
/// ✅ FIX PARPADEO: Key única basada en songId para evitar parpadeos durante inserción de anuncios
class _MiniPlayerAlbumImage extends ConsumerWidget {
  final String? coverArtUrl;
  final String? songId; 
  
  const _MiniPlayerAlbumImage({
    required this.coverArtUrl,
    this.songId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ MIRROR PATTERN: Escuchar directamente al stream de secuencia para la carátula
    // Esto garantiza que el cambio automático se detecte incluso si Riverpod tiene retraso
    // ✅ MIRROR PATTERN: Usar DIRECTAMENTE la data que viene del padre (props)
    // El padre (FinalMiniPlayer) ya obtiene la "verdad" desde realCurrentSongProvider.
    // No volver a escuchar el stream aquí porque reintroduce el bug del "zombie tag" (dato viejo).
    
    return RepaintBoundary(
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: NeumorphismTheme.coffeeMedium,
        ),
        child: ClipOval(
          child: coverArtUrl != null && coverArtUrl!.isNotEmpty
              ? StableImageWidget(
                  // ⚡ VALUEKEY: Obligar reconstrucción inmediata si cambia la URL
                  key: ValueKey(coverArtUrl), 
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
      ),
    );
  }
}



/// ⚡ OPTIMIZACIÓN: Widget separado para la información de la canción
/// Solo se reconstruye si cambia el título o artista
class _MiniPlayerSongInfo extends StatelessWidget {
  final String title;
  final String artist;
  
  const _MiniPlayerSongInfo({
    required this.title,
    required this.artist,
  });

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
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
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
      ),
    );
  }
}

/// ⚡ OPTIMIZACIÓN: Widget separado para el botón play/pause
/// Solo se reconstruye si cambia isPlaying
class _MiniPlayerPlayButton extends ConsumerWidget {
  const _MiniPlayerPlayButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        return RepaintBoundary(
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: NeumorphismTheme.coffeeMedium,
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // ✅ ACCIÓN DIRECTA: Sin intermediarios
                  try {
                    if (playing) {
                      await audioService.player.pause();
                    } else {
                      // Usar togglePlayPause del notifier si se quiere la lógica "smart" (replay on completion)
                      // O llamar directamente a audioService.player.play() si confiamos en el fix de playback_notifier
                      // Recomendación: Usar el notifier porque tiene la lógica de "Replay on Completion" y validación de anuncios
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
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ⚡ BARRA DE PROGRESO OPTIMIZADA
/// ✅ Usa el progreso del provider unificado (siempre sincronizado)
/// ✅ RepaintBoundary para optimización de renderizado
class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ MIRROR PATTERN: Sincronización directa con streams del motor de audio
    final audioService = ref.watch(audioServiceProvider);

    // Stream de duración (Outer Stream)
    return StreamBuilder<Duration?>(
      stream: audioService.durationStream,
      builder: (context, durationSnapshot) {
        final totalDuration = durationSnapshot.data ?? Duration.zero;

        // Stream de posición suavizada (Inner Stream) - 60fps fluidos
        return StreamBuilder<Duration>(
          stream: audioService.smoothPositionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            
            double value = 0.0;
            if (totalDuration.inMilliseconds > 0) {
              value = (position.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
            }

            // 🎨 RENDERIZADO: Siempre visible
            return SizedBox(
              height: 2,
              child: RepaintBoundary(
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
                  borderRadius: const BorderRadius.all(Radius.circular(1.0)),
                ),
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

