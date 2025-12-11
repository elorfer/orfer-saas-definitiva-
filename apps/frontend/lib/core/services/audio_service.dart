import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/logger.dart';

/// Servicio de audio único y limpio
/// Wrapper singleton para just_audio con una única instancia de AudioPlayer
class AudioService {
  // Instancia única del reproductor
  final AudioPlayer player = AudioPlayer();

  /// Stream de estado de reproducción (playing/paused)
  Stream<bool> get isPlayingStream => player.playingStream;

  /// Stream de posición actual
  Stream<Duration> get positionStream => player.positionStream;

  /// Stream de duración total
  Stream<Duration?> get durationStream => player.durationStream;

  /// Stream del estado de la secuencia (para obtener la canción actual)
  Stream<SequenceState?> get sequenceStateStream => player.sequenceStateStream;

  /// Stream del estado del reproductor (para buffering, etc.)
  Stream<PlayerState> get playerStateStream => player.playerStateStream;

  /// 🛡️ GUARD ANTI-LOOP: Verificar si hay error en el reproductor
  /// En just_audio, los errores se detectan cuando processingState es idle inesperadamente
  bool get hasError {
    try {
      final playerState = player.playerState;
      // Si está idle pero debería estar reproduciendo, puede haber un error
      return playerState.processingState == ProcessingState.idle;
    } catch (e) {
      return false;
    }
  }

  /// Cargar una nueva cola de canciones
  /// 
  /// [sources]: Lista de AudioSource a reproducir
  /// [initialIndex]: Índice inicial de la canción a reproducir
  Future<void> loadNewQueue(List<AudioSource> sources, int initialIndex) async {
    try {
      AppLogger.info('[AudioService] Cargando cola: ${sources.length} canciones, índice inicial: $initialIndex');
      
      // 🚨 DETENER COMPLETAMENTE EL REPRODUCTOR para evitar "Loading interrupted"
      try {
        // Pausar primero
        await player.pause();
        // Luego detener
        await player.stop();
        // Esperar más tiempo para asegurar que se complete la detención
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Verificar que el reproductor esté realmente detenido
        final playerState = player.playerState;
        if (playerState.processingState == ProcessingState.loading) {
          AppLogger.warning('[AudioService] Reproductor aún cargando, esperando más...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        // Ignorar errores al detener (puede que no haya nada reproduciendo)
        AppLogger.info('[AudioService] Error al detener (puede ser normal): $e');
      }
      
      // ⚠️ DEUDA TÉCNICA: ConcatenatingAudioSource está deprecado en just_audio 0.10.5
      // 
      // Razón: just_audio 0.10.5 aún requiere ConcatenatingAudioSource para crear colas.
      // La nueva API (setAudioSources) no está disponible en esta versión.
      //
      // Plan de migración:
      // 1. Actualizar just_audio a versión que soporte setAudioSources (plural)
      // 2. Migrar loadNewQueue() y appendToQueue() a la nueva API
      // 3. Verificar que sequenceState.sequence se maneje correctamente
      //
      // Estado: Funcional y estable. Las advertencias son informativas.
      // Prioridad: Baja (se abordará en próxima actualización mayor del paquete)
      await player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: initialIndex,
      );
      
      AppLogger.info('[AudioService] Cola cargada exitosamente');
    } catch (e, stackTrace) {
      // 🚨 MEJOR MANEJO DE ERRORES: Detectar errores de conexión específicos
      final errorString = e.toString().toLowerCase();
      final isConnectionError = errorString.contains('connectexception') ||
          errorString.contains('failed to connect') ||
          errorString.contains('network') ||
          errorString.contains('connection refused') ||
          errorString.contains('connection timed out') ||
          errorString.contains('socketexception');
      
      if (isConnectionError) {
        AppLogger.error('[AudioService] ❌ ERROR DE CONEXIÓN: No se puede conectar al servidor de audio');
        AppLogger.error('[AudioService] Verifica que el backend esté corriendo y accesible');
        AppLogger.error('[AudioService] Error: $e');
        // Lanzar un error más descriptivo
        throw Exception('Error de conexión: No se puede conectar al servidor de audio. Verifica tu conexión a internet y que el backend esté corriendo.');
      }
      
      // Manejar específicamente el error "Connection aborted" (puede ocurrir al cambiar de modo rápidamente)
      if (errorString.contains('connection aborted') || 
          errorString.contains('aborted')) {
        AppLogger.warning('[AudioService] ⚠️ Conexión abortada, reintentando...');
        
        // Esperar más tiempo antes de reintentar (dar tiempo a que se complete la operación anterior)
        await Future.delayed(const Duration(milliseconds: 800));
        
        try {
          // Detener completamente y limpiar estado
          await player.pause();
          await player.stop();
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Reintentar carga
          await player.setAudioSource(
            ConcatenatingAudioSource(children: sources),
            initialIndex: initialIndex,
          );
          
          AppLogger.info('[AudioService] ✅ Cola cargada exitosamente después de reintento (connection aborted)');
        } catch (retryError, retryStackTrace) {
          AppLogger.error('[AudioService] ❌ Error al reintentar carga después de connection aborted: $retryError', retryStackTrace);
          rethrow;
        }
      }
      // Manejar específicamente el error "Loading interrupted"
      else if (errorString.contains('loading interrupted') || 
          errorString.contains('interrupted') ||
          errorString.contains('pluginloadrequest')) {
        AppLogger.warning('[AudioService] Carga interrumpida, reintentando con más tiempo...');
        
        // Esperar más tiempo antes de reintentar
        await Future.delayed(const Duration(milliseconds: 500));
        
        try {
          // Detener completamente
          await player.pause();
          await player.stop();
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Reintentar carga (usando ConcatenatingAudioSource como se requiere en just_audio 0.10.5)
          await player.setAudioSource(
            ConcatenatingAudioSource(children: sources),
            initialIndex: initialIndex,
          );
          
          AppLogger.info('[AudioService] ✅ Cola cargada exitosamente después de reintento');
        } catch (retryError, retryStackTrace) {
          AppLogger.error('[AudioService] ❌ Error al reintentar carga: $retryError', retryStackTrace);
          rethrow;
        }
      } else {
        AppLogger.error('[AudioService] ❌ Error al cargar cola: $e', stackTrace);
        rethrow;
      }
    }
  }

  /// Reproducir
  Future<void> play() async {
    try {
      await player.play();
      AppLogger.info('[AudioService] Reproducción iniciada');
    } catch (e) {
      AppLogger.error('[AudioService] Error al reproducir: $e');
      rethrow;
    }
  }

  /// Pausar
  Future<void> pause() async {
    try {
      await player.pause();
      AppLogger.info('[AudioService] Reproducción pausada');
    } catch (e) {
      AppLogger.error('[AudioService] Error al pausar: $e');
      rethrow;
    }
  }

  /// Buscar posición
  Future<void> seek(Duration position) async {
    try {
      await player.seek(position);
      AppLogger.info('[AudioService] Buscando a: ${position.inSeconds}s');
    } catch (e) {
      AppLogger.error('[AudioService] Error al buscar: $e');
      rethrow;
    }
  }

  /// ⚡ TRANSICIÓN INSTANTÁNEA: Siguiente canción optimizado
  Future<void> next() async {
    try {
      if (player.hasNext) {
        // ⚡ CRÍTICO: seekToNext() es más rápido que stop() + play()
        // No requiere detener la reproducción actual, solo cambia de canción
        await player.seekToNext();
        // Reproducir inmediatamente sin delay
        await player.play();
        AppLogger.info('[AudioService] ⚡ Transición instantánea a siguiente canción');
      } else {
        AppLogger.info('[AudioService] No hay siguiente canción');
      }
    } catch (e) {
      AppLogger.error('[AudioService] Error al avanzar: $e');
      rethrow;
    }
  }

  /// Canción anterior
  Future<void> previous() async {
    try {
      if (player.hasPrevious) {
        await player.seekToPrevious();
        AppLogger.info('[AudioService] Canción anterior');
      } else {
        // Si no hay anterior, volver al inicio
        await player.seek(Duration.zero);
        AppLogger.info('[AudioService] Volviendo al inicio');
      }
    } catch (e) {
      AppLogger.error('[AudioService] Error al retroceder: $e');
      rethrow;
    }
  }

  /// Establecer volumen
  Future<void> setVolume(double volume) async {
    try {
      await player.setVolume(volume.clamp(0.0, 1.0));
      AppLogger.info('[AudioService] Volumen establecido: ${(volume * 100).toInt()}%');
    } catch (e) {
      AppLogger.error('[AudioService] Error al establecer volumen: $e');
      rethrow;
    }
  }

  /// Establecer modo de repetición
  Future<void> setLoopMode(LoopMode loopMode) async {
    try {
      await player.setLoopMode(loopMode);
      AppLogger.info('[AudioService] Modo de repetición: $loopMode');
    } catch (e) {
      AppLogger.error('[AudioService] Error al establecer modo de repetición: $e');
      rethrow;
    }
  }

  /// Establecer modo shuffle
  Future<void> setShuffleModeEnabled(bool enabled) async {
    try {
      await player.setShuffleModeEnabled(enabled);
      AppLogger.info('[AudioService] Shuffle ${enabled ? 'habilitado' : 'deshabilitado'}');
    } catch (e) {
      AppLogger.error('[AudioService] Error al establecer shuffle: $e');
      rethrow;
    }
  }

  /// Agregar más canciones a la cola actual (útil para modo algorithm)
  /// 
  /// ⚠️ DEUDA TÉCNICA: Usa ConcatenatingAudioSource.addAll() que está deprecado.
  /// Ver comentario en loadNewQueue() para detalles de la migración planificada.
  Future<void> appendToQueue(List<AudioSource> sources) async {
    try {
      final currentSource = player.audioSource;
      if (currentSource is ConcatenatingAudioSource) {
        await currentSource.addAll(sources);
        AppLogger.info('[AudioService] Agregadas ${sources.length} canciones a la cola');
      } else {
        AppLogger.warning('[AudioService] No se puede agregar a la cola: el audioSource actual no es ConcatenatingAudioSource');
      }
    } catch (e) {
      AppLogger.error('[AudioService] Error al agregar a la cola: $e');
      rethrow;
    }
  }

  /// Liberar recursos
  Future<void> dispose() async {
    try {
      await player.dispose();
      AppLogger.info('[AudioService] Recursos liberados');
    } catch (e) {
      AppLogger.error('[AudioService] Error al liberar recursos: $e');
    }
  }
}

/// Provider que gestiona el ciclo de vida del AudioService
/// Se limpia automáticamente cuando el provider se dispose
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  
  // Limpieza nativa al morir el Provider
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});
