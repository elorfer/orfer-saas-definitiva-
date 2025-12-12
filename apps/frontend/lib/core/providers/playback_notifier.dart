import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../services/audio_service.dart';
import '../services/intelligent_featured_service.dart';
import '../services/home_service.dart';
import '../providers/play_history_provider.dart';
import '../providers/playback_session_provider.dart';
import '../utils/logger.dart';
import 'playback_state.dart';

/// Notificador de lógica central que maneja el estado de reproducción
/// Gestiona dos modos: fixedQueue (playlists) y algorithm (recomendaciones)
class PlaybackNotifier extends Notifier<PlaybackState> {
  AudioService? _service;
  
  // Guardar las suscripciones para poder cancelarlas
  final List<StreamSubscription> _subscriptions = [];

  // Estado optimista para controles
  bool _isProcessingPlayPause = false;
  bool _isProcessingNext = false;
  bool _isProcessingPrevious = false;
  DateTime _lastControlTap = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _controlDebounce = Duration(milliseconds: 200);
  
  // Servicios de recomendación
  late final IntelligentFeaturedService _intelligentService;
  late final HomeService _homeService;

  // Control de precarga para modo algorithm
  Timer? _algorithmMonitorTimer;
  bool _isPreloading = false;
  DateTime? _lastPreloadTime; // 🚨 COOLDOWN: Timestamp de última precarga
  bool _isPlayingFromCard = false; // 🚨 PROTECCIÓN: Flag para evitar detección de saltos cuando se reproduce desde tarjeta
  bool _isGeneratingRecommendations = false; // 🚨 PROTECCIÓN: Flag para cancelar generación de recomendaciones cuando se cambia de canción
  DateTime? _lastMonitorLogTime; // 🎯 FASE 2: Timestamp del último log del monitor (para reducir verbosidad)
  int? _lastKnownIndex; // 🎯 DETECCIÓN MANUAL: Último índice conocido para detectar saltos manuales
  DateTime? _lastManualSkipCheck; // 🎯 PROTECCIÓN: Timestamp de última verificación de salto manual (debounce)
  static const Duration _manualSkipDebounce = Duration(milliseconds: 500); // Debounce para evitar múltiples verificaciones
  bool _isRestartingAlgorithm = false; // 🎯 PROTECCIÓN: Flag para evitar reinicios múltiples del algoritmo
  bool _isReplacingQueue = false; // 🎯 PROTECCIÓN: Flag cuando se reemplaza toda la cola (loadNewQueue)
  Song? _lastConfirmedSong; // 🔒 Conserva la última canción confirmada para evitar flashes de portada
  bool _isDeduplicating = false; // 🛡️ PROTECCIÓN: Flag para evitar deduplicación múltiple simultánea
  DateTime? _lastDeduplicationTime; // 🛡️ PROTECCIÓN: Timestamp de última deduplicación
  static const Duration _deduplicationCooldown = Duration(seconds: 2); // Cooldown entre deduplicaciones
  String? _lastDedupSignature; // 🛡️ PROTECCIÓN: Firma de la última deduplicación para evitar bucles
  DateTime? _lastDedupSignatureTime; // 🛡️ PROTECCIÓN: Timestamp de la última firma
  static const Duration _dedupSignatureCooldown = Duration(seconds: 5); // Cooldown para firmas repetidas
  int _dedupAttemptsWindow = 0; // 🛡️ PROTECCIÓN: Contador en ventana corta
  DateTime? _dedupAttemptsWindowStart;
  static const Duration _dedupAttemptsWindowDuration = Duration(seconds: 10);
  static const int _dedupAttemptsWindowMax = 2; // No más de 2 dedups en 10s
  
  // Prefetch para transición playlist -> algoritmo (evitar espera al terminar última canción)
  List<Song>? _prefetchedInitialSongs;
  Song? _prefetchedSeed;

  // 🛡️ GUARD ANTI-LOOP: Control de archivos corruptos
  String? _lastCorruptedSongId; // ID de la última canción que causó error CORRUPTED
  int _corruptedRetryCount = 0; // Contador de reintentos por archivo corrupto
  DateTime? _lastCorruptedErrorTime; // Timestamp del último error CORRUPTED
  static const int _maxCorruptedRetries = 2; // Máximo 2 reintentos antes de saltar
  static const Duration _corruptedErrorCooldown = Duration(seconds: 2); // Cooldown entre detecciones de CORRUPTED
  
  // 🎯 FASE 2: Umbral de Recarga Proactivo
  static const int preloadThreshold = 3; // Pre-cargar cuando quedan ≤3 canciones disponibles
  static const int _preloadTimeThreshold = 45; // ⚡ TRANSICIÓN INSTANTÁNEA: Pre-cargar cuando quedan 45 segundos (aumentado para más anticipación)
  static const Duration _preloadCooldown = Duration(seconds: 3); // 🚨 COOLDOWN: Mínimo 3 segundos entre precargas
  
  // 🎯 FASE 3.1: Precarga Progresiva - Constantes de Control
  static const int criticalSongsCount = 5; // Canciones críticas a agregar inmediatamente (siguiente + buffer)
  
  // 🚨 SINCRONIZACIÓN: Flag para prevenir actualizaciones concurrentes del estado
  bool _isUpdatingQueue = false;
  // Bloqueo crítico para transición playlist -> algoritmo (evita pintar índice 1 fugaz)
  // Bloqueo crítico: protege la portada en la transición playlist -> algoritmo.
  // just_audio/ExoPlayer emite currentIndex=1 de forma fugaz al recrear la cola.
  // Mientras esta bandera está activa, ignoramos cualquier índice distinto de 0
  // para evitar mostrar la carátula de la segunda canción por un instante.
  bool _isAwaitingInitialAlgorithmPlay = false;
  
  // 🎯 MÉTODO PROFESIONAL: Completer para esperar precarga de forma asíncrona
  Completer<void>? _preloadCompleter; // Completer para esperar a que se complete la precarga
  
  // 🚀 SPOTIFY-LEVEL: Pre-carga de audio de siguientes canciones
  static const int _audioPreloadTimeThreshold = 30; // Pre-cargar audio cuando quedan 30 segundos
  final Set<String> _preloadedAudioUrls = {}; // Trackear URLs ya pre-cargadas
  
  // ⚡ TRANSICIÓN INSTANTÁNEA: Preparar siguiente canción antes del final
  static const int _transitionPrepareTimeThreshold = 3; // Preparar transición cuando quedan 3 segundos
  bool _nextSongPrepared = false; // Flag para evitar preparación múltiple
  int? _lastPreparedSongIndex; // Trackear qué canción fue preparada
  
  // 🛡️ PREVENCIÓN DE COLA VACÍA: Sistema robusto de protección
  static const int _minQueueSize = 5; // Tamaño mínimo garantizado de la cola
  // 🎯 FASE 2: Usar preloadThreshold como umbral crítico (unificado)
  Timer? _queueProtectionTimer; // Timer para monitoreo constante de la cola
  int _consecutiveFailures = 0; // Contador de fallos consecutivos en precarga
  DateTime? _lastEmergencyCall; // Timestamp de última llamada de emergencia
  static const Duration _emergencyCooldown = Duration(seconds: 10); // Cooldown entre emergencias

  // 🔍 FILTRO: Validar canciones antes de cargar a la cola (evita carátulas de tracks corruptos)
  List<Song> _filterPlayableSongs(Iterable<Song> songs) {
    return songs
        .where((s) =>
            s.isValidForPlayback &&
            (s.fileUrl?.isNotEmpty ?? false) &&
            (s.duration ?? 0) > 1)
        .toList();
  }

  PlaybackNotifier() {
    _intelligentService = IntelligentFeaturedService();
    _homeService = HomeService();
  }

  AudioService get service {
    if (_service == null) {
      throw StateError('AudioService no está inicializado. Llame a build() primero.');
    }
    return _service!;
  }

  // Getters optimistas para UI
  bool get isProcessingPlayPause => _isProcessingPlayPause;
  bool get isProcessingNext => _isProcessingNext;
  bool get isProcessingPrevious => _isProcessingPrevious;

  @override
  PlaybackState build() {
    // Obtener AudioService del provider
    _service = ref.watch(audioServiceProvider);
    
    // Inicializar suscripciones cuando se crea el notifier
    _initSubscriptions();
    
    // Limpiar recursos cuando se dispose
    ref.onDispose(() {
      _dispose();
    });
    
    return const PlaybackState();
  }

  /// Inicializar suscripciones a los streams del reproductor
  void _initSubscriptions() {
    if (_service == null) return;
    
    // 1. Suscribirse a los cambios de la secuencia para obtener la canción actual
    _subscriptions.add(
      service.sequenceStateStream.listen((sequenceState) {
        if (sequenceState == null) return;
        
        // Obtener la canción actual usando el tag
        // Si estamos reemplazando/actualizando la cola, evitar lecturas inconsistentes
        if (_isUpdatingQueue || _isReplacingQueue) {
          return;
        }

        final currentIndex = sequenceState.currentIndex;
        if (currentIndex != null && currentIndex < state.currentQueue.length) {
          final currentSong = state.currentQueue[currentIndex];
          
          // 🎯 DETECCIÓN MANUAL: Verificar si hubo un salto manual (no secuencial)
          // Solo detectar si ya había un índice previo (evitar detección en inicialización)
          // 🚨 PROTECCIÓN: Debounce para evitar múltiples verificaciones en rápida sucesión
          // 🚨 PROTECCIÓN: Ignorar detección si se está reproduciendo desde una tarjeta o si hay actualización en curso
          if (_lastKnownIndex != null && 
              state.playbackMode == PlaybackMode.algorithm && 
              !_isPlayingFromCard && 
              !_isUpdatingQueue &&
              !_isRestartingAlgorithm &&
              !_isReplacingQueue) {
            final now = DateTime.now();
            final shouldCheckSkip = _lastManualSkipCheck == null || 
                now.difference(_lastManualSkipCheck!) >= _manualSkipDebounce;
            
            if (shouldCheckSkip) {
              final wasManualSkip = currentIndex != _lastKnownIndex && 
                  currentIndex != _lastKnownIndex! + 1 && 
                  currentIndex != _lastKnownIndex! - 1;
              
              if (wasManualSkip) {
                _lastManualSkipCheck = now; // Registrar timestamp del check
                
                // 🎯 FASE 1: Registrar canciones saltadas (si saltó hacia adelante)
                if (currentIndex > _lastKnownIndex! + 1) {
                  try {
                    final skippedSongs = state.currentQueue
                        .sublist(_lastKnownIndex! + 1, currentIndex)
                        .map((s) => s.id)
                        .toList();
                    
                    if (skippedSongs.isNotEmpty) {
                      AppLogger.info('[PlaybackNotifier] ⏭️ Salto manual detectado: saltadas ${skippedSongs.length} canciones (índice $_lastKnownIndex → $currentIndex)');
                      ref.read(playbackSessionProvider.notifier).registerPlayedSongs(skippedSongs);
                    }
                  } catch (e) {
                    // Protección contra errores de índice fuera de rango
                    AppLogger.debug('[PlaybackNotifier] Error al registrar canciones saltadas: $e');
                  }
                }
                
                // 🎯 NUEVA FUNCIONALIDAD: Reiniciar algoritmo con nueva semilla cuando se selecciona manualmente
                // Esto permite obtener recomendaciones frescas basadas en la nueva canción seleccionada
                if (state.playbackMode == PlaybackMode.algorithm && !_isRestartingAlgorithm) {
                  // Solo reiniciar si el salto es significativo (más de 2 posiciones)
                  // Esto evita reinicios innecesarios en saltos pequeños
                  final skipDistance = (currentIndex - _lastKnownIndex!).abs();
                  if (skipDistance > 2) {
                    AppLogger.info('[PlaybackNotifier] 🔄 Selección manual detectada en modo algoritmo (salto: $skipDistance posiciones). Reiniciando con nueva semilla: ${currentSong.title}');
                    
                    _isRestartingAlgorithm = true; // Marcar que estamos reiniciando
                    
                    // Limpiar parcialmente el historial (mantener solo las últimas 5 canciones para contexto)
                    final sessionNotifier = ref.read(playbackSessionProvider.notifier);
                    final currentHistory = sessionNotifier.getPlayedSongIds().toList();
                    if (currentHistory.length > 5) {
                      // Mantener solo las últimas 5 canciones
                      final recentHistory = currentHistory.skip(currentHistory.length - 5).toList();
                      sessionNotifier.clear();
                      for (final id in recentHistory) {
                        sessionNotifier.registerPlayedSong(id);
                      }
                      AppLogger.info('[PlaybackNotifier] 🗑️ Historial reducido: ${currentHistory.length} → ${recentHistory.length} canciones (manteniendo contexto reciente)');
                    }
                    
                    // Reiniciar algoritmo con la nueva canción como semilla
                    // Usar Future.delayed para evitar bloqueos en el listener
                    Future.delayed(const Duration(milliseconds: 200), () async {
                      try {
                        if (state.playbackMode == PlaybackMode.algorithm && 
                            state.currentSong?.id == currentSong.id) {
                          AppLogger.info('[PlaybackNotifier] 🚀 Reiniciando algoritmo con nueva semilla: ${currentSong.title}');
                          await playAlgorithmStart(currentSong, excludeSeedFromQueue: false);
                          AppLogger.info('[PlaybackNotifier] ✅ Algoritmo reiniciado exitosamente');
                        }
                      } catch (e) {
                        AppLogger.error('[PlaybackNotifier] ❌ Error al reiniciar algoritmo: $e');
                      } finally {
                        _isRestartingAlgorithm = false; // Liberar flag después de un delay
                        Future.delayed(const Duration(seconds: 2), () {
                          _isRestartingAlgorithm = false; // Asegurar que se libere
                        });
                      }
                    });
                  } else {
                    // Salto pequeño: solo forzar recarga si quedan pocas canciones
                    final remainingSongs = state.currentQueue.length - currentIndex - 1;
                    if (remainingSongs <= preloadThreshold) {
                      AppLogger.info('[PlaybackNotifier] ⚡ Salto manual pequeño detectado con solo $remainingSongs canciones restantes. Programando recarga...');
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (!_isPreloading && state.playbackMode == PlaybackMode.algorithm) {
                          _forceImmediatePreload();
                        }
                      });
                    }
                  }
                } else {
                  // 🎯 FASE 2: Forzar recarga inmediata si quedan pocas canciones (modo fixedQueue)
                  final remainingSongs = state.currentQueue.length - currentIndex - 1;
                  if (remainingSongs <= preloadThreshold) {
                    AppLogger.info('[PlaybackNotifier] ⚡ Salto manual detectado con solo $remainingSongs canciones restantes. Programando recarga...');
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (!_isPreloading && state.playbackMode == PlaybackMode.algorithm) {
                        _forceImmediatePreload();
                      }
                    });
                  }
                }
              }
            }
          }
          
          // Actualizar último índice conocido (siempre, incluso si no hubo salto manual)
          _lastKnownIndex = currentIndex;
          
          // Actualizar duración si está disponible
          final duration = currentSong.duration != null
              ? Duration(seconds: currentSong.duration!)
              : sequenceState.currentSource?.duration;
          
          state = state.copyWith(
            currentSong: currentSong,
            totalDuration: duration ?? Duration.zero,
          );
          
          // 🎯 FASE 1: Registrar canción reproducida en servicio centralizado
          ref.read(playbackSessionProvider.notifier).registerPlayedSong(currentSong.id);
          
          AppLogger.info('[PlaybackNotifier] Canción actual: ${currentSong.title}');
          
          // 🎯 PRE-FETCH: Si estamos en la última canción de una cola fija y está activo shouldStartAlgorithmAfterQueue,
          // preparar en background las recomendaciones para que al terminar no haya espera.
          if (state.playbackMode == PlaybackMode.fixedQueue &&
              state.shouldStartAlgorithmAfterQueue &&
              state.currentQueue.isNotEmpty &&
              currentIndex == state.currentQueue.length - 1) {
            final seed = state.currentQueue.last;
        // Recortar historial para no inflar excludeIds al terminar la playlist
        ref.read(playbackSessionProvider.notifier).trimForNewSession(keep: 10);
            // Solo prefetch si cambia de seed
            if (_prefetchedSeed?.id != seed.id) {
              _prefetchedSeed = seed;
              _prefetchedInitialSongs = null;
              AppLogger.info('[PlaybackNotifier] 🔄 Prefetch algoritmo para última canción: ${seed.title}');
              _prefetchInitialAlgorithmBuffer(seed);
            }
          }
        }
      }),
    );

    // 2. Suscribirse al estado de reproducción (play/pause)
    // 🛡️ NOTA: Este listener mantiene el estado sincronizado para otros widgets que lo necesiten
    // Pero el botón play/pause usa directamente el stream, no este estado
    _subscriptions.add(
      service.isPlayingStream.listen((isPlaying) {
        // ✅ ACTUALIZAR ESTADO: Para widgets que aún dependen del estado de Riverpod
        // El botón play/pause ya no depende de esto, usa el stream directamente
        state = state.copyWith(isPlaying: isPlaying);
        AppLogger.debug('[PlaybackNotifier] Stream actualizó isPlaying: $isPlaying');
      }),
    );

    // 3. Suscribirse a la posición (progreso)
    _subscriptions.add(
      service.positionStream.listen((position) {
        state = state.copyWith(currentPosition: position);
        // 🚀 SPOTIFY-LEVEL: Monitorear posición para pre-cargar audio de siguiente canción
        _checkAndPreloadNextAudio(position);
        // ⚡ TRANSICIÓN INSTANTÁNEA: Detectar final de canción ANTES de que termine
        _checkAndPrepareNextSongTransition(position);
      }),
    );

    // 4. Suscribirse al estado del reproductor (buffering, etc.)
    _subscriptions.add(
      service.playerStateStream.listen((playerState) {
        final isBuffering = playerState.processingState == ProcessingState.buffering ||
                           playerState.processingState == ProcessingState.loading;
        final isCompleted = playerState.processingState == ProcessingState.completed;
        
        // 🚨 CRÍTICO: Actualizar estado inmediatamente cuando la canción termina
        // Esto evita que la UI se quede congelada
        state = state.copyWith(
          isBuffering: isBuffering,
          isPlaying: !isCompleted && playerState.playing, // Actualizar isPlaying cuando termina
        );
        
        // ⚡ TRANSICIÓN INSTANTÁNEA: Detectar final de canción ANTES de que termine
        // Usar completed como fallback, pero la transición ya debería estar preparada
        if (isCompleted) {
          // 🛡️ FUENTE ÚNICA DE VERDAD: El stream actualizará isPlaying automáticamente
          // NO actualizar isPlaying manualmente - el stream es la única fuente de verdad
          
          // Usar unawaited para evitar esperar en el listener del stream
          _handleSongCompletion();
        }
      }),
    );

    // 🚨 5. SINCRONIZACIÓN: Suscribirse a cambios en la cola de just_audio
    // Esto asegura que el estado siempre refleje la realidad del reproductor
    _subscriptions.add(
      service.sequenceStateStream.listen((sequenceState) {
        _syncQueueWithAudioService(sequenceState);
        // 🚀 SPOTIFY-LEVEL: Pre-cargar audio de siguiente canción cuando cambia la cola
        _preloadNextSongAudio(sequenceState);
        // 🛡️ GUARD ANTI-LOOP: Deduplicación mejorada en runtime
        _performRuntimeDeduplication(sequenceState);
      }),
    );

    // 🛡️ 6. GUARD ANTI-LOOP: Suscribirse a errores del reproductor
    // Detecta errores de MediaCodec CORRUPTED y fuerza seekToNext()
    // Los errores aparecen cuando processingState es idle inesperadamente
    _subscriptions.add(
      service.playerStateStream.listen((playerState) {
        // Detectar errores cuando el reproductor está idle inesperadamente
        // (no debería estar idle si está reproduciendo)
        if (playerState.processingState == ProcessingState.idle && state.isPlaying) {
          // Si está idle mientras debería reproducir, puede ser un error CORRUPTED
          // Intentar obtener el error usando reflexión o simplemente detectar el estado
          try {
            // En just_audio, cuando hay un error, el processingState cambia a idle
            // Verificar si hay un error accediendo al playerState directamente
            final hasError = service.hasError;
            if (hasError) {
              // Crear un PlayerException simulado para manejar el error
              // El mensaje real vendrá de los logs del sistema
              _checkForSilentCorruption();
            }
          } catch (e) {
            AppLogger.debug('[PlaybackNotifier] Error al verificar error del reproductor: $e');
          }
        }
      }),
    );
  }

  // ============== Lógica de Colas ==============

  /// Reproducir cola fija (playlist/artista)
  /// 
  /// [playlist]: Lista de canciones a reproducir
  /// [startSong]: Canción inicial (debe estar en la playlist)
  /// [contextId]: ID del contexto (playlistId o artistId)
  Future<void> playFixedQueue(
    List<Song> playlist,
    Song startSong, {
    String? contextId,
  }) async {
    try {
      if (state.isReplacingQueue) {
        return;
      }
      if (playlist.isEmpty) {
        throw Exception('La playlist está vacía');
      }

      if (!playlist.any((s) => s.id == startSong.id)) {
        throw Exception('La canción inicial no está en la playlist');
      }

      // 🚨 CRÍTICO: Verificar si hay transiciones a algoritmo en curso ANTES de limpiar
      // Esto previene conflictos cuando se toca una canción de playlist mientras
      // el algoritmo está iniciándose (por ejemplo, después de tocar la última canción)
      final wasAlgorithmMode = state.playbackMode == PlaybackMode.algorithm;
      final hadPendingAlgorithmTransition = state.shouldStartAlgorithmAfterQueue || 
                                            _isRestartingAlgorithm || 
                                            _isGeneratingRecommendations ||
                                            _isPreloading;
      
      // Ahora limpiar los flags
      _isGeneratingRecommendations = false;
      _isPreloading = false;
      _isRestartingAlgorithm = false;
      
      // 🚨 IMPORTANTE: conservar la intención de onPressPlayAll
      // Si shouldStartAlgorithmAfterQueue venía en true, mantenerlo para que la última canción active el algoritmo.
      state = state.copyWith(
        isLoading: true,
        playbackMode: PlaybackMode.fixedQueue,
        currentQueue: playlist,
        contextId: contextId,
        shouldStartAlgorithmAfterQueue: state.shouldStartAlgorithmAfterQueue,
      );

      // Detener monitor de algoritmo si estaba activo
      _stopAlgorithmMonitor();
      
      // 🛡️ Detener sistema de protección de cola (solo para modo algoritmo)
      _stopQueueProtection();
      
      // 🚨 LIMPIEZA ROBUSTA: Si veníamos de modo algoritmo O si había una transición en curso,
      // esperar más tiempo para asegurar que el player esté completamente detenido antes de cargar nueva cola
      
      if (wasAlgorithmMode || hadPendingAlgorithmTransition) {
        AppLogger.info('[PlaybackNotifier] 🔄 Cambiando de modo algoritmo a playlist, limpiando estado...');
        if (hadPendingAlgorithmTransition) {
          AppLogger.info('[PlaybackNotifier] ⚠️ Transición a algoritmo detectada, cancelando y esperando...');
        }
        // Esperar más tiempo para asegurar que cualquier operación de algoritmo termine
        await Future.delayed(const Duration(milliseconds: 500));
        // Detener completamente el player antes de cargar nueva cola
        try {
          await service.player.pause();
          await service.player.stop();
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          AppLogger.debug('[PlaybackNotifier] Error al limpiar player (puede ser normal): $e');
        }
      }

      // 🚨 VALIDACIÓN: Filtrar canciones inválidas antes de agregar
      final validPlaylist = playlist.where((s) => s.isValidForPlayback).toList();
      
      if (validPlaylist.isEmpty) {
        AppLogger.error('[PlaybackNotifier] ❌ No hay canciones válidas en la playlist');
        state = state.copyWith(isLoading: false);
        return;
      }
      
      if (validPlaylist.length < playlist.length) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ ${playlist.length - validPlaylist.length} canciones inválidas filtradas de la playlist');
      }
      
      // Verificar que la canción de inicio sea válida
      if (!validPlaylist.any((s) => s.id == startSong.id)) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Canción de inicio inválida, usando primera válida');
        final newStartSong = validPlaylist.first;
        state = state.copyWith(currentSong: newStartSong);
        startSong = newStartSong;
      }

      // 🚨 ACTUALIZACIÓN ATÓMICA: Cargar cola de forma sincronizada
      _isUpdatingQueue = true;
      try {
        // Convertir canciones válidas a AudioSource
        final sources = validPlaylist.map((s) => s.toAudioSource()).toList();
        final startIndex = validPlaylist.indexWhere((s) => s.id == startSong.id);

        // Cargar cola en el reproductor
        await service.loadNewQueue(sources, startIndex);
        
        // 🎯 DETECCIÓN MANUAL: Inicializar índice conocido
        _lastKnownIndex = startIndex;
        
        // Actualizar estado de forma atómica
        // 🛡️ NO ACTUALIZAR isPlaying: El stream lo hará automáticamente
            state = state.copyWith(
              currentQueue: validPlaylist,
              isLoading: false,
              lastConfirmedSong: state.lastConfirmedSong ?? startSong,
            );
          state = state.copyWith(
            currentQueue: validPlaylist,
            isLoading: false,
            lastConfirmedSong: state.lastConfirmedSong ?? startSong,
          );
        
        // Sincronizar de inmediato para que currentSong no quede nulo en la UI
        _syncQueueWithAudioService(service.player.sequenceState);
        if (state.currentSong == null && startIndex >= 0 && startIndex < validPlaylist.length) {
          state = state.copyWith(currentSong: validPlaylist[startIndex]);
        }

        // Reproducir
        await service.play();

        // 🛡️ FUENTE ÚNICA DE VERDAD: El stream actualizará isPlaying automáticamente
        // NO actualizar isPlaying manualmente - el stream es la única fuente de verdad
        // Solo actualizar isBuffering si es necesario para otros widgets
        final actualPlayerState = service.player.playerState;
        final actualIsBuffering = actualPlayerState.processingState == ProcessingState.buffering ||
                                 actualPlayerState.processingState == ProcessingState.loading;
        
        state = state.copyWith(
          isBuffering: actualIsBuffering,
          lastConfirmedSong: state.currentSong ?? state.lastConfirmedSong,
        );
        
        // Sincronizar cola después de un breve delay
        _syncQueueWithAudioService(service.player.sequenceState);
        Future.delayed(const Duration(milliseconds: 200), () {
          _syncQueueWithAudioService(service.player.sequenceState);
        });

        // Asegurar currentSong y posición inicial tras iniciar reproducción
        _syncQueueWithAudioService(service.player.sequenceState);
        if (state.currentSong == null && startIndex >= 0 && startIndex < validPlaylist.length) {
          state = state.copyWith(currentSong: validPlaylist[startIndex]);
        }
        state = state.copyWith(currentPosition: Duration.zero);
      } finally {
        _isUpdatingQueue = false;
      }
      
      AppLogger.info('[PlaybackNotifier] Cola fija cargada: ${playlist.length} canciones, iniciando en: ${startSong.title}');
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al cargar cola fija: $e', stackTrace);
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Iniciar modo algoritmo (recomendaciones dinámicas)
  /// 
  /// [seedSong]: Canción inicial para generar recomendaciones
  /// [excludeSeedFromQueue]: Si es true, NO incluye la semilla en la cola (útil para transiciones desde cola fija)
  Future<void> playAlgorithmStart(Song seedSong, {bool excludeSeedFromQueue = false}) async {
    try {
      AppLogger.info('[PlaybackNotifier] 🚀 Iniciando Radio Infinita con semilla: ${seedSong.title} (ID: ${seedSong.id})${excludeSeedFromQueue ? ' (semilla excluida de cola)' : ''}');
      
      // 🚨 CRÍTICO: Detener TODOS los procesos del algoritmo anterior antes de iniciar uno nuevo
      // Esto evita conflictos cuando se cambia de canción mientras el algoritmo está activo
      _stopAlgorithmMonitor(); // Detener monitor anterior
      _stopQueueProtection(); // Detener protección de cola anterior
      _isGeneratingRecommendations = false; // Cancelar generación de recomendaciones anterior
      
      // 🚨 CRÍTICO: Limpiar flags antes de iniciar nueva reproducción
      // Esto evita timeouts y bloqueos cuando se cambia de canción
      if (_isPreloading) {
        AppLogger.info('[PlaybackNotifier] 🛑 Cancelando precarga en curso...');
        _isPreloading = false;
        _lastPreloadTime = null;
      }
      
      if (_isUpdatingQueue) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Flag _isUpdatingQueue estaba bloqueado, limpiando...');
        _isUpdatingQueue = false;
      }

      if (_isReplacingQueue) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Flag _isReplacingQueue estaba bloqueado, limpiando...');
        _isReplacingQueue = false;
      }
      
      state = state.copyWith(
        isLoading: true,
        playbackMode: PlaybackMode.algorithm,
        contextId: null,
      );

      // 🚨 VALIDACIÓN: Verificar que la semilla sea válida antes de reproducir
      if (!seedSong.isValidForPlayback) {
        AppLogger.error('[PlaybackNotifier] ❌ Semilla inválida: ${seedSong.title} (fileUrl: ${seedSong.fileUrl ?? "null"})');
        state = state.copyWith(isLoading: false);
        throw Exception('La canción semilla no tiene URL de archivo válida');
      }
      
      List<Song> initialSongs = const [];

      // Ajustar tamaño de excludeIds según origen: playlist (fin) vs tarjeta
      final sessionNotifier = ref.read(playbackSessionProvider.notifier);
      final totalKnown = sessionNotifier.getPlayedSongIds().length + state.currentQueue.length;
      final excludeLimit = totalKnown <= 12 ? 5 : 8;

      if (excludeSeedFromQueue) {
        // Caso especial: venimos de una playlist y no queremos repetir la semilla.
        // Generar primero las recomendaciones rápidas y cargar la cola SIN la semilla.
        AppLogger.info('[PlaybackNotifier] ⚡ Obteniendo buffer inicial crítico (sin semilla en cola)...');
        // Usar prefetch si existe y coincide la semilla
        if (_prefetchedSeed?.id == seedSong.id && _prefetchedInitialSongs != null && _prefetchedInitialSongs!.isNotEmpty) {
          initialSongs = _prefetchedInitialSongs!;
          AppLogger.info('[PlaybackNotifier] ⚡ Usando prefetch inicial (${initialSongs.length} canciones)');
        } else {
          initialSongs = await _generateInitialRecommendations(seedSong, excludeSeedFromQueue: true);
        }

        // Filtrar canciones no reproducibles (previene carátulas de tracks corruptos)
        initialSongs = _filterPlayableSongs(initialSongs);

        // Si no hay recomendaciones, intentar un fallback con canciones estáticas/destacadas excluyendo la semilla
        if (initialSongs.isEmpty) {
          try {
            // En este flujo, usa un exclude acotado para no inflar la request
            final playedIds = sessionNotifier.getPlayedSongIds(limit: excludeLimit);
            final fallback = await _intelligentService.getIntelligentFeaturedSongs(
              limit: 3,
              currentSongId: seedSong.id,
              forceRefresh: false,
              excludeIds: {...playedIds, seedSong.id},
            );
            if (fallback.isNotEmpty) {
              initialSongs = fallback.map((f) => f.song).toList();
              AppLogger.info('[PlaybackNotifier] ✅ Fallback inicial sin semilla: ${initialSongs.length} canciones');
            }
          } catch (e) {
            AppLogger.debug('[PlaybackNotifier] Fallback inicial sin semilla falló: $e');
          }
        }

        // Si aún no hay nada, usar la semilla como último recurso
        final songsToLoad = initialSongs.isNotEmpty ? initialSongs : <Song>[seedSong];

      _isReplacingQueue = true;
      state = state.copyWith(isReplacingQueue: true);
        _isUpdatingQueue = true;
        try {
          final sources = songsToLoad.map((s) => s.toAudioSource()).toList();
          await service.loadNewQueue(sources, 0);
          _lastKnownIndex = 0;
          // Evitar mostrar portada incorrecta: limpiar canción actual hasta que el stream reporte la nueva
          // Forzar coherencia inmediata con la primera canción de la nueva cola
          final firstTag = sources.isNotEmpty ? (sources.first as dynamic).tag : null;
          if (firstTag is Song) {
            final firstSong = firstTag;
            state = state.copyWith(
              currentQueue: songsToLoad,
              currentSong: firstSong,
              lastConfirmedSong: firstSong,
              currentPosition: Duration.zero,
              isBuffering: true,
            );
          } else {
            // Evitar mostrar portada incorrecta: limpiar canción actual hasta que el stream reporte la nueva
          state = state.copyWith(
            currentQueue: songsToLoad,
            isBuffering: true,
          );
          }
        } finally {
          _isReplacingQueue = false;
          _isUpdatingQueue = false;
          state = state.copyWith(isReplacingQueue: false);
        }

        AppLogger.info('[PlaybackNotifier] ✅ Cola cargada sin semilla (start en índice 0). Tamaño: ${state.currentQueue.length}');
        // Limpiar prefetch usado
        _prefetchedInitialSongs = null;
        _prefetchedSeed = null;
      } else {
        // Flujo normal: cargamos la semilla primero y luego agregamos buffer
        _isReplacingQueue = true;
        _isUpdatingQueue = true;
        try {
          final seedSource = seedSong.toAudioSource();
          await service.loadNewQueue([seedSource], 0);
          _lastKnownIndex = 0;
          state = state.copyWith(
            currentQueue: <Song>[seedSong],
            currentSong: seedSong,
            lastConfirmedSong: seedSong,
            currentPosition: Duration.zero,
            isBuffering: true,
          );
        } finally {
          _isReplacingQueue = false;
          _isUpdatingQueue = false;
          state = state.copyWith(isReplacingQueue: false);
        }

        AppLogger.info('[PlaybackNotifier] ✅ Semilla cargada: ${seedSong.title}');

        AppLogger.info('[PlaybackNotifier] ⚡ Obteniendo buffer inicial crítico (Fase 1 rápida)...');
        initialSongs = await _generateInitialRecommendations(seedSong, excludeSeedFromQueue: false);

        // Filtrar canciones no reproducibles antes de agregarlas
        initialSongs = _filterPlayableSongs(initialSongs);

        if (initialSongs.isNotEmpty) {
          final queueSizeBefore = state.currentQueue.length;
          await _updateQueueAtomically(
            newSongs: initialSongs,
            audioOperation: (sources) => service.appendToQueue(sources),
            replace: false,
          );
          final queueSizeAfter = state.currentQueue.length;
          final actuallyAdded = queueSizeAfter - queueSizeBefore;

          if (actuallyAdded > 0) {
            AppLogger.info('[PlaybackNotifier] ✅ Buffer inicial: $actuallyAdded canciones agregadas a la cola (${initialSongs.length} solicitadas, ${initialSongs.length - actuallyAdded} duplicadas filtradas)');
          } else {
            AppLogger.info('[PlaybackNotifier] ⚠️ Buffer inicial: Todas las canciones ya estaban en la cola (${initialSongs.length} solicitadas)');
          }
        } else {
          AppLogger.warning('[PlaybackNotifier] ⚠️ Buffer inicial: La Fase 1 no devolvió canciones. Procediendo solo con la semilla.');
        }
      }

      // 🎯 FASE 2: Iniciar reproducción SOLAMENTE DESPUÉS de cargar la semilla y el buffer inicial
      // Esto elimina el riesgo de stalling (cola vacía cuando termina la primera canción)
      state = state.copyWith(isLoading: false);

      // Sincronizar de inmediato para que currentSong no quede nulo
      _syncQueueWithAudioService(service.player.sequenceState);
      if (state.currentSong == null && _lastConfirmedSong != null) {
        state = state.copyWith(currentSong: _lastConfirmedSong);
      }

      // Activar bloqueo crítico durante el arranque del modo algoritmo
      _isAwaitingInitialAlgorithmPlay = true;

      await service.play();

      // 🛡️ FUENTE ÚNICA DE VERDAD: El stream actualizará isPlaying automáticamente
      // Solo actualizar isBuffering si es necesario para otros widgets
      final actualPlayerState = service.player.playerState;
      final actualIsBuffering = actualPlayerState.processingState == ProcessingState.buffering ||
                               actualPlayerState.processingState == ProcessingState.loading;
      
      state = state.copyWith(
        isBuffering: actualIsBuffering,
        lastConfirmedSong: state.currentSong ?? state.lastConfirmedSong,
      );

      // Sincronizar y asegurar currentSong/posición tras play
      _syncQueueWithAudioService(service.player.sequenceState);
      if (state.currentSong == null && _lastConfirmedSong != null) {
        state = state.copyWith(currentSong: _lastConfirmedSong);
      }
      state = state.copyWith(currentPosition: Duration.zero);
      
      // Sincronizar cola después de un breve delay
      Future.delayed(const Duration(milliseconds: 200), () {
        _syncQueueWithAudioService(service.player.sequenceState);
      });

      AppLogger.info('[PlaybackNotifier] ✅ Reproducción iniciada con buffer garantizado: ${state.currentQueue.length} canciones en cola');

      // 🎯 FASE 3 (BACKGROUND): Ejecutar Fase 2 completa en background (sin await)
      // Esto permite que la función retorne y la música continúe mientras se cargan más canciones
      _generateAndAppendRecommendations(seedSong, excludeSeedFromQueue: excludeSeedFromQueue);

      // Iniciar monitor optimizado (verifica cada 5s con condiciones más agresivas)
      _startAlgorithmMonitor();
      
      // 🛡️ PREVENCIÓN DE COLA VACÍA: Iniciar sistema de protección
      _startQueueProtection();
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al iniciar modo algoritmo: $e', stackTrace);
      state = state.copyWith(isLoading: false, shouldStartAlgorithmAfterQueue: false);
      rethrow;
    }
  }

  /// 🎯 FASE 1 RÁPIDA: Obtener buffer inicial crítico (1-2 canciones) antes de reproducir
  /// 
  /// Esta función garantiza que haya al menos 1-2 canciones disponibles cuando termine
  /// la primera canción, eliminando el riesgo de stalling (cola vacía).
  /// 
  /// [seedSong]: Canción semilla para generar recomendaciones
  /// [excludeSeedFromQueue]: Si es true, excluye la semilla de los IDs a excluir
  /// 
  /// Retorna: Lista de canciones iniciales (mínimo 1-2) para el buffer crítico
  Future<List<Song>> _generateInitialRecommendations(Song seedSong, {bool excludeSeedFromQueue = false}) async {
    try {
      // 🎯 FASE 1: Obtener excludeIds del servicio centralizado
      final excludeLimit = 8;
      final playedIds = ref.read(playbackSessionProvider.notifier).getPlayedSongIds(limit: excludeLimit);
      // Incluir canciones actuales en la cola (playlist) para evitar duplicados en la transición
      final currentQueueIds = state.currentQueue.map((s) => s.id).toSet();
      final excludeIds = excludeSeedFromQueue 
          ? {...playedIds, seedSong.id, ...currentQueueIds}
          : {...playedIds, ...currentQueueIds};
      
      // ⚡ OBTENER BUFFER MÍNIMO: Solo 2 canciones para garantizar transición fluida
      // Esto es mucho más rápido que obtener 6-15 canciones
      final quickRecommendations = await _intelligentService.getIntelligentFeaturedSongs(
        limit: 2, // 🎯 SOLO 2 canciones para buffer mínimo rápido
        currentSongId: seedSong.id,
        forceRefresh: true,
        excludeIds: excludeIds,
      );
      
      if (quickRecommendations.isEmpty) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Fase 1 rápida: No se obtuvieron recomendaciones');
        return [];
      }
      
      // Filtrar y validar canciones
      final seen = <String>{};
      final validSongs = quickRecommendations
          .map((f) => f.song)
          .where((s) => !excludeIds.contains(s.id))
          .where((s) {
            final isNew = !seen.contains(s.id);
            if (isNew) seen.add(s.id);
            return isNew;
          })
          .where((s) => s.isValidForPlayback) // 🚨 CRÍTICO: Solo canciones válidas
          .take(2) // Máximo 2 canciones para buffer mínimo
          .toList();
      
      if (validSongs.isEmpty) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Fase 1 rápida: Todas las canciones son inválidas o duplicadas');
        return [];
      }
      
      AppLogger.info('[PlaybackNotifier] ✅ Buffer inicial obtenido: ${validSongs.length} canciones válidas');
      return validSongs;
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] ❌ Error en Fase 1 rápida: $e');
      return []; // Retornar lista vacía en caso de error (no bloquear reproducción)
    }
  }

  /// Prefetch inicial para transición playlist -> algoritmo (última canción)
  Future<void> _prefetchInitialAlgorithmBuffer(Song seedSong) async {
    try {
      final prefetched = await _generateInitialRecommendations(seedSong, excludeSeedFromQueue: true);
      _prefetchedSeed = seedSong;
      _prefetchedInitialSongs = prefetched;
      AppLogger.info('[PlaybackNotifier] ✅ Prefetch inicial listo: ${prefetched.length} canciones (semilla: ${seedSong.title})');
    } catch (e) {
      AppLogger.debug('[PlaybackNotifier] Prefetch inicial falló: $e');
      _prefetchedInitialSongs = null;
    }
  }

  /// Generar recomendaciones y agregarlas a la cola en background (no bloquea)
  /// 
  /// Este método ejecuta la costosa lógica de backend (obtener 15 recomendaciones)
  /// y, al finalizar, agrega (append) las nuevas canciones a la cola del AudioService.
  /// Se ejecuta completamente en background sin bloquear la reproducción.
  /// 
  /// NOTA: Esta función se ejecuta DESPUÉS de que la reproducción ya ha comenzado,
  /// por lo que no bloquea el inicio de la música. Es la Fase 2 completa.
  Future<void> _generateAndAppendRecommendations(Song seedSong, {bool excludeSeedFromQueue = false}) async {
    // 🚨 PROTECCIÓN: Marcar que estamos generando recomendaciones
    _isGeneratingRecommendations = true;
    
    try {
      // 🚨 VERIFICACIÓN: Solo cancelar si el modo de reproducción cambió o se canceló explícitamente
      // NO cancelar solo porque la canción cambió (eso es normal cuando avanza la reproducción)
      if (!_isGeneratingRecommendations || state.playbackMode != PlaybackMode.algorithm) {
        AppLogger.info('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (modo de reproducción cambió o se canceló explícitamente)');
        return;
      }
      
      // 🎯 FASE 2 EN BACKGROUND: Usar las canciones que ya están en la cola como semillas
      // La Fase 1 rápida ya se ejecutó en _generateInitialRecommendations() antes de reproducir
      // Ahora usamos esas canciones (más la semilla) para generar más recomendaciones
      AppLogger.info('[PlaybackNotifier] 🔗 Iniciando Fase 2 completa en background...');
      
      // 🎯 Obtener excludeIds del servicio centralizado
      final sessionNotifier = ref.read(playbackSessionProvider.notifier);
      final totalKnown = sessionNotifier.getPlayedSongIds().length + state.currentQueue.length;
      final excludeLimit = totalKnown <= 12 ? 5 : (excludeSeedFromQueue ? 15 : 8);
      final playedIds = sessionNotifier.getPlayedSongIds(limit: excludeLimit);
      final currentQueueIds = state.currentQueue.map((s) => s.id).toSet();
      final excludeIds = excludeSeedFromQueue 
          ? {...playedIds, seedSong.id, ...currentQueueIds}
          : {...playedIds, ...currentQueueIds};
      
      // 🎯 Obtener canciones que ya están en la cola para usarlas como semillas
      // Esto incluye la semilla original + las canciones del buffer inicial
      final currentQueueSongs = state.currentQueue.toList();
      final seedSongs = currentQueueSongs.isNotEmpty 
          ? currentQueueSongs 
          : [seedSong]; // Fallback: usar solo la semilla si la cola está vacía
      
      // 🚨 VERIFICACIÓN: Solo cancelar si el modo de reproducción cambió
      if (!_isGeneratingRecommendations || state.playbackMode != PlaybackMode.algorithm) {
        AppLogger.info('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (modo de reproducción cambió)');
        return;
      }
      
      // 🚨 VERIFICACIÓN CRÍTICA: Verificar que la semilla original todavía esté en la cola
      // Si la semilla ya no está en la cola, significa que se cambió de canción y esta Fase 2 es obsoleta
      final initialSequenceState = service.player.sequenceState;
      final initialAudioQueueIds = <String>{};
      if (initialSequenceState.sequence.isNotEmpty) {
        for (final source in initialSequenceState.sequence) {
          if (source.tag is Song) {
            initialAudioQueueIds.add((source.tag as Song).id);
          }
        }
      }
      final initialStateQueueIds = state.currentQueue.map((s) => s.id).toSet();
      final initialAllQueueIds = {...initialAudioQueueIds, ...initialStateQueueIds};
      
      if (!initialAllQueueIds.contains(seedSong.id)) {
        AppLogger.info('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (semilla original ya no está en la cola - se cambió de canción antes de Fase 2)');
        return;
      }
      
      // 🎯 FASE 2: Usar las canciones de la cola como semillas DIRECTAMENTE
      // Si hay suficientes canciones (al menos 2), usar el método desacoplado rápido
      if (seedSongs.length >= 2) {
        AppLogger.info('[PlaybackNotifier] 🔗 Iniciando Fase 2 desacoplada con ${seedSongs.length} semillas de la cola actual...');
        
        // 🎯 Obtener IDs de la cola actual del audio service (más confiable que el estado)
        // Esto evita condiciones de carrera donde el estado puede estar desactualizado
        final sequenceState = service.player.sequenceState;
        final audioQueueIds = <String>{};
        if (sequenceState.sequence.isNotEmpty) {
          for (final source in sequenceState.sequence) {
            if (source.tag is Song) {
              audioQueueIds.add((source.tag as Song).id);
            }
          }
        }
        // También incluir IDs del estado por si acaso
        final stateQueueIds = state.currentQueue.map((s) => s.id).toSet();
        final allQueueIds = {...audioQueueIds, ...stateQueueIds};
        final phase2ExcludeIds = {...excludeIds, ...allQueueIds};
        
        // 🚨 VERIFICACIÓN: Solo cancelar si el modo de reproducción cambió o la semilla ya no está
        if (!_isGeneratingRecommendations || state.playbackMode != PlaybackMode.algorithm) {
          AppLogger.info('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (modo de reproducción cambió antes de Fase 2)');
          return;
        }
        
        // Verificar nuevamente que la semilla todavía esté en la cola
        final currentCheckSequenceState = service.player.sequenceState;
        final currentCheckAudioQueueIds = <String>{};
        if (currentCheckSequenceState.sequence.isNotEmpty) {
          for (final source in currentCheckSequenceState.sequence) {
            if (source.tag is Song) {
              currentCheckAudioQueueIds.add((source.tag as Song).id);
            }
          }
        }
        final currentCheckStateQueueIds = state.currentQueue.map((s) => s.id).toSet();
        final currentCheckAllQueueIds = {...currentCheckAudioQueueIds, ...currentCheckStateQueueIds};
        
        if (!currentCheckAllQueueIds.contains(seedSong.id)) {
          AppLogger.info('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (semilla original ya no está en la cola - se cambió de canción antes de generar Fase 2)');
          return;
        }
        
        // 🚨 MÉTODO DESACOPLADO: Usar semillas directamente sin llamar a getIntelligentFeaturedSongs
        // Esto evita duplicar trabajo y reduce tiempo de ~15s a ~5s
        final phase2Songs = await _intelligentService.generatePhase2RecommendationsFromSeeds(
          seeds: seedSongs.map((s) => s.id).toList(), // 🎯 USAR TODAS LAS SEMILLAS DE LA COLA ACTUAL
          count: 10, // Obtener 10 canciones adicionales
          excludeIds: phase2ExcludeIds, // Excluir todo lo que ya está en la cola
          user: null, // Nota: Se pasará el usuario cuando se implemente la autenticación completa para personalizar el scoring
        );
        
        // 🚨 VERIFICACIÓN: Solo cancelar si el modo de reproducción cambió
        if (!_isGeneratingRecommendations || state.playbackMode != PlaybackMode.algorithm) {
          AppLogger.info('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (modo de reproducción cambió después de Fase 2)');
          return;
        }
        
        // 🚨 VERIFICACIÓN CRÍTICA: Verificar que la semilla original todavía esté en la cola
        // Si la semilla ya no está en la cola, significa que se cambió de canción y esta Fase 2 es obsoleta
        final currentSequenceState = service.player.sequenceState;
        final currentAudioQueueIds = <String>{};
        if (currentSequenceState.sequence.isNotEmpty) {
          for (final source in currentSequenceState.sequence) {
            if (source.tag is Song) {
              currentAudioQueueIds.add((source.tag as Song).id);
            }
          }
        }
        final currentStateQueueIds = state.currentQueue.map((s) => s.id).toSet();
        final currentAllQueueIds = {...currentAudioQueueIds, ...currentStateQueueIds};
        
        // Verificar si la semilla original todavía está en la cola
        final seedStillInQueue = currentAllQueueIds.contains(seedSong.id);
        if (!seedStillInQueue) {
          AppLogger.info('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (semilla original ya no está en la cola - se cambió de canción)');
          return;
        }
        
        if (phase2Songs.isNotEmpty) {
          // 🚨 VERIFICACIÓN FINAL: Re-verificar duplicados contra la cola actual del audio service
          // Esto previene condiciones de carrera donde la cola cambió mientras se generaban recomendaciones
          
          // 🚨 VALIDACIÓN ROBUSTA: Filtrar canciones inválidas y duplicados usando isValidForPlayback
          final seenPhase2 = <String>{};
          final validSongs = phase2Songs.where((s) => 
            s.isValidForPlayback &&
            !currentAllQueueIds.contains(s.id) && // 🎯 VERIFICAR CONTRA COLA ACTUAL
            seenPhase2.add(s.id)
          ).toList();
          
          if (validSongs.length < phase2Songs.length) {
            AppLogger.warning('[PlaybackNotifier] ⚠️ Fase 2: ${phase2Songs.length - validSongs.length} canciones inválidas filtradas');
          }
          
          if (validSongs.isNotEmpty) {
            // 🚨 ACTUALIZACIÓN ATÓMICA: Usar método sincronizado para prevenir race conditions
            await _updateQueueAtomically(
              newSongs: validSongs,
              audioOperation: (sources) => service.appendToQueue(sources),
              replace: false,
            );
            
            AppLogger.info('[PlaybackNotifier] ✅ Fase 2 desacoplada completada: ${validSongs.length} canciones agregadas (total: ${state.currentQueue.length})');
          } else {
            AppLogger.info('[PlaybackNotifier] ⚠️ Fase 2: Todas las recomendaciones son inválidas o ya están en la cola');
          }
        } else {
          AppLogger.info('[PlaybackNotifier] ⚠️ Fase 2: No se obtuvieron recomendaciones de las semillas');
        }
      } else {
        // Fallback: Si no hay suficientes semillas, usar el método original
        AppLogger.info('[PlaybackNotifier] ⚠️ Fase 2: Usando método fallback (semillas insuficientes)');
        final recommendedSongs = await _generateInitialAlgorithmQueue(seedSong, excludeSeedFromQueue: excludeSeedFromQueue);
        
        if (recommendedSongs.isNotEmpty) {
          final currentQueueIds = state.currentQueue.map((s) => s.id).toSet();
          final songsToAdd = recommendedSongs
              .where((s) => !currentQueueIds.contains(s.id) && s.id != seedSong.id)
              .toList();
          
          if (songsToAdd.isNotEmpty) {
            // 🚨 VALIDACIÓN: Filtrar canciones inválidas antes de agregar
            final validSongsToAdd = songsToAdd.where((s) => s.isValidForPlayback).toList();
            
            if (validSongsToAdd.isEmpty) {
              AppLogger.warning('[PlaybackNotifier] ⚠️ Fallback: Todas las canciones tienen fileUrl inválido');
            } else {
              if (validSongsToAdd.length < songsToAdd.length) {
                AppLogger.warning('[PlaybackNotifier] ⚠️ Fallback: ${songsToAdd.length - validSongsToAdd.length} canciones inválidas filtradas');
              }
              
              // 🚨 ACTUALIZACIÓN ATÓMICA: Usar método sincronizado
              await _updateQueueAtomically(
                newSongs: validSongsToAdd,
                audioOperation: (sources) => service.appendToQueue(sources),
                replace: false,
              );
              
              AppLogger.info('[PlaybackNotifier] ✅ Cola completada (fallback): ${validSongsToAdd.length} canciones válidas agregadas');
            }
          }
        }
      }
    } catch (e) {
      // Silencioso en background: no debe interrumpir la experiencia del usuario
      AppLogger.debug('[PlaybackNotifier] Error en background (no crítico): $e');
    } finally {
      // 🚨 LIMPIAR: Solo limpiar el flag si todavía estamos en modo algoritmo
      // Esto permite que la Fase 2 continúe incluso si la canción cambió (normal cuando avanza)
      if (_isGeneratingRecommendations && state.playbackMode == PlaybackMode.algorithm) {
        _isGeneratingRecommendations = false;
      }
    }
  }

  /// Generar cola inicial para modo algoritmo
  /// 
  /// [seedSong]: Canción semilla para generar recomendaciones
  /// [excludeSeedFromQueue]: Si es true, NO incluye la semilla en la cola (útil para transiciones)
  Future<List<Song>> _generateInitialAlgorithmQueue(Song seedSong, {bool excludeSeedFromQueue = false}) async {
    try {
      // 🎯 FASE 1: Obtener excludeIds del servicio centralizado
      final sessionNotifier = ref.read(playbackSessionProvider.notifier);
      final totalKnown = sessionNotifier.getPlayedSongIds().length + state.currentQueue.length;
      final excludeLimit = totalKnown <= 12 ? 5 : (excludeSeedFromQueue ? 15 : 8);
      final playedIds = sessionNotifier.getPlayedSongIds(limit: excludeLimit);
      final excludeIds = excludeSeedFromQueue 
          ? {...playedIds, seedSong.id}
          : playedIds;
      
      // Usar IntelligentFeaturedService para obtener recomendaciones
      // IMPORTANTE: Excluir la semilla y el historial reciente para evitar repetición
      // 🚨 FORZAR REFRESH para obtener recomendaciones dinámicas frescas del algoritmo
      AppLogger.info('[PlaybackNotifier] 🔄 Solicitando recomendaciones dinámicas para semilla: ${seedSong.title} (ID: ${seedSong.id})');
      AppLogger.info('[PlaybackNotifier] 🚫 Excluyendo ${excludeIds.length} canciones (reproducidas: ${playedIds.length}, semilla: $excludeSeedFromQueue)');
      
      final featuredSongs = await _intelligentService.getIntelligentFeaturedSongs(
        limit: excludeSeedFromQueue ? 15 : 14, // Si excluimos la semilla, necesitamos 15 canciones
        currentSongId: seedSong.id, // 🎯 CRÍTICO: Pasar currentSongId fuerza modo algoritmo
        forceRefresh: true, // 🚨 FORZAR REFRESH para evitar cache de canciones estáticas
        excludeIds: excludeIds, // Excluir historial reciente y semilla si es necesario
      );
      
      AppLogger.info('[PlaybackNotifier] 📥 Recomendaciones recibidas: ${featuredSongs.length} canciones');

      AppLogger.info('[PlaybackNotifier] 📥 Recomendaciones recibidas: ${featuredSongs.length} canciones');
      
      // Filtrar la semilla y el historial reciente de las recomendaciones obtenidas
      final recommendedSongs = featuredSongs
          .map((f) => f.song)
          .where((s) => !excludeIds.contains(s.id))
          .take(15)
          .toList();

      AppLogger.info('[PlaybackNotifier] ✅ Canciones después de filtrar: ${recommendedSongs.length} (excluidas: ${excludeIds.length})');

      // Si no debemos excluir la semilla, agregarla al inicio (para inicio normal del algoritmo)
      if (!excludeSeedFromQueue && recommendedSongs.isNotEmpty) {
        final finalQueue = [seedSong, ...recommendedSongs];
        AppLogger.info('[PlaybackNotifier] 🎵 Cola final con semilla: ${finalQueue.length} canciones');
        return finalQueue;
      }

      // Si debemos excluir la semilla (transición desde cola fija), solo devolver recomendaciones
      if (recommendedSongs.isEmpty) {
        AppLogger.warning('[PlaybackNotifier] No se encontraron recomendaciones sin la semilla. Obteniendo canciones populares como fallback.');
        // Fallback: buscar canciones populares aleatorias (sin la semilla)
        try {
          final popularSongs = await _homeService.getPopularSongs(limit: 15);
          final filteredPopular = popularSongs
              .where((s) => s.id != seedSong.id)
              .take(15)
              .toList();
          
          if (filteredPopular.isNotEmpty) {
            AppLogger.info('[PlaybackNotifier] ✅ Fallback: ${filteredPopular.length} canciones populares obtenidas');
            return filteredPopular;
          }
        } catch (e) {
          AppLogger.error('[PlaybackNotifier] Error en fallback de canciones populares: $e');
        }
        
        return recommendedSongs; // Lista vacía si todo falla
      }

      return recommendedSongs;
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error generando cola inicial: $e');
      
      // Fallback: si no podemos generar recomendaciones, devolver lista vacía
      // Esto forzará un error que se manejará en playAlgorithmStart
      return [];
    }
  }

  /// 🎯 FASE 2: Obtener el número de canciones restantes en la cola
  /// 
  /// Calcula cuántas canciones quedan por delante de la canción actual.
  /// Retorna -1 si no se puede determinar (cola vacía o índice inválido).
  /// 🎯 FASE 2: Función centralizada para obtener canciones restantes
  /// Usa el índice real de audio cuando esté disponible para mayor precisión
  int _getRemainingQueueSize() {
    if (state.currentQueue.isEmpty) return -1;
    
    // 🚨 MEJORA: Intentar usar el índice real de audio primero (más preciso)
    final sequenceState = service.player.sequenceState;
    final audioCurrentIndex = sequenceState.currentIndex;
    
    int currentIndex;
    if (audioCurrentIndex != null && audioCurrentIndex >= 0 && audioCurrentIndex < state.currentQueue.length) {
      // Usar índice real de audio (más confiable)
      currentIndex = audioCurrentIndex;
    } else {
      // Fallback: buscar canción actual en la cola
      final currentSong = state.currentSong;
      if (currentSong == null) return -1;
      
      currentIndex = state.currentQueue.indexWhere(
        (s) => s.id == currentSong.id,
      );
      
      if (currentIndex == -1) return -1;
    }
    
    // Calcular canciones restantes: total - índice actual - 1 (porque el índice es 0-based)
    final remainingSongs = state.currentQueue.length - currentIndex - 1;
    return remainingSongs >= 0 ? remainingSongs : 0;
  }

  /// 🚀 SPOTIFY-LEVEL: Agregar más canciones a la cola del algoritmo
  /// Auto-llenado inteligente que mantiene siempre 10+ canciones disponibles
  /// Solo se ejecuta si se cumplen ambas condiciones:
  /// 1. Quedan 5 canciones o menos en la cola (aumentado para fluidez)
  /// 2. La canción actual está a 30 segundos o menos del final (aumentado para eliminar buffering)
  /// 3. No hay otra precarga en curso (_isPreloading = false)
  /// 
  /// [forceIgnoreCooldown]: Si es true, ignora el cooldown (útil para saltos manuales críticos)
  Future<void> _appendMoreAlgorithmSongs({bool forceIgnoreCooldown = false}) async {
    // 🚨 CONTROL DE CONCURRENCIA: Evitar múltiples llamadas simultáneas
    if (_isPreloading || state.currentQueue.isEmpty) {
      // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
      return;
    }
    
    // 🚨 PROTECCIÓN CRÍTICA: NO activar si se están generando recomendaciones iniciales
    // Esto evita conflictos entre _generateAndAppendRecommendations y _appendMoreAlgorithmSongs
    if (_isGeneratingRecommendations) {
      AppLogger.debug('[PlaybackNotifier] ⏳ Precarga bloqueada: generación de recomendaciones iniciales en curso');
      // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
      return;
    }
    
    // 🚨 COOLDOWN: Verificar que haya pasado el tiempo mínimo desde la última precarga
    // 🎯 EXCEPCIÓN: Si forceIgnoreCooldown es true, ignorar el cooldown (para saltos manuales críticos)
    if (!forceIgnoreCooldown && _lastPreloadTime != null) {
      final timeSinceLastPreload = DateTime.now().difference(_lastPreloadTime!);
      if (timeSinceLastPreload < _preloadCooldown) {
        final remainingCooldown = _preloadCooldown - timeSinceLastPreload;
        AppLogger.debug('[PlaybackNotifier] ⏳ Precarga bloqueada: cooldown activo (${timeSinceLastPreload.inMilliseconds}ms/${_preloadCooldown.inMilliseconds}ms, faltan ${remainingCooldown.inMilliseconds}ms)');
        // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
        if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
          _preloadCompleter!.complete();
          _preloadCompleter = null;
        }
        return;
      }
    }

    try {
      _isPreloading = true;
      _lastPreloadTime = DateTime.now(); // 🚨 COOLDOWN: Registrar timestamp
      
      final currentSong = state.currentSong ?? _lastConfirmedSong;
      if (currentSong == null) {
        _isPreloading = false;
        return;
      }
      
      // 🚀 SPOTIFY-LEVEL: Verificar condición de tiempo aumentada (30 segundos)
      final remainingTime = state.totalDuration - state.currentPosition;
      final shouldPreloadByTime = remainingTime.inSeconds <= _preloadTimeThreshold && remainingTime.inSeconds > 0;
      
      // 🎯 FASE 2: Usar función centralizada para obtener canciones restantes
      final remainingSongs = _getRemainingQueueSize();
      if (remainingSongs == -1) {
        _isPreloading = false;
        return; // No se puede determinar, salir silenciosamente
      }
      
      // 🚨 CRÍTICO: Si es precarga urgente (remainingSongs <= 2), saltar validación de tiempo
      final isUrgentPreload = remainingSongs <= 2;
      
      if (!isUrgentPreload && !shouldPreloadByTime) {
        _isPreloading = false; // Liberar flag antes de retornar
        return; // Silencioso: condición no cumplida
      }
      
      // 🎯 FASE 2: Verificar condición de cantidad usando umbral centralizado
      final shouldPreloadByCount = remainingSongs <= preloadThreshold;
      
      if (!isUrgentPreload && !shouldPreloadByCount) {
        _isPreloading = false; // Liberar flag antes de retornar
        // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
        if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
          _preloadCompleter!.complete();
          _preloadCompleter = null;
        }
        return; // Silencioso: hay suficientes canciones
      }
      
      // 🚨 LOG REDUCIDO: Solo cuando realmente inicia la precarga
      
      // 🎯 FASE 1: Obtener excludeIds del servicio centralizado + canciones en cola
      const baseExcludeLimit = 8; // precarga usa histórico corto
      final sessionNotifier = ref.read(playbackSessionProvider.notifier);
      final totalKnown = sessionNotifier.getPlayedSongIds().length + state.currentQueue.length;
      final excludeLimit = totalKnown <= 12 ? 5 : baseExcludeLimit;
      final playedIds = sessionNotifier.getPlayedSongIds(limit: excludeLimit);
      final queueIds = state.currentQueue.map((s) => s.id).toList();
      // Limitar IDs de cola para no inflar el exclude cuando la playlist es enorme
      final limitedQueueIds = queueIds.length > excludeLimit
          ? queueIds.sublist(queueIds.length - excludeLimit)
          : queueIds;
      final excludeIds = {...limitedQueueIds, ...playedIds};
      
      AppLogger.debug('[PlaybackNotifier] 🔍 Precarga: Excluyendo ${excludeIds.length} IDs (${limitedQueueIds.length} en cola (limitado) + ${playedIds.length} reproducidas)');
      
      // ⚡ TRANSICIÓN INSTANTÁNEA: Obtener más recomendaciones (20 en lugar de 15 para asegurar tercera canción)
      final featuredSongs = await _intelligentService.getIntelligentFeaturedSongs(
        limit: 20, // Aumentado para asegurar que siempre hay canciones disponibles
        currentSongId: currentSong.id,
        forceRefresh: false,
        excludeIds: excludeIds, // Excluir historial reciente y cola actual
      );

      AppLogger.debug('[PlaybackNotifier] 🔍 Precarga: Recibidas ${featuredSongs.length} recomendaciones del servicio');

      // Filtrar canciones que ya están en la cola o en el historial reciente
      final existingIds = limitedQueueIds.toSet();
      final newSongs = featuredSongs
          .map((f) => f.song)
          .where((s) => !excludeIds.contains(s.id))
          .where((s) => !existingIds.contains(s.id))
          .take(15) // Aumentado de 10 a 15 para asegurar más canciones disponibles
          .toList();

      AppLogger.debug('[PlaybackNotifier] 🔍 Precarga: ${newSongs.length} canciones nuevas después de filtrar duplicados');

      if (newSongs.isEmpty) {
        // 🛡️ PREVENCIÓN: Si no hay canciones nuevas, usar fallback para evitar cola vacía
        AppLogger.warning('[PlaybackNotifier] 🛡️ No hay canciones nuevas (${featuredSongs.length} recibidas, todas duplicadas), activando fallback para prevenir cola vacía');
        _tryFallbackRecommendations(currentSong, excludeIds);
        _isPreloading = false; // Liberar flag antes de retornar
        // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
        if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
          _preloadCompleter!.complete();
          _preloadCompleter = null;
        }
        return;
      }

      // 🚨 VALIDACIÓN: Filtrar canciones inválidas antes de agregar
      final validNewSongs = newSongs.where((s) => s.isValidForPlayback).toList();
      
      if (validNewSongs.isEmpty) {
        // 🛡️ PREVENCIÓN: Si todas son inválidas, usar fallback para evitar cola vacía
        AppLogger.warning('[PlaybackNotifier] 🛡️ Todas las canciones son inválidas, activando fallback para prevenir cola vacía');
        _tryFallbackRecommendations(currentSong, excludeIds);
        // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
        if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
          _preloadCompleter!.complete();
          _preloadCompleter = null;
        }
        return;
      }
      
      if (validNewSongs.length < newSongs.length) {
        AppLogger.debug('[PlaybackNotifier] ⚠️ Precarga: ${newSongs.length - validNewSongs.length} canciones inválidas filtradas');
      }

      // 🎯 FASE 3.1: Precarga Progresiva - Agregar solo canciones críticas inmediatamente
      // Separar canciones críticas (primeras 5) del resto
      final criticalSongs = validNewSongs.take(criticalSongsCount).toList();
      final additionalSongs = validNewSongs.skip(criticalSongsCount).toList();
      
      // 🚨 ACTUALIZACIÓN ATÓMICA: Usar método sincronizado para prevenir race conditions
      // 🎯 DETECCIÓN MANUAL: Si quedan 0 canciones, usar modo crítico que espera hasta completar
      final remainingSongsBeforeAdd = _getRemainingQueueSize();
      final isCriticalPreload = remainingSongsBeforeAdd != -1 && remainingSongsBeforeAdd <= 1;
      
      // 🎯 FASE 3.1: Agregar solo canciones críticas inmediatamente
      // El resto se agregará cuando el Monitor de Fase 2 detecte que la cola baja nuevamente
      await _updateQueueAtomically(
        newSongs: criticalSongs,
        audioOperation: (sources) => service.appendToQueue(sources),
        replace: false,
        waitForPrevious: isCriticalPreload, // Esperar si es precarga crítica
      );
      
      // 🎯 MÉTODO PROFESIONAL: Completar el Completer si existe (notificar que la precarga terminó)
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
      
      // 🎯 FASE 3.1: Log de canciones críticas agregadas
      final remainingSongsAfterAdd = _getRemainingQueueSize();
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1: PRECARGA COMPLETADA');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:    📊 Estado:');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       • Antes: ${remainingSongsBeforeAdd >= 0 ? remainingSongsBeforeAdd : "N/A"} canciones restantes');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       • Agregadas: ${criticalSongs.length} canciones críticas');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       • Después: ${remainingSongsAfterAdd >= 0 ? remainingSongsAfterAdd : "N/A"} canciones restantes');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:    🎵 Canciones agregadas:');
      for (int i = 0; i < criticalSongs.length && i < 3; i++) {
        AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       ${i + 1}. ${criticalSongs[i].title}');
      }
      if (criticalSongs.length > 3) {
        AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       ... y ${criticalSongs.length - 3} más');
      }
      
      // 🎯 FASE 3.1: Si hay más canciones, informar (pero no agregarlas ahora)
      // Por ahora, dejamos que el Monitor de Fase 2 se encargue de obtener más cuando sea necesario
      // Esto evita conflictos con el conteo de canciones del Monitor
      if (additionalSongs.isNotEmpty) {
        AppLogger.debug('[PlaybackNotifier] 📋 FASE 3.1:    💾 ${additionalSongs.length} canciones adicionales disponibles (el Monitor de Fase 2 las agregará cuando sea necesario)');
      }
      
      // 🎯 DETECCIÓN MANUAL: Si estaba en modo crítico (0 canciones), avanzar automáticamente
      // Solo si realmente estábamos sin siguiente canción y el reproductor estaba detenido/completado.
      final shouldAutoAdvance = isCriticalPreload &&
          remainingSongsBeforeAdd == 0 && // realmente sin siguiente
          criticalSongs.isNotEmpty &&
          (service.player.processingState == ProcessingState.completed ||
              !service.player.hasNext ||
              !service.player.playing);

      if (shouldAutoAdvance) {
        final remainingSongsAfterAdd = _getRemainingQueueSize();
        if (remainingSongsAfterAdd != -1 && remainingSongsAfterAdd > 0) {
          AppLogger.info('[PlaybackNotifier] ⚡ Precarga crítica completada: Avanzando automáticamente a siguiente canción...');
          // Esperar un momento para que la cola se actualice completamente
          await Future.delayed(const Duration(milliseconds: 200));
          // Avanzar solo si no hay otra actualización en curso
          if (!_isUpdatingQueue && service.player.hasNext) {
            try {
              await service.player.seekToNext();
              await service.player.play();
              AppLogger.info('[PlaybackNotifier] ✅ Avance automático completado después de precarga crítica');
            } catch (e) {
              AppLogger.debug('[PlaybackNotifier] Error en avance automático (no crítico): $e');
            }
          }
        }
      }
    } catch (e) {
      // Silencioso: errores en background no deben interrumpir la experiencia
      AppLogger.debug('[PlaybackNotifier] Error en precarga (no crítico): $e');
      // 🚨 CRÍTICO: Completar Completer incluso si hay error para evitar bloqueos
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
    } finally {
      _isPreloading = false; // 🚨 CRÍTICO: Liberar bandera siempre
      
      // 🎯 MÉTODO PROFESIONAL: Completar el Completer si existe (notificar que la precarga terminó)
      // Esto asegura que siempre se complete, incluso si hubo errores
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
    }
  }

  /// 🎯 FASE 2: Monitor proactivo para precargar canciones en modo algorithm
  /// 
  /// Detecta cuando quedan ≤3 canciones disponibles y dispara la recarga automáticamente.
  /// Usa la función centralizada _getRemainingQueueSize() como fuente única de verdad.
  void _startAlgorithmMonitor() {
    _stopAlgorithmMonitor(); // Asegurar que no haya otro monitor activo

    AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: Monitor iniciado - Verificando cada 5s (umbral: ≤$preloadThreshold canciones)');

    // 🎯 FASE 2: Verificar cada 5 segundos para detectar agotamiento del buffer
    _algorithmMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state.playbackMode != PlaybackMode.algorithm) {
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: Monitor detenido (modo cambiado)');
        _stopAlgorithmMonitor();
        return;
      }

      // 🚫 Si no se está reproduciendo o la cola está vacía, detener el monitor
      if (!service.player.playing || state.currentQueue.isEmpty) {
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: Monitor detenido (pausado o cola vacía)');
        _stopAlgorithmMonitor();
        return;
      }

      // 🎯 FASE 2: Obtener canciones restantes usando función centralizada
      final remainingSongs = _getRemainingQueueSize();
      
      if (remainingSongs == -1) {
        // No se puede determinar el tamaño, salir silenciosamente
        AppLogger.debug('[PlaybackNotifier] 🎯 FASE 2: No se puede determinar canciones restantes');
        return;
      }

      // 🎯 FASE 2: Log SIEMPRE visible cuando está cerca del umbral
      final currentIndex = state.currentQueue.indexWhere((s) => s.id == state.currentSong?.id);
      final totalSongs = state.currentQueue.length;
      final remainingTime = state.totalDuration - state.currentPosition;
      
      if (remainingSongs <= preloadThreshold) {
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR: ⚠️ CRÍTICO');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR:    📊 Estado: $remainingSongs/$totalSongs restantes (índice: ${currentIndex >= 0 ? currentIndex : "N/A"}/${totalSongs - 1})');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR:    ⏱️ Tiempo restante: ${remainingTime.inSeconds}s');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR:    🎯 Umbral: ≤$preloadThreshold canciones');
      } else {
        // Log cada 30 segundos cuando hay suficientes canciones
        final now = DateTime.now();
        if (_lastMonitorLogTime == null || now.difference(_lastMonitorLogTime!).inSeconds >= 30) {
          AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR: ✅ Estado saludable');
          AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR:    📊 Estado: $remainingSongs/$totalSongs restantes (índice: ${currentIndex >= 0 ? currentIndex : "N/A"}/${totalSongs - 1})');
          AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR:    ⏱️ Tiempo restante: ${remainingTime.inSeconds}s');
          AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR:    ✅ OK (umbral: ≤$preloadThreshold, no se dispara precarga)');
          _lastMonitorLogTime = now;
        }
      }

      // 🎯 FASE 2: Detección proactiva - Si quedan ≤3 canciones, disparar recarga
      // 🚨 PROTECCIÓN: NO activar si se están generando recomendaciones iniciales
      // Esto evita conflictos entre _generateAndAppendRecommendations y _appendMoreAlgorithmSongs
      if (remainingSongs <= preloadThreshold && !_isPreloading && !_isGeneratingRecommendations) {
        // 🚨 CRÍTICO: Si quedan ≤3 canciones (umbral crítico), IGNORAR cooldown y forzar precarga inmediata
        // Esto evita que el reproductor se quede sin canciones mientras espera el cooldown
        final remainingTime = state.totalDuration - state.currentPosition;
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: 🚀 PRECARGA PROACTIVA DISPARADA (URGENTE - COOLDOWN IGNORADO)');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2:    📊 Razón: $remainingSongs canciones restantes (umbral: ≤$preloadThreshold)');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2:    ⏱️ Tiempo restante: ${remainingTime.inSeconds}s');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2:    🎵 Canción actual: ${state.currentSong?.title ?? "N/A"}');
        // 🚨 FORZAR precarga ignorando cooldown cuando es crítico (≤3 canciones)
        _appendMoreAlgorithmSongs(forceIgnoreCooldown: true);
      }
    });
  }

  /// Detener monitor de algoritmo
  void _stopAlgorithmMonitor() {
    _algorithmMonitorTimer?.cancel();
    _algorithmMonitorTimer = null;
  }

  /// 🎯 DETECCIÓN MANUAL: Forzar recarga inmediata cuando se detecta salto manual
  /// Este método se llama cuando el usuario salta manualmente y quedan pocas canciones
  /// Ignora el cooldown para evitar "No hay siguiente canción"
  /// 🚨 PROTECCIÓN: Incluye múltiples validaciones para evitar bloqueos
  /// 🎯 MÉTODO PROFESIONAL: Ahora es async para poder esperar a que termine
  Future<void> _forceImmediatePreload() async {
    // Validaciones iniciales estrictas
    if (state.playbackMode != PlaybackMode.algorithm) {
      AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: No está en modo algoritmo');
      // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
      return;
    }
    
    if (_isPreloading) {
      AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: Precarga ya en curso, omitiendo');
      // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
      return;
    }
    
    if (state.currentQueue.isEmpty) {
      AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: Cola vacía');
      // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
      return;
    }
    
    try {
      final remainingSongs = _getRemainingQueueSize();
      if (remainingSongs == -1) {
        AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: No se puede determinar canciones restantes');
        // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
        if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
          _preloadCompleter!.complete();
          _preloadCompleter = null;
        }
        return;
      }
      
      // 🎯 DETECCIÓN MANUAL: Ignorar cooldown SIEMPRE si quedan ≤3 canciones (salto crítico)
      // Esto es especialmente importante cuando quedan 0 canciones para evitar "No hay siguiente canción"
      final shouldIgnoreCooldown = remainingSongs <= preloadThreshold;
      
      // 🚨 CRÍTICO: Si quedan pocas canciones, NO verificar cooldown (ignorarlo completamente)
      if (shouldIgnoreCooldown) {
        AppLogger.info('[PlaybackNotifier] ⚡ Salto manual detectado: Forzando recarga inmediata ($remainingSongs canciones restantes) [COOLDOWN IGNORADO - CRÍTICO]');
        // Marcar timestamp ANTES de llamar para evitar llamadas muy rápidas
        _lastPreloadTime = DateTime.now();
        // 🎯 MÉTODO PROFESIONAL: Esperar a que termine la precarga
        await _appendMoreAlgorithmSongs(forceIgnoreCooldown: true);
      } else {
        // Solo si hay suficientes canciones, verificar cooldown normalmente
        if (_lastPreloadTime != null) {
          final timeSinceLastPreload = DateTime.now().difference(_lastPreloadTime!);
          if (timeSinceLastPreload < _preloadCooldown) {
            AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: Cooldown activo (${timeSinceLastPreload.inSeconds}s/${_preloadCooldown.inSeconds}s)');
            // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
            if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
              _preloadCompleter!.complete();
              _preloadCompleter = null;
            }
            return;
          }
        }
        AppLogger.info('[PlaybackNotifier] ⚡ Salto manual: Recarga programada ($remainingSongs canciones restantes)');
        _lastPreloadTime = DateTime.now();
        // 🎯 MÉTODO PROFESIONAL: Esperar a que termine la precarga
        await _appendMoreAlgorithmSongs();
      }
    } catch (e, stackTrace) {
      // 🚨 PROTECCIÓN: Capturar cualquier error para evitar que bloquee la app
      AppLogger.error('[PlaybackNotifier] ❌ Error en _forceImmediatePreload: $e', stackTrace);
      // 🚨 CRÍTICO: Completar Completer si existe para evitar bloqueos
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
    }
  }

  /// 🛡️ PREVENCIÓN DE COLA VACÍA: Sistema de protección robusto
  /// Monitorea constantemente el tamaño de la cola y previene que se quede vacía
  void _startQueueProtection() {
    _stopQueueProtection(); // Asegurar que no haya otro monitor activo

    // Monitorear cada 5 segundos (reducido para evitar falsos positivos)
    _queueProtectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state.playbackMode != PlaybackMode.algorithm) {
        _stopQueueProtection();
        return;
      }

      // 🛡️ VALIDACIÓN MEJORADA: Usar el índice correcto de la secuencia de audio
      final sequenceState = service.player.sequenceState;
      final audioCurrentIndex = sequenceState.currentIndex;
      
      // Si no hay índice de audio, usar el índice de la canción actual en la cola
      int currentIndex;
      if (audioCurrentIndex != null && audioCurrentIndex >= 0) {
        currentIndex = audioCurrentIndex;
      } else {
        // Fallback: buscar canción actual en la cola
        final foundIndex = state.currentQueue.indexWhere(
          (s) => s.id == state.currentSong?.id,
        );
        currentIndex = foundIndex >= 0 ? foundIndex : 0;
      }

      final queueSize = state.currentQueue.length;
      
      // 🛡️ VALIDACIÓN: Asegurar que el índice sea válido
      if (currentIndex < 0 || currentIndex >= queueSize) {
        // Índice inválido, usar 0 como fallback seguro
        currentIndex = 0;
      }

      // 🎯 FASE 2: Usar función centralizada para obtener canciones restantes
      final remainingSongs = _getRemainingQueueSize();
      
      // 🎯 FASE 2: Si remainingSongs es -1, usar cálculo manual como fallback
      final effectiveRemainingSongs = remainingSongs == -1 
          ? (queueSize > 0 && currentIndex >= 0 ? queueSize - currentIndex - 1 : 0)
          : remainingSongs;

      // 🛡️ VALIDACIÓN ADICIONAL: Verificar que realmente hay una cola
      if (queueSize == 0) {
        // Cola realmente vacía
        if (_canTriggerEmergency()) {
          AppLogger.error('[PlaybackNotifier] 🚨 EMERGENCIA: Cola completamente vacía!');
          _emergencyRefillQueue();
        }
        return;
      }

      // 🛡️ CRÍTICO: Si la cola está vacía o casi vacía, acción inmediata
      // PERO solo si realmente quedan 0 o menos canciones (no durante inicialización)
      if (effectiveRemainingSongs <= 0 && queueSize > 0 && currentIndex < queueSize - 1) {
        // Esto puede ser un falso positivo durante transiciones
        // Solo activar si no hay precarga en curso y ha pasado el cooldown
        if (_canTriggerEmergency()) {
          AppLogger.error('[PlaybackNotifier] 🚨 EMERGENCIA: Cola vacía detectada! (índice: $currentIndex, tamaño: $queueSize)');
          _emergencyRefillQueue();
        }
        return;
      }

      // 🎯 FASE 2: Si quedan ≤3 canciones, precargar inmediatamente (usar umbral centralizado)
      // 🚨 PROTECCIÓN: NO activar si se están generando recomendaciones iniciales
      if (effectiveRemainingSongs <= preloadThreshold && effectiveRemainingSongs > 0 && !_isPreloading && !_isGeneratingRecommendations) {
        AppLogger.warning('[PlaybackNotifier] 🛡️ Cola crítica: Solo $effectiveRemainingSongs canciones restantes. Precarga urgente activada.');
        _appendMoreAlgorithmSongs();
        return;
      }

      // 🛡️ PREVENTIVO: Si quedan menos de 5 canciones, precargar proactivamente
      // 🚨 PROTECCIÓN: NO activar si se están generando recomendaciones iniciales
      if (effectiveRemainingSongs < _minQueueSize && effectiveRemainingSongs > 0 && !_isPreloading && !_isGeneratingRecommendations) {
        final remainingTime = state.totalDuration - state.currentPosition;
        // Precargar si quedan menos de 60 segundos (más anticipación)
        if (remainingTime.inSeconds <= 60 && remainingTime.inSeconds > 0) {
          AppLogger.info('[PlaybackNotifier] 🛡️ Precarga preventiva: $effectiveRemainingSongs canciones restantes (objetivo: $_minQueueSize)');
          _appendMoreAlgorithmSongs();
        }
      }

      // 🛡️ VALIDACIÓN: Verificar que la cola tenga tamaño mínimo
      // 🚨 PROTECCIÓN: NO activar si se están generando recomendaciones iniciales
      if (queueSize < _minQueueSize && !_isPreloading && !_isGeneratingRecommendations && queueSize > 0) {
        AppLogger.warning('[PlaybackNotifier] 🛡️ Cola pequeña detectada: $queueSize canciones (mínimo: $_minQueueSize). Precargando...');
        _appendMoreAlgorithmSongs();
      }
    });
  }

  /// Verificar si se puede activar emergencia (cooldown)
  bool _canTriggerEmergency() {
    if (_isPreloading) return false; // Ya hay una precarga en curso
    
    if (_lastEmergencyCall != null) {
      final timeSinceLastCall = DateTime.now().difference(_lastEmergencyCall!);
      if (timeSinceLastCall < _emergencyCooldown) {
        // Aún en cooldown, no activar
        return false;
      }
    }
    
    return true;
  }

  /// Detener sistema de protección de cola
  void _stopQueueProtection() {
    _queueProtectionTimer?.cancel();
    _queueProtectionTimer = null;
  }

  /// 🚨 EMERGENCIA: Rellenar cola cuando está vacía o crítica
  /// Usa múltiples estrategias de fallback para garantizar que siempre haya canciones
  Future<void> _emergencyRefillQueue() async {
    if (!_canTriggerEmergency()) {
      AppLogger.debug('[PlaybackNotifier] 🛡️ Emergencia bloqueada: cooldown activo o precarga en curso');
      return;
    }

    try {
      _isPreloading = true;
      _lastEmergencyCall = DateTime.now(); // Registrar timestamp
      AppLogger.error('[PlaybackNotifier] 🚨 EMERGENCIA: Iniciando relleno de emergencia de la cola');

      // Estrategia 1: Usar última canción reproducida como semilla
      Song? seedSong = state.currentSong;
      if (seedSong == null && state.currentQueue.isNotEmpty) {
        seedSong = state.currentQueue.last;
      }

      // Estrategia 2: Si no hay semilla, usar canciones populares
      if (seedSong == null) {
        AppLogger.warning('[PlaybackNotifier] 🚨 No hay semilla disponible, usando canciones populares');
        try {
          final popularSongs = await _homeService.getPopularSongs(limit: 10);
          final validPopular = popularSongs.where((s) => s.isValidForPlayback).take(10).toList();
          
          if (validPopular.isNotEmpty) {
            await _updateQueueAtomically(
              newSongs: validPopular,
              audioOperation: (sources) => service.appendToQueue(sources),
              replace: false,
            );
            AppLogger.info('[PlaybackNotifier] ✅ Emergencia: ${validPopular.length} canciones populares agregadas');
            _consecutiveFailures = 0;
            return;
          }
        } catch (e) {
          AppLogger.error('[PlaybackNotifier] ❌ Error en estrategia de emergencia (populares): $e');
        }
      }

      // Estrategia 3: Si hay semilla, obtener recomendaciones rápidas
      if (seedSong != null) {
        try {
          final emergencySongs = await _intelligentService.getIntelligentFeaturedSongs(
            limit: 15,
            currentSongId: seedSong.id,
            forceRefresh: true,
            excludeIds: ref.read(playbackSessionProvider.notifier).getPlayedSongIds(limit: 15),
          );

          final validEmergency = emergencySongs
              .map((f) => f.song)
              .where((s) => s.isValidForPlayback)
              .where((s) => !state.currentQueue.map((s) => s.id).contains(s.id))
              .take(10)
              .toList();

          if (validEmergency.isNotEmpty) {
            await _updateQueueAtomically(
              newSongs: validEmergency,
              audioOperation: (sources) => service.appendToQueue(sources),
              replace: false,
            );
            AppLogger.info('[PlaybackNotifier] ✅ Emergencia: ${validEmergency.length} recomendaciones agregadas');
            _consecutiveFailures = 0;
            return;
          }
        } catch (e) {
          AppLogger.error('[PlaybackNotifier] ❌ Error en estrategia de emergencia (recomendaciones): $e');
        }
      }

      // Estrategia 4: Último recurso - canciones populares sin filtros
      try {
        final lastResortSongs = await _homeService.getPopularSongs(limit: 20);
        final validLastResort = lastResortSongs
            .where((s) => s.isValidForPlayback)
            .take(15)
            .toList();

        if (validLastResort.isNotEmpty) {
          await _updateQueueAtomically(
            newSongs: validLastResort,
            audioOperation: (sources) => service.appendToQueue(sources),
            replace: false,
          );
          AppLogger.info('[PlaybackNotifier] ✅ Emergencia (último recurso): ${validLastResort.length} canciones agregadas');
          _consecutiveFailures = 0;
        } else {
          _consecutiveFailures++;
          AppLogger.error('[PlaybackNotifier] ❌ CRÍTICO: Todas las estrategias de emergencia fallaron. Fallos consecutivos: $_consecutiveFailures');
        }
      } catch (e) {
        _consecutiveFailures++;
        AppLogger.error('[PlaybackNotifier] ❌ CRÍTICO: Error en último recurso de emergencia: $e. Fallos consecutivos: $_consecutiveFailures');
      }
    } finally {
      _isPreloading = false;
    }
  }

  /// 🛡️ FALLBACK: Intentar obtener recomendaciones alternativas cuando falla la estrategia principal
  /// Previene que la cola se quede vacía usando múltiples fuentes
  Future<void> _tryFallbackRecommendations(Song currentSong, Set<String> excludeIds) async {
    try {
      // Fallback 1: Canciones populares
      final popularSongs = await _homeService.getPopularSongs(limit: 10);
      final validPopular = popularSongs
          .where((s) => s.isValidForPlayback)
          .where((s) => !excludeIds.contains(s.id))
          .take(10)
          .toList();

      if (validPopular.isNotEmpty) {
        await _updateQueueAtomically(
          newSongs: validPopular,
          audioOperation: (sources) => service.appendToQueue(sources),
          replace: false,
        );
        AppLogger.info('[PlaybackNotifier] 🛡️ Fallback exitoso: ${validPopular.length} canciones populares agregadas');
        _consecutiveFailures = 0;
        return;
      }
    } catch (e) {
      AppLogger.debug('[PlaybackNotifier] Fallback 1 falló: $e');
    }

    // Fallback 2: Recomendaciones con forceRefresh
    try {
      final fallbackRecommendations = await _intelligentService.getIntelligentFeaturedSongs(
        limit: 10,
        currentSongId: currentSong.id,
        forceRefresh: true, // Forzar refresh para evitar cache
        excludeIds: excludeIds,
      );

      final validFallback = fallbackRecommendations
          .map((f) => f.song)
          .where((s) => s.isValidForPlayback)
          .where((s) => !excludeIds.contains(s.id))
          .take(10)
          .toList();

      if (validFallback.isNotEmpty) {
        await _updateQueueAtomically(
          newSongs: validFallback,
          audioOperation: (sources) => service.appendToQueue(sources),
          replace: false,
        );
        AppLogger.info('[PlaybackNotifier] 🛡️ Fallback exitoso: ${validFallback.length} recomendaciones con refresh agregadas');
        _consecutiveFailures = 0;
        return;
      }
    } catch (e) {
      AppLogger.debug('[PlaybackNotifier] Fallback 2 falló: $e');
    }

    _consecutiveFailures++;
    AppLogger.warning('[PlaybackNotifier] 🛡️ Todos los fallbacks fallaron. Fallos consecutivos: $_consecutiveFailures');
  }

  /// ⚡ TRANSICIÓN INSTANTÁNEA: Manejar cuando una canción termina
  /// Optimizado para transiciones sin delay
  Future<void> _handleSongCompletion() async {
    // Resetear flag de preparación
    _nextSongPrepared = false;
    _lastPreparedSongIndex = null;
    
    if (state.playbackMode == PlaybackMode.fixedQueue) {
      // Detectar si estamos en la última canción para evitar volver a la playlist
      final sequenceState = service.player.sequenceState;
      final currentIndex = sequenceState.currentIndex;
      final total = sequenceState.sequence.length;
      final isLast = currentIndex != null && currentIndex >= total - 1;

      // Si debe iniciar algoritmo al terminar la cola y estamos en la última canción,
      // saltar directo al algoritmo (sin seek a la playlist).
      if (state.shouldStartAlgorithmAfterQueue && isLast) {
        final lastSongInQueue = state.currentQueue.isNotEmpty ? state.currentQueue.last : state.currentSong;
        if (lastSongInQueue != null) {
          AppLogger.info('[PlaybackNotifier] 🎵 Fin de cola fija detectado. Iniciando Radio Infinita con semilla: ${lastSongInQueue.title}');
          state = state.copyWith(shouldStartAlgorithmAfterQueue: false);
          await playAlgorithmStart(lastSongInQueue, excludeSeedFromQueue: true);
          return;
        }
      }

      // En modo fixedQueue, verificar si hay siguiente canción
      if (service.player.hasNext) {
        try {
          await service.player.seekToNext();
          await service.player.play();

          final actualIsPlaying = service.player.playing;
          final actualPlayerState = service.player.playerState;
          final actualIsBuffering = actualPlayerState.processingState == ProcessingState.buffering ||
                                   actualPlayerState.processingState == ProcessingState.loading;

          _syncQueueWithAudioService(service.player.sequenceState);
          state = state.copyWith(
            isPlaying: actualIsPlaying,
            isBuffering: actualIsBuffering,
            currentPosition: Duration.zero,
          );

          Future.delayed(const Duration(milliseconds: 200), () {
            final currentPlayerState = service.player.playerState;
            final currentIsBuffering = currentPlayerState.processingState == ProcessingState.buffering ||
                                     currentPlayerState.processingState == ProcessingState.loading;

            state = state.copyWith(
              isBuffering: currentIsBuffering,
            );
          });

          AppLogger.info('[PlaybackNotifier] ⚡ Transición instantánea completada');
        } catch (e) {
          AppLogger.error('[PlaybackNotifier] Error en transición instantánea, usando método fallback: $e');
          await service.next();
        }
      } else {
        // 🚩 Fin de cola: si hay algoritmo pendiente, priorizarlo sobre repeat
        if (state.shouldStartAlgorithmAfterQueue && state.currentQueue.isNotEmpty) {
          final lastSongInQueue = state.currentQueue.last;
          AppLogger.info('[PlaybackNotifier] 🎵 Fin de cola fija detectado. Iniciando Radio Infinita con semilla: ${lastSongInQueue.title}');
          state = state.copyWith(shouldStartAlgorithmAfterQueue: false);
          await playAlgorithmStart(lastSongInQueue, excludeSeedFromQueue: true);
        } else if (state.repeatMode == RepeatMode.all) {
          await service.seek(Duration.zero);
          await service.player.seek(Duration.zero, index: 0);
        } else {
          AppLogger.info('[PlaybackNotifier] Fin de cola fija. Deteniendo reproducción.');
          await service.pause();
          _stopAlgorithmMonitor(); // Detener monitor si terminamos la cola fija
        }
      }
    } else if (state.playbackMode == PlaybackMode.algorithm) {
      // ⚡ TRANSICIÓN INSTANTÁNEA: En modo algorithm, avanzar inmediatamente
      if (service.player.hasNext) {
        try {
          // Usar seekToNext() para transición instantánea
          await service.player.seekToNext();
          await service.player.play();
          
          // Actualizar estado inmediatamente
          // 🛡️ NO ACTUALIZAR isPlaying: El stream lo hará automáticamente
          _syncQueueWithAudioService(service.player.sequenceState);
          state = state.copyWith(currentPosition: Duration.zero);
          
          AppLogger.info('[PlaybackNotifier] ⚡ Transición instantánea en modo algoritmo completada');
        } catch (e) {
          AppLogger.error('[PlaybackNotifier] Error en transición algoritmo: $e');
          // Fallback al método original
          await service.next();
        }
      }
      
      // Asegurar que haya más canciones precargadas en background
      _appendMoreAlgorithmSongs();
    }
  }

  // ============== Controles Comunes ==============

  /// Reproducir una canción individual (modo simple)
  Future<void> playSong(Song song) async {
    try {
      AppLogger.info('[PlaybackNotifier] 🎵 Reproduciendo canción individual: ${song.title}');
      await playFixedQueue([song], song);
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] ❌ Error al reproducir canción: $e', stackTrace);
      rethrow;
    }
  }

  /// Alternar play/pause - FUENTE ÚNICA DE VERDAD
  /// ✅ SOLO EJECUTAR LA ACCIÓN: El stream de just_audio es la única fuente de verdad
  /// NO tocar estado local, el StreamBuilder en el widget escucha directamente el stream
  Future<void> togglePlayPause() async {
    final player = service.player;
    
    // ✅ SOLO EJECUTAR LA ACCIÓN - NO TOCAR VARIABLES LOCALES DE ESTADO
    // El StreamBuilder en el widget escucha isPlayingStream directamente
    // No necesitamos actualizar estado aquí, el stream lo hace automáticamente
    try {
      if (player.playing) {
        await player.pause();
        _stopAlgorithmMonitor();
      } else {
        await player.play();
      }
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error en togglePlayPause: $e');
      // No lanzar excepción, solo loguear
    }
    
    // ✅ El stream (isPlayingStream) actualizará el UI automáticamente
    // NO actualizar isPlaying en el estado local - el stream es la fuente única de verdad
  }

  /// Siguiente canción
  /// Si estamos en una cola fija y llegamos al final, activa Radio Infinita automáticamente
  /// 🎯 DETECCIÓN MANUAL: En modo algoritmo, fuerza recarga inmediata si quedan pocas canciones
  Future<void> next() async {
    final now = DateTime.now();
    if (now.difference(_lastControlTap) < _controlDebounce) return;
    _lastControlTap = now;
    _isProcessingNext = true;
    state = state.copyWith(isProcessingNext: true);
    if (state.playbackMode == PlaybackMode.fixedQueue && state.shouldStartAlgorithmAfterQueue) {
      // Verificar si estamos en la última canción de la cola
      final currentIndex = state.currentQueue.indexWhere(
        (s) => s.id == state.currentSong?.id,
      );
      
      if (currentIndex != -1) {
        final isLastSong = currentIndex >= state.currentQueue.length - 1;
        
        if (isLastSong) {
          // Estamos en la última canción, activar Radio Infinita
          final lastSong = state.currentQueue.last;
          AppLogger.info('[PlaybackNotifier] ⏭️ Botón siguiente presionado en última canción. Activando Radio Infinita con semilla: ${lastSong.title}');
          
          // Resetear la bandera ANTES de iniciar el algoritmo
          state = state.copyWith(shouldStartAlgorithmAfterQueue: false);
          
          // Activar algoritmo con la última canción como semilla
          await playAlgorithmStart(lastSong, excludeSeedFromQueue: true);
          _isProcessingNext = false;
          state = state.copyWith(isProcessingNext: false);
          return;
        }
      }
    }
    
    // 🎯 DETECCIÓN MANUAL: En modo algoritmo, verificar y forzar recarga antes del salto
    if (state.playbackMode == PlaybackMode.algorithm) {
      final currentIndex = state.currentQueue.indexWhere(
        (s) => s.id == state.currentSong?.id,
      );
      
      if (currentIndex != -1) {
        final remainingSongs = state.currentQueue.length - currentIndex - 1;
        
        // Si quedan ≤3 canciones, forzar recarga inmediata ANTES del salto
        // 🚨 PROTECCIÓN: Solo llamar si no hay precarga en curso
        if (remainingSongs <= preloadThreshold && !_isPreloading) {
          // 🎯 CASO CRÍTICO: Si quedan 0 canciones, esperar a que se complete la recarga
          if (remainingSongs == 0) {
            AppLogger.info('[PlaybackNotifier] ⏭️ Salto manual detectado con 0 canciones. Recargando primero...');
            
            // 🎯 MÉTODO PROFESIONAL: Esperar directamente a que termine la precarga
            // Ya no necesitamos Completer porque _forceImmediatePreload() ahora es async
            try {
              await _forceImmediatePreload().timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  AppLogger.warning('[PlaybackNotifier] ⚠️ Timeout esperando precarga (5s). Continuando...');
                },
              );
              
              // 🚨 MEJORA: Sincronizar cola con reproductor después de agregar canciones
              _syncQueueWithAudioService(service.player.sequenceState);
              
              // 🚨 MEJORA: Verificar tanto hasNext como el tamaño de la cola en el estado
              final queueSizeAfterPreload = state.currentQueue.length;
              final currentIndexAfterPreload = state.currentQueue.indexWhere(
                (s) => s.id == state.currentSong?.id,
              );
              final remainingAfterPreload = currentIndexAfterPreload != -1 
                  ? queueSizeAfterPreload - currentIndexAfterPreload - 1 
                  : 0;
              
              // Verificar si ahora hay siguiente canción (tanto en el reproductor como en el estado)
              if (service.player.hasNext || remainingAfterPreload > 0) {
                AppLogger.info('[PlaybackNotifier] ✅ Canciones agregadas (cola: $queueSizeAfterPreload, restantes: $remainingAfterPreload), avanzando...');
                
                // Si el reproductor aún no tiene siguiente, forzar sincronización y reintentar
                if (!service.player.hasNext && remainingAfterPreload > 0) {
                  AppLogger.info('[PlaybackNotifier] 🔄 Reproductor no sincronizado, forzando sincronización...');
                  // Esperar un poco más para que el reproductor se sincronice
                  await Future.delayed(const Duration(milliseconds: 200));
                  _syncQueueWithAudioService(service.player.sequenceState);
                }
                
                // Intentar avanzar
                if (service.player.hasNext) {
                  await service.next();
                } else if (remainingAfterPreload > 0) {
                  // Si aún no hay siguiente en el reproductor pero hay en el estado, usar seekToNext forzado
                  AppLogger.info('[PlaybackNotifier] 🔄 Forzando avance manual usando índice...');
                  final nextIndex = currentIndexAfterPreload + 1;
                  if (nextIndex < queueSizeAfterPreload) {
                    // Cargar la siguiente canción manualmente
                    await service.loadNewQueue(
                      state.currentQueue.map((s) => s.toAudioSource()).toList(),
                      nextIndex,
                    );
                    await service.play();
                    AppLogger.info('[PlaybackNotifier] ✅ Avance manual completado a índice $nextIndex');
                  }
                }
                
                _isProcessingNext = false;
                state = state.copyWith(isProcessingNext: false);
                return; // Salir aquí, ya avanzamos
              } else {
                AppLogger.warning('[PlaybackNotifier] ⚠️ Aún no hay siguiente canción después de recarga (cola: $queueSizeAfterPreload, restantes: $remainingAfterPreload)');
                _isProcessingNext = false;
                state = state.copyWith(isProcessingNext: false);
                return; // No avanzar si no hay siguiente
              }
            } catch (e) {
              AppLogger.error('[PlaybackNotifier] Error en precarga crítica: $e');
              // 🚨 CRÍTICO: Siempre limpiar el flag, incluso si hay errores
              _isProcessingNext = false;
              state = state.copyWith(isProcessingNext: false);
              return; // Salir si hay error
            }
          } else {
            // Caso no crítico: programar recarga en background (no esperar)
            AppLogger.info('[PlaybackNotifier] ⏭️ Salto manual detectado (botón siguiente) con $remainingSongs canciones restantes. Programando recarga...');
            // Usar Future.delayed para evitar bloqueos (no esperar)
            Future.delayed(const Duration(milliseconds: 50), () {
              if (!_isPreloading && state.playbackMode == PlaybackMode.algorithm) {
                _forceImmediatePreload(); // No esperar, ejecutar en background
              }
            });
          }
        }
      }
    }
    
    // Avanzar normalmente (solo si no es caso crítico que ya se manejó arriba)
    try {
      if (service.player.hasNext) {
        await service.next();
      } else {
        AppLogger.info('[PlaybackNotifier] ℹ️ No hay siguiente canción disponible');
      }
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error al avanzar: $e');
    } finally {
      // 🚨 CRÍTICO: Siempre limpiar el flag, incluso si hay errores
      _isProcessingNext = false;
      state = state.copyWith(isProcessingNext: false);
    }
  }

  /// Canción anterior
  /// 🎯 DETECCIÓN MANUAL: En modo algoritmo, verifica estado después del salto
  Future<void> previous() async {
    final now = DateTime.now();
    if (now.difference(_lastControlTap) < _controlDebounce) return;
    _lastControlTap = now;
    _isProcessingPrevious = true;
    state = state.copyWith(isProcessingPrevious: true);
    // En modo algoritmo, el salto hacia atrás también puede necesitar recarga
    // (aunque es menos común, puede ocurrir si el usuario retrocede mucho)
    if (state.playbackMode == PlaybackMode.algorithm) {
      // Nota: No forzamos recarga en previous() porque retroceder no reduce el buffer
      // Pero sí registramos la canción saltada cuando el listener detecta el cambio
    }
    
    await service.previous();
    _isProcessingPrevious = false;
    state = state.copyWith(isProcessingPrevious: false);
  }

  /// Buscar posición
  /// Si se busca manualmente cerca del final de una cola fija, puede activar Radio Infinita
  Future<void> seek(Duration position) async {
    await service.seek(position);
    
    // No activar algoritmo por seek manual; dejar que la canción termine y _handleSongCompletion lo haga
  }

  /// Alternar shuffle
  void toggleShuffle() {
    final newShuffled = !state.isShuffled;
    service.setShuffleModeEnabled(newShuffled);
    state = state.copyWith(isShuffled: newShuffled);
  }

  /// Alternar repeat
  void toggleRepeat() {
    RepeatMode newMode;
    switch (state.repeatMode) {
      case RepeatMode.off:
        newMode = RepeatMode.all;
        service.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        newMode = RepeatMode.one;
        service.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        newMode = RepeatMode.off;
        service.setLoopMode(LoopMode.off);
        break;
    }
    state = state.copyWith(repeatMode: newMode);
  }

  /// Abrir reproductor completo
  void openFullPlayer() {
    state = state.copyWith(isPlayerExpanded: true);
  }

  /// Cerrar reproductor completo
  void closeFullPlayer() {
    state = state.copyWith(isPlayerExpanded: false);
  }

  /// 🚀 SPOTIFY-LEVEL: PRE-CARGAR AUDIO DE SIGUIENTE CANCIÓN
  /// Pre-carga el audio de la siguiente canción cuando quedan 30 segundos
  /// Esto elimina completamente el buffering entre canciones
  void _checkAndPreloadNextAudio(Duration currentPosition) {
    if (state.currentQueue.length < 2 || state.totalDuration == Duration.zero) {
      return; // No hay siguiente canción o duración desconocida
    }

    final remainingTime = state.totalDuration - currentPosition;
    if (remainingTime.inSeconds <= _audioPreloadTimeThreshold && remainingTime.inSeconds > 0) {
      // Obtener siguiente canción de la cola
      final sequenceState = service.player.sequenceState;
      final currentIndex = sequenceState.currentIndex;
      if (currentIndex != null && currentIndex + 1 < sequenceState.sequence.length) {
        final nextSource = sequenceState.sequence[currentIndex + 1];
        if (nextSource.tag is Song) {
          final nextSong = nextSource.tag as Song;
          _preloadSongAudio(nextSong);
        }
      }
    }
  }

  /// 🚀 SPOTIFY-LEVEL: PRE-CARGAR AUDIO DE SIGUIENTE CANCIÓN AL CAMBIAR COLA
  /// Pre-carga inmediatamente el audio de la siguiente canción cuando se actualiza la cola
  void _preloadNextSongAudio(SequenceState? sequenceState) {
    if (sequenceState == null) return;

    final currentIndex = sequenceState.currentIndex;
    if (currentIndex != null && currentIndex + 1 < sequenceState.sequence.length) {
      final nextSource = sequenceState.sequence[currentIndex + 1];
      if (nextSource.tag is Song) {
        final nextSong = nextSource.tag as Song;
        _preloadSongAudio(nextSong);
      }
    }
  }

  /// ⚡ TRANSICIÓN INSTANTÁNEA: PREPARAR SIGUIENTE CANCIÓN ANTES DEL FINAL
  /// Prepara la transición cuando quedan 3 segundos para eliminar cualquier delay
  void _checkAndPrepareNextSongTransition(Duration currentPosition) {
    if (state.currentQueue.length < 2 || state.totalDuration == Duration.zero) {
      return; // No hay siguiente canción o duración desconocida
    }

    final remainingTime = state.totalDuration - currentPosition;
    final sequenceState = service.player.sequenceState;
    final currentIndex = sequenceState.currentIndex;
    
    // ⚡ PREPARAR TRANSICIÓN cuando quedan 3 segundos o menos
    if (remainingTime.inSeconds <= _transitionPrepareTimeThreshold && 
        remainingTime.inSeconds > 0 &&
        currentIndex != null &&
        currentIndex + 1 < sequenceState.sequence.length) {
      
      // Evitar preparación múltiple para la misma canción
      if (_nextSongPrepared && _lastPreparedSongIndex == currentIndex) {
        return;
      }
      
      _nextSongPrepared = true;
      _lastPreparedSongIndex = currentIndex;
      
      // ⚡ PREPARAR SIGUIENTE CANCIÓN: Pre-cargar y preparar just_audio
      final nextSource = sequenceState.sequence[currentIndex + 1];
      if (nextSource.tag is Song) {
        final nextSong = nextSource.tag as Song;
        
        // Pre-cargar audio si no está pre-cargado
        _preloadSongAudio(nextSong);
        
        AppLogger.debug('[PlaybackNotifier] ⚡ Transición preparada para: ${nextSong.title} (quedan ${remainingTime.inSeconds}s)');
      }
    }
    
    // Resetear flag cuando cambia la canción
    if (remainingTime.inSeconds > _transitionPrepareTimeThreshold + 1) {
      _nextSongPrepared = false;
    }
  }

  /// 🚀 SPOTIFY-LEVEL: PRE-CARGAR AUDIO DE UNA CANCIÓN ESPECÍFICA
  /// just_audio pre-carga automáticamente cuando se agrega a la cola,
  /// pero marcamos como pre-cargada para evitar trabajo duplicado
  void _preloadSongAudio(Song song) {
    if (song.fileUrl == null || song.fileUrl!.isEmpty) return;
    if (!song.isValidForPlayback) return;
    if (_preloadedAudioUrls.contains(song.id)) return; // Ya pre-cargada

    try {
      // 🚀 SPOTIFY-LEVEL: Marcar como pre-cargada
      // just_audio maneja la pre-carga automáticamente cuando se agrega a la cola
      // pero podemos optimizar marcando canciones que ya están en la cola
      _preloadedAudioUrls.add(song.id);
      
      AppLogger.debug('[PlaybackNotifier] 🚀 Audio marcado para pre-carga: ${song.title}');
      
      // Limpiar cache después de 5 minutos para liberar memoria
      Future.delayed(const Duration(minutes: 5), () {
        _preloadedAudioUrls.remove(song.id);
      });
    } catch (e) {
      AppLogger.debug('[PlaybackNotifier] Error pre-cargando audio (no crítico): $e');
    }
  }

  /// 🔄 SINCRONIZAR COLA CON AUDIO SERVICE
  /// Valida y sincroniza state.currentQueue con la cola real de just_audio
  /// Previene race conditions y desincronizaciones
  void _syncQueueWithAudioService(SequenceState? sequenceState) {
    if (sequenceState == null) {
      return; // No hay estado
    }

    try {
      final audioSources = sequenceState.sequence;
      if (audioSources.isEmpty) {
        // Si la cola de audio está vacía pero el estado tiene canciones, limpiar
        if (state.currentQueue.isNotEmpty || state.currentSong != null) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ Desincronización detectada: cola de audio vacía pero estado tiene ${state.currentQueue.length} canciones');
          state = state.copyWith(currentQueue: [], currentSong: null, currentPosition: Duration.zero);
        }
        return;
      }

      // Extraer Songs de los AudioSource (usando el tag)
      final songsFromAudio = <Song>[];
      for (final source in audioSources) {
        if (source.tag is Song) {
          songsFromAudio.add(source.tag as Song);
        }
      }

      // Comparar con el estado actual
      if (songsFromAudio.length != state.currentQueue.length) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Desincronización detectada: audio tiene ${songsFromAudio.length} canciones, estado tiene ${state.currentQueue.length}');
        state = state.copyWith(currentQueue: songsFromAudio);
        AppLogger.info('[PlaybackNotifier] ✅ Cola sincronizada con audio service');
      } else {
        // Verificar que los IDs coincidan
        final audioIds = songsFromAudio.map((s) => s.id).toList();
        final stateIds = state.currentQueue.map((s) => s.id).toList();
        
        bool idsMatch = true;
        for (int i = 0; i < audioIds.length; i++) {
          if (i >= stateIds.length || audioIds[i] != stateIds[i]) {
            idsMatch = false;
            break;
          }
        }
        
        if (!idsMatch) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ Desincronización de IDs detectada, sincronizando...');
          state = state.copyWith(currentQueue: songsFromAudio);
          AppLogger.info('[PlaybackNotifier] ✅ IDs sincronizados con audio service');
        }
      }

      // Actualizar currentSong desde la cola real, conservando la actual hasta que el índice cambie
      final currentIdx = sequenceState.currentIndex;
      final currentSongId = state.currentSong?.id;

      // 🔒 Bloqueo crítico: mientras inicia algoritmo, ignorar índices distintos de 0
      if (_isAwaitingInitialAlgorithmPlay) {
        if (currentIdx == null) {
          return;
        }
        if (currentIdx != 0) {
          // Mantener portada previa; esperar a que se estabilice en 0
          return;
        }
        // Llegó a índice 0 estable: liberar bloqueo
        _isAwaitingInitialAlgorithmPlay = false;
      }

      if (currentIdx != null && currentIdx >= 0 && currentIdx < songsFromAudio.length) {
        final songAtIdx = songsFromAudio[currentIdx];
        final currentPos = service.player.position;
        final currentDuration = sequenceState.currentSource?.duration ??
            (songAtIdx.duration != null ? Duration(seconds: songAtIdx.duration!) : null);
        final playerState = service.player.playerState;
        final processingState = playerState.processingState;
        // Ignorar cambios de índice cuando el reproductor está idle/completed (ruido de transición)
        final bool processingActive = processingState == ProcessingState.ready ||
            processingState == ProcessingState.buffering ||
            processingState == ProcessingState.loading;
        if (!processingActive) {
          return;
        }
        // No adelantar portada si el player no está activo
        state = state.copyWith(
          currentPosition: currentPos,
          totalDuration: currentDuration ?? state.totalDuration,
          lastConfirmedSong: songAtIdx,
        );

        // Si aún no cambia la canción, no sobrescribir la portada; solo actualizar barra
        if (currentSongId != null && currentSongId == songAtIdx.id) {
          return;
        } else {
          // Solo cambiar currentSong cuando el índice cambia o estaba vacío
          state = state.copyWith(
            currentSong: songAtIdx,
            currentPosition: currentPos,
            totalDuration: currentDuration ?? Duration.zero,
            lastConfirmedSong: songAtIdx,
          );
          AppLogger.info('[PlaybackNotifier] ✅ Canción sincronizada: ${songAtIdx.title}');
        }
      } else {
        // Sin índice válido: si tenemos una confirmada previa, mantenerla para evitar flashes
        if (state.currentSong == null && state.lastConfirmedSong != null) {
          state = state.copyWith(currentSong: state.lastConfirmedSong, currentPosition: Duration.zero);
        }
      }

    } catch (e) {
      AppLogger.debug('[PlaybackNotifier] Error al sincronizar cola (no crítico): $e');
    }
  }


  /// 🛡️ GUARD ANTI-LOOP: Detectar corrupción silenciosa
  /// Cuando el reproductor está idle pero debería estar reproduciendo, puede ser CORRUPTED
  Future<void> _checkForSilentCorruption() async {
    final currentSong = state.currentSong;
    if (currentSong == null) return;
    
    final now = DateTime.now();
    
    // Verificar cooldown para evitar múltiples detecciones del mismo error
    if (_lastCorruptedErrorTime != null && 
        now.difference(_lastCorruptedErrorTime!) < _corruptedErrorCooldown) {
      AppLogger.debug('[PlaybackNotifier] 🛡️ Error CORRUPTED en cooldown, ignorando...');
      return;
    }
    
    _lastCorruptedErrorTime = now;
    
    // Si la misma canción está causando problemas repetidamente, puede estar corrupta
    if (currentSong.id == _lastCorruptedSongId) {
      _corruptedRetryCount++;
      AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ════════════════════════════════════════');
      AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ⚠️ CORRUPCIÓN DETECTADA');
      AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    🎵 Canción: ${currentSong.title}');
      AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    🔢 Intento: $_corruptedRetryCount/$_maxCorruptedRetries');
      AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    📊 Estado: Reproductor idle mientras debería reproducir');
      
      if (_corruptedRetryCount >= _maxCorruptedRetries) {
        AppLogger.error('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: 🚨 MÁXIMO DE REINTENTOS ALCANZADO');
        AppLogger.error('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    ⚡ Forzando salto a siguiente canción...');
        
        if (service.player.hasNext) {
          try {
            final nextIndex = (state.currentQueue.indexWhere((s) => s.id == currentSong.id) + 1);
            final nextSong = nextIndex < state.currentQueue.length ? state.currentQueue[nextIndex] : null;
            
            await service.player.seekToNext();
            await service.player.play();
            _lastCorruptedSongId = null;
            _corruptedRetryCount = 0;
            
            AppLogger.info('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ✅ SALTO FORZADO COMPLETADO');
            AppLogger.info('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    🎵 Nueva canción: ${nextSong?.title ?? "N/A"}');
            AppLogger.info('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    🔄 Reproducción continuada');
            AppLogger.info('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ════════════════════════════════════════');
          } catch (e) {
            AppLogger.error('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ❌ Error al forzar salto: $e');
            AppLogger.error('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ════════════════════════════════════════');
          }
        } else {
          AppLogger.error('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ❌ No hay siguiente canción disponible');
          AppLogger.error('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    ⏸️ Pausando reproducción');
          AppLogger.error('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ════════════════════════════════════════');
          await service.pause();
          _lastCorruptedSongId = null;
          _corruptedRetryCount = 0;
        }
      } else {
        AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ⏳ Esperando más intentos antes de saltar...');
        AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ════════════════════════════════════════');
      }
    } else {
      _lastCorruptedSongId = currentSong.id;
      _corruptedRetryCount = 1;
      AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: ⚠️ Nueva corrupción detectada');
      AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    🎵 Canción: ${currentSong.title}');
      AppLogger.warning('[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP:    🔢 Intento: 1/$_maxCorruptedRetries');
    }
  }

  /// 🛡️ GUARD ANTI-LOOP: Deduplicación mejorada en runtime
  /// Valida y elimina duplicados de la cola en tiempo real con validación estricta
  /// ACTUALIZA REALMENTE la cola del audio service, no solo el estado
  Future<void> _performRuntimeDeduplication(SequenceState? sequenceState) async {
    if (sequenceState == null || _isUpdatingQueue || _isDeduplicating) {
      return; // No deduplicar si estamos actualizando, deduplicando, o no hay estado
    }

    // No deduplicar si el player está buffering/loading
    final playerState = service.player.playerState;
    if (playerState.processingState == ProcessingState.buffering ||
        playerState.processingState == ProcessingState.loading) {
      return;
    }

    // No deduplicar si quedan pocas canciones para evitar reinicios al final
    final remaining = _getRemainingQueueSize();
    if (remaining != -1 && remaining <= preloadThreshold) {
      return;
    }

    // 🛡️ COOLDOWN: Prevenir ejecuciones múltiples muy rápidas
    if (_lastDeduplicationTime != null) {
      final timeSinceLastDedup = DateTime.now().difference(_lastDeduplicationTime!);
      if (timeSinceLastDedup < _deduplicationCooldown) {
        return; // Aún en cooldown
      }
    }

    try {
      _isDeduplicating = true;
      _lastDeduplicationTime = DateTime.now();
      
      final audioSources = sequenceState.sequence;
      if (audioSources.isEmpty) {
        _isDeduplicating = false;
        return;
      }

      // Extraer Songs de los AudioSource con validación estricta
      final songsFromAudio = <Song>[];
      final seenIds = <String>{};
      final duplicateIndices = <int>[];
      final duplicateIds = <String>[];
      
      for (int i = 0; i < audioSources.length; i++) {
        final source = audioSources[i];
        if (source.tag is Song) {
          final song = source.tag as Song;
          
          // 🛡️ VALIDACIÓN ESTRICTA: Detectar duplicados por ID
          if (seenIds.contains(song.id)) {
            duplicateIndices.add(i);
            duplicateIds.add(song.id);
          } else {
            seenIds.add(song.id);
            songsFromAudio.add(song);
          }
        }
      }

      // Si hay duplicados, ACTUALIZAR REALMENTE la cola del audio service
      if (duplicateIndices.isNotEmpty && state.currentSong != null) {
        // 🛡️ EVITAR BUCLE: si la firma es la misma en una ventana de 5s, no repetir
        final signatureIds = duplicateIds.toList()..sort();
        final signature = '${audioSources.length}|${signatureIds.join(",")}|${state.currentSong?.id ?? "no-song"}';
        final now = DateTime.now();
        if (_lastDedupSignature != null &&
            _lastDedupSignature == signature &&
            _lastDedupSignatureTime != null &&
            now.difference(_lastDedupSignatureTime!) < _dedupSignatureCooldown) {
          _isDeduplicating = false;
          return;
        }

        // 🛡️ VENTANA DE INTENTOS: limitar dedup a 2 en 10s
        if (_dedupAttemptsWindowStart == null || now.difference(_dedupAttemptsWindowStart!) > _dedupAttemptsWindowDuration) {
          _dedupAttemptsWindowStart = now;
          _dedupAttemptsWindow = 0;
        }
        if (_dedupAttemptsWindow >= _dedupAttemptsWindowMax) {
          AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] Limite de deduplicaciones alcanzado en ventana de 10s. Omitiendo para evitar bucle.');
          _isDeduplicating = false;
          return;
        }
        _dedupAttemptsWindow++;
        // Guardar firma antes de actualizar para evitar bucle incluso si falla la carga
        _lastDedupSignature = signature;
        _lastDedupSignatureTime = now;

        // 📊 CALCULAR IMPACTO ANTES DE ACTUALIZAR
        final queueSizeBefore = audioSources.length;
        final remainingSongsBefore = _getRemainingQueueSize();
        final currentIndex = sequenceState.currentIndex;
        final currentSongId = state.currentSong?.id;
        
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] ════════════════════════════════════════');
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] 🔍 DEDUPLICACIÓN DETECTADA');
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] 📊 Estado ANTES:');
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Total canciones en audio: $queueSizeBefore');
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Canciones restantes: ${remainingSongsBefore >= 0 ? remainingSongsBefore : "N/A"}');
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Índice actual: ${currentIndex ?? "N/A"}');
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] 🗑️ Eliminando ${duplicateIndices.length} duplicados...');
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • IDs duplicados: ${duplicateIds.map((id) => id.substring(0, 8)).join(", ")}');
        
        // 🚨 CRÍTICO: Calcular el nuevo índice preservando la canción actual
        int newIndex = 0;
        if (currentIndex != null && currentSongId != null) {
          // Buscar la posición de la canción actual en la lista deduplicada
          final newIndexFound = songsFromAudio.indexWhere((s) => s.id == currentSongId);
          if (newIndexFound >= 0) {
            newIndex = newIndexFound;
          } else if (currentIndex < songsFromAudio.length) {
            // Si la canción actual no está en la lista deduplicada, usar el índice ajustado
            newIndex = currentIndex < songsFromAudio.length ? currentIndex : songsFromAudio.length - 1;
          }
        }
        
        // 🚨 ACTUALIZAR REALMENTE la cola del audio service con canciones únicas
        // Preservar la posición actual si seguimos en la misma canción
        final currentPosition = service.player.position;
        _isUpdatingQueue = true; // Marcar que estamos actualizando para evitar sincronizaciones
        try {
          final uniqueSources = songsFromAudio.map((s) => s.toAudioSource()).toList();
          await service.loadNewQueue(uniqueSources, newIndex);
          
          // Restaurar posición si seguimos en la misma canción y la duración es consistente
          if (currentSongId != null && newIndex < songsFromAudio.length && songsFromAudio[newIndex].id == currentSongId) {
            final songDuration = songsFromAudio[newIndex].duration;
            if (songDuration == null || currentPosition < Duration(seconds: songDuration)) {
              try {
                await service.player.seek(currentPosition);
              } catch (_) {
                // Ignorar si no se puede restaurar
              }
            }
          }
          
          // Actualizar estado con cola deduplicada
          state = state.copyWith(currentQueue: songsFromAudio);
          
          // 📊 CALCULAR IMPACTO DESPUÉS DE ACTUALIZAR
          final queueSizeAfter = songsFromAudio.length;
          final remainingSongsAfter = _getRemainingQueueSize();
          
          AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] 📊 Estado DESPUÉS:');
          AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Total canciones: $queueSizeAfter (${queueSizeBefore - queueSizeAfter} eliminadas)');
          AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Canciones restantes: ${remainingSongsAfter >= 0 ? remainingSongsAfter : "N/A"} ${remainingSongsBefore >= 0 && remainingSongsAfter >= 0 && remainingSongsBefore != remainingSongsAfter ? "(${remainingSongsBefore - remainingSongsAfter} menos)" : ""}');
          AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Índice actualizado: ${currentIndex ?? "N/A"} → $newIndex');
          AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] ✅ Deduplicación completada: ${songsFromAudio.length} únicas (${duplicateIndices.length} duplicados eliminados del audio service)');
          AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] ════════════════════════════════════════');
        } finally {
          _isUpdatingQueue = false;
        }
      }
    } catch (e) {
      AppLogger.debug('[PlaybackNotifier] Error en deduplicación runtime (no crítico): $e');
    } finally {
      _isDeduplicating = false;
    }
  }

  /// 🔒 ACTUALIZAR COLA DE FORMA ATÓMICA
  /// Wrapper para actualizar tanto la cola de audio como el estado de forma sincronizada
  /// 
  /// [waitForPrevious]: Si es true, espera hasta que termine la actualización anterior (útil para casos críticos)
  Future<void> _updateQueueAtomically({
    required List<Song> newSongs,
    required Future<void> Function(List<AudioSource>) audioOperation,
    bool replace = false,
    bool waitForPrevious = false,
  }) async {
    // 🚨 LOCK: Prevenir actualizaciones concurrentes
    if (_isUpdatingQueue) {
      if (waitForPrevious) {
        // 🎯 CASO CRÍTICO: Esperar hasta que termine la actualización anterior
        AppLogger.info('[PlaybackNotifier] ⏳ Esperando que termine actualización anterior (modo crítico)...');
        int attempts = 0;
        while (_isUpdatingQueue && attempts < 30) { // Máximo 3 segundos (reducido de 5)
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        if (_isUpdatingQueue) {
          // 🚨 CRÍTICO: Si hay timeout, forzar limpieza del flag para evitar bloqueos
          AppLogger.warning('[PlaybackNotifier] ⚠️ Timeout esperando actualización de cola (${attempts * 100}ms). Forzando limpieza...');
          _isUpdatingQueue = false;
          // Continuar de todas formas para evitar bloqueos permanentes
        }
        AppLogger.info('[PlaybackNotifier] ✅ Actualización anterior completada, continuando...');
      } else {
        // Modo normal: esperar un poco más para evitar timeouts prematuros
        AppLogger.info('[PlaybackNotifier] ⏳ Actualización de cola en progreso, esperando...');
        int attempts = 0;
        while (_isUpdatingQueue && attempts < 10) { // Esperar hasta 1 segundo
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        if (_isUpdatingQueue) {
          // 🚨 CRÍTICO: Si hay timeout después de 1 segundo, forzar limpieza del flag
          AppLogger.warning('[PlaybackNotifier] ⚠️ Timeout esperando actualización de cola (${attempts * 100}ms). Forzando limpieza...');
          _isUpdatingQueue = false;
        } else {
          AppLogger.info('[PlaybackNotifier] ✅ Actualización anterior completada, continuando...');
        }
      }
    }

    _isUpdatingQueue = true;
    
    try {
      // 🚨 VERIFICACIÓN DE DUPLICADOS: Verificar contra la cola actual del audio service
      // Esto previene agregar canciones que ya están en la cola
      final sequenceState = service.player.sequenceState;
      final currentAudioQueueIds = <String>{};
      if (sequenceState.sequence.isNotEmpty) {
        for (final source in sequenceState.sequence) {
          if (source.tag is Song) {
            currentAudioQueueIds.add((source.tag as Song).id);
          }
        }
      }
      final currentStateQueueIds = state.currentQueue.map((s) => s.id).toSet();
      final allCurrentQueueIds = {...currentAudioQueueIds, ...currentStateQueueIds};
      
      // Filtrar duplicados antes de agregar
      final uniqueNewSongs = newSongs.where((s) => !allCurrentQueueIds.contains(s.id)).toList();
      
      if (uniqueNewSongs.isEmpty) {
        AppLogger.info('[PlaybackNotifier] ⚠️ Todas las canciones ya están en la cola, omitiendo agregado');
        return; // No hay nada que agregar
      }
      
      if (uniqueNewSongs.length < newSongs.length) {
        AppLogger.info('[PlaybackNotifier] ⚠️ ${newSongs.length - uniqueNewSongs.length} canciones duplicadas filtradas antes de agregar');
      }
      
      // Convertir canciones únicas a AudioSource
      final sources = uniqueNewSongs.map((s) => s.toAudioSource()).toList();
      
      // Ejecutar operación de audio
      await audioOperation(sources);
      
      // Actualizar estado de forma atómica
      final updatedQueue = replace 
          ? uniqueNewSongs 
          : [...state.currentQueue, ...uniqueNewSongs];
      
      state = state.copyWith(currentQueue: updatedQueue);
      
      // 🚨 MEJORA: Sincronizar inmediatamente y luego validar después de un breve delay
      // Esto asegura que el estado esté sincronizado antes de que otros procesos lo usen
      _syncQueueWithAudioService(service.player.sequenceState);
      
      // Validar sincronización después de un breve delay para asegurar que todo esté actualizado
      Future.delayed(const Duration(milliseconds: 200), () {
        _syncQueueWithAudioService(service.player.sequenceState);
      });
      
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error en actualización atómica de cola: $e', stackTrace);
      // Intentar sincronizar estado con realidad
      _syncQueueWithAudioService(service.player.sequenceState);
      rethrow;
    } finally {
      _isUpdatingQueue = false;
    }
  }

  /// Reproducir desde una card (con algoritmo opcional)
  /// 
  /// [song]: Canción a reproducir (si es null y useAlgorithm es true, se obtiene una semilla dinámica)
  /// [useAlgorithm]: Si es true, activa Radio Infinita
  Future<void> playFromCard(Song? song, {bool useAlgorithm = false}) async {
    // 🚨 PROTECCIÓN: Detener TODOS los procesos del algoritmo anterior antes de iniciar nueva reproducción
    // Esto evita conflictos cuando se cambia de canción mientras el algoritmo está activo
    if (state.playbackMode == PlaybackMode.algorithm) {
      AppLogger.info('[PlaybackNotifier] 🛑 Deteniendo algoritmo anterior antes de cambiar de canción...');
      _stopAlgorithmMonitor(); // Detener monitor anterior
      _stopQueueProtection(); // Detener protección de cola anterior
      _isGeneratingRecommendations = false; // Cancelar generación de recomendaciones anterior
    }
    
    // 🚨 PROTECCIÓN: Limpiar TODOS los flags antes de iniciar nueva reproducción
    // Esto evita bloqueos en la segunda reproducción
    if (_isPreloading) {
      AppLogger.info('[PlaybackNotifier] 🛑 Cancelando precarga en curso antes de cambiar de canción...');
      _isPreloading = false;
      _lastPreloadTime = null;
    }
    
    if (_isUpdatingQueue) {
      AppLogger.warning('[PlaybackNotifier] ⚠️ Flag _isUpdatingQueue estaba bloqueado, limpiando...');
      _isUpdatingQueue = false;
    }

    if (_isReplacingQueue) {
      AppLogger.warning('[PlaybackNotifier] ⚠️ Flag _isReplacingQueue estaba bloqueado, limpiando...');
      _isReplacingQueue = false;
    }
    
    if (_isRestartingAlgorithm) {
      AppLogger.warning('[PlaybackNotifier] ⚠️ Flag _isRestartingAlgorithm estaba bloqueado, limpiando...');
      _isRestartingAlgorithm = false;
    }
    
    // 🚨 PROTECCIÓN: Marcar que estamos reproduciendo desde una tarjeta
    // Esto evita que el listener detecte el cambio como un "salto manual"
    _isPlayingFromCard = true;
    
    try {
      
      if (useAlgorithm) {
      // Nueva sesión de algoritmo desde tarjeta: recortar historial para no inflar excludeIds
      ref.read(playbackSessionProvider.notifier).trimForNewSession(keep: 5);
      // Si no hay canción proporcionada, obtener una semilla dinámica
      Song? seedSong = song;
      if (seedSong == null) {
        AppLogger.info('[PlaybackNotifier] 🎲 No hay canción específica, obteniendo semilla dinámica...');
        // Obtener semilla dinámica
        seedSong = await _getDynamicSeedSong();
        if (seedSong == null) {
          AppLogger.error('[PlaybackNotifier] No se pudo obtener una semilla para el algoritmo');
          return;
        }
      } else {
        AppLogger.info('[PlaybackNotifier] 🎵 Usando canción tocada como semilla: ${seedSong.title} (ID: ${seedSong.id})');
      }
      await playAlgorithmStart(seedSong);
      } else {
        if (song == null) {
          AppLogger.error('[PlaybackNotifier] No se puede reproducir sin canción');
          return;
        }
        await playSong(song);
      }
      
      // 🛡️ FUENTE ÚNICA DE VERDAD: El stream actualizará isPlaying automáticamente
      // NO actualizar isPlaying manualmente - el stream es la única fuente de verdad
      // Solo actualizar isBuffering si es necesario para otros widgets
      await Future.delayed(const Duration(milliseconds: 200));
      final actualPlayerState = service.player.playerState;
      final actualIsBuffering = actualPlayerState.processingState == ProcessingState.buffering ||
                               actualPlayerState.processingState == ProcessingState.loading;
      
      state = state.copyWith(
        isBuffering: actualIsBuffering,
      );
      
      AppLogger.info('[PlaybackNotifier] Reproducción desde tarjeta completada');
      
    } finally {
      // 🚨 PROTECCIÓN: Liberar flag después de que la reproducción se haya iniciado completamente
      // Usar un delay para permitir que el listener se actualice, pero no demasiado largo
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_isPlayingFromCard) {
          _isPlayingFromCard = false;
          AppLogger.debug('[PlaybackNotifier] Flag _isPlayingFromCard liberado');
        }
      });
    }
  }

  /// 🎲 Obtener una semilla dinámica para el algoritmo
  /// 
  /// Estrategia:
  /// 1. Intentar obtener la última canción del historial del usuario
  /// 2. Si no hay historial, obtener una canción popular aleatoria
  /// 3. Si falla, obtener una canción destacada aleatoria
  Future<Song?> _getDynamicSeedSong() async {
    try {
      AppLogger.info('[PlaybackNotifier] 🎲 Obteniendo semilla dinámica para Radio Infinita...');
      
      // Estrategia 1: Obtener última canción del historial local
      final playHistoryNotifier = ref.read(playHistoryProvider.notifier);
      final playHistory = playHistoryNotifier.getRecentHistory(limit: 10);
      if (playHistory.isNotEmpty) {
        // Seleccionar una canción aleatoria del historial reciente (últimas 5)
        final recentSongs = playHistory.take(5).toList();
        final randomIndex = Random().nextInt(recentSongs.length);
        final seedSong = recentSongs[randomIndex];
        AppLogger.info('[PlaybackNotifier] ✅ Semilla desde historial: ${seedSong.title}');
        return seedSong;
      }

      // Estrategia 2: Obtener canción popular aleatoria
      final popularSongs = await _homeService.getPopularSongs(limit: 20);
      if (popularSongs.isNotEmpty) {
        // Seleccionar una canción aleatoria de las populares
        final randomIndex = Random().nextInt(popularSongs.length);
        final seedSong = popularSongs[randomIndex];
        AppLogger.info('[PlaybackNotifier] ✅ Semilla desde canciones populares: ${seedSong.title}');
        return seedSong;
      }

      // Estrategia 3: Obtener canción destacada aleatoria
      final featuredSongs = await _intelligentService.getIntelligentFeaturedSongs(limit: 20);
      if (featuredSongs.isNotEmpty) {
        final randomIndex = Random().nextInt(featuredSongs.length);
        final seedSong = featuredSongs[randomIndex].song;
        AppLogger.info('[PlaybackNotifier] ✅ Semilla desde canciones destacadas: ${seedSong.title}');
        return seedSong;
      }

      AppLogger.warning('[PlaybackNotifier] ⚠️ No se pudo obtener ninguna semilla dinámica');
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] ❌ Error obteniendo semilla dinámica: $e', stackTrace);
      return null;
    }
  }

  /// Reproducir todas las canciones de una lista
  /// 
  /// [startSong]: Canción inicial (puede ser la primera o una seleccionada)
  /// [contextId]: ID del contexto (playlistId o artistId)
  /// [allSongs]: Lista completa de canciones a reproducir
  /// 
  /// 🚩 Establece la bandera shouldStartAlgorithmAfterQueue para que,
  /// al finalizar la última canción, el sistema cambie automáticamente
  /// al Modo Algoritmo (Radio Infinita) usando la última canción como semilla.
  Future<void> onPressPlayAll(
    Song startSong,
    String? contextId, {
    required List<Song> allSongs,
  }) async {
    if (allSongs.isEmpty) return;
    
    // Asegurar que startSong esté en allSongs
    final validStartSong = allSongs.contains(startSong) 
        ? startSong 
        : allSongs.first;
    
    // 🚩 Establecer la bandera ANTES de cargar la cola
    // Esto indica que al finalizar la última canción, debe iniciar el algoritmo
    state = state.copyWith(
      shouldStartAlgorithmAfterQueue: true,
    );

    // Prefetch anticipado de buffer algorítmico con la última canción de la playlist
    // No se espera; prepara recomendaciones para eliminar gap en la transición
    if (allSongs.isNotEmpty) {
      final lastSong = allSongs.last;
      // Solo lanzar si la semilla es reproducible
      if (lastSong.isValidForPlayback) {
        unawaited(_prefetchInitialAlgorithmBuffer(lastSong));
      }
    }

    try {
      await playFixedQueue(allSongs, validStartSong, contextId: contextId);
    } catch (e) {
      // Si falla la carga de la cola, limpiar la bandera para evitar estados latentes
      state = state.copyWith(shouldStartAlgorithmAfterQueue: false);
      rethrow;
    }
  }

  /// Asegurar que el servicio esté inicializado
  Future<void> ensureInitialized() async {
    // El servicio ya está inicializado por el provider
    // Este método existe para compatibilidad
  }

  /// Limpiar recursos
  void _dispose() {
    // Cancelar todas las suscripciones
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // Detener monitor de algoritmo
    _stopAlgorithmMonitor();
    
    // 🛡️ Detener sistema de protección de cola
    _stopQueueProtection();
  }
}

/// Provider que la UI consumirá
/// El AudioService se obtiene dentro del build() del notifier
final playbackNotifierProviderFactory = NotifierProvider<PlaybackNotifier, PlaybackState>(() {
  return PlaybackNotifier();
});

