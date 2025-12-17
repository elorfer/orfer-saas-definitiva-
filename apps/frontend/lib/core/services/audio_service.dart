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
      // 🛡️ PROTECCIÓN: Esperar a que just_audio termine cualquier operación en curso antes de detener
      // ⚡ OPTIMIZACIÓN: Reducir delays para minimizar pausa perceptible
      try {
        // ⚡ OPTIMIZACIÓN: Reducido de 100ms a 50ms
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Verificar el estado del reproductor antes de intentar detenerlo
        final playerState = player.playerState;
        if (playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering) {
          // Si está cargando o buffering, esperar más tiempo
          AppLogger.debug('[AudioService] Reproductor en estado ${playerState.processingState}, esperando...');
          await Future.delayed(const Duration(milliseconds: 150)); // Reducido de 200ms
        }
        
        // Pausar primero (más suave que stop)
        try {
          await player.pause();
        } catch (e) {
          // Si falla pause, intentar stop directamente
          AppLogger.debug('[AudioService] Error al pausar, intentando stop: $e');
        }
        
        // Luego detener
        try {
          await player.stop();
        } catch (e) {
          // Si falla stop, puede ser que ya esté detenido
          AppLogger.debug('[AudioService] Error al detener (puede ser normal si ya está detenido): $e');
        }
        
        // ⚡ OPTIMIZACIÓN: Reducido de 200ms a 100ms para minimizar pausa
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verificar que el reproductor esté realmente detenido
        final finalPlayerState = player.playerState;
        if (finalPlayerState.processingState == ProcessingState.loading) {
          AppLogger.warning('[AudioService] Reproductor aún cargando después de detener, esperando más...');
          await Future.delayed(const Duration(milliseconds: 300)); // Reducido de 500ms
        }
      } catch (e) {
        // Ignorar errores al detener (puede que no haya nada reproduciendo o que just_audio esté ocupado)
        // Este error es común cuando just_audio está procesando otro evento
        AppLogger.debug('[AudioService] Error al detener (puede ser normal si just_audio está ocupado): $e');
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

  /// ⚡ INYECCIÓN INSTANTÁNEA: Insertar canción al inicio de la cola y cambiar inmediatamente
  /// 
  /// Esta es la forma más rápida de cambiar de canción cuando ya hay una reproduciendo.
  /// En lugar de reconstruir toda la cola con setAudioSource(), simplemente inserta
  /// la nueva canción en el índice 0 y hace seek a ese índice.
  /// 
  /// Ventaja: El reproductor no tiene que reconstruir todo su estado; simplemente
  /// pasa al índice que ya está configurado para la reproducción.
  /// 
  /// [source]: AudioSource de la nueva canción a reproducir
  /// 
  /// Retorna true si la inyección fue exitosa, false si no hay cola activa
  Future<bool> insertSongAtStart(AudioSource source) async {
    try {
      final currentSource = player.audioSource;
      
      // Solo funciona si ya hay un ConcatenatingAudioSource activo
      if (currentSource is! ConcatenatingAudioSource) {
        AppLogger.info('[AudioService] No hay cola activa para inyección instantánea');
        return false;
      }

      AppLogger.info('[AudioService] ⚡ Inyección instantánea: insertando canción al inicio de la cola');
      
      // 🔄 CRÍTICO: Guardar estado de reproducción ANTES de insertar
      // seek() y seekToPrevious() pueden pausar el reproductor automáticamente
      final wasPlaying = player.playing;
      
      // Insertar la nueva canción en el índice 0
      await currentSource.insert(0, source);
      
      // 🔄 SINCRONIZACIÓN: Esperar que just_audio actualice su sequenceState después de insertar
      // ⚡ OPTIMIZACIÓN: Delay mínimo (15ms) para reducir latencia mientras permitimos que just_audio actualice
      await Future.delayed(const Duration(milliseconds: 15));
      
      // ⚡ OPTIMIZACIÓN: Usar seek() con index: 0 para saltar directamente al inicio
      // Nota: Después de insert(0, source), el índice actual siempre se incrementa,
      // así que siempre necesitamos hacer seek para volver al índice 0.
      // Esto causa dos flush/start (uno del insert, otro del seek), pero es inevitable.
      try {
        // just_audio permite seek con index para saltar directamente a una canción específica
        await player.seek(Duration.zero, index: 0);
        AppLogger.debug('[AudioService] ⚡ Seek directo al índice 0 completado');
      } catch (e) {
        // Fallback: si seek con index no funciona, usar el método anterior
        AppLogger.warning('[AudioService] ⚠️ Seek con index falló, usando fallback: $e');
        final newSequenceState = player.sequenceState;
        final newCurrentIndex = newSequenceState.currentIndex ?? 0;
        
        if (newCurrentIndex > 0) {
          // Navegar hacia atrás hasta llegar al índice 0 (método anterior)
          for (int i = 0; i < newCurrentIndex && player.hasPrevious; i++) {
            await player.seekToPrevious();
          }
        } else {
          await player.seek(Duration.zero);
        }
      }
      
      // 🔄 CRÍTICO: Reanudar reproducción si estaba reproduciendo antes
      // seek() puede pausar el reproductor, necesitamos reanudarlo
      if (wasPlaying && !player.playing) {
        await player.play();
        AppLogger.info('[AudioService] ▶️ Reproducción reanudada después de seek');
      }
      
      AppLogger.info('[AudioService] ✅ Inyección instantánea completada');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[AudioService] ❌ Error en inyección instantánea: $e', stackTrace);
      return false;
    }
  }

  /// ⚡ INYECCIÓN INSTANTÁNEA: Insertar canción en cualquier posición de la cola
  /// 
  /// Similar a insertSongAtStart pero permite insertar en cualquier índice.
  /// Útil para insertar anuncios después de la canción actual sin interrumpir la reproducción.
  /// 
  /// Esta es la forma más rápida de insertar contenido en la cola cuando ya hay una reproduciendo.
  /// Usa flush/start optimizado en lugar de Release/Init lento.
  /// 
  /// [source]: AudioSource de la nueva canción/anuncio a insertar
  /// [index]: Índice donde insertar (0 = inicio, currentIndex + 1 = después de la actual)
  /// 
  /// Retorna true si la inyección fue exitosa, false si no hay cola activa
  Future<bool> insertSongAtIndex(AudioSource source, int index) async {
    try {
      final currentSource = player.audioSource;
      
      // Solo funciona si ya hay un ConcatenatingAudioSource activo
      if (currentSource is! ConcatenatingAudioSource) {
        AppLogger.info('[AudioService] No hay cola activa para inyección instantánea en índice $index');
        return false;
      }

      // Validar que el índice sea válido
      if (index < 0 || index > currentSource.length) {
        AppLogger.warning('[AudioService] Índice $index inválido (cola tiene ${currentSource.length} elementos)');
        return false;
      }

      AppLogger.info('[AudioService] ⚡ Inyección instantánea: insertando en índice $index');
      
      // 🔄 CRÍTICO: Guardar estado de reproducción ANTES de insertar
      // seek() puede pausar el reproductor automáticamente
      final wasPlaying = player.playing;
      final currentIndex = player.currentIndex ?? 0;
      
      // Insertar la nueva canción/anuncio en el índice especificado
      await currentSource.insert(index, source);
      
      // 🔄 SINCRONIZACIÓN: Esperar que just_audio actualice su sequenceState después de insertar
      // ⚡ OPTIMIZACIÓN: Delay mínimo (15ms) para reducir latencia mientras permitimos que just_audio actualice
      await Future.delayed(const Duration(milliseconds: 15));
      
      // Si insertamos después de la canción actual y queremos reproducir el anuncio inmediatamente
      if (index == currentIndex + 1 && wasPlaying) {
        // ⚡ OPTIMIZACIÓN: Usar seek() con index para saltar directamente al anuncio
        // Esto usa flush/start optimizado, no Release/Init lento
        try {
          await player.seek(Duration.zero, index: index);
          AppLogger.debug('[AudioService] ⚡ Seek directo al índice $index completado');
          
          // 🔄 CRÍTICO: Reanudar reproducción si estaba reproduciendo antes
          // seek() puede pausar el reproductor, necesitamos reanudarlo
          if (wasPlaying && !player.playing) {
            await player.play();
            AppLogger.info('[AudioService] ▶️ Reproducción reanudada después de inserción en índice $index');
          }
        } catch (e) {
          // Fallback: si seek con index no funciona, continuar con la reproducción actual
          AppLogger.warning('[AudioService] ⚠️ Seek con index falló, continuando reproducción actual: $e');
          // No hacer nada, la canción actual seguirá reproduciéndose y el anuncio estará en la cola
        }
      }
      // Si insertamos en otra posición, no cambiar la reproducción actual
      // El contenido quedará en la cola para reproducirse después
      
      AppLogger.info('[AudioService] ✅ Inyección instantánea en índice $index completada');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[AudioService] ❌ Error en inyección instantánea en índice $index: $e', stackTrace);
      return false;
    }
  }

  /// 🛡️ Eliminar ítems de la cola en los índices especificados
  /// 
  /// [indices]: Lista de índices a eliminar
  /// 
  /// Retorna true si la eliminación fue exitosa
  Future<bool> removeQueueItemsAt(List<int> indices) async {
    try {
      AppLogger.warning('[AudioService] 🛡️ removeQueueItemsAt llamado con ${indices.length} índices: $indices');
      
      final currentSource = player.audioSource;
      
      // Solo funciona si ya hay un ConcatenatingAudioSource activo
      if (currentSource is! ConcatenatingAudioSource) {
        AppLogger.warning('[AudioService] 🛡️ ❌ No hay cola activa para eliminación (tipo: ${currentSource.runtimeType})');
        return false;
      }

      if (indices.isEmpty) {
        return true; // No hay nada que eliminar
      }
      
      // 🛡️ PROTECCIÓN ADICIONAL: Verificar que los índices sean válidos
      final validIndices = indices.where((idx) => idx >= 0 && idx < currentSource.length).toList();
      if (validIndices.isEmpty) {
        AppLogger.warning('[AudioService] 🛡️ ❌ Ningún índice es válido para eliminación (cola tiene ${currentSource.length} elementos)');
        return false;
      }
      
      // 🔄 CRÍTICO: Guardar estado de reproducción ANTES de remover
      final wasPlaying = player.playing;
      final currentPosition = player.position;
      
      // 🛡️ PROTECCIÓN: Verificar que el reproductor no esté en un estado inestable
      final playerState = player.playerState;
      if (playerState.processingState == ProcessingState.loading ||
          playerState.processingState == ProcessingState.buffering) {
        // Esperar a que el reproductor se estabilice antes de modificar la cola
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Ordenar índices descendente para evitar desplazamientos incorrectos
      final sortedIndices = List<int>.from(validIndices)..sort((a, b) => b.compareTo(a));
      
      // 🛡️ PROTECCIÓN CONTRA CONCURRENCIA: Remover uno por uno con delays
      int successfullyRemoved = 0;
      for (final index in sortedIndices) {
        try {
          // Verificar que el índice sigue siendo válido
          if (index < currentSource.length && index >= 0) {
            // 🔄 CRÍTICO: Pequeño delay entre cada removeAt
            if (successfullyRemoved > 0) {
              await Future.delayed(const Duration(milliseconds: 20));
            }
            
            await currentSource.removeAt(index);
            successfullyRemoved++;
          }
        } catch (e, stackTrace) {
          AppLogger.error('[AudioService] ⚠️ Error al remover índice $index: $e', stackTrace);
        }
      }
      
      if (successfullyRemoved == 0) {
        return false;
      }
      
      // 🔄 SINCRONIZACIÓN: Esperar que just_audio actualice
      await Future.delayed(const Duration(milliseconds: 50));
      
      // ⚡ OPTIMIZACIÓN: Solo restaurar posición si ha cambiado significativamente (>1 segundo)
      final newPosition = player.position;
      final positionDiff = (currentPosition - newPosition).abs();
      
      if (positionDiff > const Duration(seconds: 1)) {
        try {
          await player.seek(currentPosition);
        } catch (_) {}
      }
      
      // 🔄 CRÍTICO: Reanudar reproducción si estaba reproduciendo antes
      if (wasPlaying && !player.playing) {
        await player.play();
      }
      
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[AudioService] ❌ Error en removeQueueItemsAt: $e', stackTrace);
      return false;
    }
  }

  /// 🛡️ Deduplicación suave: Elimina canciones duplicadas sin destruir el reproductor
  /// Usa removeQueueItemsAt para mantener el pipeline activo
  /// 
  /// [duplicateIndices]: Lista de índices (ordenados descendente) a eliminar
  /// 
  /// Retorna true si la eliminación fue exitosa, false si no hay cola activa
  Future<bool> removeDuplicates(List<int> duplicateIndices) async {
    return removeQueueItemsAt(duplicateIndices);
  }

  /// Verificar si hay una cola activa (ConcatenatingAudioSource)
  bool get hasActiveQueue {
    try {
      return player.audioSource is ConcatenatingAudioSource;
    } catch (e) {
      return false;
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
