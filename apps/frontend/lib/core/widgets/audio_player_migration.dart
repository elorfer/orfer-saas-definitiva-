import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'bottom_player.dart'; // BottomPlayer deshabilitado
import 'professional_audio_player.dart';
import '../providers/professional_audio_provider.dart';
import '../utils/logger.dart';

/// Enumeración para el tipo de reproductor a usar
enum AudioPlayerType {
  /// Reproductor básico (original)
  basic,
  
  /// Reproductor profesional (nuevo)
  professional,
  
  /// Auto-detecta según configuración
  auto,
}

// Variable global para el tipo de reproductor (simplificado)
AudioPlayerType _currentAudioPlayerType = AudioPlayerType.basic;

/// Provider para controlar qué tipo de reproductor usar
final audioPlayerTypeProvider = Provider<AudioPlayerType>((ref) {
  // Por defecto usar el reproductor básico para no romper nada
  // Se puede cambiar a 'professional' cuando esté listo
  return _currentAudioPlayerType;
});

/// Widget wrapper que permite cambiar entre reproductores gradualmente
/// 
/// Uso:
/// ```dart
/// AudioPlayerWrapper(
///   type: AudioPlayerType.professional, // o AudioPlayerType.basic
///   // ... otros parámetros solo necesarios para el reproductor básico
/// )
/// ```
class AudioPlayerWrapper extends ConsumerWidget {
  /// Tipo de reproductor a usar
  final AudioPlayerType? type;
  
  // Parámetros solo necesarios para el reproductor básico
  final String? songTitle;
  final String? artistName;
  final String? imageUrl;
  final bool? isPlaying;
  final Duration? position;
  final Duration? duration;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTap;
  final ValueChanged<double>? onSeek;

  const AudioPlayerWrapper({
    super.key,
    this.type,
    // Parámetros del reproductor básico
    this.songTitle,
    this.artistName,
    this.imageUrl,
    this.isPlaying,
    this.position,
    this.duration,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onTap,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determinar qué tipo de reproductor usar
    final playerType = type ?? ref.watch(audioPlayerTypeProvider);

    // Si está en modo auto, intentar usar el profesional si está disponible
    if (playerType == AudioPlayerType.auto) {
      final currentSongAsync = ref.watch(professionalCurrentSongProvider);
      final currentSong = currentSongAsync.maybeWhen(
        data: (song) => song,
        orElse: () => null,
      );
      // Si hay una canción cargada en el reproductor profesional, usarlo
      if (currentSong != null) {
        return const ProfessionalAudioPlayer();
      }
      // Si no, usar el básico
      return _buildBasicPlayer(ref);
    }

    // Reproducir profesional
    if (playerType == AudioPlayerType.professional) {
      return const ProfessionalAudioPlayer();
    }

    // Reproducir básico (default)
    return _buildBasicPlayer(ref);
  }

  Widget _buildBasicPlayer(WidgetRef ref) {
    // BottomPlayer deshabilitado - siempre devolver widget vacío
    // Este método se mantiene para compatibilidad pero no renderiza nada
    return const SizedBox.shrink();
    
    /* Código comentado - BottomPlayer ha sido deshabilitado
    // Callbacks con fallback al servicio profesional si están disponibles
    final audioService = ref.read(professionalAudioServiceProvider);
    
    return BottomPlayer(
      songTitle: songTitle,
      artistName: artistName,
      imageUrl: imageUrl,
      isPlaying: playing,
      position: pos,
      duration: dur,
      onPlayPause: onPlayPause ?? () {
        if (playing) {
          audioService.pause();
        } else {
          audioService.play();
        }
      },
      onPrevious: onPrevious ?? () => audioService.previous(),
      onNext: onNext ?? () => audioService.next(),
      onTap: onTap,
      onSeek: onSeek ?? (position) {
        if (dur != null) {
          audioService.seek(Duration(
            seconds: (position * dur.inSeconds).toInt(),
          ));
        }
      },
    );
    */
  }
}

/// Función helper para cambiar el tipo de reproductor globalmente
/// 
/// Ejemplo:
/// ```dart
/// // Cambiar a reproductor profesional
/// changeAudioPlayerType(ref, AudioPlayerType.professional);
/// 
/// // Volver al básico si hay problemas
/// changeAudioPlayerType(ref, AudioPlayerType.basic);
/// ```
void changeAudioPlayerType(
  WidgetRef ref,
  AudioPlayerType type,
) {
  _currentAudioPlayerType = type;
  // Invalidar el provider para notificar cambios
  ref.invalidate(audioPlayerTypeProvider);
}

/// Función helper para migrar datos del reproductor básico al profesional
/// 
/// Útil cuando se quiere cargar una canción en el reproductor profesional
/// desde el reproductor básico
Future<void> migrateToProfessionalPlayer(
  WidgetRef ref,
  String? songUrl,
  String? songTitle,
  String? artistName,
) async {
  if (songUrl == null || songUrl.isEmpty) {
    return;
  }

  try {
    final audioService = ref.read(professionalAudioServiceProvider);
    
    // Si el servicio no está inicializado, inicializarlo
    if (!audioService.isInitialized) {
      await audioService.initialize(enableBackground: true);
    }

    // Buscar la canción en el provider actual (si existe)
    // Por ahora, cargamos directamente desde la URL si está disponible
    // Nota: En una implementación completa, deberías tener acceso al modelo Song
    
    // Cambiar al reproductor profesional
    changeAudioPlayerType(ref, AudioPlayerType.professional);
  } catch (e) {
    // Si falla, mantener el reproductor básico
    // Podrías mostrar un mensaje de error al usuario
    AppLogger.error('[AudioPlayerMigration] Error al migrar al reproductor profesional: $e');
  }
}

