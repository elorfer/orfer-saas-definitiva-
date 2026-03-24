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
          MediaControl.stop,
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

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
