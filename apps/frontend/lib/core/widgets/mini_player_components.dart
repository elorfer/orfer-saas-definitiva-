import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import 'stable_image_widget.dart';

/// ⚡ OPTIMIZACIÓN: Widget separado para la imagen del álbum
/// Solo se reconstruye si cambia la URL de la imagen
class _MiniPlayerAlbumImage extends StatelessWidget {
  final String? coverArtUrl;
  
  const _MiniPlayerAlbumImage({
    required this.coverArtUrl,
  });

  @override
  Widget build(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: NeumorphismTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            artist,
            style: GoogleFonts.inter(
              color: NeumorphismTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    // ⚡ OPTIMIZACIÓN: Solo escuchar isPlaying, no todo el estado
    final isPlaying = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlaying),
    );
    
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
              try {
                await ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
              } catch (e) {
                AppLogger.error('[MiniPlayerPlayButton] Error toggle: $e');
              }
            },
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ⚡ OPTIMIZACIÓN: Widget separado para la barra de progreso
/// Solo se reconstruye si cambia el progreso
/// ✅ PROTECCIÓN: Evita parpadeos cuando el progreso se resetea temporalmente
class _MiniPlayerProgressBar extends ConsumerStatefulWidget {
  const _MiniPlayerProgressBar();

  @override
  ConsumerState<_MiniPlayerProgressBar> createState() => _MiniPlayerProgressBarState();
}

class _MiniPlayerProgressBarState extends ConsumerState<_MiniPlayerProgressBar> {
  // ✅ PROTECCIÓN: Guardar último progreso válido para evitar saltos a 0
  double? _lastValidProgress;
  // ✅ PROTECCIÓN: Guardar ID de la última canción para detectar cambios
  String? _lastSongId;

  @override
  Widget build(BuildContext context) {
    // ✅ PROTECCIÓN: Observar también el ID de la canción para detectar cambios
    final currentSongId = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong?.id),
    );
    // ⚡ OPTIMIZACIÓN: Solo escuchar progress, no todo el estado
    final progress = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.progress),
    );
    
    // ✅ PROTECCIÓN: Si cambió la canción, resetear el progreso guardado
    if (currentSongId != null && currentSongId != _lastSongId) {
      _lastSongId = currentSongId;
      _lastValidProgress = null; // Resetear progreso guardado cuando cambia la canción
    }
    
    // ✅ PROTECCIÓN: Evitar saltos a 0 cuando el progreso se resetea temporalmente
    // Solo usar el progreso del estado si es válido (mayor que 0) o si no tenemos un progreso guardado
    double effectiveProgress = progress.clamp(0.0, 1.0);
    if (effectiveProgress == 0.0 && _lastValidProgress != null && _lastValidProgress! > 0.0 && currentSongId == _lastSongId) {
      // Si el progreso es 0 pero tenemos un progreso válido guardado Y es la misma canción, mantenerlo
      // Esto evita que la barra parpadee cuando se sincroniza el estado
      effectiveProgress = _lastValidProgress!;
    } else if (effectiveProgress > 0.0) {
      // Guardar el último progreso válido
      _lastValidProgress = effectiveProgress;
    }
    
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: effectiveProgress.clamp(0.0, 1.0),
        backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
        valueColor: const AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
        borderRadius: const BorderRadius.all(Radius.circular(1.5)),
      ),
    );
  }
}

/// ⚡ EXPORT: Componentes optimizados para uso en MiniPlayer
class MiniPlayerComponents {
  static Widget albumImage(String? coverArtUrl) => _MiniPlayerAlbumImage(coverArtUrl: coverArtUrl);
  static Widget songInfo(String title, String artist) => _MiniPlayerSongInfo(title: title, artist: artist);
  static Widget playButton() => const _MiniPlayerPlayButton();
  static Widget progressBar() => const _MiniPlayerProgressBar();
}

