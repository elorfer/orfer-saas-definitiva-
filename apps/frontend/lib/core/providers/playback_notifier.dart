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
  
  // Servicios de recomendación
  late final IntelligentFeaturedService _intelligentService;
  late final HomeService _homeService;

  // Control de precarga para modo algorithm
  Timer? _algorithmMonitorTimer;
  bool _isPreloading = false;
  DateTime? _lastPreloadTime; // 🚨 COOLDOWN: Timestamp de última precarga
  DateTime? _lastMonitorLogTime; // 🎯 FASE 2: Timestamp del último log del monitor (para reducir verbosidad)
  int? _lastKnownIndex; // 🎯 DETECCIÓN MANUAL: Último índice conocido para detectar saltos manuales
  DateTime? _lastManualSkipCheck; // 🎯 PROTECCIÓN: Timestamp de última verificación de salto manual (debounce)
  static const Duration _manualSkipDebounce = Duration(milliseconds: 500); // Debounce para evitar múltiples verificaciones
  
  // 🎯 FASE 2: Umbral de Recarga Proactivo
  static const int PRELOAD_THRESHOLD = 3; // Pre-cargar cuando quedan ≤3 canciones disponibles
  static const int _preloadTimeThreshold = 45; // ⚡ TRANSICIÓN INSTANTÁNEA: Pre-cargar cuando quedan 45 segundos (aumentado para más anticipación)
  static const Duration _preloadCooldown = Duration(seconds: 3); // 🚨 COOLDOWN: Mínimo 3 segundos entre precargas
  
  // 🎯 FASE 3.1: Precarga Progresiva - Constantes de Control
  static const int CRITICAL_SONGS_COUNT = 5; // Canciones críticas a agregar inmediatamente (siguiente + buffer)
  
  // 🚨 SINCRONIZACIÓN: Flag para prevenir actualizaciones concurrentes del estado
  bool _isUpdatingQueue = false;
  
  // 🚀 SPOTIFY-LEVEL: Pre-carga de audio de siguientes canciones
  static const int _audioPreloadTimeThreshold = 30; // Pre-cargar audio cuando quedan 30 segundos
  final Set<String> _preloadedAudioUrls = {}; // Trackear URLs ya pre-cargadas
  
  // ⚡ TRANSICIÓN INSTANTÁNEA: Preparar siguiente canción antes del final
  static const int _transitionPrepareTimeThreshold = 3; // Preparar transición cuando quedan 3 segundos
  bool _nextSongPrepared = false; // Flag para evitar preparación múltiple
  int? _lastPreparedSongIndex; // Trackear qué canción fue preparada
  
  // 🛡️ PREVENCIÓN DE COLA VACÍA: Sistema robusto de protección
  static const int _minQueueSize = 5; // Tamaño mínimo garantizado de la cola
  // 🎯 FASE 2: Usar PRELOAD_THRESHOLD como umbral crítico (unificado)
  Timer? _queueProtectionTimer; // Timer para monitoreo constante de la cola
  int _consecutiveFailures = 0; // Contador de fallos consecutivos en precarga
  DateTime? _lastEmergencyCall; // Timestamp de última llamada de emergencia
  static const Duration _emergencyCooldown = Duration(seconds: 10); // Cooldown entre emergencias

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
        final currentIndex = sequenceState.currentIndex;
        if (currentIndex != null && currentIndex < state.currentQueue.length) {
          final currentSong = state.currentQueue[currentIndex];
          
          // 🎯 DETECCIÓN MANUAL: Verificar si hubo un salto manual (no secuencial)
          // Solo detectar si ya había un índice previo (evitar detección en inicialización)
          // 🚨 PROTECCIÓN: Debounce para evitar múltiples verificaciones en rápida sucesión
          if (_lastKnownIndex != null && state.playbackMode == PlaybackMode.algorithm) {
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
                      AppLogger.info('[PlaybackNotifier] ⏭️ Salto manual detectado: saltadas ${skippedSongs.length} canciones (índice ${_lastKnownIndex} → ${currentIndex})');
                      ref.read(playbackSessionProvider.notifier).registerPlayedSongs(skippedSongs);
                    }
                  } catch (e) {
                    // Protección contra errores de índice fuera de rango
                    AppLogger.debug('[PlaybackNotifier] Error al registrar canciones saltadas: $e');
                  }
                }
                
                // 🎯 FASE 2: Forzar recarga inmediata si quedan pocas canciones
                // Usar un delay adicional para evitar bloqueos en el listener
                final remainingSongs = state.currentQueue.length - currentIndex - 1;
                if (remainingSongs <= PRELOAD_THRESHOLD) {
                  AppLogger.info('[PlaybackNotifier] ⚡ Salto manual detectado con solo $remainingSongs canciones restantes. Programando recarga...');
                  // Usar Future.delayed con un pequeño delay en lugar de microtask para evitar acumulación
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (!_isPreloading && state.playbackMode == PlaybackMode.algorithm) {
                      _forceImmediatePreload();
                    }
                  });
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
          
          // 🎯 DETECTAR FIN DE COLA FIJA AL AVANZAR MANUALMENTE
          // Si estamos en una cola fija y llegamos a la última canción, activar Radio Infinita
          if (state.playbackMode == PlaybackMode.fixedQueue && 
              state.shouldStartAlgorithmAfterQueue &&
              currentIndex >= state.currentQueue.length - 1) {
            
            final lastSong = state.currentQueue.last;
            AppLogger.info('[PlaybackNotifier] ⏭️ Avance manual detectado en última canción. Activando Radio Infinita con semilla: ${lastSong.title}');
            
            // Resetear la bandera ANTES de iniciar el algoritmo
            state = state.copyWith(shouldStartAlgorithmAfterQueue: false);
            
            // Activar algoritmo con la última canción como semilla
            playAlgorithmStart(lastSong, excludeSeedFromQueue: true);
          }
        }
      }),
    );

    // 2. Suscribirse al estado de reproducción (play/pause)
    _subscriptions.add(
      service.isPlayingStream.listen((isPlaying) {
        state = state.copyWith(isPlaying: isPlaying);
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
        
        state = state.copyWith(isBuffering: isBuffering);
        
        // ⚡ TRANSICIÓN INSTANTÁNEA: Detectar final de canción ANTES de que termine
        // Usar completed como fallback, pero la transición ya debería estar preparada
        if (playerState.processingState == ProcessingState.completed) {
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
      if (playlist.isEmpty) {
        throw Exception('La playlist está vacía');
      }

      if (!playlist.any((s) => s.id == startSong.id)) {
        throw Exception('La canción inicial no está en la playlist');
      }

      state = state.copyWith(
        isLoading: true,
        playbackMode: PlaybackMode.fixedQueue,
        currentQueue: playlist,
        contextId: contextId,
        // Mantener la bandera shouldStartAlgorithmAfterQueue si ya estaba establecida
        // (no sobrescribirla si fue establecida por onPressPlayAll)
      );

      // Detener monitor de algoritmo si estaba activo
      _stopAlgorithmMonitor();
      
      // 🛡️ Detener sistema de protección de cola (solo para modo algoritmo)
      _stopQueueProtection();

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
        state = state.copyWith(
          currentQueue: validPlaylist,
          isPlaying: false, // Se actualizará cuando se llame a play()
          isLoading: false,
        );
        
        // Reproducir
        await service.play();

        // 🚨 SINCRONIZACIÓN INMEDIATA: Forzar el estado de reproducción para actualizar UI instantáneamente
        state = state.copyWith(
          isPlaying: true,
          isLoading: false,
        );
        
        // Validar sincronización después de un breve delay
        Future.delayed(const Duration(milliseconds: 200), () {
          _syncQueueWithAudioService(service.player.sequenceState);
        });
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
      
      state = state.copyWith(
        isLoading: true,
        playbackMode: PlaybackMode.algorithm,
        contextId: null,
      );

      // 🚨 REPRODUCCIÓN INMEDIATA: Iniciar con solo la semilla primero
      // Esto evita el retraso de 40 segundos esperando recomendaciones
      final immediateQueue = excludeSeedFromQueue ? <Song>[] : <Song>[seedSong];
      state = state.copyWith(currentQueue: immediateQueue);

      // 🚨 VALIDACIÓN: Verificar que la semilla sea válida antes de reproducir
      if (!seedSong.isValidForPlayback) {
        AppLogger.error('[PlaybackNotifier] ❌ Semilla inválida: ${seedSong.title} (fileUrl: ${seedSong.fileUrl ?? "null"})');
        state = state.copyWith(isLoading: false);
        throw Exception('La canción semilla no tiene URL de archivo válida');
      }
      
      // 🚨 ACTUALIZACIÓN ATÓMICA: Cargar semilla de forma sincronizada
      _isUpdatingQueue = true;
      try {
        // Convertir semilla a AudioSource e iniciar reproducción INMEDIATAMENTE
        final seedSource = seedSong.toAudioSource();
        await service.loadNewQueue([seedSource], 0);
        
        // 🎯 DETECCIÓN MANUAL: Inicializar índice conocido
        _lastKnownIndex = 0;
        
        // Actualizar estado de forma atómica
        state = state.copyWith(
          currentQueue: immediateQueue,
          isPlaying: false, // Se actualizará cuando se llame a play()
          isLoading: false,
        );
        
        await service.play();

        // 🚨 SINCRONIZACIÓN INMEDIATA: Forzar el estado de reproducción para actualizar UI instantáneamente
        state = state.copyWith(
          isPlaying: true,
          isLoading: false,
        );
        
        // Validar sincronización después de un breve delay
        Future.delayed(const Duration(milliseconds: 200), () {
          _syncQueueWithAudioService(service.player.sequenceState);
        });
      } finally {
        _isUpdatingQueue = false;
      }

      // 🚨 LOG CRÍTICO: Solo eventos importantes
      AppLogger.info('[PlaybackNotifier] ✅ Reproducción inmediata iniciada con semilla: ${seedSong.title}');

      // 🚨 FASE 2 (BACKGROUND): Llamar sin await para no bloquear
      // Esto permite que la función retorne y la música empiece inmediatamente
      _generateAndAppendRecommendations(seedSong, excludeSeedFromQueue: excludeSeedFromQueue);

      // Iniciar monitor optimizado (verifica cada 5s con condiciones más agresivas)
      _startAlgorithmMonitor();
      
      // 🛡️ PREVENCIÓN DE COLA VACÍA: Iniciar sistema de protección
      _startQueueProtection();
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al iniciar modo algoritmo: $e', stackTrace);
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Generar recomendaciones y agregarlas a la cola en background (no bloquea)
  /// 
  /// Este método ejecuta la costosa lógica de backend (obtener 15 recomendaciones)
  /// y, al finalizar, agrega (append) las nuevas canciones a la cola del AudioService.
  /// Se ejecuta completamente en background sin bloquear la reproducción.
  Future<void> _generateAndAppendRecommendations(Song seedSong, {bool excludeSeedFromQueue = false}) async {
    try {
      // 🚨 OPTIMIZACIÓN CRÍTICA: Obtener primeras 4 canciones RÁPIDAMENTE (Fase 1)
      // Esto asegura que haya canciones disponibles cuando termine la primera canción
      AppLogger.info('[PlaybackNotifier] ⚡ Obteniendo primeras recomendaciones rápidas (Fase 1)...');
      
      // 🎯 FASE 1: Obtener excludeIds del servicio centralizado
      final playedIds = ref.read(playbackSessionProvider.notifier).getPlayedSongIds();
      final excludeIds = excludeSeedFromQueue 
          ? {...playedIds, seedSong.id}
          : playedIds;
      
      // ⚡ TRANSICIÓN INSTANTÁNEA: Obtener 6 canciones primero (aumentado para asegurar tercera canción)
      final quickRecommendations = await _intelligentService.getIntelligentFeaturedSongs(
        limit: 6, // Aumentado de 4 a 6 para asegurar tercera canción disponible
        currentSongId: seedSong.id,
        forceRefresh: true,
        excludeIds: excludeIds,
      );
      
      // 🚨 CRÍTICO: Declarar quickSongs fuera del bloque para usarlo en Fase 2
      List<Song> quickSongs = [];
      
      if (quickRecommendations.isNotEmpty) {
        quickSongs = quickRecommendations
            .map((f) => f.song)
            .where((s) => !excludeIds.contains(s.id))
            .take(6) // Aumentado de 4 a 6
            .toList();
        
        if (quickSongs.isNotEmpty) {
          // 🚨 VALIDACIÓN: Filtrar canciones inválidas antes de agregar
          final validQuickSongs = quickSongs.where((s) => s.isValidForPlayback).toList();
          
          if (validQuickSongs.isEmpty) {
            AppLogger.warning('[PlaybackNotifier] ⚠️ Fase 1: Todas las canciones tienen fileUrl inválido');
          } else if (validQuickSongs.length < quickSongs.length) {
            AppLogger.warning('[PlaybackNotifier] ⚠️ Fase 1: ${quickSongs.length - validQuickSongs.length} canciones inválidas filtradas');
          }
          
          if (validQuickSongs.isNotEmpty) {
            // 🚨 AGREGAR INMEDIATAMENTE: Usar método atómico para prevenir race conditions
            await _updateQueueAtomically(
              newSongs: validQuickSongs,
              audioOperation: (sources) => service.appendToQueue(sources),
              replace: false,
            );
            
            // Ajustar cola si excluimos la semilla
            if (excludeSeedFromQueue && state.currentQueue.first.id == seedSong.id) {
              state = state.copyWith(
                currentQueue: state.currentQueue.where((s) => s.id != seedSong.id).toList(),
              );
            }
            
            AppLogger.info('[PlaybackNotifier] ⚡ Primeras ${validQuickSongs.length} canciones válidas agregadas inmediatamente (asegurando tercera canción disponible)');
          }
        }
      }
      
      // 🚨 FASE 2 EN BACKGROUND: Usar las 6 canciones de la Fase 1 como semillas DIRECTAMENTE
      // 🎯 DESACOPLADO: Usa método dedicado que evita duplicar llamadas a getIntelligentFeaturedSongs
      if (quickSongs.isNotEmpty && quickSongs.length >= 2) {
        AppLogger.info('[PlaybackNotifier] 🔗 Iniciando Fase 2 desacoplada con ${quickSongs.length} semillas de la Fase 1...');
        
        // 🎯 FASE 1: Combinar todos los IDs que ya están en la cola para excluir
        final allQueueIds = state.currentQueue.map((s) => s.id).toSet();
        final phase2ExcludeIds = {...excludeIds, ...allQueueIds};
        
        // 🚨 MÉTODO DESACOPLADO: Usar semillas directamente sin llamar a getIntelligentFeaturedSongs
        // Esto evita duplicar trabajo y reduce tiempo de ~15s a ~5s
        final phase2Songs = await _intelligentService.generatePhase2RecommendationsFromSeeds(
          seeds: quickSongs.map((s) => s.id).toList(), // 🎯 USAR TODAS LAS SEMILLAS DE FASE 1
          count: 10, // Obtener 10 canciones adicionales
          excludeIds: phase2ExcludeIds, // Excluir todo lo que ya está en la cola
          user: null, // TODO: Pasar usuario si está disponible
        );
        
        if (phase2Songs.isNotEmpty) {
          // 🚨 VALIDACIÓN ROBUSTA: Filtrar canciones inválidas usando isValidForPlayback
          final validSongs = phase2Songs.where((s) => 
            s.isValidForPlayback &&
            !allQueueIds.contains(s.id)
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
    }
  }

  /// Generar cola inicial para modo algoritmo
  /// 
  /// [seedSong]: Canción semilla para generar recomendaciones
  /// [excludeSeedFromQueue]: Si es true, NO incluye la semilla en la cola (útil para transiciones)
  Future<List<Song>> _generateInitialAlgorithmQueue(Song seedSong, {bool excludeSeedFromQueue = false}) async {
    try {
      // 🎯 FASE 1: Obtener excludeIds del servicio centralizado
      final playedIds = ref.read(playbackSessionProvider.notifier).getPlayedSongIds();
      final excludeIds = excludeSeedFromQueue 
          ? {...playedIds, seedSong.id}
          : playedIds;
      
      // Usar IntelligentFeaturedService para obtener recomendaciones
      // IMPORTANTE: Excluir la semilla y el historial reciente para evitar repetición
      // 🚨 FORZAR REFRESH para obtener recomendaciones dinámicas frescas del algoritmo
      AppLogger.info('[PlaybackNotifier] 🔄 Solicitando recomendaciones dinámicas para semilla: ${seedSong.title} (ID: ${seedSong.id})');
      AppLogger.info('[PlaybackNotifier] 🚫 Excluyendo ${excludeIds.length} canciones (reproducidas: ${playedIds.length}, semilla: ${excludeSeedFromQueue})');
      
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
  int _getRemainingQueueSize() {
    if (state.currentQueue.isEmpty) return -1;
    
    final currentSong = state.currentSong;
    if (currentSong == null) return -1;
    
    final currentIndex = state.currentQueue.indexWhere(
      (s) => s.id == currentSong.id,
    );
    
    if (currentIndex == -1) return -1;
    
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
    if (_isPreloading || state.currentQueue.isEmpty) return;
    
    // 🚨 COOLDOWN: Verificar que haya pasado el tiempo mínimo desde la última precarga
    // 🎯 EXCEPCIÓN: Si forceIgnoreCooldown es true, ignorar el cooldown (para saltos manuales críticos)
    if (!forceIgnoreCooldown && _lastPreloadTime != null) {
      final timeSinceLastPreload = DateTime.now().difference(_lastPreloadTime!);
      if (timeSinceLastPreload < _preloadCooldown) {
        AppLogger.debug('[PlaybackNotifier] ⏳ Precarga bloqueada: cooldown activo (${timeSinceLastPreload.inSeconds}s/${_preloadCooldown.inSeconds}s)');
        return;
      }
    }

    try {
      _isPreloading = true;
      _lastPreloadTime = DateTime.now(); // 🚨 COOLDOWN: Registrar timestamp
      
      final currentSong = state.currentSong ?? state.currentQueue.first;
      
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
      final shouldPreloadByCount = remainingSongs <= PRELOAD_THRESHOLD;
      
      if (!isUrgentPreload && !shouldPreloadByCount) {
        _isPreloading = false; // Liberar flag antes de retornar
        return; // Silencioso: hay suficientes canciones
      }
      
      // 🚨 LOG REDUCIDO: Solo cuando realmente inicia la precarga
      
      // 🎯 FASE 1: Obtener excludeIds del servicio centralizado + canciones en cola
      final playedIds = ref.read(playbackSessionProvider.notifier).getPlayedSongIds();
      final existingIds = state.currentQueue.map((s) => s.id).toSet();
      final excludeIds = {...existingIds, ...playedIds};
      
      AppLogger.debug('[PlaybackNotifier] 🔍 Precarga: Excluyendo ${excludeIds.length} IDs (${existingIds.length} en cola + ${playedIds.length} reproducidas)');
      
      // ⚡ TRANSICIÓN INSTANTÁNEA: Obtener más recomendaciones (20 en lugar de 15 para asegurar tercera canción)
      final featuredSongs = await _intelligentService.getIntelligentFeaturedSongs(
        limit: 20, // Aumentado para asegurar que siempre hay canciones disponibles
        currentSongId: currentSong.id,
        forceRefresh: false,
        excludeIds: excludeIds, // Excluir historial reciente y cola actual
      );

      AppLogger.debug('[PlaybackNotifier] 🔍 Precarga: Recibidas ${featuredSongs.length} recomendaciones del servicio');

      // Filtrar canciones que ya están en la cola o en el historial reciente
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
        return;
      }

      // 🚨 VALIDACIÓN: Filtrar canciones inválidas antes de agregar
      final validNewSongs = newSongs.where((s) => s.isValidForPlayback).toList();
      
      if (validNewSongs.isEmpty) {
        // 🛡️ PREVENCIÓN: Si todas son inválidas, usar fallback para evitar cola vacía
        AppLogger.warning('[PlaybackNotifier] 🛡️ Todas las canciones son inválidas, activando fallback para prevenir cola vacía');
        _tryFallbackRecommendations(currentSong, excludeIds);
        return;
      }
      
      if (validNewSongs.length < newSongs.length) {
        AppLogger.debug('[PlaybackNotifier] ⚠️ Precarga: ${newSongs.length - validNewSongs.length} canciones inválidas filtradas');
      }

      // 🎯 FASE 3.1: Precarga Progresiva - Agregar solo canciones críticas inmediatamente
      // Separar canciones críticas (primeras 5) del resto
      final criticalSongs = validNewSongs.take(CRITICAL_SONGS_COUNT).toList();
      final additionalSongs = validNewSongs.skip(CRITICAL_SONGS_COUNT).toList();
      
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
      
      // 🎯 FASE 3.1: Log de canciones críticas agregadas
      AppLogger.info('[PlaybackNotifier] ✅ Fase 3.1: ${criticalSongs.length} canciones críticas agregadas inmediatamente');
      
      // 🎯 FASE 3.1: Si hay más canciones, informar (pero no agregarlas ahora)
      // Por ahora, dejamos que el Monitor de Fase 2 se encargue de obtener más cuando sea necesario
      // Esto evita conflictos con el conteo de canciones del Monitor
      if (additionalSongs.isNotEmpty) {
        AppLogger.debug('[PlaybackNotifier] 📋 Fase 3.1: ${additionalSongs.length} canciones adicionales disponibles (el Monitor de Fase 2 las agregará cuando sea necesario)');
      }

      // 🚨 LOG CRÍTICO: Solo cuando se completa exitosamente
      AppLogger.info('[PlaybackNotifier] ✅ Precarga finalizada y cola extendida: ${criticalSongs.length} canciones críticas agregadas');
      
      // 🎯 DETECCIÓN MANUAL: Si estaba en modo crítico (0 canciones), avanzar automáticamente
      if (isCriticalPreload && criticalSongs.isNotEmpty) {
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
    } finally {
      _isPreloading = false; // 🚨 CRÍTICO: Liberar bandera siempre
    }
  }

  /// 🎯 FASE 2: Monitor proactivo para precargar canciones en modo algorithm
  /// 
  /// Detecta cuando quedan ≤3 canciones disponibles y dispara la recarga automáticamente.
  /// Usa la función centralizada _getRemainingQueueSize() como fuente única de verdad.
  void _startAlgorithmMonitor() {
    _stopAlgorithmMonitor(); // Asegurar que no haya otro monitor activo

    AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: Monitor iniciado - Verificando cada 5s (umbral: ≤${PRELOAD_THRESHOLD} canciones)');

    // 🎯 FASE 2: Verificar cada 5 segundos para detectar agotamiento del buffer
    _algorithmMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state.playbackMode != PlaybackMode.algorithm) {
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: Monitor detenido (modo cambiado)');
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
      if (remainingSongs <= PRELOAD_THRESHOLD) {
        final remainingTime = state.totalDuration - state.currentPosition;
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR: ⚠️ CRÍTICO - ${remainingSongs} canciones restantes (umbral: ≤${PRELOAD_THRESHOLD}) - Tiempo restante: ${remainingTime.inSeconds}s');
      } else {
        // Log cada 30 segundos cuando hay suficientes canciones
        final now = DateTime.now();
        if (_lastMonitorLogTime == null || now.difference(_lastMonitorLogTime!).inSeconds >= 30) {
          AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR: ✅ ${remainingSongs} canciones restantes (umbral: ≤${PRELOAD_THRESHOLD}) - OK (no se dispara precarga)');
          _lastMonitorLogTime = now;
        }
      }

      // 🎯 FASE 2: Detección proactiva - Si quedan ≤3 canciones, disparar recarga
      if (remainingSongs <= PRELOAD_THRESHOLD && !_isPreloading) {
        // Verificar cooldown antes de disparar
        final canPreload = _lastPreloadTime == null || 
            DateTime.now().difference(_lastPreloadTime!) >= _preloadCooldown;
        
        if (canPreload) {
          final remainingTime = state.totalDuration - state.currentPosition;
          AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: Precarga proactiva DISPARADA ✅ (${remainingSongs} canciones restantes, ${remainingTime.inSeconds}s para final)');
          _appendMoreAlgorithmSongs();
        } else {
          final timeSinceLastPreload = DateTime.now().difference(_lastPreloadTime!);
          AppLogger.info('[PlaybackNotifier] ⏳ FASE 2: Precarga bloqueada por cooldown (${remainingSongs} canciones restantes, cooldown: ${timeSinceLastPreload.inSeconds}s/${_preloadCooldown.inSeconds}s)');
        }
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
  void _forceImmediatePreload() {
    // Validaciones iniciales estrictas
    if (state.playbackMode != PlaybackMode.algorithm) {
      AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: No está en modo algoritmo');
      return;
    }
    
    if (_isPreloading) {
      AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: Precarga ya en curso, omitiendo');
      return;
    }
    
    if (state.currentQueue.isEmpty) {
      AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: Cola vacía');
      return;
    }
    
    try {
      final remainingSongs = _getRemainingQueueSize();
      if (remainingSongs == -1) {
        AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: No se puede determinar canciones restantes');
        return;
      }
      
      // 🎯 DETECCIÓN MANUAL: Ignorar cooldown SIEMPRE si quedan ≤3 canciones (salto crítico)
      // Esto es especialmente importante cuando quedan 0 canciones para evitar "No hay siguiente canción"
      final shouldIgnoreCooldown = remainingSongs <= PRELOAD_THRESHOLD;
      
      // 🚨 CRÍTICO: Si quedan pocas canciones, NO verificar cooldown (ignorarlo completamente)
      if (shouldIgnoreCooldown) {
        AppLogger.info('[PlaybackNotifier] ⚡ Salto manual detectado: Forzando recarga inmediata (${remainingSongs} canciones restantes) [COOLDOWN IGNORADO - CRÍTICO]');
        // Marcar timestamp ANTES de llamar para evitar llamadas muy rápidas
        _lastPreloadTime = DateTime.now();
        // Llamar directamente sin verificar cooldown (forceIgnoreCooldown = true)
        _appendMoreAlgorithmSongs(forceIgnoreCooldown: true);
      } else {
        // Solo si hay suficientes canciones, verificar cooldown normalmente
        if (_lastPreloadTime != null) {
          final timeSinceLastPreload = DateTime.now().difference(_lastPreloadTime!);
          if (timeSinceLastPreload < _preloadCooldown) {
            AppLogger.debug('[PlaybackNotifier] ⏭️ Salto manual: Cooldown activo (${timeSinceLastPreload.inSeconds}s/${_preloadCooldown.inSeconds}s)');
            return;
          }
        }
        AppLogger.info('[PlaybackNotifier] ⚡ Salto manual: Recarga programada (${remainingSongs} canciones restantes)');
        _lastPreloadTime = DateTime.now();
        _appendMoreAlgorithmSongs();
      }
    } catch (e, stackTrace) {
      // 🚨 PROTECCIÓN: Capturar cualquier error para evitar que bloquee la app
      AppLogger.error('[PlaybackNotifier] ❌ Error en _forceImmediatePreload: $e', stackTrace);
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
      if (effectiveRemainingSongs <= PRELOAD_THRESHOLD && effectiveRemainingSongs > 0 && !_isPreloading) {
        AppLogger.warning('[PlaybackNotifier] 🛡️ Cola crítica: Solo $effectiveRemainingSongs canciones restantes. Precarga urgente activada.');
        _appendMoreAlgorithmSongs();
        return;
      }

      // 🛡️ PREVENTIVO: Si quedan menos de 5 canciones, precargar proactivamente
      if (effectiveRemainingSongs < _minQueueSize && effectiveRemainingSongs > 0 && !_isPreloading) {
        final remainingTime = state.totalDuration - state.currentPosition;
        // Precargar si quedan menos de 60 segundos (más anticipación)
        if (remainingTime.inSeconds <= 60 && remainingTime.inSeconds > 0) {
          AppLogger.info('[PlaybackNotifier] 🛡️ Precarga preventiva: $effectiveRemainingSongs canciones restantes (objetivo: $_minQueueSize)');
          _appendMoreAlgorithmSongs();
        }
      }

      // 🛡️ VALIDACIÓN: Verificar que la cola tenga tamaño mínimo
      if (queueSize < _minQueueSize && !_isPreloading && queueSize > 0) {
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
            excludeIds: ref.read(playbackSessionProvider.notifier).getPlayedSongIds(),
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
      // En modo fixedQueue, verificar si hay siguiente canción
      if (service.player.hasNext) {
        // ⚡ TRANSICIÓN INSTANTÁNEA: Usar seekToNext() que es más rápido que next()
        try {
          // seekToNext() es más eficiente porque no requiere detener/reproducir
          await service.player.seekToNext();
          // ⚡ CRÍTICO: Reproducir inmediatamente sin delay
          await service.player.play();
          
          // Actualizar estado inmediatamente
          final sequenceState = service.player.sequenceState;
          final currentIndex = sequenceState.currentIndex;
          if (currentIndex != null && currentIndex < sequenceState.sequence.length) {
            final currentSource = sequenceState.sequence[currentIndex];
            if (currentSource.tag is Song) {
              final currentSong = currentSource.tag as Song;
              state = state.copyWith(
                currentSong: currentSong,
                isPlaying: true,
                currentPosition: Duration.zero,
              );
            }
          }
          
          AppLogger.info('[PlaybackNotifier] ⚡ Transición instantánea completada');
        } catch (e) {
          AppLogger.error('[PlaybackNotifier] Error en transición instantánea, usando método fallback: $e');
          // Fallback al método original
          await service.next();
        }
      } else {
        // 🚩 FIN DE LA COLA: Verificar si debemos iniciar el algoritmo
        if (state.shouldStartAlgorithmAfterQueue && state.currentQueue.isNotEmpty) {
          // Obtener la última canción de la cola como semilla
          final lastSongInQueue = state.currentQueue.last;
          
          AppLogger.info('[PlaybackNotifier] 🎵 Fin de cola fija detectado. Iniciando Radio Infinita con semilla: ${lastSongInQueue.title}');
          
          // Resetear la bandera ANTES de iniciar el algoritmo
          state = state.copyWith(shouldStartAlgorithmAfterQueue: false);
          
          // 🚨 SOLUCIÓN DEFINITIVA: CARGAR NUEVA COLA INMEDIATAMENTE
          // NO pausar ni detener - simplemente cargar la nueva cola que sobrecargará el reproductor
          // La función playAlgorithmStart() se encarga de:
          // 1. Generar la nueva cola (excluyendo la semilla)
          // 2. Cargar la nueva cola con loadNewQueue()
          // 3. Reproducir inmediatamente con play()
          // Esto evita que el reproductor tenga tiempo de repetir la última canción
          await playAlgorithmStart(lastSongInQueue, excludeSeedFromQueue: true);
        } else if (state.repeatMode == RepeatMode.all) {
          // Si está en repeat all, volver al inicio
          await service.seek(Duration.zero);
          await service.player.seek(Duration.zero, index: 0);
        } else {
          // Si no hay algoritmo esperando y no está en repeat, detener la reproducción
          AppLogger.info('[PlaybackNotifier] Fin de cola fija. Deteniendo reproducción.');
          await service.pause();
          state = state.copyWith(isPlaying: false);
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
          final sequenceState = service.player.sequenceState;
          final currentIndex = sequenceState.currentIndex;
          if (currentIndex != null && currentIndex < sequenceState.sequence.length) {
            final currentSource = sequenceState.sequence[currentIndex];
            if (currentSource.tag is Song) {
              final currentSong = currentSource.tag as Song;
              state = state.copyWith(
                currentSong: currentSong,
                isPlaying: true,
                currentPosition: Duration.zero,
              );
            }
          }
          
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

  /// Alternar play/pause
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await service.pause();
    } else {
      await service.play();
    }
  }

  /// Siguiente canción
  /// Si estamos en una cola fija y llegamos al final, activa Radio Infinita automáticamente
  /// 🎯 DETECCIÓN MANUAL: En modo algoritmo, fuerza recarga inmediata si quedan pocas canciones
  Future<void> next() async {
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
        if (remainingSongs <= PRELOAD_THRESHOLD && !_isPreloading) {
          // 🎯 CASO CRÍTICO: Si quedan 0 canciones, esperar a que se complete la recarga
          if (remainingSongs == 0) {
            AppLogger.info('[PlaybackNotifier] ⏭️ Salto manual detectado con 0 canciones. Recargando primero...');
            // Ejecutar recarga de forma síncrona (esperar)
            await Future.delayed(const Duration(milliseconds: 50));
            _forceImmediatePreload();
            
            // Esperar a que se agreguen las canciones (máximo 3 segundos)
            int waitAttempts = 0;
            while (_isPreloading && waitAttempts < 30) {
              await Future.delayed(const Duration(milliseconds: 100));
              waitAttempts++;
            }
            
            // Verificar si ahora hay siguiente canción
            if (service.player.hasNext) {
              AppLogger.info('[PlaybackNotifier] ✅ Canciones agregadas, avanzando...');
              await service.next();
              return; // Salir aquí, ya avanzamos
            } else {
              AppLogger.warning('[PlaybackNotifier] ⚠️ Aún no hay siguiente canción después de recarga');
              return; // No avanzar si no hay siguiente
            }
          } else {
            // Caso no crítico: programar recarga en background
            AppLogger.info('[PlaybackNotifier] ⏭️ Salto manual detectado (botón siguiente) con $remainingSongs canciones restantes. Programando recarga...');
            // Usar Future.delayed para evitar bloqueos
            Future.delayed(const Duration(milliseconds: 50), () {
              if (!_isPreloading && state.playbackMode == PlaybackMode.algorithm) {
                _forceImmediatePreload();
              }
            });
          }
        }
      }
    }
    
    // Avanzar normalmente (solo si no es caso crítico que ya se manejó arriba)
    if (service.player.hasNext) {
      await service.next();
    } else {
      AppLogger.info('[PlaybackNotifier] ℹ️ No hay siguiente canción disponible');
    }
  }

  /// Canción anterior
  /// 🎯 DETECCIÓN MANUAL: En modo algoritmo, verifica estado después del salto
  Future<void> previous() async {
    // En modo algoritmo, el salto hacia atrás también puede necesitar recarga
    // (aunque es menos común, puede ocurrir si el usuario retrocede mucho)
    if (state.playbackMode == PlaybackMode.algorithm) {
      // Nota: No forzamos recarga en previous() porque retroceder no reduce el buffer
      // Pero sí registramos la canción saltada cuando el listener detecta el cambio
    }
    
    await service.previous();
  }

  /// Buscar posición
  /// Si se busca manualmente cerca del final de una cola fija, puede activar Radio Infinita
  Future<void> seek(Duration position) async {
    await service.seek(position);
    
    // Si estamos en una cola fija y el usuario busca cerca del final, verificar si debemos activar algoritmo
    if (state.playbackMode == PlaybackMode.fixedQueue && 
        state.shouldStartAlgorithmAfterQueue &&
        state.currentQueue.isNotEmpty) {
      
      final currentIndex = state.currentQueue.indexWhere(
        (s) => s.id == state.currentSong?.id,
      );
      
      if (currentIndex != -1) {
        final isLastSong = currentIndex >= state.currentQueue.length - 1;
        final remainingTime = state.totalDuration - position;
        
        // Si estamos en la última canción y cerca del final (últimos 10 segundos)
        if (isLastSong && remainingTime.inSeconds <= 10 && remainingTime.inSeconds > 0) {
          final lastSong = state.currentQueue.last;
          AppLogger.info('[PlaybackNotifier] ⏩ Seek manual cerca del final. Activando Radio Infinita con semilla: ${lastSong.title}');
          
          // Activar algoritmo
          state = state.copyWith(shouldStartAlgorithmAfterQueue: false);
          await playAlgorithmStart(lastSong, excludeSeedFromQueue: true);
        }
      }
    }
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
    if (sequenceState == null || _isUpdatingQueue) {
      return; // No sincronizar si estamos actualizando o no hay estado
    }

    try {
      final audioSources = sequenceState.sequence;
      if (audioSources.isEmpty) {
        // Si la cola de audio está vacía pero el estado tiene canciones, limpiar
        if (state.currentQueue.isNotEmpty) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ Desincronización detectada: cola de audio vacía pero estado tiene ${state.currentQueue.length} canciones');
          state = state.copyWith(currentQueue: []);
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
        
        // Sincronizar: usar la cola real de audio como fuente de verdad
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
    } catch (e) {
      AppLogger.debug('[PlaybackNotifier] Error al sincronizar cola (no crítico): $e');
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
        while (_isUpdatingQueue && attempts < 50) { // Máximo 5 segundos
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        if (_isUpdatingQueue) {
          AppLogger.error('[PlaybackNotifier] ❌ Timeout esperando actualización de cola (${attempts * 100}ms)');
          return;
        }
        AppLogger.info('[PlaybackNotifier] ✅ Actualización anterior completada, continuando...');
      } else {
        // Modo normal: solo esperar un poco
        AppLogger.warning('[PlaybackNotifier] ⚠️ Actualización de cola en progreso, esperando...');
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isUpdatingQueue) {
          AppLogger.error('[PlaybackNotifier] ❌ Timeout esperando actualización de cola');
          return;
        }
      }
    }

    _isUpdatingQueue = true;
    
    try {
      // Convertir canciones a AudioSource
      final sources = newSongs.map((s) => s.toAudioSource()).toList();
      
      // Ejecutar operación de audio
      await audioOperation(sources);
      
      // Actualizar estado de forma atómica
      final updatedQueue = replace 
          ? newSongs 
          : [...state.currentQueue, ...newSongs];
      
      state = state.copyWith(currentQueue: updatedQueue);
      
      // Validar sincronización después de un breve delay
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
    if (useAlgorithm) {
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
    
    await playFixedQueue(allSongs, validStartSong, contextId: contextId);
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

