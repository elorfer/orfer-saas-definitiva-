import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/logger.dart';
import '../models/song_model.dart';

/// Instancia global del handler para acceso desde AudioService wrapper
/// ⚠️ NULLABLE: Puede no estar inicializado si el timeout de AudioService.init ocurre
StrukyAudioHandler? _globalAudioHandler;

/// Getter seguro para el audio handler
StrukyAudioHandler get globalAudioHandler {
  final handler = _globalAudioHandler;
  if (handler == null) {
    throw StateError(
      'StrukyAudioHandler no está inicializado. '
      'Asegúrate de que AudioService.init() haya completado correctamente.'
    );
  }
  return handler;
}

/// Setter para inicializar el handler
set globalAudioHandler(StrukyAudioHandler handler) {
  _globalAudioHandler = handler;
}

/// Verificar si el audio handler está listo (sin lanzar excepción)
bool get isAudioHandlerReady => _globalAudioHandler != null;

/// ═══════════════════════════════════════════════════════════════════════════
/// 🛡️ STRUKY AUDIO HANDLER (NATIVE BACKGROUND)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Este handler es el puente entre la App Flutter y el Sistema Operativo Android/iOS.
/// Garantiza que la música siga sonando en background y maneja las notificaciones nativas.
///
class StrukyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // 1. Instancia central del Player (Movida desde AudioService)
  final AudioPlayer _player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        // Buffer inicial agresivo: 5 segundos para empezar, pero intentando reproducir cuanto antes
        minBufferDuration: Duration(seconds: 5),
        maxBufferDuration: Duration(seconds: 50),
        bufferForPlaybackDuration: Duration(milliseconds: 500), // Iniciar rápidamente (500ms)
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
      ),
      darwinLoadControl: DarwinLoadControl(
        automaticallyWaitsToMinimizeStalling: false, // Arriesgarse para iniciar rápido
      ),
    ),
  );

  /// 🚀 SEÑAL DE STOP INTENCIONAL
  /// Se dispara ANTES de detener el player para que los listeners (playback_notifier)
  /// puedan limpiar su estado y evitar que el guard anti-corrupción reinicie la música.
  final _sessionStoppedController = StreamController<void>.broadcast();
  Stream<void> get sessionStoppedStream => _sessionStoppedController.stream;

  /// Getter público para acceder al player directamente cuando sea necesario
  /// (Necesario para mantener compatibilidad con la lógica compleja de streams existente en AudioService)
  AudioPlayer get player => _player;

  /// Inicialización
  StrukyAudioHandler() {
    AppLogger.info('[StrukyAudioHandler] 🎵 Constructor llamado - Inicializando handler');
    _initStreams();
    _initPlayerListeners();
    AppLogger.info('[StrukyAudioHandler] ✅ Handler completamente inicializado');
  }

  /// Configura los streams para sincronizar just_audio -> audio_service
  void _initStreams() {
    // No necesitamos transformar streams aquí si AudioService consume directamente del player,
    // pero para la notificación nativa, necesitamos alimentar playbackState.
  }

  void _initPlayerListeners() {
    // 1. Sincronizar estado de reproducción (Play/Pause/Buffering) con AudioService
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      // Mapear estados de just_audio a audio_service
      final activity = _mapProcessingStateToActivity(processingState, isPlaying);
      
      playbackState.add(playbackState.value.copyWith(
        playing: isPlaying,
        processingState: activity,
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2], // Prev, Play/Pause, Next
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ));
    });

    // 2. Sincronizar posición actual para la barra de progreso en notificación
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // 3. Sincronizar Posición Buffered
    _player.bufferedPositionStream.listen((buffered) {
      playbackState.add(playbackState.value.copyWith(
        bufferedPosition: buffered,
      ));
    });

    // 4. Sincronizar Metadata (Canción actual)
    AppLogger.info('[StrukyAudioHandler] 🎧 Configurando listener de sequenceStateStream');
    _player.sequenceStateStream.listen((sequenceState) {
      AppLogger.debug('[StrukyAudioHandler] 📡 sequenceStateStream emitió evento');
      final sequence = sequenceState.sequence;
      if (sequence.isEmpty) {
        AppLogger.debug('[StrukyAudioHandler] ⚠️ Secuencia vacía o nula');
        return;
      }
      
      final currentItem = sequenceState.currentSource;
      AppLogger.info('[StrukyAudioHandler] 🎵 Source actual: ${currentItem?.tag?.runtimeType}');
      
      if (currentItem != null && currentItem.tag != null) {
        // 🔄 AUTO-CONVERSIÓN: Detectar si el tag es una Canción y actualizar notificación
        if (currentItem.tag is Song) {
           final song = currentItem.tag as Song;
           AppLogger.info('[StrukyAudioHandler] ✅ Tag es Song: ${song.title}');
           final newItem = MediaItem(
             id: song.id,
             album: song.artist?.stageName ?? 'Struky Music',
             title: song.title ?? 'Desconocido',
             artist: song.artist?.stageName,
             duration: song.duration != null ? Duration(seconds: song.duration!) : null,
             artUri: song.coverArtUrl != null ? Uri.parse(song.coverArtUrl!) : null,
             extras: {
               'fileUrl': song.fileUrl,
             }
           );
           
           // Emitir item actualizado para la notificación nativa
           mediaItem.add(newItem);
           AppLogger.info('[StrukyAudioHandler] 📢 MediaItem emitido: ${song.title}');
        } 
        // 📢 SOPORTE PARA ANUNCIOS: Si es un anuncio
        else if (currentItem.tag.toString().contains('AudioAd')) {
           AppLogger.info('[StrukyAudioHandler] 📢 Tag es AudioAd');
           final adItem = MediaItem(
             id: 'ad_break',
             title: 'Publicidad',
             artist: 'Struky',
             duration: currentItem.duration,
           );
           mediaItem.add(adItem);
        } else {
           AppLogger.warning('[StrukyAudioHandler] ⚠️ Tag no reconocido: ${currentItem.tag.runtimeType}');
        }
      } else {
        AppLogger.warning('[StrukyAudioHandler] ⚠️ No hay tag, usando fallback');
        mediaItem.add(MediaItem(
             id: 'unknown',
             title: 'Struky Music',
             artist: 'Escuchando ahora',
             duration: currentItem?.duration,
        ));
      }
    });
  }

  AudioProcessingState _mapProcessingStateToActivity(ProcessingState state, bool playing) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return playing ? AudioProcessingState.ready : AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎮 CONTROLES DE TRANSPORTE (Llamados desde notificación o UI)
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<void> play() async {
    AppLogger.debug('[StrukyAudioHandler] ▶️ play() llamado');
    await _player.play();
  }

  @override
  Future<void> pause() async {
    AppLogger.debug('[StrukyAudioHandler] ⏸️ pause() llamado');
    await _player.pause();
  }

  /// Flag para evitar doble-dispose del player
  bool _playerDisposed = false;

  /// 🛡️ Helper interno: Detener player de forma segura
  Future<void> _safeStopPlayer() async {
    if (_playerDisposed) return;
    try {
      if (_player.playing) {
        await _player.pause(); // Pausa inmediata (más rápido que stop)
      }
      await _player.stop();
    } catch (e) {
      AppLogger.error('[StrukyAudioHandler] Error al detener player: $e');
    }
  }

  /// 🛡️ Helper interno: Emitir estado idle al sistema
  void _emitIdleState() {
    try {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        controls: [],
      ));
    } catch (e) {
      AppLogger.error('[StrukyAudioHandler] Error emitiendo estado idle: $e');
    }
  }

  @override
  Future<void> stop() async {
    AppLogger.info('[StrukyAudioHandler] 🛑 stop() llamado - Finalizando servicio');
    // 🚀 SEÑAL PRIMERO: Notificar a listeners ANTES de detener el player
    _sessionStoppedController.add(null);
    await _safeStopPlayer();
    _emitIdleState();
    await super.stop(); // 🚀 CRÍTICO: Informar a audio_service que debe detener el foreground service
  }

  @override
  Future<void> onNotificationDeleted() async {
    AppLogger.info('[StrukyAudioHandler] 🗑️ Notificación eliminada por el usuario');
    // 🚀 SEÑAL PRIMERO: Notificar a listeners ANTES de detener el player
    _sessionStoppedController.add(null);
    // NO llamamos dispose() aquí porque super.stop() necesita el player vivo
    // para limpiar los listeners internos de audio_service
    await _safeStopPlayer();
    _emitIdleState();
    await super.stop(); // Esto mata el foreground service
  }

  /// 🚀 CRÍTICO: Llamado por Android cuando el usuario desliza la app de recientes
  /// Sin esto, el servicio de audio sigue corriendo en background indefinidamente
  @override
  Future<void> onTaskRemoved() async {
    AppLogger.info('[StrukyAudioHandler] 🗑️ App removida de recientes - Deteniendo servicio');
    // 🚀 SEÑAL PRIMERO: Notificar a listeners ANTES de detener
    _sessionStoppedController.add(null);
    await _safeStopPlayer();
    _emitIdleState();
    
    // En onTaskRemoved sí podemos dispose() porque la app ya se fue
    if (!_playerDisposed) {
      try {
        await _player.dispose();
        _playerDisposed = true;
      } catch (e) {
        AppLogger.error('[StrukyAudioHandler] Error en dispose de onTaskRemoved: $e');
      }
    }
    
    await super.stop();
    await super.onTaskRemoved();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= (_player.sequence.length ?? 0)) return;
    await _player.seek(Duration.zero, index: index);
  }

  /// Cargar una lista de reproducción
  /// Aquí actualizamos la cola de `audio_service` para la notificación
  Future<void> setQueue(List<AudioSource> sources, List<MediaItem> mediaItems, int initialIndex) async {
    // 1. Cargar en player usando el método nativo (just_audio 0.10.5+)
    try {
      await _player.setAudioSources(sources, initialIndex: initialIndex);
    } catch (e) {
      AppLogger.error('Error cargando audio source en handler: $e');
      rethrow;
    }

    // 3. Actualizar cola de notificación (MediaItems)
    queue.add(mediaItems);
    
    // 4. Actualizar item actual
    if (mediaItems.isNotEmpty && initialIndex < mediaItems.length) {
      mediaItem.add(mediaItems[initialIndex]);
    }
  }

  /// Actualizar el MediaItem actual manualmente (útil si cambia metadata dinámicamente)
  void updateCurrentMediaItem(MediaItem item) {
    mediaItem.add(item);
  }
}
