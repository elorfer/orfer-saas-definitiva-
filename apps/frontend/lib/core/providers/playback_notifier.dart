import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song_model.dart';
import '../models/audio_ad_model.dart';
import '../services/audio_service.dart';
import '../services/intelligent_featured_service.dart';
import '../services/home_service.dart';
import '../providers/play_history_provider.dart';
import '../providers/playback_session_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';
import 'playback_state.dart';
import 'ad_insertion_manager.dart';
import '../../features/ads/models/audio_ad_model.dart';
import '../../features/ads/providers/ads_provider.dart';

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
  DateTime? _lastTrigger50LogTime; // ✅ FASE 3: Timestamp del último log del trigger del 50% (para evitar spam)
  int? _lastKnownIndex; // 🎯 DETECCIÓN MANUAL: Último índice conocido para detectar saltos manuales
  DateTime? _lastManualSkipCheck; // 🎯 PROTECCIÓN: Timestamp de última verificación de salto manual (debounce)
  static const Duration _manualSkipDebounce = Duration(milliseconds: 500); // Debounce para evitar múltiples verificaciones
  bool _isRestartingAlgorithm = false; // 🎯 PROTECCIÓN: Flag para evitar reinicios múltiples del algoritmo
  bool _isReplacingQueue = false; // 🎯 PROTECCIÓN: Flag cuando se reemplaza toda la cola (loadNewQueue)
  Song? _lastConfirmedSong; // 🔒 Conserva la última canción confirmada para evitar flashes de portada
  bool _isDeduplicating = false; // 🛡️ PROTECCIÓN: Flag para evitar deduplicación múltiple simultánea
  DateTime? _lastDeduplicationTime; // 🛡️ PROTECCIÓN: Timestamp de última deduplicación
  DateTime? _lastAdCompletionTime; // ✅ PROTECCIÓN: Timestamp de última finalización de anuncio (para evitar cambios de carátula inmediatos)
  static const Duration _deduplicationCooldown = Duration(seconds: 2); // Cooldown entre deduplicaciones
  DateTime? _lastInjectionTime; // 🛡️ PROTECCIÓN: Timestamp de última inyección instantánea
  static const Duration _injectionProtectionWindow = Duration(milliseconds: 1500); // ⚡ AUMENTADO: Ventana de protección después de inyección (1.5s para evitar deduplicación inmediata)
  String? _lastDedupSignature; // 🛡️ PROTECCIÓN: Firma de la última deduplicación para evitar bucles
  DateTime? _lastDedupSignatureTime; // 🛡️ PROTECCIÓN: Timestamp de la última firma
  static const Duration _dedupSignatureCooldown = Duration(seconds: 5); // Cooldown para firmas repetidas
  int _dedupAttemptsWindow = 0; // 🛡️ PROTECCIÓN: Contador en ventana corta
  DateTime? _dedupAttemptsWindowStart;
  static const Duration _dedupAttemptsWindowDuration = Duration(seconds: 10);
  static const int _dedupAttemptsWindowMax = 2; // No más de 2 dedups en 10s
  
  // 📢 ANUNCIOS: Variables para tracking de anuncios
  DateTime? _adStartTime; // Timestamp de inicio del anuncio actual
  AdInsertionManager? _adInsertionManager; // ✅ MEJOR PRÁCTICA: Gestor dedicado para inserción
  bool _isInsertingAd = false; // ✅ PROTECCIÓN: Flag para evitar detección incorrecta durante inserción
  bool _isHandlingAdInsertion = false; // ✅ PROTECCIÓN CRÍTICA: Bloqueo atómico para evitar race conditions
  bool _isRemovingOrphanedAd = false; // ✅ PROTECCIÓN: Flag para evitar eliminaciones simultáneas de anuncios huérfanos
  bool _isCompletingAd = false; // ✅ PROTECCIÓN CRÍTICA: Flag para evitar procesamiento duplicado de finalización de anuncio
  bool _preventiveAdTriggered = false; // ✅ PROTECCIÓN: Flag para evitar múltiples triggers de pausa preventiva
  String? _lastSongIdWithAd; // ✅ PROTECCIÓN: ID de la última canción que tuvo un anuncio (evita duplicados)
  int _adFrequencyFromAdmin = 0; // Frecuencia de anuncios cargada desde el admin
  
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

  // 🛡️ ESCUDO DE TRANSICIÓN: Bloqueo de actualizaciones del stream tras saltos manuales
  bool _isManualSkipping = false;
  Timer? _manualSkipTimer;
  DateTime? _lastSeekTime; // 🎯 TRIGGER 50%: Timestamp del último seek manual
  
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
  DateTime? _lastCriticalQueueWarning; // Timestamp de último warning de cola crítica
  static const Duration _emergencyCooldown = Duration(seconds: 10); // Cooldown entre emergencias
  static const Duration _criticalQueueWarningCooldown = Duration(seconds: 15); // Cooldown entre warnings de cola crítica

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

  /// Cargar frecuencia de anuncios desde el backend
  Future<void> _loadAdFrequency() async {
    try {
      // Usar Future.delayed para asegurar que los providers estén listos
      await Future.delayed(Duration.zero);
      final frequency = await ref.read(adsProvider.notifier).fetchAdFrequency();
      _adFrequencyFromAdmin = frequency;
      AppLogger.info('[PlaybackNotifier] 📢 Frecuencia de anuncios actualizada desde API: $_adFrequencyFromAdmin');
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error al cargar frecuencia de anuncios: $e');
    }
  }

  @override
  PlaybackState build() {
    // Inicializar logger
    AppLogger.init();
    
    // Cargar frecuencia de anuncios en segundo plano
    _loadAdFrequency();
    
    // Obtener AudioService del provider
    _service = ref.watch(audioServiceProvider);
    
    // ✅ MEJOR PRÁCTICA: Inicializar gestor de inserción de anuncios
    if (_service != null) {
      _adInsertionManager = AdInsertionManager(_service!);
    }
    
    // Inicializar suscripciones cuando se crea el notifier
    _initSubscriptions();
    
    // Limpiar recursos cuando se dispose
    ref.onDispose(() {
      _dispose();
    });
    
    return const PlaybackState();
  }

  /// Activa el escudo de transición para bloquear actualizaciones del stream por 600ms
  void _activateTransitionShield() {
    _isManualSkipping = true;
    _manualSkipTimer?.cancel();
    _manualSkipTimer = Timer(const Duration(milliseconds: 600), () {
      _isManualSkipping = false;
    });
  }

  /// Inicializar suscripciones a los streams del reproductor
  void _initSubscriptions() {
    if (_service == null) return;
    
    // 1. Suscribirse a los cambios de la secuencia para obtener la canción actual
    _subscriptions.add(
      service.sequenceStateStream.listen((sequenceState) {
        // 🛡️ ESCUDO DE TRANSICIÓN: Si estamos en un salto manual, ignorar actualizaciones del stream
        // Esto evita el "Efecto Látigo" donde se muestra brevemente la canción anterior
        if (_isManualSkipping) return;

        if (sequenceState == null) return;
        
        final currentIndex = sequenceState.currentIndex;
        final currentSource = sequenceState.currentSource;
        
        // ✅ FIX CRÍTICO: Verificar PRIMERO si hay una canción reproduciéndose y limpiar estado del anuncio
        // Esto debe hacerse ANTES de cualquier verificación de protección para asegurar que el estado se limpie
        // inmediatamente cuando el anuncio termina y el reproductor avanza a una canción
        // PERO solo si realmente hay una canción reproduciéndose (no durante inserción de anuncio)
        if (currentSource != null && currentSource.tag is Song && (state.isPlayingAd || state.currentAd != null)) {
          final songAtCurrentIndex = currentSource.tag as Song;
          
          // ✅ FIX CRÍTICO: Verificar que realmente estamos en el índice de la canción (no durante inserción)
          final sequence = sequenceState.sequence;
          final isAtSongIndex = currentIndex != null && 
                               currentIndex >= 0 && 
                               currentIndex < sequence.length &&
                               sequence[currentIndex].tag is Song;
          
          // Solo limpiar si realmente estamos en una canción (no durante inserción de anuncio)
          // ✅ FIX CRÍTICO: NO limpiar si estamos en proceso de pausa preventiva O inserción de anuncio O completando anuncio
          // porque el reproductor puede avanzar temporalmente antes de que se reproduzca el anuncio
          // o porque el manejo de finalización del anuncio ya está en proceso
          if (isAtSongIndex && !_preventiveAdTriggered && !_isInsertingAd && !_isHandlingAdInsertion && !_isCompletingAd) {
            AppLogger.warning('[PlaybackNotifier] 🛑 LIMPIEZA EN STREAM: Hay canción reproduciéndose (${songAtCurrentIndex.title}) pero estado tiene anuncio, limpiando INMEDIATAMENTE');
            
            
            // Limpiar flags si están activos (el anuncio ya terminó)
            if (_isHandlingAdInsertion || _isInsertingAd || _isCompletingAd) {
              AppLogger.warning('[PlaybackNotifier] 🧹 Limpiando flags de inserción porque el anuncio ya terminó');
              _isHandlingAdInsertion = false;
              _isInsertingAd = false;
              _isCompletingAd = false;
            }
            
            // 🛑 FORCE CLEAR: Obtener duración de la nueva canción INMEDIATAMENTE del reproductor
            // Esto evita que la barra de progreso muestre la duración del anuncio por unos segundos
            final newSongDuration = currentSource.duration ?? 
                                   (songAtCurrentIndex.duration != null 
                                     ? Duration(seconds: songAtCurrentIndex.duration!) 
                                     : Duration.zero);
            final newSongPosition = _service?.player.position ?? Duration.zero;
            
            // ✅ FIX CRÍTICO: SIEMPRE actualizar currentSong y lastConfirmedSong con la canción actual del reproductor
            // Esto asegura que la UI muestre la canción correcta inmediatamente después del anuncio
            // No usar ?? porque puede mantener la canción anterior si ya estaba establecida
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true,
              // ✅ FIX CRÍTICO: SIEMPRE actualizar con la canción actual del reproductor
              currentSong: songAtCurrentIndex,
              lastConfirmedSong: songAtCurrentIndex,
              // 🛑 FORCE CLEAR: Resetear posición y duración INMEDIATAMENTE para evitar "State Lag"
              currentPosition: newSongPosition,
              totalDuration: newSongDuration.inMilliseconds > 0 ? newSongDuration : Duration.zero,
            );
            AppLogger.info('[PlaybackNotifier] ✅ Estado limpiado y canción actualizada: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}, currentSong=${state.currentSong?.id ?? "null"}');
            AppLogger.info('[PlaybackNotifier] 🛑 [FORCE CLEAR] Duración reseteada: ${newSongDuration.inSeconds}s (posición: ${newSongPosition.inSeconds}s)');
            
            // Sincronizar inmediatamente después de limpiar para actualizar duración y posición
            _syncQueueWithAudioService(sequenceState, forceSync: true);
            return; // No continuar con el procesamiento normal si limpiamos el estado
          }
        }
        
        // 🧹 LIMPIEZA AUTOMÁTICA DE ANUNCIOS HUÉRFANOS: Eliminar anuncios que ya fueron saltados
        // Esto previene que anuncios "huérfanos" bloqueen futuras inserciones
        // ✅ FIX CRÍTICO: Usar microtask para diferir la eliminación fuera del ciclo del stream listener
        // Esto evita el error "Cannot fire new event. Controller is already firing an event"
        // ✅ PROTECCIÓN: NO eliminar anuncios que están justo antes del índice actual si acabamos de completar un anuncio
        // Esto evita eliminar anuncios que simplemente terminaron de reproducirse normalmente
        if (_service != null && currentIndex != null && _adInsertionManager != null && !_isRemovingOrphanedAd && !_isCompletingAd) {
          final sequenceState = _service!.player.sequenceState;
          // ✅ FIX CRÍTICO: Solo buscar anuncios huérfanos que están MUY antes del índice actual (más de 1 posición)
          // Los anuncios que están justo antes (índice actual - 1) probablemente acaban de terminar de reproducirse
          // y se eliminarán automáticamente en _handleAdCompletion
          for (int i = 0; i < currentIndex - 1 && i < sequenceState.sequence.length; i++) {
            final source = sequenceState.sequence[i];
            if (source.tag is AudioAd) {
              final orphanedAd = source.tag as AudioAd;
              final orphanedIndex = i; // Capturar el índice antes de diferir
              AppLogger.warning('[PlaybackNotifier] 🧹 [STREAM] Detectado anuncio huérfano en índice $orphanedIndex (actual: $currentIndex): ${orphanedAd.title} - Programando eliminación...');
              
              // ✅ FIX CRÍTICO: Diferir la eliminación usando un microtask para evitar conflictos con el stream
              _isRemovingOrphanedAd = true;
              Future.microtask(() async {
                try {
                  await _adInsertionManager!.removeAdAt(orphanedIndex);
                  AppLogger.info('[PlaybackNotifier] 🧹 [STREAM] Anuncio huérfano eliminado exitosamente del índice $orphanedIndex');
                } catch (e) {
                  AppLogger.error('[PlaybackNotifier] Error al eliminar anuncio huérfano: $e');
                } finally {
                  _isRemovingOrphanedAd = false;
                }
              });
              
              // Después de programar la eliminación, salir del loop
              break;
            }
          }
        }
        
        // Obtener la canción actual usando el tag
        // Si estamos reemplazando/actualizando la cola, evitar lecturas inconsistentes
        // ✅ PROTECCIÓN: También ignorar durante inserción de anuncios para evitar race conditions
        if (_isUpdatingQueue || _isReplacingQueue || _isHandlingAdInsertion || _isInsertingAd) {
          return;
        }
        
        // 📢 ANUNCIOS: Verificar si el AudioSource actual es un anuncio
        // #region agent log
        AppLogger.debugLog('playback_notifier.dart:192', 'Stream listener check', {
          'currentSourceTag': currentSource?.tag.runtimeType.toString(),
          'isAd': currentSource?.tag is AudioAd,
          'isPlayingAd': state.isPlayingAd,
          'currentAdId': state.currentAd?.id,
          'isInsertingAd': _isInsertingAd,
          'playing': _service?.player.playing ?? false,
          'currentIndex': currentIndex
        }, 'C');
        // #endregion
        AppLogger.info('[PlaybackNotifier] 🔍 Stream listener: índice=$currentIndex, tag=${currentSource?.tag.runtimeType}, isPlayingAd=${state.isPlayingAd}, isInsertingAd=$_isInsertingAd');
        
        // ✅ FIX CRÍTICO: Verificar que realmente estamos en el índice del anuncio ANTES de procesarlo
        // Si currentSource es un anuncio pero el índice actual no coincide, no procesar
        final sequence = sequenceState.sequence;
        final isAtAdIndex = currentIndex != null && 
                            currentIndex >= 0 && 
                            currentIndex < sequence.length &&
                            sequence[currentIndex].tag is AudioAd;
        
        if (currentSource != null && currentSource.tag is AudioAd && isAtAdIndex) {
          final ad = currentSource.tag as AudioAd;
          final isPlaying = _service?.player.playing ?? false;
          
          // ✅ FIX CRÍTICO: Verificar también que el ID del anuncio coincide
          final adIdMatches = (sequence[currentIndex].tag as AudioAd).id == ad.id;
          
          if (!adIdMatches) {
            AppLogger.warning('[PlaybackNotifier] ⚠️ Stream detectó anuncio pero el ID no coincide, omitiendo actualización');
            return;
          }
          
          // ✅ FIX CRÍTICO: Verificar también que el currentSource coincide con el índice actual
          // Esto asegura que realmente estamos reproduciendo el anuncio, no solo que está en la cola
          final sourceMatchesIndex = currentSource == sequenceState.sequence[currentIndex];
          
          AppLogger.info('[PlaybackNotifier] 🔍 Verificación de anuncio: índice=$currentIndex, isAtAdIndex=$isAtAdIndex, sourceMatchesIndex=$sourceMatchesIndex, currentSourceTag=${currentSource.tag.runtimeType}');
          
          // ✅ FIX CRÍTICO: Solo actualizar estado si realmente estamos en el índice del anuncio Y el source coincide
          // Esto previene que se active el estado del anuncio cuando se presiona play durante una canción
          if (!isAtAdIndex || !sourceMatchesIndex) {
            AppLogger.warning('[PlaybackNotifier] ⚠️ Stream detectó anuncio pero no estamos en su índice o el source no coincide (índice actual: $currentIndex, isAtAdIndex: $isAtAdIndex, sourceMatchesIndex: $sourceMatchesIndex), omitiendo actualización');
            return; // No actualizar estado si no estamos realmente en el anuncio
          }
          
          // ✅ OPTIMIZACIÓN: Actualizar estado inmediatamente cuando se detecta el anuncio
          // Esto asegura que la UI responda al instante sin retrasos
          if (!state.isPlayingAd || state.currentAd?.id != ad.id) {
            // #region agent log
            AppLogger.debugLog('playback_notifier.dart:199', 'Ad detected in stream', {'adId': ad.id, 'isPlaying': isPlaying, 'isInsertingAd': _isInsertingAd, 'currentIndex': currentIndex}, 'D');
            // #endregion
            AppLogger.info('[PlaybackNotifier] 📢 Anuncio detectado en stream: ${ad.title} (reproduciendo: $isPlaying, índice: $currentIndex)');
            
            // Registrar timestamp de inicio del anuncio
            _adStartTime = DateTime.now();
            
            // ✅ OPTIMIZACIÓN: Obtener posición y duración inmediatamente
            final initialPosition = _service?.player.position ?? Duration.zero;
            final duration = currentSource.duration ?? ad.duration;
            
            // ✅ OPTIMIZACIÓN: Actualizar estado inmediatamente con todos los datos
            state = state.copyWith(
              isPlayingAd: true,
              currentAd: ad,
              clearCurrentSong: true,
              clearLastConfirmedSong: true,
              totalDuration: duration.inMilliseconds > 0 ? duration : ad.duration,
              currentPosition: initialPosition,
            );
            
            _adStartTime ??= DateTime.now();
            
            // ✅ OPTIMIZACIÓN: Solo reproducir si no está reproduciendo y no estamos insertando
            // Eliminar delays innecesarios - confiar en que _insertAdInQueue ya manejó la reproducción
            if (!isPlaying && _service != null && !_isInsertingAd && !_isHandlingAdInsertion) {
              // ✅ OPTIMIZACIÓN: Verificación rápida sin delay
              Future.microtask(() async {
                if (_service != null && !_service!.player.playing && !_isInsertingAd && !_isHandlingAdInsertion) {
                  final checkState = _service!.player.sequenceState;
                  final checkSource = checkState.currentSource;
                  if (checkSource?.tag is AudioAd && (checkSource!.tag as AudioAd).id == ad.id) {
                    try {
                      await _service!.play();
                      // ✅ OPTIMIZACIÓN: Actualizar posición inmediatamente después de play
                      final afterPlayPosition = _service!.player.position;
                      if (afterPlayPosition.inMilliseconds > 0) {
                        state = state.copyWith(
                          currentPosition: afterPlayPosition,
                        );
                      }
                      AppLogger.info('[PlaybackNotifier] ▶️ Reproducción iniciada para anuncio desde stream listener');
                    } catch (e) {
                      AppLogger.warning('[PlaybackNotifier] Error al iniciar reproducción del anuncio: $e');
                    }
                  }
                }
              });
            }
          }
          
          // ✅ OPTIMIZACIÓN: Actualizar posición en tiempo real sin delays
          // Esto asegura que la barra de progreso se mueva suavemente
          final duration = currentSource.duration ?? ad.duration;
          final currentPosition = _service?.player.position ?? Duration.zero;
          
          // ✅ OPTIMIZACIÓN: Solo actualizar si la posición cambió significativamente
          // Esto reduce rebuilds innecesarios pero mantiene la barra fluida
          final lastPosition = state.currentPosition;
          final positionDiff = (currentPosition.inMilliseconds - lastPosition.inMilliseconds).abs();
          
          // Actualizar si la diferencia es mayor a 100ms o si es la primera actualización
          if (positionDiff > 100 || lastPosition.inMilliseconds == 0) {
            state = state.copyWith(
              isPlayingAd: true,
              currentAd: ad,
              totalDuration: duration.inMilliseconds > 0 ? duration : ad.duration,
              currentPosition: currentPosition,
            );
          }
          
          // No procesar más lógica de canciones cuando es un anuncio
          return;
        }
        
        // Si estábamos reproduciendo un anuncio pero ahora no, manejar finalización
        // ✅ PROTECCIÓN: No procesar si estamos insertando un anuncio o ya estamos completando uno
        // #region agent log
        AppLogger.debugLog('playback_notifier.dart:258', 'Ad completion check', {
          'isPlayingAd': state.isPlayingAd,
          'currentSourceTag': currentSource?.tag.runtimeType.toString(),
          'isAd': currentSource?.tag is AudioAd,
          'isInsertingAd': _isInsertingAd,
          'isCompletingAd': _isCompletingAd,
          'willHandleCompletion': state.isPlayingAd && currentSource != null && currentSource.tag is! AudioAd && !_isInsertingAd && !_isCompletingAd
        }, 'F');
        // #endregion
        if (state.isPlayingAd && 
            currentSource != null && 
            currentSource.tag is! AudioAd &&
            !_isInsertingAd &&
            !_isCompletingAd) { // ✅ FIX CRÍTICO: Proteger contra procesamiento duplicado
          final completedAd = state.currentAd;
          if (completedAd != null) {
            // #region agent log
            AppLogger.debugLog('playback_notifier.dart:264', 'Ad completion detected', {'completedAdId': completedAd.id}, 'F');
            // #endregion
            AppLogger.info('[PlaybackNotifier] 📢 Anuncio terminado, continuando con música');
            // El anuncio terminó naturalmente (no fue saltado)
            
            // ✅ FIX CRÍTICO: Marcar que estamos completando el anuncio para evitar procesamiento duplicado
            _isCompletingAd = true;
            
            // ✅ FIX CRÍTICO: Limpiar estado del anuncio INMEDIATAMENTE antes de cualquier otra lógica
            // Esto evita que otros listeners procesen el evento como si fuera una canción
            // Usar clearCurrentAd: true para forzar el reset a null
            AppLogger.info('[PlaybackNotifier] 🛑 RESETEO INMEDIATO: isPlayingAd=false, currentAd=null');
            
            // 🛑 FORCE CLEAR: Obtener duración de la nueva canción INMEDIATAMENTE del reproductor
            // Esto evita que la barra de progreso muestre la duración del anuncio por unos segundos
            // currentSource no puede ser null aquí porque ya verificamos que currentSource != null arriba
            final newSongDuration = currentSource.duration ?? Duration.zero;
            final newSongPosition = _service!.player.position;
            
            // Si currentSource es una canción, obtener su duración
            Song? newSong;
            Duration? songDuration;
            if (currentSource.tag is Song) {
              newSong = currentSource.tag as Song;
              songDuration = newSong.duration != null 
                ? Duration(seconds: newSong.duration!) 
                : (newSongDuration.inMilliseconds > 0 ? newSongDuration : Duration.zero);
            }
            
            // ✅ FIX CRÍTICO: Limpiar el estado múltiples veces para asegurar que se propague
            // 🛑 FORCE CLEAR: Resetear posición y duración INMEDIATAMENTE
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true, // ✅ FIX CRÍTICO: Forzar reset a null
              currentPosition: newSongPosition, // 🛑 FORCE CLEAR: Resetear posición inmediatamente
              totalDuration: songDuration ?? newSongDuration, // 🛑 FORCE CLEAR: Usar duración de la nueva canción
              currentSong: newSong ?? state.currentSong, // Actualizar canción si está disponible
            );
            
            // ✅ FIX CRÍTICO: Forzar una segunda actualización para asegurar que Riverpod propague el cambio
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true,
              currentPosition: newSongPosition, // 🛑 FORCE CLEAR: Mantener posición reseteada
              totalDuration: songDuration ?? newSongDuration, // 🛑 FORCE CLEAR: Mantener duración correcta
            );
            
            AppLogger.info('[PlaybackNotifier] 🛑 [FORCE CLEAR] Estado reseteado: posición=${newSongPosition.inSeconds}s, duración=${(songDuration ?? newSongDuration).inSeconds}s');
            
            AppLogger.info('[PlaybackNotifier] ✅ Estado después del reset: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
            
            // ✅ FIX CRÍTICO: Verificar una vez más que el estado se limpió correctamente
            if (state.isPlayingAd || state.currentAd != null) {
              AppLogger.error('[PlaybackNotifier] ❌ ERROR: El estado del anuncio NO se limpió correctamente después del reset');
              AppLogger.error('[PlaybackNotifier] ❌ Estado actual: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
              // Intentar limpiar de nuevo
              state = state.copyWith(
                isPlayingAd: false,
                clearCurrentAd: true,
              );
            }
            
            // ✅ FIX CRÍTICO: Manejar finalización del anuncio y sincronizar INMEDIATAMENTE
            // Esto asegura que la UI muestre la canción correcta sin delay
            _handleAdCompletion(completedAd, false).then((_) async {
              // ✅ FIX CRÍTICO: Sincronizar inmediatamente la canción actual después de limpiar el anuncio
              // Esto asegura que la UI muestre la carátula correcta de la canción siguiente
              if (_service != null) {
                // Obtener el estado actualizado del reproductor inmediatamente
                final updatedSequenceState = _service!.player.sequenceState;
                final updatedSource = updatedSequenceState.currentSource;
                
                // Si el reproductor ya avanzó a una canción, actualizar estado INMEDIATAMENTE con duración correcta
                if (updatedSource != null && updatedSource.tag is Song) {
                  final nextSong = updatedSource.tag as Song;
                  AppLogger.info('[PlaybackNotifier] 📢 Reproductor ya avanzó a canción: ${nextSong.title}, actualizando estado INMEDIATAMENTE');
                  AppLogger.info('[PlaybackNotifier] 🔍 Estado antes de actualizar: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}, currentSong=${state.currentSong?.id ?? "null"}');
                  
                  // ✅ FIX CRÍTICO: Obtener duración de la canción INMEDIATAMENTE antes de actualizar estado
                  final currentPos = _service!.player.position;
                  final songDuration = updatedSource.duration ?? 
                                       (nextSong.duration != null ? Duration(seconds: nextSong.duration!) : null) ??
                                       Duration.zero;
                  
                  AppLogger.info('[PlaybackNotifier] 🎵 Duración de canción obtenida INMEDIATAMENTE: ${songDuration.inSeconds}s (source: ${updatedSource.duration?.inSeconds ?? "null"}, model: ${nextSong.duration ?? "null"})');
                  
                  // ✅ FIX CRÍTICO: Actualizar estado INMEDIATAMENTE con duración de la canción, no del anuncio
                  // Esto asegura que la barra de progreso muestre la duración correcta desde el inicio
                  state = state.copyWith(
                    isPlayingAd: false,
                    clearCurrentAd: true,
                    currentSong: nextSong,
                    lastConfirmedSong: nextSong,
                    // ✅ CRÍTICO: Usar songDuration, nunca state.totalDuration que podría ser del anuncio
                    totalDuration: songDuration,
                    currentPosition: currentPos.inMilliseconds > 0 ? currentPos : Duration.zero,
                  );
                  
                  AppLogger.info('[PlaybackNotifier] ✅ Estado actualizado INMEDIATAMENTE: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}, totalDuration=${state.totalDuration.inSeconds}s');
                  
                  // ✅ FIX CRÍTICO: Limpiar timestamp ANTES de sincronizar para permitir actualizaciones inmediatas
                  _lastAdCompletionTime = null;
                  
                  // ✅ FIX CRÍTICO: Sincronizar después de actualizar estado para confirmar valores
                  _syncQueueWithAudioService(updatedSequenceState, forceSync: true);
                  
                  // ✅ FIX CRÍTICO: Verificar que el estado se limpió correctamente
                  AppLogger.info('[PlaybackNotifier] 🔍 Estado después de sincronizar: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}, currentSong=${state.currentSong?.id ?? "null"}');
                  
                  // ✅ FIX CRÍTICO: Si el estado aún tiene anuncio después de sincronizar, limpiarlo de nuevo
                  if (state.isPlayingAd || state.currentAd != null) {
                    AppLogger.error('[PlaybackNotifier] ❌ ERROR CRÍTICO: Estado aún tiene anuncio después de sincronizar, limpiando de nuevo');
                    state = state.copyWith(
                      isPlayingAd: false,
                      clearCurrentAd: true,
                    );
                    // Forzar otra sincronización después de limpiar
                    _syncQueueWithAudioService(_service!.player.sequenceState, forceSync: true);
                  }
                  
                  // Limpiar timestamp de finalización para permitir actualizaciones normales
                  _lastAdCompletionTime = null;
                  
                  // Asegurar que la reproducción continúe
                  if (!_service!.player.playing) {
                    await _service!.play();
                    AppLogger.info('[PlaybackNotifier] ▶️ Reproducción reanudada después del anuncio');
                  }
                } else if (_service!.player.hasNext) {
                  // Si no avanzó automáticamente, avanzar manualmente
                  AppLogger.info('[PlaybackNotifier] 📢 Avanzando manualmente a siguiente canción después del anuncio');
                  try {
                    await _service!.next();
                    // ✅ FIX CRÍTICO: Sincronizar inmediatamente después del avance sin delays largos
                    if (_service != null) {
                      _syncQueueWithAudioService(_service!.player.sequenceState, forceSync: true);
                      // Limpiar timestamp de finalización para permitir actualizaciones normales
                      _lastAdCompletionTime = null;
                      // Asegurar que la reproducción continúe
                      if (!_service!.player.playing) {
                        await _service!.play();
                      }
                    }
                  } catch (e) {
                    AppLogger.warning('[PlaybackNotifier] Error al avanzar después del anuncio: $e');
                  }
                } else {
                  // No hay siguiente canción, solo sincronizar el estado actual
                  AppLogger.info('[PlaybackNotifier] 📢 No hay siguiente canción, sincronizando estado actual');
                  _syncQueueWithAudioService(updatedSequenceState, forceSync: true);
                  // Limpiar timestamp de finalización
                  _lastAdCompletionTime = null;
                }
              }
            }).catchError((e) {
              AppLogger.error('[PlaybackNotifier] Error al manejar finalización de anuncio: $e');
              // Asegurar que el flag se resetee incluso si hay error
              _isCompletingAd = false;
            }).whenComplete(() {
              // ✅ FIX CRÍTICO: Resetear flag después de completar el manejo del anuncio
              _isCompletingAd = false;
            });
            
            // ✅ FIX CRÍTICO: Hacer return aquí para evitar procesar la lógica de canción mientras se maneja el anuncio
            // Esto evita que se procese dos veces y que el estado se desincronice
            return;
          }
        }
        
        // 🛑 FIX CRÍTICO: Verificar y corregir inconsistencia de estado ANTES de procesar la canción
        // Si hay una canción reproduciéndose pero isPlayingAd es true, corregirlo inmediatamente
        // ✅ FIX CRÍTICO: Esta verificación debe ser LO PRIMERO para evitar que el anuncio se muestre por encima
        // #region agent log
        AppLogger.debugLog('playback_notifier.dart:384', 'State inconsistency check', {
          'currentSourceTag': currentSource?.tag.runtimeType.toString(),
          'isSong': currentSource?.tag is Song,
          'isPlayingAd': state.isPlayingAd,
          'currentAdId': state.currentAd?.id,
          'willClearAd': currentSource != null && currentSource.tag is Song && (state.isPlayingAd || state.currentAd != null)
        }, 'F');
        // #endregion
        if (currentSource != null && currentSource.tag is Song && (state.isPlayingAd || state.currentAd != null)) {
          final nextSong = currentSource.tag as Song;
          AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN INMEDIATA: Hay canción reproduciéndose (${nextSong.title}) pero estado tiene anuncio activo');
          AppLogger.warning('[PlaybackNotifier] 🛑 Limpiando estado de anuncio: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
          
          // ✅ FIX CRÍTICO: Obtener duración de la canción INMEDIATAMENTE
          final currentPos = _service?.player.position ?? Duration.zero;
          final songDuration = currentSource.duration ?? 
                               (nextSong.duration != null ? Duration(seconds: nextSong.duration!) : null) ??
                               Duration.zero;
          
          // ✅ FIX CRÍTICO: Limpiar INMEDIATAMENTE el estado del anuncio Y actualizar con la canción correcta
          // Esto previene que el widget muestre el anuncio por encima de la canción
          // Y asegura que la barra de carga muestre la duración correcta desde el inicio
          state = state.copyWith(
            isPlayingAd: false,
            clearCurrentAd: true, // ✅ FIX CRÍTICO: Forzar reset a null
            currentSong: nextSong,
            lastConfirmedSong: nextSong,
            // ✅ FIX CRÍTICO: Actualizar totalDuration y currentPosition INMEDIATAMENTE con valores de la canción
            totalDuration: songDuration,
            currentPosition: currentPos.inMilliseconds > 0 ? currentPos : Duration.zero,
          );
          // Limpiar timestamp de finalización para permitir actualizaciones normales
          _lastAdCompletionTime = null;
          // #region agent log
          AppLogger.debugLog('playback_notifier.dart:397', 'AFTER clear ad state', {'isPlayingAd': state.isPlayingAd, 'currentAdId': state.currentAd?.id, 'totalDuration': state.totalDuration.inSeconds}, 'F');
          // #endregion
          AppLogger.info('[PlaybackNotifier] ✅ Estado corregido: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}, totalDuration=${state.totalDuration.inSeconds}s');
        }
        
        // ✅ FIX CRÍTICO ADICIONAL: Verificar también si NO hay anuncio reproduciéndose pero el estado dice que sí
        // Esto corrige casos donde el estado se desincronizó
        if (currentSource != null && currentSource.tag is! AudioAd && (state.isPlayingAd || state.currentAd != null)) {
          AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN ADICIONAL: No hay anuncio reproduciéndose pero estado dice que sí');
          state = state.copyWith(
            isPlayingAd: false,
            clearCurrentAd: true, // ✅ FIX CRÍTICO: Forzar reset a null
          );
          // Limpiar timestamp de finalización para permitir actualizaciones normales
          _lastAdCompletionTime = null;
          AppLogger.info('[PlaybackNotifier] ✅ Estado corregido adicionalmente: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
        }
        
        // ✅ FIX CRÍTICO: Obtener la canción directamente del tag del reproductor, no de la cola por índice
        // El tag es la fuente de verdad del reproductor y siempre tiene la canción correcta
        Song? currentSong;
        if (currentSource != null && currentSource.tag is Song) {
          currentSong = currentSource.tag as Song;
          AppLogger.info('[PlaybackNotifier] 🎵 Canción obtenida del tag del reproductor: ${currentSong.title} (índice: $currentIndex)');
        } else if (currentIndex != null && currentIndex >= 0 && currentIndex < state.currentQueue.length) {
          // Fallback: usar la cola si el tag no está disponible
          currentSong = state.currentQueue[currentIndex];
          AppLogger.warning('[PlaybackNotifier] ⚠️ Usando fallback: canción obtenida de la cola por índice: ${currentSong.title}');
        } else {
          // No hay canción disponible
          AppLogger.warning('[PlaybackNotifier] ⚠️ No se pudo obtener canción: índice=$currentIndex, colaLength=${state.currentQueue.length}');
          return;
        }
        
        // ✅ PROTECCIÓN OPTIMIZADA: Solo bloquear actualizaciones si es la misma canción Y acabamos de terminar un anuncio
        // PERO SIEMPRE permitir actualización si hay una nueva canción (el reproductor ya avanzó)
        // Esto asegura que la barra de carga se actualice inmediatamente después de cada anuncio
        if (_lastAdCompletionTime != null) {
          final isNewSong = currentSource != null && currentSource.tag is Song && 
                           (state.currentSong == null || state.currentSong?.id != currentSong.id);
          
          // ✅ FIX CRÍTICO: Si es una nueva canción después del anuncio, SIEMPRE permitir actualización inmediatamente
          // Esto asegura que la barra de carga se actualice inmediatamente después de cada anuncio
          if (isNewSong) {
            AppLogger.info('[PlaybackNotifier] 📢 Nueva canción detectada después del anuncio, limpiando protección y actualizando inmediatamente');
            _lastAdCompletionTime = null; // Limpiar timestamp inmediatamente para permitir actualizaciones normales
            // Continuar con la actualización normal - NO retornar aquí
          } else {
            // Solo bloquear si es la misma canción y acabamos de terminar un anuncio (muy reciente)
            final timeSinceAdCompletion = DateTime.now().difference(_lastAdCompletionTime!);
            final isSameSong = state.currentSong?.id == currentSong.id;
            
            if (isSameSong && timeSinceAdCompletion < const Duration(milliseconds: 300)) {
              // ✅ OPTIMIZACIÓN: Reducir tiempo de protección a 300ms solo para evitar cambios de carátula
              // Pero permitir actualizaciones de posición para que la barra de carga funcione
              AppLogger.debug('[PlaybackNotifier] ⏳ Listener: Protección activa después del anuncio (${timeSinceAdCompletion.inMilliseconds}ms), solo bloqueando cambios de canción');
              // NO retornar aquí - permitir actualizaciones de posición y duración
            } else {
              // Si pasó suficiente tiempo o no es la misma canción, limpiar el timestamp
              _lastAdCompletionTime = null;
            }
          }
        }
        
        // ✅ FIX CRÍTICO: Asegurar que currentIndex no sea null antes de continuar
        // currentSong ya está garantizado como no-null por el return en línea 591
        if (currentIndex == null) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ currentIndex es null, no se puede continuar');
          return;
        }
        
        // ✅ FIX: currentIndex ya está verificado como no-null arriba
        final nonNullCurrentIndex = currentIndex;
        
        // 🎯 DETECCIÓN MANUAL: Verificar si hubo un salto manual (no secuencial)
        // Solo detectar si ya había un índice previo (evitar detección en inicialización)
        // 🚨 PROTECCIÓN: Debounce para evitar múltiples verificaciones en rápida sucesión
        // 🚨 PROTECCIÓN: Ignorar detección si se está reproduciendo desde una tarjeta o si hay actualización en curso
        // ✅ FIX CRÍTICO: Ignorar detección si se está procesando play/pause (no es un salto manual)
        if (_lastKnownIndex != null && 
            state.playbackMode == PlaybackMode.algorithm && 
            !_isPlayingFromCard && 
            !_isUpdatingQueue &&
            !_isRestartingAlgorithm &&
            !_isReplacingQueue &&
            !_isProcessingPlayPause) {
          final now = DateTime.now();
          final shouldCheckSkip = _lastManualSkipCheck == null || 
              now.difference(_lastManualSkipCheck!) >= _manualSkipDebounce;
          
          if (shouldCheckSkip) {
            final wasManualSkip = nonNullCurrentIndex != _lastKnownIndex && 
                nonNullCurrentIndex != _lastKnownIndex! + 1 && 
                nonNullCurrentIndex != _lastKnownIndex! - 1;
            
            if (wasManualSkip) {
              _lastManualSkipCheck = now; // Registrar timestamp del check
              
              // 📢 ANUNCIOS: Verificar anuncios también cuando se pasa manualmente
              // ✅ PROTECCIÓN: Solo verificar si no hay anuncio reproduciéndose o en proceso de inserción
              // ✅ PROTECCIÓN CRÍTICA: NO insertar anuncios inmediatamente después de un salto manual
              // Los anuncios se insertarán cuando la canción llegue al 50% (con protección de 5 segundos)
              // Esto evita crear anuncios huérfanos cuando el usuario salta múltiples canciones rápidamente
              // NOTA: Comentado para evitar anuncios huérfanos - los anuncios se insertarán en el trigger del 50%
              /*
              if (!state.isPlayingAd && 
                  state.currentAd == null && 
                  !_isInsertingAd && 
                  !_isHandlingAdInsertion &&
                  currentSource?.tag is Song) {
                AppLogger.info('[PlaybackNotifier] 🎵 [SALTO MANUAL] Verificando anuncios después de salto manual...');
                _checkAndInsertAd().catchError((e) {
                  AppLogger.error('[PlaybackNotifier] 📢 [SALTO MANUAL] Error al verificar anuncios: $e');
                });
              }
              */
              AppLogger.info('[PlaybackNotifier] 🎵 [SALTO MANUAL] Omitiendo inserción inmediata de anuncios - se insertarán cuando la canción llegue al 50%');
              
              // 🎯 FASE 1: Registrar canciones saltadas (si saltó hacia adelante)
              if (nonNullCurrentIndex > _lastKnownIndex! + 1) {
                try {
                  final skippedSongs = state.currentQueue
                      .sublist(_lastKnownIndex! + 1, nonNullCurrentIndex)
                      .map((s) => s.id)
                      .toList();
                  
                  if (skippedSongs.isNotEmpty) {
                    AppLogger.info('[PlaybackNotifier] ⏭️ Salto manual detectado: saltadas ${skippedSongs.length} canciones (índice $_lastKnownIndex → $nonNullCurrentIndex)');
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
                final skipDistance = (nonNullCurrentIndex - _lastKnownIndex!).abs();
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
                  final songToUse = currentSong; // Capturar para usar en el closure
                  Future.delayed(const Duration(milliseconds: 200), () async {
                    try {
                      if (state.playbackMode == PlaybackMode.algorithm && 
                          state.currentSong?.id == songToUse.id) {
                        AppLogger.info('[PlaybackNotifier] 🚀 Reiniciando algoritmo con nueva semilla: ${songToUse.title}');
                        await playAlgorithmStart(songToUse, excludeSeedFromQueue: false);
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
                  final remainingSongs = state.currentQueue.length - nonNullCurrentIndex - 1;
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
                final remainingSongs = state.currentQueue.length - nonNullCurrentIndex - 1;
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
        // ✅ FIX CRÍTICO: NO actualizar _lastKnownIndex si se está procesando play/pause
        // Esto previene que se detecte un cambio de canción cuando solo se presiona play/pause
        final previousIndex = _lastKnownIndex;
        if (!_isProcessingPlayPause) {
          _lastKnownIndex = nonNullCurrentIndex;
        }
        
        // ✅ FIX CRÍTICO: Verificar anuncios cuando cambia la canción normalmente
        // Solo si no se está procesando completion (para evitar duplicados)
        // Esto asegura que los anuncios se inserten incluso si _handleSongCompletion no se llama
        // ✅ FIX CRÍTICO: NO detectar cambio de canción si se está procesando play/pause
        // Esto previene que se cambie de canción cuando solo se presiona play/pause en el reproductor extendido
        if (previousIndex != null && 
            nonNullCurrentIndex == previousIndex + 1 && // Solo avance normal
            !_isProcessingPlayPause && // ✅ FIX CRÍTICO: Ignorar si se está procesando play/pause
            !state.isPlayingAd &&
            !_isHandlingAdInsertion && // ✅ PROTECCIÓN: No verificar si ya se está procesando inserción
            !_isInsertingAd && // ✅ PROTECCIÓN: No verificar si ya se está insertando
            state.currentAd == null && // ✅ PROTECCIÓN: No verificar si ya hay anuncio en estado
            currentSource?.tag is Song) {
          // La canción avanzó normalmente - verificar anuncios en background
          AppLogger.info('[PlaybackNotifier] 🎵 [CAMBIO CANCIÓN] Canción avanzó normalmente: índice $previousIndex → $nonNullCurrentIndex');
          AppLogger.info('[PlaybackNotifier] 🎵 [CAMBIO CANCIÓN] Verificando anuncios después de cambio de canción...');
          // ✅ FIX CRÍTICO: Diferir la verificación usando Future.microtask para evitar conflictos con el stream
          // Esto previene el error "Cannot fire new event. Controller is already firing an event"
          Future.microtask(() async {
            try {
              await _checkAndInsertAd();
            } catch (e) {
              AppLogger.error('[PlaybackNotifier] 📢 [CAMBIO CANCIÓN] Error al verificar anuncios: $e');
            }
          });
        }
        
        // Actualizar duración si está disponible
        final duration = currentSong.duration != null
            ? Duration(seconds: currentSong.duration!)
            : sequenceState.currentSource?.duration;
        
        // ✅ FIX CRÍTICO: SIEMPRE actualizar currentSong y lastConfirmedSong cuando cambia la canción
        // Esto asegura que la UI muestre la información correcta
        // Solo usar protección de tiempo si es la MISMA canción después de un anuncio
        final isSameSong = state.currentSong?.id == currentSong.id;
        final shouldUpdate = !isSameSong || 
                            (_lastAdCompletionTime == null || 
                             DateTime.now().difference(_lastAdCompletionTime!) >= const Duration(seconds: 1));
        
        if (shouldUpdate) {
          // ✅ FIX CRÍTICO: SIEMPRE actualizar currentSong y lastConfirmedSong cuando cambia
          state = state.copyWith(
            currentSong: currentSong,
            lastConfirmedSong: currentSong, // ✅ FIX CRÍTICO: Actualizar también lastConfirmedSong
            totalDuration: duration ?? Duration.zero,
          );
          AppLogger.info('[PlaybackNotifier] ✅ Canción actualizada en stream listener: ${currentSong.title}');
        } else {
          // Solo actualizar la duración si no cambió la canción (para evitar cambios de tiempos)
          if (duration != null && duration != state.totalDuration) {
            state = state.copyWith(totalDuration: duration);
          }
        }
        
        // 🎯 FASE 1: Registrar canción reproducida en servicio centralizado
        ref.read(playbackSessionProvider.notifier).registerPlayedSong(currentSong.id);
        
        // ⚡ OPTIMIZACIÓN: Solo loggear cuando realmente cambia la canción (no en cada update)
        if (state.currentSong?.id != currentSong.id) {
          AppLogger.info('[PlaybackNotifier] Canción actual: ${currentSong.title}');
        }
        
        // 🎯 PRE-FETCH: Si estamos en la última canción de una cola fija y está activo shouldStartAlgorithmAfterQueue,
        // preparar en background las recomendaciones para que al terminar no haya espera.
        if (state.playbackMode == PlaybackMode.fixedQueue &&
            state.shouldStartAlgorithmAfterQueue &&
            state.currentQueue.isNotEmpty &&
            nonNullCurrentIndex == state.currentQueue.length - 1) {
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
        // ✅ FIX CRÍTICO: Actualizar posición siempre, incluso durante anuncios
        // Esto asegura que la barra de progreso del anuncio se actualice correctamente
        state = state.copyWith(currentPosition: position);
        
        // 🚀 SPOTIFY-LEVEL: Monitorear posición para pre-cargar audio de siguiente canción
        // Solo si no estamos reproduciendo un anuncio
        if (!state.isPlayingAd) {
          _checkAndPreloadNextAudio(position);
          // ⚡ TRANSICIÓN INSTANTÁNEA: Detectar final de canción ANTES de que termine
          _checkAndPrepareNextSongTransition(position);
        }
      }),
    );

    // 4. Suscribirse al estado del reproductor (buffering, etc.)
    _subscriptions.add(
      service.playerStateStream.listen((playerState) {
        final isBuffering = playerState.processingState == ProcessingState.buffering ||
                           playerState.processingState == ProcessingState.loading;
        final isCompleted = playerState.processingState == ProcessingState.completed;
        
        // ✅ FIX CRÍTICO: No procesar completed si estamos reproduciendo un anuncio
        // El anuncio se maneja en el listener de sequenceStateStream
        if (isCompleted && state.isPlayingAd) {
          AppLogger.debug('[PlaybackNotifier] ⏭️ Ignorando completed durante anuncio (se maneja en sequenceStateStream)');
          return;
        }
        
        // 🚨 CRÍTICO: Actualizar estado inmediatamente cuando la canción termina
        // Esto evita que la UI se quede congelada
        state = state.copyWith(
          isBuffering: isBuffering,
          isPlaying: !isCompleted && playerState.playing, // Actualizar isPlaying cuando termina
        );
        
        // ⚡ TRANSICIÓN INSTANTÁNEA: Detectar final de canción ANTES de que termine
        // Usar completed como fallback, pero la transición ya debería estar preparada
        if (isCompleted && !state.isPlayingAd) {
          // 🛡️ FUENTE ÚNICA DE VERDAD: El stream actualizará isPlaying automáticamente
          // NO actualizar isPlaying manualmente - el stream es la única fuente de verdad
          
          // Usar unawaited para evitar esperar en el listener del stream
          _handleSongCompletion();
        }
      }),
    );

    // 🚨 5. SINCRONIZACIÓN: Suscribirse a cambios en la cola de just_audio
    // Esto asegura que el estado siempre refleje la realidad del reproductor
    // ⚡ OPTIMIZACIÓN: Usar debounce para evitar ejecuciones excesivas (máx 2 veces por segundo)
    // ✅ PROTECCIÓN: Ignorar sincronización durante inserción de anuncios o cuando hay anuncio reproduciéndose
    _subscriptions.add(
      service.sequenceStateStream
          .debounceTime(const Duration(milliseconds: 500))
          .listen((sequenceState) {
        if (sequenceState == null) return;
        
        final currentSource = sequenceState.currentSource;
        final isActuallyPlayingAd = currentSource != null && currentSource.tag is AudioAd;
        
        // ✅ FIX CRÍTICO: Verificar PRIMERO si hay inconsistencia de estado ANTES de verificar flags
        // Si el reproductor NO está reproduciendo un anuncio pero el estado dice que sí,
        // SIEMPRE limpiar el estado, incluso si los flags están activos
        // Esto asegura que cuando el anuncio termina y el reproductor avanza a una canción,
        // el estado se limpie inmediatamente
        // ✅ PROTECCIÓN CRÍTICA: NO limpiar si estamos en proceso de pausa preventiva
        if (!isActuallyPlayingAd && (state.isPlayingAd || state.currentAd != null) && !_preventiveAdTriggered) {
          // ✅ FIX CRÍTICO: Si hay una canción reproduciéndose, limpiar el estado del anuncio SIEMPRE
          // Esto previene que el visual del anuncio se quede mostrándose después de que termina
          if (currentSource != null && currentSource.tag is Song) {
            AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN DEFENSIVA CRÍTICA: Reproductor tiene canción pero estado dice anuncio, limpiando INMEDIATAMENTE...');
            AppLogger.warning('[PlaybackNotifier] 🔍 Flags: _isHandlingAdInsertion=$_isHandlingAdInsertion, _isInsertingAd=$_isInsertingAd, _isCompletingAd=$_isCompletingAd');
            
            // Limpiar flags si están activos (el anuncio ya terminó)
            if (_isHandlingAdInsertion || _isInsertingAd || _isCompletingAd) {
              AppLogger.warning('[PlaybackNotifier] 🧹 Limpiando flags de inserción porque el anuncio ya terminó');
              _isHandlingAdInsertion = false;
              _isInsertingAd = false;
              _isCompletingAd = false;
            }
            
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true, // ✅ FIX CRÍTICO: Forzar reset a null
            );
            AppLogger.info('[PlaybackNotifier] ✅ Estado después de corrección defensiva: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
            
            // ✅ FIX CRÍTICO: Sincronizar inmediatamente la canción
            AppLogger.info('[PlaybackNotifier] 🔄 Sincronizando canción después de corrección defensiva');
            _syncQueueWithAudioService(sequenceState, forceSync: true);
            return; // No continuar con la sincronización normal si corregimos el estado
          }
        }
        
        // ✅ PROTECCIÓN CRÍTICA: NO ejecutar corrección defensiva durante inserción de anuncios
        // Esto previene que se limpie el estado del anuncio mientras se está insertando
        // PERO solo si realmente hay un anuncio reproduciéndose
        if ((_isHandlingAdInsertion || _isInsertingAd || _isCompletingAd) && isActuallyPlayingAd) {
          AppLogger.debug('[PlaybackNotifier] ⏭️ Omitiendo corrección defensiva: operación de anuncio en curso y hay anuncio reproduciéndose');
          return;
        }
        
        // ✅ PROTECCIÓN: No sincronizar durante inserción de anuncios o cuando hay anuncio reproduciéndose
        if (state.isPlayingAd && isActuallyPlayingAd) {
          return;
        }
        
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
      
      // ⚡ OPTIMIZACIÓN: Solo limpiar si realmente veníamos de modo algoritmo
      // Si no veníamos de algoritmo, iniciar reproducción inmediatamente sin delays
      if (wasAlgorithmMode || hadPendingAlgorithmTransition) {
        AppLogger.info('[PlaybackNotifier] 🔄 Cambiando de modo algoritmo a playlist, limpiando estado...');
        if (hadPendingAlgorithmTransition) {
          AppLogger.info('[PlaybackNotifier] ⚠️ Transición a algoritmo detectada, cancelando...');
        }
        // ⚡ OPTIMIZACIÓN: Reducir delays - detener player y continuar más rápido
        try {
          await service.player.pause();
          await service.player.stop();
          // Reducir delay de limpieza para inicio más rápido
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          AppLogger.debug('[PlaybackNotifier] Error al limpiar player (puede ser normal): $e');
        }
      }
      // ⚡ Si NO veníamos de algoritmo, no hay delays - inicio instantáneo

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
        // Esperar un momento para que just_audio actualice su estado
        Future.delayed(const Duration(milliseconds: 200), () {
          _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
        });
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
        
        // ⚡ OPTIMIZACIÓN: Sincronizar inmediatamente sin delays adicionales
        _syncQueueWithAudioService(service.player.sequenceState);
        
        // Asegurar currentSong y posición inicial tras iniciar reproducción
        if (state.currentSong == null && startIndex >= 0 && startIndex < validPlaylist.length) {
          state = state.copyWith(currentSong: validPlaylist[startIndex]);
        }
        state = state.copyWith(currentPosition: Duration.zero);
        
        // ⚡ OPTIMIZACIÓN: Sincronización adicional en background (no bloquea inicio)
        Future.microtask(() {
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
      bool usedInjectionForSeed = false; // Variable para rastrear si se usó inyección instantánea

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
          // ⚡ OPTIMIZACIÓN: Si hay cola activa, usar inyección instantánea para evitar Release/Init
          if (service.hasActiveQueue && songsToLoad.isNotEmpty) {
            final firstSong = songsToLoad.first;
            final firstSource = firstSong.toAudioSource();
            
            // Guardar estado de reproducción antes de insertar
            final wasPlaying = service.player.playing;
            
            // Insertar la primera canción al inicio
            final success = await service.insertSongAtStart(firstSource);
            
            if (success) {
              usedInjectionForSeed = true;
              // Insertar el resto de canciones después de la primera
              if (songsToLoad.length > 1) {
                final restSources = songsToLoad.sublist(1).map((s) => s.toAudioSource()).toList();
                await service.appendToQueue(restSources);
              }
              
              _lastKnownIndex = 0;
              
              // 🔄 SINCRONIZACIÓN INMEDIATA: Actualizar estado ANTES de cualquier otra operación
              // Esperar un momento mínimo para que just_audio actualice su sequenceState
              await Future.delayed(const Duration(milliseconds: 50));
              
              // 🔄 CRÍTICO: Sincronizar PRIMERO para actualizar el estado con la nueva cola
              // Esto evita que la deduplicación detecte una desincronización falsa
              _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
              
              // 🔄 ACTUALIZACIÓN EXPLÍCITA: Asegurar que el estado refleje la cola correcta
              final firstSongFromSync = songsToLoad.isNotEmpty ? songsToLoad.first : seedSong;
              final syncedState = state;
              state = syncedState.copyWith(
                currentSong: firstSongFromSync,
                lastConfirmedSong: firstSongFromSync,
                currentPosition: Duration.zero,
                isBuffering: true,
                isPlaying: wasPlaying, // Mantener estado de reproducción
                // currentQueue ya fue actualizado por _syncQueueWithAudioService
              );
              
              AppLogger.debug('[PlaybackNotifier] 🔄 Estado sincronizado después de inyección: ${state.currentQueue.length} canciones');
              
              // 🔄 CRÍTICO: Reproducir inmediatamente después de insertar si estaba reproduciendo
              // Esto previene que el reproductor quede pausado y el frontend quede "muerto"
              if (wasPlaying) {
                await service.play();
                AppLogger.info('[PlaybackNotifier] ▶️ Reproducción reanudada después de inyección instantánea');
              }
              
              // 🛡️ PROTECCIÓN: Marcar tiempo de inyección para evitar deduplicación inmediata
              _lastInjectionTime = DateTime.now();
              
              AppLogger.info('[PlaybackNotifier] ⚡ Inyección instantánea exitosa para algoritmo (${songsToLoad.length} canciones)');
            } else {
              // Fallback a método estándar si la inyección falla
              AppLogger.info('[PlaybackNotifier] Inyección instantánea falló, usando loadNewQueue estándar');
              final sources = songsToLoad.map((s) => s.toAudioSource()).toList();
              await service.loadNewQueue(sources, 0);
              _lastKnownIndex = 0;
            }
          } else {
            // No hay cola activa, usar método estándar
            final sources = songsToLoad.map((s) => s.toAudioSource()).toList();
            await service.loadNewQueue(sources, 0);
            _lastKnownIndex = 0;
          }
          
          // ⚠️ Solo resetear el estado manualmente si NO se usó inyección instantánea
          // Si se usó inyección, la sincronización ya actualizó la cola completa
          if (!usedInjectionForSeed) {
            // Evitar mostrar portada incorrecta: limpiar canción actual hasta que el stream reporte la nueva
            // Forzar coherencia inmediata con la primera canción de la nueva cola
            final firstSong = songsToLoad.isNotEmpty ? songsToLoad.first : seedSong;
            final firstSource = firstSong.toAudioSource();
            final firstTag = (firstSource as dynamic).tag;
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
          }
        } finally {
          _isReplacingQueue = false;
          _isUpdatingQueue = false;
          state = state.copyWith(isReplacingQueue: false);
          
          // 🔄 SINCRONIZACIÓN FORZADA: Esperar un momento para que just_audio actualice su estado
          // y luego forzar una sincronización para asegurar coherencia
          // Reducido a 100ms para respuesta más rápida
          Future.delayed(const Duration(milliseconds: 100), () {
            _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
          });
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
          // ⚡ OPTIMIZACIÓN: Si hay cola activa, usar inyección instantánea para evitar Release/Init
          final seedSource = seedSong.toAudioSource();
          
          if (service.hasActiveQueue) {
            // Guardar estado de reproducción antes de insertar
            final wasPlaying = service.player.playing;
            
            final success = await service.insertSongAtStart(seedSource);
            
            if (success) {
              usedInjectionForSeed = true;
              _lastKnownIndex = 0;
              
              // 🔄 SINCRONIZACIÓN INMEDIATA: Actualizar estado ANTES de cualquier otra operación
              // Esperar un momento mínimo para que just_audio actualice su sequenceState
              await Future.delayed(const Duration(milliseconds: 50));
              
              // 🔄 CRÍTICO: Sincronizar PRIMERO para actualizar el estado con la nueva cola
              // Esto evita que la deduplicación detecte una desincronización falsa
              _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
              
              // 🔄 ACTUALIZACIÓN EXPLÍCITA: Asegurar que el estado refleje la cola correcta
              // Después de la sincronización, actualizar campos adicionales
              final syncedState = state;
              state = syncedState.copyWith(
                currentSong: seedSong,
                lastConfirmedSong: seedSong,
                currentPosition: Duration.zero,
                isBuffering: true,
                isPlaying: wasPlaying, // Mantener estado de reproducción
                // currentQueue ya fue actualizado por _syncQueueWithAudioService
              );
              
              AppLogger.debug('[PlaybackNotifier] 🔄 Estado sincronizado después de inyección: ${state.currentQueue.length} canciones');
              
              // 🔄 CRÍTICO: Reproducir inmediatamente después de insertar si estaba reproduciendo
              // Esto previene que el reproductor quede pausado y el frontend quede "muerto"
              if (wasPlaying) {
                await service.play();
                AppLogger.info('[PlaybackNotifier] ▶️ Reproducción reanudada después de inyección instantánea');
              }
              
              // 🛡️ PROTECCIÓN: Marcar tiempo de inyección para evitar deduplicación inmediata
              _lastInjectionTime = DateTime.now();
              
              AppLogger.info('[PlaybackNotifier] ⚡ Inyección instantánea exitosa para semilla: ${seedSong.title}');
            } else {
              // Fallback a método estándar si la inyección falla
              AppLogger.info('[PlaybackNotifier] Inyección instantánea falló, usando loadNewQueue estándar');
              await service.loadNewQueue([seedSource], 0);
              _lastKnownIndex = 0;
            }
          } else {
            // No hay cola activa, usar método estándar
            await service.loadNewQueue([seedSource], 0);
            _lastKnownIndex = 0;
          }
          
          // ⚠️ Solo resetear el estado si NO se usó inyección instantánea
          // Si se usó inyección, la sincronización ya actualizó la cola completa
          if (!usedInjectionForSeed) {
            state = state.copyWith(
              currentQueue: <Song>[seedSong],
              currentSong: seedSong,
              lastConfirmedSong: seedSong,
              currentPosition: Duration.zero,
              isBuffering: true,
            );
          }
        } finally {
          _isReplacingQueue = false;
          _isUpdatingQueue = false;
          state = state.copyWith(isReplacingQueue: false);
          
          // 🔄 SINCRONIZACIÓN FORZADA: Esperar un momento para que just_audio actualice su estado
          // y luego forzar una sincronización para asegurar coherencia
          // Reducido a 100ms para respuesta más rápida
          Future.delayed(const Duration(milliseconds: 100), () {
            _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
          });
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

      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Después del bloque de buffer inicial, continuando con Fase 2...');

      // 🎯 FASE 2: Iniciar reproducción SOLAMENTE DESPUÉS de cargar la semilla y el buffer inicial
      // Esto elimina el riesgo de stalling (cola vacía cuando termina la primera canción)
      state = state.copyWith(isLoading: false);
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Estado isLoading actualizado a false');
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Línea inmediatamente después de isLoading = false');

      // Sincronizar de inmediato para que currentSong no quede nulo
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Antes de primera sincronización');
      _syncQueueWithAudioService(service.player.sequenceState);
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Después de primera sincronización');
      if (state.currentSong == null && _lastConfirmedSong != null) {
        state = state.copyWith(currentSong: _lastConfirmedSong);
        AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] currentSong actualizado desde _lastConfirmedSong');
      }

      // Activar bloqueo crítico durante el arranque del modo algoritmo
      _isAwaitingInitialAlgorithmPlay = true;
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] _isAwaitingInitialAlgorithmPlay = true');

      // 🔄 CRÍTICO: Solo llamar a play() si NO se usó inyección instantánea
      // Si se usó inyección, ya se llamó a play() inmediatamente después de insertar
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Verificando usedInjectionForSeed: $usedInjectionForSeed');
      if (!usedInjectionForSeed) {
        // ✅ OPTIMIZACIÓN: Verificar si ya está reproduciendo antes de llamar a play()
        if (service.player.playing) {
          AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Reproductor ya está reproduciendo, saltando service.play()');
        } else {
          AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Llamando a service.play() (sin inyección)');
          try {
            await service.play().timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                AppLogger.warning('[PlaybackNotifier] ⚠️ service.play() timeout después de 5 segundos');
              },
            );
            AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] service.play() completado');
          } catch (e) {
            AppLogger.error('[PlaybackNotifier] ❌ Error en service.play(): $e');
            // Continuar de todos modos si el reproductor ya está reproduciendo
            if (service.player.playing) {
              AppLogger.info('[PlaybackNotifier] ✅ Reproductor está reproduciendo a pesar del error, continuando...');
            } else {
              rethrow;
            }
          }
        }
      } else {
        // Si se usó inyección, verificar que el reproductor esté reproduciendo
        // Si no está reproduciendo, iniciar reproducción
        AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Verificando si reproductor está reproduciendo: ${service.player.playing}');
        if (!service.player.playing) {
          AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Llamando a service.play() (con inyección pero no reproduciendo)');
          await service.play();
          AppLogger.info('[PlaybackNotifier] ▶️ Reproducción iniciada después de verificación');
        } else {
          AppLogger.info('[PlaybackNotifier] ✅ Reproductor ya está reproduciendo después de inyección');
        }
      }

      // 🛡️ FUENTE ÚNICA DE VERDAD: El stream actualizará isPlaying automáticamente
      // Solo actualizar isBuffering si es necesario para otros widgets
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Obteniendo estado del reproductor');
      final actualPlayerState = service.player.playerState;
      final actualIsBuffering = actualPlayerState.processingState == ProcessingState.buffering ||
                               actualPlayerState.processingState == ProcessingState.loading;
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] actualIsBuffering: $actualIsBuffering');
      
      state = state.copyWith(
        isBuffering: actualIsBuffering,
        lastConfirmedSong: state.currentSong ?? state.lastConfirmedSong,
      );
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Estado actualizado con isBuffering');

      // Sincronizar y asegurar currentSong/posición tras play
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Antes de segunda sincronización');
      _syncQueueWithAudioService(service.player.sequenceState);
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Después de segunda sincronización');
      if (state.currentSong == null && _lastConfirmedSong != null) {
        state = state.copyWith(currentSong: _lastConfirmedSong);
        AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] currentSong actualizado desde _lastConfirmedSong (segunda vez)');
      }
      state = state.copyWith(currentPosition: Duration.zero);
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] currentPosition reseteado a zero');
      
      // Sincronizar cola después de un breve delay
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Programando sincronización diferida');
      Future.delayed(const Duration(milliseconds: 200), () {
        _syncQueueWithAudioService(service.player.sequenceState);
      });

      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Llegando a línea antes de log de reproducción iniciada');
      AppLogger.info('[PlaybackNotifier] ✅ Reproducción iniciada con buffer garantizado: ${state.currentQueue.length} canciones en cola');
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Después de log de reproducción iniciada');

      // 🎯 FASE 3 (BACKGROUND): Ejecutar Fase 2 completa en background (sin await)
      // ⚡ OPTIMIZACIÓN: Iniciar inmediatamente sin esperar, ejecutando en paralelo con la reproducción
      // Esto permite que la función retorne y la música continúe mientras se cargan más canciones
      AppLogger.info('[PlaybackNotifier] 🚀 Llamando a Fase 2 completa en background...');
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Estado antes de Fase 2: playbackMode=${state.playbackMode}, queueLength=${state.currentQueue.length}');
      _generateAndAppendRecommendations(seedSong, excludeSeedFromQueue: excludeSeedFromQueue);

      // Iniciar monitor optimizado (verifica cada 5s con condiciones más agresivas)
      _startAlgorithmMonitor();
      
      // 🛡️ PREVENCIÓN DE COLA VACÍA: Iniciar sistema de protección
      _startQueueProtection();
      
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] playAlgorithmStart COMPLETADO exitosamente');
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al iniciar modo algoritmo: $e', stackTrace);
      AppLogger.error('[PlaybackNotifier] 🔍 [DEBUG] playAlgorithmStart FALLÓ con error: $e');
      state = state.copyWith(isLoading: false, shouldStartAlgorithmAfterQueue: false);
      rethrow;
    }
  }

  /// 🎯 FASE 1 RÁPIDA: Obtener buffer inicial crítico (4-5 canciones) antes de reproducir
  /// 
  /// Esta función garantiza que haya al menos 4-5 canciones disponibles cuando termine
  /// la primera canción, eliminando el riesgo de stalling (cola vacía) y haciendo
  /// la transición a la Fase 2 más suave y menos abrupta.
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
      
      // ⚡ OBTENER BUFFER INICIAL: 4-5 canciones para transición más suave
      // Aumentado de 2 a 4-5 para que la transición entre Fase 1 y Fase 2 sea menos abrupta
      // Esto garantiza que haya suficientes canciones mientras la Fase 2 completa se ejecuta en background
      final quickRecommendations = await _intelligentService.getIntelligentFeaturedSongs(
        limit: 5, // 🎯 5 canciones para buffer inicial más generoso (antes: 2)
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
          .take(5) // Máximo 5 canciones para buffer inicial más generoso (antes: 2)
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
    AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] _generateAndAppendRecommendations INICIADA (modo: ${state.playbackMode})');
    
    try {
      // ⚡ OPTIMIZACIÓN: Reducir verificaciones redundantes para hacer la transición más rápida
      // Solo verificar una vez al inicio
      if (state.playbackMode != PlaybackMode.algorithm) {
        AppLogger.warning('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (modo de reproducción cambió: ${state.playbackMode} != ${PlaybackMode.algorithm})');
        _isGeneratingRecommendations = false;
        return;
      }
      
      // 🎯 FASE 2 EN BACKGROUND: Usar las canciones que ya están en la cola como semillas
      // La Fase 1 rápida ya se ejecutó en _generateInitialRecommendations() antes de reproducir
      // Ahora usamos esas canciones (más la semilla) para generar más recomendaciones
      AppLogger.info('[PlaybackNotifier] 🔗 Iniciando Fase 2 completa en background...');
      
      // ⚡ OPTIMIZACIÓN: Simplificar cálculo de excludeIds para hacer la transición más rápida
      final sessionNotifier = ref.read(playbackSessionProvider.notifier);
      final excludeLimit = excludeSeedFromQueue ? 10 : 8; // Reducido para ser más rápido
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
      
      // ⚡ OPTIMIZACIÓN: Verificar solo una vez más antes de la llamada costosa
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Verificando condiciones: modo=${state.playbackMode}, seedSongs.length=${seedSongs.length}, currentQueue.length=${state.currentQueue.length}');
      if (state.playbackMode != PlaybackMode.algorithm || seedSongs.isEmpty) {
        AppLogger.warning('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (modo cambió o cola vacía) - modo: ${state.playbackMode}, seedSongs: ${seedSongs.length}');
        _isGeneratingRecommendations = false;
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
        
        // ⚡ OPTIMIZACIÓN: Simplificar verificaciones redundantes para hacer la transición más rápida
        // Solo verificar una vez antes de hacer la llamada costosa
        if (state.playbackMode != PlaybackMode.algorithm) {
          AppLogger.info('[PlaybackNotifier] ⏹️ Generación de recomendaciones cancelada (modo de reproducción cambió antes de Fase 2)');
          _isGeneratingRecommendations = false;
          return;
        }
        
        // 🚨 MÉTODO DESACOPLADO: Usar semillas directamente sin llamar a getIntelligentFeaturedSongs
        // Esto evita duplicar trabajo y reduce tiempo de ~15s a ~5s
        // ⚡ OPTIMIZACIÓN: Reducir de 10 a 6 canciones para hacer la Fase 2 más rápida
        // El Monitor de Fase 2 se encargará de agregar más canciones cuando sea necesario
        final phase2Songs = await _intelligentService.generatePhase2RecommendationsFromSeeds(
          seeds: seedSongs.map((s) => s.id).toList(), // 🎯 USAR TODAS LAS SEMILLAS DE LA COLA ACTUAL
          count: 6, // ⚡ REDUCIDO: 6 canciones para transición más rápida (antes: 10)
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
      
      // ✅ CRÍTICO: Mantener el orden de las recomendaciones del algoritmo
      // El backend ordena las canciones por score (mejor primero), así que mantenemos ese orden
      final recommendedSongs = featuredSongs
          .map((f) => f.song)
          .where((s) => !excludeIds.contains(s.id))
          .take(15)
          .toList();

      // ✅ VALIDACIÓN: Verificar que la primera canción es la mejor recomendación
      if (recommendedSongs.isNotEmpty) {
        AppLogger.info('[PlaybackNotifier] 🎯 SIGUIENTE CANCIÓN (mejor recomendación del algoritmo): ${recommendedSongs.first.title}');
        if (recommendedSongs.length > 1) {
          AppLogger.info('[PlaybackNotifier] 🎯 Próximas recomendaciones: ${recommendedSongs.take(3).map((s) => s.title).join(", ")}');
        }
      }

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
      
      // 🎯 FASE 1: EXCLUSIÓN REFORZADA - Obtener TODAS las canciones de la cola y historial
      // 🚀 MEJORA: Incluir TODAS las canciones activas para forzar diversidad en el backend
      final sessionNotifier = ref.read(playbackSessionProvider.notifier);
      
      // 1. Obtener TODAS las canciones de la cola del audio service (no limitadas)
      final sequenceState = service.player.sequenceState;
      final allAudioQueueIds = <String>{};
      if (sequenceState.sequence.isNotEmpty) {
        for (final source in sequenceState.sequence) {
          // Extraer ID del tag de la fuente (método correcto)
          if (source.tag is Song) {
            allAudioQueueIds.add((source.tag as Song).id);
          }
        }
      }
      
      // 2. También incluir todas las canciones del estado (por si hay desincronización)
      final allStateQueueIds = state.currentQueue.map((s) => s.id).toSet();
      
      // 3. Combinar ambas fuentes para máxima cobertura
      final allQueueIds = {...allAudioQueueIds, ...allStateQueueIds};
      
      // 4. Obtener TODAS las canciones del historial reciente (no limitadas a 8)
      final allPlayedIds = sessionNotifier.getPlayedSongIds(limit: 40); // Usar máximo del historial
      
      // 5. Construir lista de exclusión completa
      final excludeIds = {...allQueueIds, ...allPlayedIds};
      
      AppLogger.info('[PlaybackNotifier] 🔍 Precarga: EXCLUSIÓN REFORZADA - Excluyendo ${excludeIds.length} IDs (${allQueueIds.length} en cola + ${allPlayedIds.length} reproducidas)');
      
      // ⚡ TRANSICIÓN INSTANTÁNEA: Obtener más recomendaciones (20 en lugar de 15 para asegurar tercera canción)
      final featuredSongs = await _intelligentService.getIntelligentFeaturedSongs(
        limit: 20, // Aumentado para asegurar que siempre hay canciones disponibles
        currentSongId: currentSong.id,
        forceRefresh: false,
        excludeIds: excludeIds, // Excluir historial reciente y cola actual
      );

      AppLogger.debug('[PlaybackNotifier] 🔍 Precarga: Recibidas ${featuredSongs.length} recomendaciones del servicio');

      // ✅ CRÍTICO: Mantener el orden de las recomendaciones del algoritmo
      // El backend ordena las canciones por score (mejor primero), así que mantenemos ese orden
      final newSongs = featuredSongs
          .map((f) => f.song)
          .where((s) => !excludeIds.contains(s.id))
          .take(15) // Aumentado de 10 a 15 para asegurar más canciones disponibles
          .toList();

      // ✅ VALIDACIÓN: Verificar que la primera canción es la mejor recomendación
      if (newSongs.isNotEmpty) {
        AppLogger.info('[PlaybackNotifier] 🎯 SIGUIENTE CANCIÓN (mejor recomendación del algoritmo): ${newSongs.first.title}');
        if (newSongs.length > 1) {
          final nextSongs = newSongs.take(3).map((s) => s.title).toList();
          AppLogger.debug('[PlaybackNotifier] 🎯 Próximas recomendaciones: ${nextSongs.join(", ")}');
        }
      }

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

      // ✅ CRÍTICO: Mantener el orden de score del algoritmo
      // Las canciones ya vienen ordenadas por score del backend (mejor primero)
      // La primera canción es la mejor recomendación y será la siguiente canción
      
      // 🎯 FASE 3.1: Precarga Progresiva - Agregar solo canciones críticas inmediatamente
      // Separar canciones críticas (primeras 5) del resto
      // ✅ IMPORTANTE: Las primeras canciones son las mejores recomendaciones del algoritmo
      final criticalSongs = validNewSongs.take(criticalSongsCount).toList();
      final additionalSongs = validNewSongs.skip(criticalSongsCount).toList();
      
      // ✅ VALIDACIÓN FINAL: Verificar que la primera canción crítica es la mejor recomendación
      if (criticalSongs.isNotEmpty) {
        AppLogger.info('[PlaybackNotifier] ✅ SIGUIENTE CANCIÓN CONFIRMADA (mejor recomendación): ${criticalSongs.first.title}');
        AppLogger.info('[PlaybackNotifier] ✅ Esta será la siguiente canción que se reproducirá después de la actual');
      }
      
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
      // ✅ FIX CRÍTICO: Establecer flag ANTES de llamar a _appendMoreAlgorithmSongs para evitar múltiples ejecuciones
      // ✅ FASE 3 (ANUNCIOS): Bloquear Monitor si hay inserción de anuncios en curso
      // Razón: Si el monitor inserta canciones mientras se inserta un anuncio, los índices se desincronizan
      if (remainingSongs <= preloadThreshold && 
          !_isPreloading && 
          !_isGeneratingRecommendations &&
          !_isInsertingAd &&           // ✅ FASE 3: Bloquear si hay anuncio en inserción
          !_isHandlingAdInsertion) {  // ✅ FASE 3: Bloquear si hay manejo de anuncio
        // ✅ PROTECCIÓN CRÍTICA: Establecer flag inmediatamente para evitar múltiples ejecuciones simultáneas
        _isPreloading = true;
        // 🚨 FORZAR precarga ignorando cooldown cuando es crítico (≤3 canciones)
        // ✅ FIX CRÍTICO: Usar Future.microtask para diferir la ejecución y evitar bloqueos en el timer
        Future.microtask(() async {
          try {
            await _appendMoreAlgorithmSongs(forceIgnoreCooldown: true);
          } catch (e) {
            AppLogger.error('[PlaybackNotifier] 🎯 FASE 2: Error en precarga proactiva: $e');
          } finally {
            // ✅ CRÍTICO: Liberar flag después de completar (o fallar) la precarga
            _isPreloading = false;
          }
        });
      } else if (remainingSongs <= preloadThreshold && (_isInsertingAd || _isHandlingAdInsertion)) {
        // ✅ FASE 3: Log informativo cuando el Monitor está bloqueado por inserción de anuncios
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: Monitor bloqueado temporalmente (inserción de anuncio en curso)');
        // 🚨 CRÍTICO: Si quedan ≤3 canciones (umbral crítico), IGNORAR cooldown y forzar precarga inmediata
        // Esto evita que el reproductor se quede sin canciones mientras espera el cooldown
        final remainingTime = state.totalDuration - state.currentPosition;
        
        // ✅ FUENTE DE VERDAD REAL: Obtener la canción directamente del reproductor de audio
        // Igual que el widget, para garantizar consistencia
        final sequenceState = service.player.sequenceState;
        final realCurrentSource = sequenceState.currentSource;
        String currentSongTitle = "N/A";
        if (realCurrentSource != null && realCurrentSource.tag is Song) {
          final realCurrentSong = realCurrentSource.tag as Song;
          currentSongTitle = realCurrentSong.title ?? "N/A";
        } else if (state.currentSong != null) {
          // Fallback: usar el estado si no se pudo obtener del reproductor
          currentSongTitle = state.currentSong!.title ?? "N/A";
        }
        
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2: 🚀 PRECARGA PROACTIVA DISPARADA (URGENTE - COOLDOWN IGNORADO)');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2:    📊 Razón: $remainingSongs canciones restantes (umbral: ≤$preloadThreshold)');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2:    ⏱️ Tiempo restante: ${remainingTime.inSeconds}s');
        AppLogger.info('[PlaybackNotifier] 🎯 FASE 2:    🎵 Canción actual: $currentSongTitle');
        // 🚨 FORZAR precarga ignorando cooldown cuando es crítico (≤3 canciones)
        // ✅ FIX CRÍTICO: Usar Future.microtask para diferir la ejecución y evitar bloqueos en el timer
        Future.microtask(() async {
          try {
            await _appendMoreAlgorithmSongs(forceIgnoreCooldown: true);
          } catch (e) {
            AppLogger.error('[PlaybackNotifier] 🎯 FASE 2: Error en precarga proactiva: $e');
          } finally {
            // ✅ CRÍTICO: Liberar flag después de completar (o fallar) la precarga
            _isPreloading = false;
          }
        });
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
        // 🛡️ COOLDOWN: Solo mostrar warning si ha pasado el cooldown (evitar spam de logs)
        final shouldLogWarning = _lastCriticalQueueWarning == null || 
            DateTime.now().difference(_lastCriticalQueueWarning!) >= _criticalQueueWarningCooldown;
        
        // 🛡️ COOLDOWN ADICIONAL: Verificar que haya pasado tiempo desde la última precarga
        // para evitar llamadas repetidas muy rápidas
        final canTriggerPreload = _lastPreloadTime == null || 
            DateTime.now().difference(_lastPreloadTime!) >= const Duration(seconds: 3);
        
        if (canTriggerPreload) {
          if (shouldLogWarning) {
            AppLogger.warning('[PlaybackNotifier] 🛡️ Cola crítica: Solo $effectiveRemainingSongs canciones restantes. Precarga urgente activada.');
            _lastCriticalQueueWarning = DateTime.now();
          }
          _appendMoreAlgorithmSongs();
        }
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
    // 🛡️ FALLBACK DE AGOTAMIENTO: Intento A - Exclusión total
    try {
      // Fallback 1: Canciones populares con exclusión total
      final popularSongs = await _homeService.getPopularSongs(limit: 10);
      var validPopular = popularSongs
          .where((s) => s.isValidForPlayback)
          .where((s) => !excludeIds.contains(s.id))
          .take(10)
          .toList();

      // 🛡️ FALLBACK DE AGOTAMIENTO: Intento B - Solo excluir canción actual
      if (validPopular.isEmpty && excludeIds.isNotEmpty) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ REPERTORIO AGOTADO. Aplicando relajación de filtros.');
        
        // Solo excluir la canción actual
        final relaxedExcludeIds = {currentSong.id};
        validPopular = popularSongs
            .where((s) => s.isValidForPlayback)
            .where((s) => !relaxedExcludeIds.contains(s.id))
            .take(10)
            .toList();
        
        AppLogger.info('[PlaybackNotifier] 🔄 Relajación nivel 1: ${validPopular.length} canciones obtenidas (solo excluyendo canción actual)');
        
        // 🛡️ FALLBACK DE AGOTAMIENTO: Intento C - Sin exclusiones
        if (validPopular.isEmpty) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ Aún sin resultados. Permitiendo todas las canciones disponibles.');
          validPopular = popularSongs
              .where((s) => s.isValidForPlayback)
              .take(10)
              .toList();
          AppLogger.info('[PlaybackNotifier] 🔄 Relajación nivel 2: ${validPopular.length} canciones obtenidas (sin exclusiones)');
        }
      }

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
      // Intento A: Con exclusión total
      var fallbackRecommendations = await _intelligentService.getIntelligentFeaturedSongs(
        limit: 10,
        currentSongId: currentSong.id,
        forceRefresh: true, // Forzar refresh para evitar cache
        excludeIds: excludeIds,
      );

      var validFallback = fallbackRecommendations
          .map((f) => f.song)
          .where((s) => s.isValidForPlayback)
          .where((s) => !excludeIds.contains(s.id))
          .take(10)
          .toList();

      // 🛡️ FALLBACK DE AGOTAMIENTO: Intento B - Solo excluir canción actual
      if (validFallback.isEmpty && excludeIds.isNotEmpty) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Recomendaciones agotadas. Aplicando relajación de filtros.');
        
        fallbackRecommendations = await _intelligentService.getIntelligentFeaturedSongs(
          limit: 10,
          currentSongId: currentSong.id,
          forceRefresh: true,
          excludeIds: {currentSong.id}, // Solo excluir canción actual
        );

        validFallback = fallbackRecommendations
            .map((f) => f.song)
            .where((s) => s.isValidForPlayback)
            .where((s) => s.id != currentSong.id)
            .take(10)
            .toList();
        
        AppLogger.info('[PlaybackNotifier] 🔄 Relajación nivel 1: ${validFallback.length} recomendaciones obtenidas (solo excluyendo canción actual)');
        
        // 🛡️ FALLBACK DE AGOTAMIENTO: Intento C - Sin exclusiones
        if (validFallback.isEmpty) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ Aún sin resultados. Permitiendo todas las recomendaciones disponibles.');
          fallbackRecommendations = await _intelligentService.getIntelligentFeaturedSongs(
            limit: 10,
            currentSongId: currentSong.id,
            forceRefresh: true,
            excludeIds: <String>{}, // Sin exclusiones
          );

          validFallback = fallbackRecommendations
              .map((f) => f.song)
              .where((s) => s.isValidForPlayback)
              .take(10)
              .toList();
          
          AppLogger.info('[PlaybackNotifier] 🔄 Relajación nivel 2: ${validFallback.length} recomendaciones obtenidas (sin exclusiones)');
        }
      }

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
    
    // 🚨 DETENER ALGORITMO: Si todos los fallbacks fallan, detener el algoritmo
    // pero NO pausar la canción actual (debe seguir reproduciéndose hasta el final)
    if (state.playbackMode == PlaybackMode.algorithm) {
      AppLogger.warning('[PlaybackNotifier] ⚠️ No hay más canciones disponibles. Deteniendo algoritmo (la canción actual continuará reproduciéndose).');
      _stopAlgorithmMonitor(); // Detener el monitor para que no intente generar más recomendaciones
      // NO pausar aquí - dejar que la canción actual termine de reproducirse
      // La pausa se hará automáticamente cuando la canción termine en _handleSongCompletion()
    }
  }

  /// 🛑 PAUSA PREVENTIVA: Bloquear avance automático 200ms antes del final
  /// Esto previene que el reproductor nativo salte a la siguiente canción antes de insertar el anuncio
  /// 
  // 🎯 MÉTODO ELIMINADO: Ya no usamos pausa preventiva
  // Ahora usamos el patrón "Proxy Source" donde el anuncio se inserta al 50% de la canción
  // y el reproductor nativo maneja la transición automáticamente
  // El método _handlePreventiveAdInsertion() fue eliminado porque ya no es necesario
  /*
  Future<void> _handlePreventiveAdInsertion() async {
    // ✅ PROTECCIÓN: Evitar llamadas reentrantes
    if (_isHandlingAdInsertion || _isInsertingAd || state.isPlayingAd) {
      AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ⏭️ Saltando: inserción de anuncio ya en curso');
      return;
    }
    
    AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-200ms: Trigger detectado - Iniciando pausa preventiva');
    
    try {
      // 1. 🛑 PAUSAR INMEDIATAMENTE para bloquear el avance automático
      final wasPlaying = service.player.playing;
      final currentIndexBeforePause = service.player.currentIndex;
      
      if (wasPlaying && currentIndexBeforePause != null) {
        AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-150ms: Ejecutando player.pause() - Índice actual: $currentIndexBeforePause');
        await service.pause();
        
        // ✅ ESTADO DE PAUSA REAL: Esperar a que el hardware realmente se detenga
        // Verificar ProcessingState.ready o idle para confirmar que el hardware se detuvo
        await _waitForProcessingState([ProcessingState.ready, ProcessingState.idle], timeout: const Duration(milliseconds: 500));
        AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Hardware detenido - Precarga de Canción B bloqueada');
        
        // 🧹 LIMPIEZA AGRESIVA DEL BÚFER: Hacer seek al inicio de la canción actual
        // Esto fuerza la limpieza del búfer de hardware que puede tener audio residual
        try {
          await service.player.seek(Duration.zero, index: currentIndexBeforePause);
          AppLogger.info('[PlaybackNotifier] 🧹 [PREVENTIVE] Búfer limpiado con seek al inicio del índice $currentIndexBeforePause');
          
          // Esperar a que el seek se complete
          await _waitForProcessingState([ProcessingState.ready], timeout: const Duration(milliseconds: 300));
        } catch (e) {
          AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] Error al limpiar búfer: $e');
        }
      }
      
      // 2. 📢 VERIFICAR E INSERTAR ANUNCIO de forma síncrona
      // El anuncio debe entrar en currentIndex + 1 (correcto porque estamos pausados 200ms antes)
      final targetAdIndex = (currentIndexBeforePause ?? 0) + 1;
      AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-100ms: Iniciando inserción de AudioAd en índice $targetAdIndex');
      
      // ✅ FIX CRÍTICO: NO activar _isHandlingAdInsertion ANTES de llamar a _checkAndInsertAd()
      // porque _checkAndInsertAd() verifica ese flag y retorna inmediatamente si está activo
      // En su lugar, llamar directamente a la lógica interna sin las protecciones que bloquean
      try {
        // Llamar directamente a la lógica de inserción sin las protecciones que bloquean
        // Extraer la lógica interna de _checkAndInsertAd() pero sin verificar _isHandlingAdInsertion
        if (state.isPlayingAd || state.currentAd != null || _isInsertingAd) {
          AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] [PREVENTIVE] ⏭️ Omitiendo: ya hay anuncio reproduciéndose o en proceso');
          return;
        }
        
        if (_service == null) {
          AppLogger.warning('[PlaybackNotifier] 📢 [ANUNCIOS] [PREVENTIVE] ⚠️ AudioService no disponible');
          return;
        }
        
        final sequenceState = _service!.player.sequenceState;
        final currentSource = sequenceState.currentSource;
        if (currentSource == null || currentSource.tag is! Song) {
          AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] [PREVENTIVE] ⏭️ Omitiendo: no hay canción reproduciéndose');
          return;
        }
        
        AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] [PREVENTIVE] Iniciando verificación de anuncio...');
        
        // Verificar si usuario es premium
        final authState = ref.read(authStateProvider);
        final user = authState.user;
        final isPremium = user?.isPremium ?? false;
        
        if (isPremium) {
          AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] [PREVENTIVE] ❌ Usuario premium, no se insertan anuncios');
          return;
        }
        
        
        // Obtener anuncio del backend
        final adsNotifier = ref.read(adsProvider.notifier);
        final currentSong = state.currentSong;
        final genre = currentSong?.genres?.isNotEmpty == true 
            ? currentSong!.genres!.first 
            : currentSong?.genreId;
        
        AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] [PREVENTIVE] 🔍 Solicitando anuncio al backend');
        final nextAd = await adsNotifier.getNextAd(
          genre: genre,
          artist: currentSong?.artist?.stageName,
          playlistId: state.contextId,
        );
        
        if (nextAd == null) {
          AppLogger.warning('[PlaybackNotifier] 📢 [ANUNCIOS] [PREVENTIVE] ❌ No hay anuncios disponibles');
          return;
        }
        
        AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] [PREVENTIVE] ✅ Anuncio obtenido: ${nextAd.title}');
        
        // Insertar anuncio en la cola
        final expectedAdIndex = (currentIndexBeforePause ?? 0) + 1;
        AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Insertando anuncio en índice $expectedAdIndex');
        await _insertAdInQueue(nextAd);
        AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Inserción de anuncio completada');
        
        // ✅ FIX CRÍTICO: Reproducir el anuncio INMEDIATAMENTE después de insertarlo
        // No esperar el delay de 150ms porque el reproductor puede avanzar automáticamente
        try {
          // Verificar inmediatamente después de insertar
          final immediateStateCheck = service.player.sequenceState;
          final sequence = immediateStateCheck.sequence;
          
          // Verificar si el anuncio está en la cola en el índice esperado
          bool adFoundInQueue = false;
          AudioAd? adInQueue;
          if (expectedAdIndex < sequence.length) {
            final sourceAtExpectedIndex = sequence[expectedAdIndex];
            if (sourceAtExpectedIndex.tag is AudioAd) {
              adFoundInQueue = true;
              adInQueue = sourceAtExpectedIndex.tag as AudioAd;
              AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio encontrado en cola índice $expectedAdIndex: ${adInQueue.title}');
            }
          }
          
          if (adFoundInQueue && adInQueue != null) {
            // Actualizar estado ANTES de reproducir para evitar que el stream listener lo limpie
            final adDuration = adInQueue.duration;
            state = state.copyWith(
              isPlayingAd: true,
              currentAd: adInQueue,
              clearCurrentSong: true,
              clearLastConfirmedSong: true,
              totalDuration: adDuration,
              currentPosition: Duration.zero,
            );
            AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Estado del anuncio actualizado ANTES de reproducir');
            
            // ✅ CRÍTICO: Hacer seek al anuncio y reproducirlo INMEDIATAMENTE
            // NO esperar delays innecesarios porque el reproductor puede avanzar automáticamente
            AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Ejecutando seek al índice $expectedAdIndex INMEDIATAMENTE');
            await service.player.seek(Duration.zero, index: expectedAdIndex);
            
            // ✅ CRÍTICO: Esperar SOLO lo mínimo necesario para que el seek se complete
            await _waitForProcessingState([ProcessingState.ready], timeout: const Duration(milliseconds: 200));
            
            // Verificar que estamos en el anuncio ANTES de reproducir
            final afterSeekState = service.player.sequenceState;
            final afterSeekSource = afterSeekState.currentSource;
            final afterSeekIndex = afterSeekState.currentIndex;
            
            AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Después del seek: índice=$afterSeekIndex (esperado=$expectedAdIndex), esAd=${afterSeekSource?.tag is AudioAd}');
            
            if (afterSeekSource?.tag is AudioAd && afterSeekIndex == expectedAdIndex) {
              // ✅ CRÍTICO: Reproducir INMEDIATAMENTE sin delay
              AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio confirmado en índice correcto, ejecutando play() INMEDIATAMENTE');
              await service.play();
              
              // ✅ CRÍTICO: Esperar SOLO lo mínimo necesario para que la reproducción se inicie
              await Future.delayed(const Duration(milliseconds: 150));
              
              // Verificar que el anuncio se está reproduciendo
              final finalVerifyState = service.player.sequenceState;
              final finalVerifySource = finalVerifyState.currentSource;
              final finalVerifyIndex = finalVerifyState.currentIndex;
              final finalVerifyPlaying = service.player.playing;
              
              AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Verificación después de play: índice=$finalVerifyIndex (esperado=$expectedAdIndex), esAd=${finalVerifySource?.tag is AudioAd}, playing=$finalVerifyPlaying');
              
              if (finalVerifySource?.tag is AudioAd && finalVerifyIndex == expectedAdIndex && finalVerifyPlaying) {
                AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio confirmado reproduciéndose correctamente');
                _preventiveAdTriggered = false; // Resetear flag después de reproducir
                return; // Salir aquí, ya reproducimos el anuncio exitosamente
              } else if (finalVerifySource?.tag is AudioAd && finalVerifyIndex == expectedAdIndex && !finalVerifyPlaying) {
                // El anuncio está en el índice correcto pero no está reproduciendo, intentar reproducir de nuevo
                AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] ⚠️ Anuncio en índice correcto pero no reproduciendo, intentando play() de nuevo');
                await service.play();
                await Future.delayed(const Duration(milliseconds: 100));
                final retryState = service.player.sequenceState;
                final retryPlaying = service.player.playing;
                if (retryPlaying && retryState.currentSource?.tag is AudioAd) {
                  AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio reproduciéndose después de retry');
                  _preventiveAdTriggered = false;
                  return;
                }
              } else {
                AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] ⚠️ Anuncio no se está reproduciendo correctamente después de play. Índice: $finalVerifyIndex (esperado=$expectedAdIndex), esAd: ${finalVerifySource?.tag is AudioAd}, playing: $finalVerifyPlaying');
                // Continuar con la sección 3 como fallback
              }
            } else {
              AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] ⚠️ Después del seek: índice=$afterSeekIndex (esperado=$expectedAdIndex), esAd=${afterSeekSource?.tag is AudioAd}');
              // Continuar con la sección 3 como fallback
            }
          } else {
            AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] ⚠️ Anuncio no encontrado en cola índice $expectedAdIndex');
            // Continuar con la sección 3 como fallback
          }
        } catch (e, stackTrace) {
          AppLogger.error('[PlaybackNotifier] 🛑 [PREVENTIVE] Error al reproducir anuncio inmediatamente: $e', stackTrace);
          // Continuar con la sección 3 como fallback
        }
      } catch (e, stackTrace) {
        AppLogger.error('[PlaybackNotifier] 🛑 [PREVENTIVE] Error al verificar anuncios: $e', stackTrace);
      }
      
      // 3. 🔀 FALLBACK: Si el anuncio no se reprodujo inmediatamente, intentar reproducirlo aquí
      // ✅ FIX CRÍTICO: Solo ejecutar esta sección si el anuncio NO se reprodujo inmediatamente
      if (_preventiveAdTriggered) {
        AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Ejecutando fallback: anuncio no se reprodujo inmediatamente');
        await Future.delayed(const Duration(milliseconds: 50)); // Reducido porque ya debería estar insertado
        
        final finalStateCheck = service.player.sequenceState;
      final finalSourceCheck = finalStateCheck.currentSource;
      final finalIndexCheck = finalStateCheck.currentIndex;
      final isAdAfterDelay = finalSourceCheck?.tag is AudioAd;
      final expectedAdIndex = (currentIndexBeforePause ?? 0) + 1;
      
      AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Verificación final: índice=$finalIndexCheck (esperado=$expectedAdIndex), esAd=$isAdAfterDelay, isPlayingAd=${state.isPlayingAd}, isInsertingAd=$_isInsertingAd');
      
      // ✅ FIX CRÍTICO: Verificar si el anuncio está en la cola, incluso si no está en el índice actual
      final sequence = finalStateCheck.sequence;
      bool adFoundInQueue = false;
      AudioAd? adInQueue;
      if (expectedAdIndex < sequence.length) {
        final sourceAtExpectedIndex = sequence[expectedAdIndex];
        if (sourceAtExpectedIndex.tag is AudioAd) {
          adFoundInQueue = true;
          adInQueue = sourceAtExpectedIndex.tag as AudioAd;
          AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio encontrado en cola índice $expectedAdIndex: ${adInQueue.title}');
        } else {
          AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] ⚠️ En índice $expectedAdIndex hay: ${sourceAtExpectedIndex.tag.runtimeType}, no AudioAd');
        }
      }
      
      // ✅ FIX CRÍTICO: Si el anuncio está en la cola pero el reproductor avanzó a otra canción,
      // hacer seek al anuncio INMEDIATAMENTE y reproducirlo
      if (adFoundInQueue && adInQueue != null) {
        AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-0ms: Anuncio confirmado en cola, ejecutando seek y play al índice $expectedAdIndex');
        try {
          // ✅ FIX CRÍTICO: Asegurar que estamos en el índice del anuncio antes de reproducir
          if (finalIndexCheck != expectedAdIndex) {
            AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Reproductor avanzó a índice $finalIndexCheck, haciendo seek al anuncio en índice $expectedAdIndex');
            await service.player.seek(Duration.zero, index: expectedAdIndex);
            await _waitForProcessingState([ProcessingState.ready], timeout: const Duration(milliseconds: 500));
            
            // Verificar después del seek
            final afterSeekState = service.player.sequenceState;
            final afterSeekSource = afterSeekState.currentSource;
            final afterSeekIndex = afterSeekState.currentIndex;
            AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Después del seek: índice=$afterSeekIndex, esAd=${afterSeekSource?.tag is AudioAd}');
          }
          
          // Verificar una vez más que estamos en el anuncio antes de reproducir
          final verifyState = service.player.sequenceState;
          final verifySource = verifyState.currentSource;
          final verifyIndex = verifyState.currentIndex;
          
          if (verifySource?.tag is AudioAd && verifyIndex == expectedAdIndex) {
            // ✅ FIX CRÍTICO: Actualizar estado ANTES de reproducir para evitar que el stream listener limpie el anuncio
            final adDuration = verifySource?.duration ?? adInQueue.duration;
            state = state.copyWith(
              isPlayingAd: true,
              currentAd: adInQueue,
              clearCurrentSong: true,
              clearLastConfirmedSong: true,
              totalDuration: adDuration,
              currentPosition: Duration.zero,
            );
            AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] Estado del anuncio actualizado ANTES de reproducir');
            
            // ✅ CRÍTICO: Reproducir INMEDIATAMENTE para evitar que el reproductor avance automáticamente
            await service.play();
            AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio reproducido INMEDIATAMENTE - Buffer limpio y URL del Anuncio cargada');
            
            // Esperar un momento para asegurar que la reproducción se inicie
            await Future.delayed(const Duration(milliseconds: 100));
            
            // Verificar una vez más que el anuncio se está reproduciendo
            final finalVerifyState = service.player.sequenceState;
            final finalVerifySource = finalVerifyState.currentSource;
            final finalVerifyIndex = finalVerifyState.currentIndex;
            final finalVerifyPlaying = service.player.playing;
            
            if (finalVerifySource?.tag is AudioAd && finalVerifyIndex == expectedAdIndex && finalVerifyPlaying) {
              AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio confirmado reproduciéndose correctamente');
            } else {
              AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] ⚠️ Anuncio no se está reproduciendo correctamente. Índice: $finalVerifyIndex, esAd: ${finalVerifySource?.tag is AudioAd}, playing: $finalVerifyPlaying');
            }
            
            // Resetear flag después de reproducir el anuncio
            _preventiveAdTriggered = false;
          } else {
            AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] ⚠️ Anuncio no confirmado después del seek. Índice: $verifyIndex, esAd: ${verifySource?.tag is AudioAd}');
            _preventiveAdTriggered = false; // Resetear flag en caso de error
          }
        } catch (e, stackTrace) {
          AppLogger.error('[PlaybackNotifier] 🛑 [PREVENTIVE] Error al reproducir anuncio: $e', stackTrace);
          _preventiveAdTriggered = false; // Resetear flag en caso de error
        }
      } else if (isAdAfterDelay && finalIndexCheck == expectedAdIndex) {
        // ✅ Anuncio ya está en el índice correcto, solo reproducir
        AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-0ms: Anuncio ya en índice correcto, reproduciendo');
        try {
          await service.play();
          AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio reproducido');
          _preventiveAdTriggered = false;
        } catch (e) {
          AppLogger.error('[PlaybackNotifier] 🛑 [PREVENTIVE] Error al reproducir: $e');
          _preventiveAdTriggered = false;
        }
      } else if (!state.isPlayingAd && !_isInsertingAd && !isAdAfterDelay && wasPlaying) {
        // ✅ No se insertó anuncio, reanudar reproducción de la canción
        AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] No se insertó anuncio, reanudando reproducción');
        final currentSourceBeforePlay = service.player.sequenceState.currentSource;
        if (currentSourceBeforePlay?.tag is! AudioAd) {
          await service.play();
          AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ▶️ Reproducción reanudada (no se insertó anuncio)');
        }
        _preventiveAdTriggered = false; // Resetear flag si no se insertó anuncio
      } else {
        AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] ⚠️ Estado inconsistente después de inserción. No se puede determinar acción.');
        _preventiveAdTriggered = false; // Resetear flag en caso de estado inconsistente
      }
      } // Cerrar el bloque if (_preventiveAdTriggered)
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] 🛑 [PREVENTIVE] Error en pausa preventiva: $e');
      _preventiveAdTriggered = false; // Resetear flag en caso de error
    } finally {
      // Asegurar que el flag se resetee siempre
      if (_preventiveAdTriggered) {
        AppLogger.warning('[PlaybackNotifier] 🛑 [PREVENTIVE] Reseteando flag en finally');
        _preventiveAdTriggered = false;
      }
    }
  }
  */


  /// ⚡ TRANSICIÓN INSTANTÁNEA: Manejar cuando una canción termina
  /// ✅ FIX CRÍTICO: Bloqueo atómico para evitar race conditions con el reproductor nativo
  Future<void> _handleSongCompletion() async {
    // ✅ PROTECCIÓN: Evitar llamadas reentrantes
    // ✅ FIX CRÍTICO: Si la pausa preventiva ya se activó, no procesar completion normal
    if (_isHandlingAdInsertion || _preventiveAdTriggered) {
      AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] ⏭️ Saltando manejo: inserción de anuncio en curso o pausa preventiva activa');
      return;
    }
    
    AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] Canción terminada - Iniciando manejo de finalización');
    AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] Estado actual: isPlayingAd=${state.isPlayingAd}, playbackMode=${state.playbackMode}');
    
    // Resetear flag de preparación
    _nextSongPrepared = false;
    _lastPreparedSongIndex = null;
    _preventiveAdTriggered = false; // ✅ Resetear flag de pausa preventiva cuando termina la canción
    
    // ✅ FIX CRÍTICO: Bloquear el avance automático del reproductor
    // Detener temporalmente para evitar que avance a la siguiente canción
    final wasPlaying = service.player.playing;
    if (wasPlaying) {
      try {
        await service.pause();
        AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] ⏸️ Reproductor pausado temporalmente para inserción de anuncio');
        
        // 🛑 LIMPIEZA AGRESIVA DEL BÚFER: Hacer seek al inicio de la canción actual
        // Esto fuerza la limpieza del búfer de hardware (AudioTrack) que puede tener
        // audio residual de la siguiente canción precargada
        // ✅ OPTIMIZACIÓN: Confiamos en que await seek() es suficiente, sin esperas explícitas
        try {
          final currentIndex = service.player.currentIndex;
          if (currentIndex != null) {
            await service.player.seek(Duration.zero, index: currentIndex);
            AppLogger.info('[PlaybackNotifier] 🧹 [COMPLETION] Búfer limpiado con seek al inicio del índice $currentIndex');
          } else {
            // Si no hay índice, hacer seek simple al inicio
            await service.player.seek(Duration.zero);
            AppLogger.info('[PlaybackNotifier] 🧹 [COMPLETION] Búfer limpiado con seek al inicio');
          }
        } catch (e) {
          AppLogger.warning('[PlaybackNotifier] 🎵 [COMPLETION] Error al limpiar búfer: $e');
          // Continuar aunque falle la limpieza del búfer
        }
      } catch (e) {
        AppLogger.warning('[PlaybackNotifier] 🎵 [COMPLETION] Error al pausar: $e');
      }
    }
    
    // 📢 ANUNCIOS: Verificar e insertar anuncio ANTES de hacer cualquier transición
    // ✅ FIX CRÍTICO: Esperar la inserción de forma síncrona para evitar race conditions
    AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] Verificando anuncios: isPlayingAd=${state.isPlayingAd}');
    if (!state.isPlayingAd) {
      AppLogger.info('[PlaybackNotifier] 📢 [COMPLETION] ✅ No hay anuncio reproduciéndose, verificando si debe insertar anuncio...');
      
      _isHandlingAdInsertion = true; // ✅ Bloquear
      try {
        // ✅ FIX CRÍTICO: Esperar la inserción de forma síncrona
        await _checkAndInsertAd();
      } catch (e) {
        AppLogger.error('[PlaybackNotifier] 📢 [COMPLETION] Error al verificar anuncios: $e');
      } finally {
        _isHandlingAdInsertion = false; // ✅ Desbloquear
      }
    } else {
      AppLogger.info('[PlaybackNotifier] 📢 [COMPLETION] ⏭️ Omitiendo verificación de anuncio: ya hay un anuncio reproduciéndose');
    }
    
    // ✅ FIX CRÍTICO: Si no se insertó un anuncio Y no estamos insertando uno, reanudar reproducción
    // El reproductor avanzará automáticamente a la siguiente canción
    // ✅ FIX CRÍTICO: Verificar también _isInsertingAd para evitar que se reproduzca otra canción antes del anuncio
    // ✅ FIX ADICIONAL: Esperar un momento adicional para asegurar que la inserción del anuncio se complete
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Verificar el estado una vez más después del delay
    final finalStateCheck = service.player.sequenceState;
    final finalSourceCheck = finalStateCheck.currentSource;
    final isAdAfterDelay = finalSourceCheck?.tag is AudioAd;
    
    AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] Verificación final: isPlayingAd=${state.isPlayingAd}, isInsertingAd=$_isInsertingAd, isAdAfterDelay=$isAdAfterDelay');
    
    if (!state.isPlayingAd && !_isInsertingAd && !isAdAfterDelay && wasPlaying) {
      try {
        // ✅ FIX CRÍTICO: Verificar que realmente no hay anuncio antes de reproducir
        final currentSourceBeforePlay = service.player.sequenceState.currentSource;
        if (currentSourceBeforePlay?.tag is! AudioAd) {
          await service.play();
          AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] ▶️ Reproducción reanudada (no se insertó anuncio)');
        } else {
          AppLogger.warning('[PlaybackNotifier] 🎵 [COMPLETION] ⚠️ Detectado anuncio antes de reproducir, omitiendo reproducción');
        }
      } catch (e) {
        AppLogger.warning('[PlaybackNotifier] 🎵 [COMPLETION] Error al reanudar: $e');
      }
    } else if (_isInsertingAd) {
      AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] ⏸️ No reanudando reproducción: anuncio en proceso de inserción');
    } else if (state.isPlayingAd || isAdAfterDelay) {
      AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] ⏸️ No reanudando reproducción: anuncio reproduciéndose');
    }
    
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
          await service.player.seek(Duration.zero);
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
      } else {
        // 🚨 PROTECCIÓN: Si no hay siguiente canción, intentar generar recomendaciones urgentes
        // y si no se pueden generar, pausar para evitar que el reproductor se quede colgado
        AppLogger.warning('[PlaybackNotifier] ⚠️ No hay siguiente canción en modo algoritmo. Intentando precarga urgente...');
        
        final currentSong = state.currentSong;
        if (currentSong != null) {
          // Intentar precarga urgente esperando resultado
          try {
            await _forceImmediatePreload().timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                AppLogger.warning('[PlaybackNotifier] ⚠️ Timeout en precarga urgente (3s)');
              },
            );
            
            // Sincronizar después de la precarga
            _syncQueueWithAudioService(service.player.sequenceState);
            
            // Verificar si ahora hay siguiente canción
            if (service.player.hasNext) {
              AppLogger.info('[PlaybackNotifier] ✅ Precarga urgente exitosa, avanzando...');
              await service.player.seekToNext();
              await service.player.play();
              _syncQueueWithAudioService(service.player.sequenceState);
              state = state.copyWith(currentPosition: Duration.zero);
            } else {
              // Si aún no hay siguiente después de la precarga, pausar
              AppLogger.warning('[PlaybackNotifier] ⚠️ No se pudieron generar más canciones. Pausando reproducción.');
              await service.pause();
              state = state.copyWith(isPlaying: false);
            }
          } catch (e) {
            AppLogger.error('[PlaybackNotifier] ❌ Error en precarga urgente: $e');
            // Si hay error, pausar para evitar estado inconsistente
            await service.pause();
            state = state.copyWith(isPlaying: false);
          }
        } else {
          // Si no hay canción actual, pausar directamente
          AppLogger.warning('[PlaybackNotifier] ⚠️ No hay canción actual ni siguiente. Pausando reproducción.');
          await service.pause();
          state = state.copyWith(isPlaying: false);
        }
        return; // Salir aquí, ya manejamos el caso sin siguiente canción
      }
      
      // Asegurar que haya más canciones precargadas en background (solo si hay siguiente)
      if (service.player.hasNext) {
        _appendMoreAlgorithmSongs();
      }
    }
    
    // ✅ NOTA: La verificación de anuncios ya se ejecutó al inicio de esta función
    // para asegurar que se ejecute incluso si hay returns tempranos
  }

  // ============== Sistema de Anuncios ==============

  /// Verificar si debe reproducir un anuncio e insertarlo en la cola
  /// [triggerSongId]: ID de la canción que disparó la verificación (para marcarla como procesada)
  Future<void> _checkAndInsertAd({String? triggerSongId}) async {
    // ✅ CRÍTICO: El flag _isInsertingAd ya se estableció en el trigger del 50%
    // Usar try-finally para asegurar que se libere SIEMPRE, incluso si retornamos temprano
    try {
      // ✅ PROTECCIÓN CRÍTICA: Verificar si ya hay un anuncio reproduciéndose o se está insertando uno
      // NOTA: No verificamos _isInsertingAd aquí porque ya se estableció en el trigger del 50%
      if (state.isPlayingAd || state.currentAd != null || _isHandlingAdInsertion) {
        AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ⏭️ Omitiendo verificación: ya hay anuncio reproduciéndose o en proceso de inserción');
        _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
        return;
      }
      
      // 🛑 PROTECCIÓN CRÍTICA: Verificar si ya hay un anuncio en la cola antes de insertar otro
      if (_service != null) {
        final sequenceState = _service!.player.sequenceState;
        final currentIndex = _service!.player.currentIndex ?? 0;
        
        // 🧹 LIMPIEZA DE ANUNCIOS HUÉRFANOS: Eliminar anuncios que ya fueron saltados
        // Un anuncio es "huérfano" si está antes del índice actual (ya fue saltado)
        // ✅ FIX CRÍTICO: Usar microtask para diferir la eliminación y evitar conflictos con el stream
        bool hasOrphanedAds = false;
        final orphanedIndices = <int>[];
        
        for (int i = 0; i < currentIndex && i < sequenceState.sequence.length; i++) {
          final source = sequenceState.sequence[i];
          if (source.tag is AudioAd) {
            final orphanedAd = source.tag as AudioAd;
            AppLogger.warning('[PlaybackNotifier] 🧹 [ANUNCIOS] Detectado anuncio huérfano en índice $i (actual: $currentIndex): ${orphanedAd.title} - Programando eliminación...');
            hasOrphanedAds = true;
            orphanedIndices.add(i);
          }
        }
        
        // ✅ FIX CRÍTICO: Si hay anuncios huérfanos, eliminarlos ANTES de verificar duplicados
        // Esto evita que se inserten anuncios duplicados cuando hay huérfanos que no se eliminaron correctamente
        if (hasOrphanedAds && _adInsertionManager != null && !_isRemovingOrphanedAd) {
          _isRemovingOrphanedAd = true;
          try {
            // ✅ CRÍTICO: Usar Future.microtask para diferir la eliminación y evitar conflictos con el stream
            // Esto previene el error "Cannot fire new event. Controller is already firing an event"
            await Future.microtask(() async {
              // Eliminar en orden inverso para evitar problemas con índices que cambian
              for (int i = orphanedIndices.length - 1; i >= 0; i--) {
                final index = orphanedIndices[i];
                await _adInsertionManager!.removeAdAt(index);
                AppLogger.info('[PlaybackNotifier] 🧹 [ANUNCIOS] Anuncio huérfano eliminado del índice $index');
              }
            });
            AppLogger.info('[PlaybackNotifier] 🧹 [ANUNCIOS] ${orphanedIndices.length} anuncios huérfanos eliminados, continuando con verificación...');
          } catch (e) {
            AppLogger.error('[PlaybackNotifier] Error al eliminar anuncios huérfanos: $e');
            // Si falla la eliminación, verificar TODA la cola (incluyendo huérfanos) antes de insertar
            AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] Eliminación falló, verificando TODA la cola antes de insertar...');
            final fullSequenceState = _service!.player.sequenceState;
            for (int i = 0; i < fullSequenceState.sequence.length; i++) {
              final source = fullSequenceState.sequence[i];
              if (source.tag is AudioAd) {
                final existingAd = source.tag as AudioAd;
                AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] Detectado anuncio en cola (índice $i): ${existingAd.title} (ID: ${existingAd.id}) - Omitiendo inserción para evitar duplicado');
                _isRemovingOrphanedAd = false;
                _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
                return;
              }
            }
          } finally {
            _isRemovingOrphanedAd = false;
          }
          
          // ✅ CRÍTICO: Obtener el estado FRESCO después de eliminar huérfanos
          // porque los índices pueden haber cambiado
          final freshSequenceState = _service!.player.sequenceState;
          final freshCurrentIndex = _service!.player.currentIndex ?? 0;
          
          // Verificar anuncios VÁLIDOS (solo los que están en el índice actual o después)
          // Un anuncio es válido si está en el índice actual (reproduciéndose) o después (pendiente)
          for (int i = freshCurrentIndex; i < freshSequenceState.sequence.length; i++) {
            final source = freshSequenceState.sequence[i];
            if (source.tag is AudioAd) {
              final existingAd = source.tag as AudioAd;
              AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] Ya hay un anuncio válido en la cola (índice $i, actual: $freshCurrentIndex): ${existingAd.title} (ID: ${existingAd.id}) - Omitiendo inserción duplicada');
              
              // ✅ FIX CRÍTICO: Marcar la canción actual como procesada para evitar bucle infinito
              if (triggerSongId != null) {
                _lastSongIdWithAd = triggerSongId;
                AppLogger.info('[PlaybackNotifier] 🛑 [ANUNCIOS] Canción marcada como procesada: $triggerSongId');
              } else {
                 AppLogger.warning('[PlaybackNotifier] ⚠️ triggerSongId es null, no se puede marcar como procesada');
              }
              
              _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
              return;
            }
          }
        } else {
          // Si no hay huérfanos, verificar normalmente
          // Verificar anuncios VÁLIDOS (solo los que están en el índice actual o después)
          // Un anuncio es válido si está en el índice actual (reproduciéndose) o después (pendiente)
          for (int i = currentIndex; i < sequenceState.sequence.length; i++) {
            final source = sequenceState.sequence[i];
            if (source.tag is AudioAd) {
              final existingAd = source.tag as AudioAd;
              AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] Ya hay un anuncio válido en la cola (índice $i, actual: $currentIndex): ${existingAd.title} (ID: ${existingAd.id}) - Omitiendo inserción duplicada');
              
              // ✅ FIX CRÍTICO: Marcar la canción actual como procesada para evitar bucle infinito
              if (triggerSongId != null) {
                _lastSongIdWithAd = triggerSongId;
                AppLogger.info('[PlaybackNotifier] 🛑 [ANUNCIOS] Canción marcada como procesada: $triggerSongId');
              }
              
              _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
              return;
            }
          }
        }
      }
      
      // ✅ PROTECCIÓN CRÍTICA: Verificar que realmente hay una canción reproduciéndose
      if (_service == null) {
        AppLogger.warning('[PlaybackNotifier] 📢 [ANUNCIOS] ⚠️ AudioService no disponible');
        _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
        return;
      }
      
      final sequenceState = _service!.player.sequenceState;
      final currentSource = sequenceState.currentSource;
      if (currentSource == null || currentSource.tag is! Song) {
        AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ⏭️ Omitiendo verificación: no hay canción reproduciéndose');
        _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
        return;
      }
      
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] Iniciando verificación de anuncio...');
      
      // 1. Verificar si usuario es premium
      final authState = ref.read(authStateProvider);
      final user = authState.user;
      final subscriptionStatus = user?.subscriptionStatus;
      final isPremium = user?.isPremium ?? false;
      
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] 👤 Estado del usuario:');
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS]    - subscriptionStatus: $subscriptionStatus');
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS]    - isPremium: $isPremium');
      
      if (isPremium) {
        AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ❌ Usuario premium, no se insertan anuncios');
        // ✅ FIX CRÍTICO: Marcar como procesada para no verificar de nuevo
        if (triggerSongId != null) _lastSongIdWithAd = triggerSongId;
        _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
        return;
      }
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ✅ Usuario NO premium, continuando con verificación de anuncios...');
      
      // 3. Obtener anuncio del backend
      final adsNotifier = ref.read(adsProvider.notifier);
      final currentSong = state.currentSong;
      
      // Obtener primer género si existe (para targeting)
      final genre = currentSong?.genres?.isNotEmpty == true 
          ? currentSong!.genres!.first 
          : currentSong?.genreId;
      
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] 🔍 Solicitando anuncio al backend (género: $genre, artista: ${currentSong?.artist?.stageName})');
      
      final nextAd = await adsNotifier.getNextAd(
        genre: genre,
        artist: currentSong?.artist?.stageName,
        playlistId: state.contextId,
      );
      
      if (nextAd == null) {
        AppLogger.warning('[PlaybackNotifier] 📢 [ANUNCIOS] ❌ No hay anuncios disponibles del backend');
        // ✅ FIX CRÍTICO: Marcar como procesada para no verificar de nuevo (al menos por ahora)
        if (triggerSongId != null) _lastSongIdWithAd = triggerSongId;
        _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
        return;
      }
      
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ✅ Anuncio obtenido: ${nextAd.title} (ID: ${nextAd.id})');
      
      // 4. Insertar anuncio en la cola
      // ✅ FIX CRÍTICO: La inserción ya maneja el bloqueo interno
      // NOTA: _insertAdInQueue() maneja el flag _isInsertingAd internamente
      await _insertAdInQueue(nextAd);
      
      // ✅ FIX CRÍTICO: Si se insertó un anuncio, el reproductor ya debería estar reproduciéndolo
      // No necesitamos hacer nada más aquí - el stream listener detectará el anuncio
      // El flag _isInsertingAd se libera dentro de _insertAdInQueue() después de la inserción exitosa
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] 📢 [ANUNCIOS] ❌ Error al verificar e insertar anuncio: $e', stackTrace);
      _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag en caso de error
      // No bloquear la reproducción si falla la inserción de anuncios
    } finally {
      // ✅ CRÍTICO: Asegurar que el flag se libere SIEMPRE si no se insertó el anuncio
      // Si la inserción fue exitosa, _insertAdInQueue() ya liberó el flag
      // Este finally solo actúa como respaldo para casos donde retornamos temprano
      // pero NO debemos liberar el flag si _insertAdInQueue() está en proceso
      // Por eso verificamos si el flag aún está activo (significa que no se insertó)
      if (_isInsertingAd && !state.isPlayingAd && state.currentAd == null) {
        // Solo liberar si realmente no se insertó nada (no hay anuncio en el estado)
        AppLogger.warning('[PlaybackNotifier] 📢 [ANUNCIOS] ⚠️ Liberando flag _isInsertingAd en finally (inserción no completada)');
        _isInsertingAd = false;
      }
    }
  }

  /// ✅ OPTIMIZADO: Insertar anuncio de forma fluida sin delays innecesarios
  /// Confía en el stream listener para actualizar el estado en tiempo real
  Future<void> _insertAdInQueue(AudioAd ad) async {
    // ✅ PROTECCIÓN: Marcar que estamos insertando
    _isInsertingAd = true;
    
    try {
      if (_service == null || _adInsertionManager == null) {
        AppLogger.warning('[PlaybackNotifier] AudioService o AdInsertionManager no disponible');
        _isInsertingAd = false;
        return;
      }
      
      final service = _service!;
      final currentIndex = service.player.currentIndex ?? 0;
      final targetIndex = currentIndex + 1;
      
      // 🛑 PROTECCIÓN CRÍTICA: Verificar una vez más si ya hay un anuncio en la posición objetivo
      final sequenceState = service.player.sequenceState;
      if (targetIndex < sequenceState.sequence.length) {
        final existingSource = sequenceState.sequence[targetIndex];
        if (existingSource.tag is AudioAd) {
          final existingAd = existingSource.tag as AudioAd;
          AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] Ya hay un anuncio en el índice objetivo $targetIndex: ${existingAd.title} (ID: ${existingAd.id}) - Omitiendo inserción duplicada');
          _isInsertingAd = false;
          return;
        }
      }
      
      // 🛑 PROTECCIÓN CRÍTICA: Verificar también en las posiciones adyacentes (por si el índice cambió durante la inserción)
      for (int i = 0; i <= 2 && currentIndex + i < sequenceState.sequence.length; i++) {
        final checkIndex = currentIndex + i;
        if (checkIndex != currentIndex) { // No verificar la posición actual
          final checkSource = sequenceState.sequence[checkIndex];
          if (checkSource.tag is AudioAd) {
            final existingAd = checkSource.tag as AudioAd;
            if (existingAd.id == ad.id) {
              AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] El mismo anuncio ya está en la cola (índice $checkIndex): ${existingAd.title} - Omitiendo inserción duplicada');
              _isInsertingAd = false;
              return;
            }
          }
        }
      }
      
      // ✅ FIX CRÍTICO: Verificar una última vez que el currentIndex no haya cambiado
      // Si el índice cambió durante la inserción, podría crear un anuncio huérfano
      final finalCurrentIndex = service.player.currentIndex ?? 0;
      final finalTargetIndex = finalCurrentIndex + 1;
      
      // Si el índice cambió significativamente (más de 1 posición), abortar para evitar huérfanos
      if ((finalCurrentIndex - currentIndex).abs() > 1) {
        AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] El índice cambió durante la inserción (de $currentIndex a $finalCurrentIndex) - Abortando para evitar anuncio huérfano');
        _isInsertingAd = false;
        return;
      }
      
      // Si el índice cambió en 1 posición (avanzó), usar el nuevo targetIndex
      final actualTargetIndex = finalTargetIndex;
      
      // ✅ CRÍTICO: Obtener un sequenceState FRESCO después de verificar el índice final
      final finalSequenceState = service.player.sequenceState;
      
      // Verificar una última vez que no haya anuncios en la nueva posición objetivo
      if (actualTargetIndex < finalSequenceState.sequence.length) {
        final finalCheckSource = finalSequenceState.sequence[actualTargetIndex];
        if (finalCheckSource.tag is AudioAd) {
          final existingAd = finalCheckSource.tag as AudioAd;
          AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] Ya hay un anuncio en el índice objetivo final $actualTargetIndex: ${existingAd.title} (ID: ${existingAd.id}) - Omitiendo inserción duplicada');
          _isInsertingAd = false;
          return;
        }
      }
      
      // ✅ FIX CRÍTICO: Insertar anuncio PRIMERO, luego actualizar estado cuando esté confirmado
      // Esto evita inconsistencias donde el estado dice que hay anuncio pero aún no está en la cola
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] Insertando anuncio en la cola: ${ad.title} (índice objetivo: $actualTargetIndex, índice original: $targetIndex)');
      
      // ✅ OPTIMIZACIÓN: Insertar anuncio primero sin actualizar estado todavía
      final success = await _adInsertionManager!.insertAd(ad, actualTargetIndex);
      
      if (!success) {
        AppLogger.warning('[PlaybackNotifier] No se pudo insertar anuncio en la cola');
        _isInsertingAd = false;
        return;
      }
      
      // ✅ FIX CRÍTICO: Establecer timestamp de inicio cuando el anuncio se insertó correctamente
      _adStartTime = DateTime.now();
      
      // 🎯 PATRÓN "PROXY SOURCE": Guardar el ID de la canción actual para evitar duplicados
      final currentSource = service.player.sequenceState.currentSource;
      if (currentSource?.tag is Song) {
        _lastSongIdWithAd = (currentSource!.tag as Song).id;
        AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ID de canción guardado para evitar duplicados: $_lastSongIdWithAd');
      }
      
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] Timestamp de inicio establecido después de inserción exitosa: $_adStartTime');
      AppLogger.info('[PlaybackNotifier] 🎯 [PROXY SOURCE] Anuncio insertado en índice $actualTargetIndex - el reproductor nativo manejará la transición automáticamente');
      
      // 🎯 PATRÓN "PROXY SOURCE": El anuncio ya está en la cola
      // El reproductor nativo avanzará automáticamente al anuncio cuando la canción termine
      // El stream listener detectará el anuncio y actualizará el estado automáticamente
      // NO necesitamos hacer seek ni pausar - dejar que el reproductor nativo haga su trabajo
      
      // ✅ OPTIMIZACIÓN: Liberar flag inmediatamente después de insertar
      _isInsertingAd = false;
      
      // 🎯 FRECUENCIA DE ANUNCIOS: Resetear contador tras inserción exitosa
      _songsPlayedCount = 0;
      AppLogger.info('[PlaybackNotifier] 📢 [FRECUENCIA] Contador reseteado a 0 tras inserción exitosa');
      
      AppLogger.info('[PlaybackNotifier] ✅ Flag _isInsertingAd liberado');
      
      // ✅ NOTA: El estado se actualizará automáticamente cuando el stream listener detecte el anuncio
      // No necesitamos actualizar el estado aquí porque el reproductor aún está reproduciendo la canción actual
      
      AppLogger.info('[PlaybackNotifier] ✅ Anuncio insertado exitosamente: ${ad.title}');
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al insertar anuncio: $e', stackTrace);
      state = state.copyWith(
        isPlayingAd: false,
        clearCurrentAd: true,
      );
      _isInsertingAd = false;
    }
  }

  /// Manejar finalización de anuncio (completado o saltado)
  /// 🛑 CRÍTICO: Esta función DEBE resetear isPlayingAd: false SIEMPRE, incluso si hay errores
  Future<void> _handleAdCompletion(AudioAd ad, bool wasSkipped) async {
    // ✅ FIX CRÍTICO: Resetear estado INMEDIATAMENTE al inicio para garantizar que la UI reaccione
    // Esto se ejecuta ANTES de cualquier lógica que pueda fallar
    // Si el reset ya se hizo en el listener, esto lo confirma; si no, lo hace aquí
    if (state.isPlayingAd || state.currentAd != null) {
      // 🛑 FORCE CLEAR: Obtener duración de la nueva canción INMEDIATAMENTE del reproductor
      final currentSource = _service?.player.sequenceState.currentSource;
      final newSongDuration = currentSource?.duration ?? Duration.zero;
      final newSongPosition = _service?.player.position ?? Duration.zero;
      
      // Si currentSource es una canción, obtener su duración
      Song? newSong;
      Duration? songDuration;
      if (currentSource?.tag is Song) {
        newSong = currentSource!.tag as Song;
        songDuration = newSong.duration != null 
          ? Duration(seconds: newSong.duration!) 
          : (newSongDuration.inMilliseconds > 0 ? newSongDuration : Duration.zero);
      }
      
      AppLogger.info('[PlaybackNotifier] 🛑 RESETEO CRÍTICO: isPlayingAd -> false en _handleAdCompletion');
      state = state.copyWith(
        isPlayingAd: false,
        clearCurrentAd: true, // ✅ FIX CRÍTICO: Forzar reset a null
        currentPosition: newSongPosition, // 🛑 FORCE CLEAR: Resetear posición inmediatamente
        totalDuration: songDuration ?? newSongDuration, // 🛑 FORCE CLEAR: Usar duración de la nueva canción
        currentSong: newSong ?? state.currentSong, // Actualizar canción si está disponible
      );
      AppLogger.info('[PlaybackNotifier] ✅ Estado después del reset inicial: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
      AppLogger.info('[PlaybackNotifier] 🛑 [FORCE CLEAR] Duración reseteada en _handleAdCompletion: ${(songDuration ?? newSongDuration).inSeconds}s (posición: ${newSongPosition.inSeconds}s)');
    }
    
    try {
      // 1. Calcular duración reproducida
      final durationPlayed = _adStartTime != null
          ? DateTime.now().difference(_adStartTime!)
          : Duration.zero;
      
      // 2. Registrar en backend (puede fallar, pero el reset ya se hizo)
      final adsNotifier = ref.read(adsProvider.notifier);
      final currentSong = state.currentSong;
      
      try {
        await adsNotifier.logPlay(
          ad.id,
          durationSeconds: durationPlayed.inSeconds,
          wasCompleted: !wasSkipped,
          wasSkipped: wasSkipped,
          genre: currentSong?.genres?.isNotEmpty == true 
              ? currentSong!.genres!.first 
              : currentSong?.genreId,
          artist: currentSong?.artist?.stageName,
          playlistId: state.contextId,
        );
      } catch (logError) {
        // Si el logging falla, no es crítico - el reset ya se hizo
        AppLogger.warning('[PlaybackNotifier] Error al loguear anuncio (no crítico): $logError');
      }
      
      // 3. ✅ FIX CRÍTICO: Confirmar reset de estado (por si acaso)
      // Esto asegura que los widgets detecten el cambio y muestren la canción correcta
      // IMPORTANTE: Limpiar también lastConfirmedSong si estaba relacionado con el anuncio
      // ✅ FIX: No resetear duración y posición si hay una canción actual válida
      // Esto evita que los tiempos cambien cuando se presiona play después del anuncio
      final shouldPreserveTiming = state.currentSong != null;
      if (state.isPlayingAd || state.currentAd != null) {
        AppLogger.warning('[PlaybackNotifier] 🛑 ADVERTENCIA: Estado aún tiene anuncio activo, forzando reset');
        state = state.copyWith(
          isPlayingAd: false,
          clearCurrentAd: true, // ✅ FIX CRÍTICO: Forzar reset a null
          // ✅ FIX: Solo resetear duración y posición si no hay canción actual
          // Si hay canción actual, mantener los valores para evitar cambios de tiempos
          totalDuration: shouldPreserveTiming ? state.totalDuration : Duration.zero,
          currentPosition: shouldPreserveTiming ? state.currentPosition : Duration.zero,
        );
        AppLogger.info('[PlaybackNotifier] ✅ Estado después del reset de confirmación: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
      }
      
      // 4. ✅ FIX CRÍTICO: Sincronizar inmediatamente después de limpiar el estado del anuncio
      // Esto asegura que currentSong se actualice correctamente
      if (_service != null) {
        // Obtener el estado actual del reproductor
        final sequenceState = _service!.player.sequenceState;
        final currentSource = sequenceState.currentSource;
        
        // Si el reproductor ya avanzó a una canción, sincronizar y continuar reproducción INMEDIATAMENTE
        if (currentSource != null && currentSource.tag is Song) {
          final nextSong = currentSource.tag as Song;
          AppLogger.info('[PlaybackNotifier] 📢 Reproductor ya avanzó a canción después del anuncio: ${nextSong.title}');
          
          // ✅ FIX CRÍTICO: Limpiar estado del anuncio INMEDIATAMENTE antes de cualquier otra cosa
          // Esto asegura que la barra de carga se actualice inmediatamente con los valores de la canción
          if (state.isPlayingAd || state.currentAd != null) {
            final currentPos = _service!.player.position;
            // ✅ FIX CRÍTICO: Obtener duración de la canción con múltiples fallbacks para asegurar que SIEMPRE sea la duración correcta
            // Prioridad: 1) currentSource.duration, 2) nextSong.duration del modelo, 3) Duration.zero (nunca usar state.totalDuration que podría ser del anuncio)
            final songDuration = currentSource.duration ?? 
                                 (nextSong.duration != null ? Duration(seconds: nextSong.duration!) : null) ??
                                 Duration.zero;
            
            AppLogger.info('[PlaybackNotifier] 🛑 Limpiando estado del anuncio INMEDIATAMENTE y actualizando barra de carga');
            AppLogger.info('[PlaybackNotifier] 🎵 Duración de canción obtenida: ${songDuration.inSeconds}s (source: ${currentSource.duration?.inSeconds ?? "null"}, model: ${nextSong.duration ?? "null"})');
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true,
              currentSong: nextSong,
              lastConfirmedSong: nextSong,
              // ✅ FIX CRÍTICO: SIEMPRE usar songDuration, nunca state.totalDuration que podría ser del anuncio
              totalDuration: songDuration,
              currentPosition: currentPos.inMilliseconds > 0 ? currentPos : Duration.zero,
            );
            AppLogger.info('[PlaybackNotifier] ✅ Estado limpiado: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}, totalDuration=${state.totalDuration.inSeconds}s');
          }
          
          // ✅ FIX CRÍTICO: Limpiar timestamp ANTES de sincronizar para permitir actualizaciones inmediatas
          _lastAdCompletionTime = null;
          
          // ✅ FIX CRÍTICO: Sincronizar inmediatamente para actualizar currentSong SIN DELAYS
          // PERO solo si no acabamos de limpiar el estado del anuncio (para evitar actualizaciones duplicadas)
          // Si ya limpiamos el estado arriba, la duración y posición ya están correctas
          if (!(state.isPlayingAd || state.currentAd != null)) {
            // Solo sincronizar si el estado ya está limpio para evitar sobrescribir la duración correcta
            _syncQueueWithAudioService(sequenceState, forceSync: true);
          } else {
            // Si aún hay estado de anuncio, sincronizar para limpiarlo
            _syncQueueWithAudioService(sequenceState, forceSync: true);
          }
          
          // ✅ FIX CRÍTICO: Asegurar que la reproducción continúe
          if (!_service!.player.playing) {
            await _service!.play();
            AppLogger.info('[PlaybackNotifier] ▶️ Reproducción reanudada después del anuncio');
          }
        } else {
          // Si no avanzó automáticamente, sincronizar de todos modos
          _syncQueueWithAudioService(sequenceState, forceSync: true);
          
          // ✅ FIX CRÍTICO: Verificar inmediatamente si avanzó (sin delay largo)
          // El reproductor debería avanzar automáticamente cuando el anuncio termina
          if (!wasSkipped) {
            // Usar un delay muy corto solo para dar tiempo al reproductor de avanzar
            await Future.delayed(const Duration(milliseconds: 50));
            if (_service != null) {
              final updatedSequenceState = _service!.player.sequenceState;
              final updatedSource = updatedSequenceState.currentSource;
              
              // Si ahora hay una canción, sincronizar y continuar reproducción INMEDIATAMENTE
              if (updatedSource != null && updatedSource.tag is Song) {
                final nextSong = updatedSource.tag as Song;
                AppLogger.info('[PlaybackNotifier] 📢 Canción detectada después del delay corto: ${nextSong.title}');
                
                // ✅ FIX CRÍTICO: Limpiar estado del anuncio INMEDIATAMENTE antes de sincronizar
                // Esto asegura que la barra de carga se actualice inmediatamente con los valores de la canción
                if (state.isPlayingAd || state.currentAd != null) {
                  final currentPos = _service!.player.position;
                  // ✅ FIX CRÍTICO: Obtener duración de la canción con múltiples fallbacks para asegurar que SIEMPRE sea la duración correcta
                  // Prioridad: 1) updatedSource.duration, 2) nextSong.duration del modelo, 3) Duration.zero (nunca usar state.totalDuration que podría ser del anuncio)
                  final songDuration = updatedSource.duration ?? 
                                       (nextSong.duration != null ? Duration(seconds: nextSong.duration!) : null) ??
                                       Duration.zero;
                  
                  AppLogger.info('[PlaybackNotifier] 🛑 Limpiando estado del anuncio INMEDIATAMENTE y actualizando barra de carga');
                  AppLogger.info('[PlaybackNotifier] 🎵 Duración de canción obtenida: ${songDuration.inSeconds}s (source: ${updatedSource.duration?.inSeconds ?? "null"}, model: ${nextSong.duration ?? "null"})');
                  state = state.copyWith(
                    isPlayingAd: false,
                    clearCurrentAd: true,
                    currentSong: nextSong,
                    lastConfirmedSong: nextSong,
                    // ✅ FIX CRÍTICO: SIEMPRE usar songDuration, nunca state.totalDuration que podría ser del anuncio
                    totalDuration: songDuration,
                    currentPosition: currentPos.inMilliseconds > 0 ? currentPos : Duration.zero,
                  );
                  AppLogger.info('[PlaybackNotifier] ✅ Estado limpiado: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}, totalDuration=${state.totalDuration.inSeconds}s');
                }
                
                // ✅ FIX CRÍTICO: Limpiar timestamp ANTES de sincronizar para permitir actualizaciones inmediatas
                _lastAdCompletionTime = null;
                _syncQueueWithAudioService(updatedSequenceState, forceSync: true);
                if (!_service!.player.playing) {
                  await _service!.play();
                  AppLogger.info('[PlaybackNotifier] ▶️ Reproducción reanudada después del delay corto');
                }
              } else {
                // ✅ FIX: Limpiar timestamp incluso si no hay canción todavía para permitir actualizaciones futuras
                _lastAdCompletionTime = null;
                _syncQueueWithAudioService(updatedSequenceState, forceSync: true);
              }
              AppLogger.debug('[PlaybackNotifier] Estado sincronizado después del anuncio');
            }
          } else {
            // ✅ FIX: Si fue saltado, limpiar timestamp inmediatamente para permitir actualizaciones
            _lastAdCompletionTime = null;
          }
        }
      }
      
      // 5. Actualizar tracking
      // ✅ FIX CRÍTICO: Solo establecer _lastAdCompletionTime si NO se limpió arriba
      // Si ya se detectó una canción y se limpió, no volver a establecer para evitar bloquear actualizaciones
      // Esto asegura que la barra de carga se actualice inmediatamente después del segundo anuncio
      if (_lastAdCompletionTime == null) {
        // Solo establecer si aún no se limpió (para casos donde no se detectó canción inmediatamente)
        _lastAdCompletionTime = DateTime.now();
        AppLogger.info('[PlaybackNotifier] 📢 Timestamp de finalización establecido: $_lastAdCompletionTime');
      } else {
        AppLogger.info('[PlaybackNotifier] 📢 Timestamp de finalización ya limpiado, no reestableciendo');
      }
      _adStartTime = null;
      
      AppLogger.info('[PlaybackNotifier] ✅ Anuncio completado: ${ad.title} (${wasSkipped ? 'saltado' : 'completo'})');
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al manejar finalización de anuncio: $e', stackTrace);
      // ✅ FIX CRÍTICO: Limpiar estado SIEMPRE, incluso si hay error
      // Esto es crítico para que la UI se actualice correctamente
      if (state.isPlayingAd || state.currentAd != null) {
        AppLogger.warning('[PlaybackNotifier] 🛑 RESETEO DE EMERGENCIA: Limpiando estado de anuncio después de error');
        state = state.copyWith(
          isPlayingAd: false,
          clearCurrentAd: true, // ✅ FIX CRÍTICO: Forzar reset a null
        );
        AppLogger.info('[PlaybackNotifier] ✅ Estado después del reset de emergencia: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
      }
      _adStartTime = null;
      _lastAdCompletionTime = DateTime.now(); // ✅ Marcar timestamp incluso si falla
    } finally {
      // ✅ FIX CRÍTICO: Garantizar reset final en finally para asegurar que siempre se ejecute
      // Esto es la última línea de defensa para asegurar que isPlayingAd sea false
      if (state.isPlayingAd || state.currentAd != null) {
        AppLogger.warning('[PlaybackNotifier] 🛑 RESETEO FINAL EN FINALLY: Forzando limpieza de estado de anuncio');
        
        // ✅ FIX CRÍTICO: Si hay una canción reproduciéndose, actualizar con su duración correcta
        if (_service != null) {
          final sequenceState = _service!.player.sequenceState;
          final currentSource = sequenceState.currentSource;
          
          if (currentSource != null && currentSource.tag is Song) {
            final song = currentSource.tag as Song;
            final currentPos = _service!.player.position;
            final songDuration = currentSource.duration ?? 
                               (song.duration != null ? Duration(seconds: song.duration!) : null) ??
                               Duration.zero;
            
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true,
              currentSong: song,
              lastConfirmedSong: song,
              totalDuration: songDuration,
              currentPosition: currentPos.inMilliseconds > 0 ? currentPos : Duration.zero,
            );
            AppLogger.info('[PlaybackNotifier] ✅ Estado limpiado en finally con duración de canción: totalDuration=${songDuration.inSeconds}s');
          } else {
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true,
            );
          }
        } else {
          state = state.copyWith(
            isPlayingAd: false,
            clearCurrentAd: true,
          );
        }
        
        AppLogger.info('[PlaybackNotifier] ✅ Estado después del reset final: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
      }
      
      // ✅ FIX CRÍTICO: Limpiar timestamp en finally para asegurar que siempre se limpie
      _lastAdCompletionTime = null;
      
      AppLogger.debug('[PlaybackNotifier] ✅ Estado final verificado: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
    }
  }

  /// Saltar anuncio actual (llamado desde UI)
  Future<void> skipAd() async {
    final currentAd = state.currentAd;
    if (currentAd == null || !state.isPlayingAd) {
      return;
    }
    
    AppLogger.info('[PlaybackNotifier] 🛑 Saltando anuncio: ${currentAd.title}');
    
    // ✅ FIX CRÍTICO: Resetear estado INMEDIATAMENTE antes de cualquier otra operación
    // Esto asegura que la UI reaccione inmediatamente
    state = state.copyWith(
      isPlayingAd: false,
      clearCurrentAd: true, // ✅ FIX CRÍTICO: Forzar reset a null
    );
    AppLogger.info('[PlaybackNotifier] ✅ Estado después de skip: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
    
    // Registrar skip
    await _handleAdCompletion(currentAd, true); // wasSkipped = true
    
    // ✅ FIX CRÍTICO: Avanzar a siguiente canción y sincronizar inmediatamente
    if (_service != null && _service!.player.hasNext) {
      try {
        await _service!.next();
        // ✅ FIX CRÍTICO: Sincronizar inmediatamente después de avanzar SIN DELAYS
        if (_service != null) {
          _syncQueueWithAudioService(_service!.player.sequenceState, forceSync: true);
          // Limpiar timestamp de finalización para permitir actualizaciones normales
          _lastAdCompletionTime = null;
          // Asegurar que la reproducción continúe
          if (!_service!.player.playing) {
            await _service!.play();
          }
        }
      } catch (e) {
        AppLogger.error('[PlaybackNotifier] Error al avanzar después de skip: $e');
      }
    } else {
      // Si no hay siguiente canción, solo sincronizar el estado actual
      if (_service != null) {
        _syncQueueWithAudioService(_service!.player.sequenceState, forceSync: true);
        // Limpiar timestamp de finalización
        _lastAdCompletionTime = null;
      }
    }
  }

  // ============== Controles Comunes ==============

  /// Reproducir una canción individual (modo simple)
  Future<void> playSong(Song song) async {
    _activateTransitionShield(); // 🛡️ Activar escudo
    try {
      AppLogger.info('[PlaybackNotifier] 🎵 Reproduciendo canción individual: ${song.title}');
      
      // ⚡ INYECCIÓN INSTANTÁNEA: Si hay una cola activa, usar inserción rápida
      if (service.hasActiveQueue && song.isValidForPlayback) {
        try {
          AppLogger.info('[PlaybackNotifier] ⚡ Usando inyección instantánea para cambio rápido de canción');
          final source = song.toAudioSource();
          final success = await service.insertSongAtStart(source);
          
          if (success) {
            // 🔄 SINCRONIZACIÓN INMEDIATA: Esperar que just_audio actualice su estado
            await Future.delayed(const Duration(milliseconds: 50));
            
            // Sincronizar cola primero para obtener el estado real
            _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
            
            // Actualizar estado basándose en la sincronización
            // ✅ CORRECCIÓN: NO resetear currentPosition a 0 manualmente
            // Dejar que el stream de posición lo actualice para evitar parpadeos
            state = state.copyWith(
              currentSong: song,
              lastConfirmedSong: song,
              // NO actualizar currentPosition aquí - el stream lo hará automáticamente
              isBuffering: true,
            );
            
            // Reproducir inmediatamente
            await service.play();
            
            // Sincronizar una vez más después de reproducir
            _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
            
            AppLogger.info('[PlaybackNotifier] ✅ Cambio instantáneo de canción completado');
            return; // Salir aquí, ya completamos la reproducción
          } else {
            AppLogger.info('[PlaybackNotifier] Inyección instantánea falló, usando método estándar');
            // Continuar con el método estándar
          }
        } catch (e, stackTrace) {
          AppLogger.error('[PlaybackNotifier] Error en inyección instantánea, usando método estándar: $e', e, stackTrace);
          // Continuar con el método estándar
        }
      }
      
      // Método estándar (cuando no hay cola activa o la inyección falló)
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
    // ✅ FIX CRÍTICO: Marcar que estamos procesando play/pause para evitar detección de salto manual
    _isProcessingPlayPause = true;
    
    final player = service.player;
    
    // ✅ FIX CRÍTICO: Verificar qué está realmente reproduciéndose antes de hacer play/pause
    // Esto previene que se active incorrectamente el estado del anuncio cuando se presiona play durante una canción
    final sequenceState = player.sequenceState;
    final currentSource = sequenceState.currentSource;
    final currentIndex = sequenceState.currentIndex;
    final isActuallyPlayingAd = currentSource != null && currentSource.tag is AudioAd;
    
    AppLogger.info('[PlaybackNotifier] 🔍 togglePlayPause: índice=$currentIndex, tag=${currentSource?.tag.runtimeType}, isActuallyPlayingAd=$isActuallyPlayingAd, estado.isPlayingAd=${state.isPlayingAd}, estado.currentAd=${state.currentAd?.id ?? "null"}');
    
    // 🚨 PROTECCIÓN CRÍTICA: BLOQUEAR play/pause durante anuncios
    // Los anuncios NO deben poder pausarse ni detenerse
    if (isActuallyPlayingAd || state.isPlayingAd) {
      AppLogger.warning('[PlaybackNotifier] 🛑 BLOQUEO: No se puede pausar/detener durante un anuncio');
      _isProcessingPlayPause = false;
      return; // Salir inmediatamente sin hacer nada
    }
    
    // 🚨 PROTECCIÓN CRÍTICA: Si hay un anuncio siendo insertado, cancelar la inserción
    // Esto previene que el anuncio interrumpa la reproducción cuando el usuario presiona play
    if (_isInsertingAd || _isHandlingAdInsertion) {
      AppLogger.info('[PlaybackNotifier] 🛑 Cancelando inserción de anuncio porque usuario quiere hacer play/pause');
      _isInsertingAd = false;
      _isHandlingAdInsertion = false;
      
      // Limpiar estado del anuncio para evitar que se muestre en la UI
      if (state.isPlayingAd || state.currentAd != null) {
        state = state.copyWith(
          isPlayingAd: false,
          clearCurrentAd: true,
        );
        AppLogger.info('[PlaybackNotifier] ✅ Estado del anuncio limpiado en togglePlayPause');
      }
    }
    
    // ✅ FIX CRÍTICO: Si el estado dice que hay anuncio pero realmente hay una canción reproduciéndose,
    // limpiar el estado del anuncio ANTES de hacer play/pause
    if (!isActuallyPlayingAd && (state.isPlayingAd || state.currentAd != null)) {
      AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN EN togglePlayPause: Estado dice anuncio pero hay canción, limpiando estado');
      state = state.copyWith(
        isPlayingAd: false,
        clearCurrentAd: true,
      );
      AppLogger.info('[PlaybackNotifier] ✅ Estado limpiado en togglePlayPause: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}');
    }
    
    // ✅ SOLO EJECUTAR LA ACCIÓN - NO TOCAR VARIABLES LOCALES DE ESTADO
    // El StreamBuilder en el widget escucha isPlayingStream directamente
    // No necesitamos actualizar estado aquí, el stream lo hace automáticamente
    try {
      final wasPlaying = player.playing;
      if (wasPlaying) {
        AppLogger.info('[PlaybackNotifier] ⏸️ Pausando reproducción desde togglePlayPause');
        await player.pause();
        _stopAlgorithmMonitor();
      } else {
        AppLogger.info('[PlaybackNotifier] ▶️ Iniciando reproducción desde togglePlayPause');
        
        // ✅ FIX CRÍTICO: Guardar el estado ANTES de hacer play para prevenir restauración incorrecta
        final wasActuallyPlayingAdBeforePlay = isActuallyPlayingAd;
        final currentSongBeforePlay = currentSource != null && currentSource.tag is Song ? currentSource.tag as Song : null;
        
        await player.play();
        
        // ✅ FIX CRÍTICO: Después de hacer play, verificar inmediatamente qué está reproduciéndose
        // y asegurar que el estado se mantenga limpio si hay una canción
        await Future.delayed(const Duration(milliseconds: 50));
        final afterPlayState = player.sequenceState;
        final afterPlaySource = afterPlayState.currentSource;
        final afterPlayIsAd = afterPlaySource != null && afterPlaySource.tag is AudioAd;
        final afterPlayIsSong = afterPlaySource != null && afterPlaySource.tag is Song;
        
        AppLogger.info('[PlaybackNotifier] 🔍 Después de play: índice=${afterPlayState.currentIndex}, tag=${afterPlaySource?.tag.runtimeType}, isAd=$afterPlayIsAd, isSong=$afterPlayIsSong');
        
        // ✅ FIX CRÍTICO: Si hay una canción reproduciéndose, asegurar que el estado esté limpio
        // Esto previene que el stream listener restaure incorrectamente el estado del anuncio
        if (afterPlayIsSong && (state.isPlayingAd || state.currentAd != null)) {
          AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN POST-PLAY: Después de play hay canción pero estado dice anuncio, limpiando INMEDIATAMENTE');
          final afterPlaySong = afterPlaySource.tag as Song;
          state = state.copyWith(
            isPlayingAd: false,
            clearCurrentAd: true,
            // Asegurar que currentSong esté establecido
            currentSong: currentSongBeforePlay ?? afterPlaySong,
            lastConfirmedSong: currentSongBeforePlay ?? afterPlaySong,
          );
          AppLogger.info('[PlaybackNotifier] ✅ Estado limpiado POST-PLAY: isPlayingAd=${state.isPlayingAd}, currentAd=${state.currentAd?.id ?? "null"}, currentSong=${state.currentSong?.id ?? "null"}');
        }
        
        // ✅ FIX CRÍTICO: Si antes de play había una canción y después de play también hay canción,
        // pero el estado dice anuncio, limpiar el estado
        if (!wasActuallyPlayingAdBeforePlay && afterPlayIsSong && (state.isPlayingAd || state.currentAd != null)) {
          AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN POST-PLAY (consistencia): Había canción antes y después, limpiando estado del anuncio');
          state = state.copyWith(
            isPlayingAd: false,
            clearCurrentAd: true,
          );
        }
      }
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error en togglePlayPause: $e');
      // No lanzar excepción, solo loguear
    } finally {
      // ✅ FIX CRÍTICO: Liberar el flag después de un breve delay para permitir que el stream se actualice
      Future.delayed(const Duration(milliseconds: 200), () {
        _isProcessingPlayPause = false;
      });
    }
    
    // ✅ El stream (isPlayingStream) actualizará el UI automáticamente
    // NO actualizar isPlaying en el estado local - el stream es la fuente única de verdad
  }

  /// 🧹 LIMPIEZA DE ANUNCIOS HUÉRFANOS: Eliminar anuncios que siguen a la canción actual
  /// Se llama al hacer skip manual para asegurar que el siguiente item sea una canción
  Future<void> _cleanupOrphanedAds() async {
    if (_service == null) return;
    
    try {
      final sequenceState = _service!.player.sequenceState;
      final currentIndex = sequenceState.currentIndex;
      
      if (currentIndex == null) return;
      
      final sequence = sequenceState.sequence;
      final indicesToRemove = <int>[];
      
      // Buscar anuncios inmediatamente después de la canción actual
      // Solo eliminamos los que están contiguos, para no romper la cola futura
      for (int i = currentIndex + 1; i < sequence.length; i++) {
        final source = sequence[i];
        if (source.tag is AudioAd) {
          final ad = source.tag as AudioAd;
          AppLogger.info('[PlaybackNotifier] 🧹 [SKIP] Detectado anuncio huérfano para eliminar: ${ad.title} (índice $i)');
          indicesToRemove.add(i);
        } else {
          // Si encontramos una canción, detenemos la búsqueda
          // Solo queremos limpiar los anuncios que están INMEDIATAMENTE después
          break;
        }
      }
      
      if (indicesToRemove.isNotEmpty) {
        AppLogger.info('[PlaybackNotifier] 🧹 [SKIP] Eliminando ${indicesToRemove.length} anuncios huérfanos antes del salto...');
        await _service!.removeQueueItemsAt(indicesToRemove);
        AppLogger.info('[PlaybackNotifier] 🧹 [SKIP] Limpieza completada');
      }
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error en _cleanupOrphanedAds: $e');
    }
  }

  /// Siguiente canción
  /// Si estamos en una cola fija y llegamos al final, activa Radio Infinita automáticamente
  /// 🎯 DETECCIÓN MANUAL: En modo algoritmo, fuerza recarga inmediata si quedan pocas canciones
  Future<void> next() async {
    final now = DateTime.now();
    if (now.difference(_lastControlTap) < _controlDebounce) return;
    _lastControlTap = now;
    _isProcessingNext = true;
    _activateTransitionShield(); // 🛡️ Activar escudo al presionar siguiente
    state = state.copyWith(isProcessingNext: true);

    // 🧹 LIMPIEZA AGRESIVA: Eliminar anuncios huérfanos antes de saltar
    // Esto asegura que el siguiente item sea una canción
    await _cleanupOrphanedAds();

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
                    
                    // 🔄 SINCRONIZACIÓN FORZADA: Asegurar coherencia después de loadNewQueue
                    Future.delayed(const Duration(milliseconds: 200), () {
                      _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
                    });
                    
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
        
        // ⚡ SINCRONIZACIÓN INMEDIATA: Forzar actualización del estado después de cambio manual
        // Esto evita que la UI muestre la carátula anterior mientras el audio ya cambió
        await Future.delayed(const Duration(milliseconds: 50)); // Pequeño delay para que just_audio actualice
        _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
        AppLogger.debug('[PlaybackNotifier] ⚡ Estado sincronizado inmediatamente después de next()');
      } else {
        AppLogger.info('[PlaybackNotifier] ℹ️ No hay siguiente canción disponible');
        
        // 🚨 DETENER ALGORITMO: Si no hay más canciones en modo algoritmo, detener el algoritmo
        // pero NO pausar la canción actual (debe seguir reproduciéndose hasta el final)
        if (state.playbackMode == PlaybackMode.algorithm) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ No hay más canciones disponibles en modo algoritmo. Deteniendo algoritmo (la canción actual continuará reproduciéndose).');
          // Detener el monitor del algoritmo para que no intente generar más recomendaciones
          _stopAlgorithmMonitor();
          // NO pausar aquí - dejar que la canción actual termine de reproducirse
          // La pausa se hará automáticamente cuando la canción termine en _handleSongCompletion()
        }
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
  /// Canción anterior
  /// 🎯 DETECCIÓN MANUAL: En modo algoritmo, verifica estado después del salto
  Future<void> previous() async {
    _activateTransitionShield(); // 🛡️ Activar escudo al presionar anterior
    
    final now = DateTime.now();
    if (now.difference(_lastControlTap) < _controlDebounce) return;
    _lastControlTap = now;
    _isProcessingPrevious = true;
    state = state.copyWith(isProcessingPrevious: true);
    
    // En modo algoritmo, el salto hacia atrás también puede necesitar recarga
    if (state.playbackMode == PlaybackMode.algorithm) {
      // Nota: No forzamos recarga en previous() porque retroceder no reduce el buffer
    }
    
    if (_service != null && _service!.player.hasPrevious) {
      await _service!.previous();
    }
    
    // ⚡ SINCRONIZACIÓN INMEDIATA: Forzar actualización del estado
    await Future.delayed(const Duration(milliseconds: 50));
    if (_service != null) {
      _syncQueueWithAudioService(_service!.player.sequenceState, forceSync: true);
    }
    
    _isProcessingPrevious = false;
    state = state.copyWith(isProcessingPrevious: false);
  }

  /// Buscar posición
  /// Si se busca manualmente cerca del final de una cola fija, puede activar Radio Infinita
  Future<void> seek(Duration position) async {
    _lastSeekTime = DateTime.now(); // 🎯 TRIGGER 50%: Registrar seek manual
    if (_service != null) {
      await _service!.seek(position);
    }
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

  /// 🎯 PATRÓN "PROXY SOURCE": Insertar anuncio cuando la canción está a la mitad
  /// La solución profesional: Inyectar el anuncio en la cola ANTES de que la canción termine
  /// El reproductor nativo (ExoPlayer) gestionará la transición de forma perfecta
  /// porque para él, el anuncio es simplemente "la siguiente pista"
  void _checkAndPrepareNextSongTransition(Duration currentPosition) {
    if (state.currentQueue.length < 2 || state.totalDuration == Duration.zero) {
      return; // No hay siguiente canción o duración desconocida
    }

    // Obtener datos frescos del reproductor
    final playerDuration = service.player.duration ?? Duration.zero;
    final playerPosition = service.player.position;
    
    // Usar los datos del reproductor si están disponibles, sino usar los del estado
    final duration = playerDuration.inSeconds > 0 ? playerDuration : state.totalDuration;
    final position = playerPosition.inSeconds > 0 ? playerPosition : currentPosition;
    
    final sequenceState = service.player.sequenceState;
    final currentIndex = sequenceState.currentIndex;
    
    // ✅ PATRÓN PROFESIONAL: Insertar anuncio cuando la canción está al 50% de su duración
    // Esto permite que el reproductor nativo pre-cargue el anuncio mientras la canción actual sigue reproduciéndose
    // ✅ PROTECCIÓN CRÍTICA: No insertar anuncios inmediatamente después de un salto manual
    // Esperar al menos 5 segundos después de un salto manual para evitar anuncios huérfanos
    final timeSinceLastSkip = _lastManualSkipCheck != null 
        ? DateTime.now().difference(_lastManualSkipCheck!)
        : const Duration(days: 1); // Si no hay timestamp, asumir que pasó mucho tiempo
    final canInsertAfterSkip = timeSinceLastSkip.inSeconds >= 5; // Esperar 5 segundos después de un salto
    
    // ✅ FASE 3.1: "Modo Silencio" - Esperar si la Fase 3.1 está agregando canciones críticas
    // Razón: Si la Fase 3.1 está insertando canciones, los índices pueden cambiar y el anuncio quedaría en posición incorrecta
    // El anuncio debe esperar a que la cola se estabilice antes de insertarse
    // 🛡️ PRIORIDAD DE MÚSICA (FASE 2): Si estamos precargando (Fase 2), prohibido insertar anuncios
    final isQueueStable = !_isPreloading && !_isGeneratingRecommendations;

    // 🎯 TRIGGER 50% (ORGANIC CHECK): Verificar que no sea un seek reciente
    final timeSinceLastSeek = _lastSeekTime != null 
        ? DateTime.now().difference(_lastSeekTime!)
        : const Duration(days: 1);
    final isOrganicReach = timeSinceLastSeek.inSeconds >= 2; // Si hubo seek hace < 2s, no es orgánico
    
    // ✅ FASE 3.1: Log informativo cuando el trigger del 50% está esperando por cola inestable
    // ✅ FIX CRÍTICO: Debounce del log para evitar spam (máximo 1 log cada 5 segundos)
    if (duration.inSeconds > 0 && 
        position.inSeconds >= duration.inSeconds * 0.5 && 
        position.inSeconds < duration.inSeconds * 0.6 &&
        !state.isPlayingAd &&
        !_isInsertingAd &&
        !_isHandlingAdInsertion &&
        canInsertAfterSkip &&
        !isQueueStable) {
      final now = DateTime.now();
      final shouldLog = _lastTrigger50LogTime == null || 
          now.difference(_lastTrigger50LogTime!) >= const Duration(seconds: 5);
      if (shouldLog) {
        _lastTrigger50LogTime = now;
        AppLogger.info('[PlaybackNotifier] 📢 FASE 3 (ANUNCIOS): Trigger del 50% esperando (cola en mantenimiento: Fase 3.1 activa)');
      }
    }
    
    if (duration.inSeconds > 0 && 
        position.inSeconds >= duration.inSeconds * 0.5 && // ✅ 50% de la canción
        position.inSeconds < duration.inSeconds * 0.6 && // ✅ Solo una vez entre 50% y 60%
        !state.isPlayingAd &&
        !_isInsertingAd &&
        !_isHandlingAdInsertion &&
        canInsertAfterSkip && // ✅ PROTECCIÓN: No insertar si hubo salto manual reciente
        isOrganicReach &&    // 🎯 TRIGGER 50%: Solo insertar si llegó orgánicamente
        isQueueStable &&     // ✅ FASE 3.1: Esperar a que la cola esté estable (sin precarga activa)
        currentIndex != null) {
      
      // Verificar que la siguiente posición en la cola NO sea ya un anuncio
      if (currentIndex + 1 < sequenceState.sequence.length) {
        final nextSource = sequenceState.sequence[currentIndex + 1];
        if (nextSource.tag is AudioAd) {
          // Ya hay un anuncio insertado, no hacer nada
          return;
        }
      }
      
      // ✅ VERIFICAR que la misma canción no haya tenido un anuncio ya
      final currentSource = sequenceState.currentSource;
      String? triggerId;
      
      AppLogger.debug('[PlaybackNotifier] 🔍 CheckTransition: index=${sequenceState.currentIndex}, tagType=${currentSource?.tag.runtimeType}, isSong=${currentSource?.tag is Song}');
      
      if (currentSource?.tag is Song) {
        final currentSong = currentSource!.tag as Song;
        triggerId = currentSong.id;
        if (_lastSongIdWithAd == triggerId) {
          return; // Esta canción ya fue procesada (ya sea que tuvo anuncio o contó para la frecuencia)
        }
      } else {
        AppLogger.debug('[PlaybackNotifier] 🔍 CheckTransition: Tag no es Song, es ${currentSource?.tag.runtimeType} - Cancelando inserción');
        return; // 🛑 CRÍTICO: Si no es una canción (es un anuncio, etc.), NO intentar insertar otro anuncio
      }
      
      // 🎯 FRECUENCIA DE ANUNCIOS: Lógica de contador
      // Marcar esta canción como procesada para no contarla múltiples veces
      _lastSongIdWithAd = triggerId;
      
      _songsPlayedCount++;
      AppLogger.info('[PlaybackNotifier] 📢 [FRECUENCIA] Canción procesada al 50%. Contador: $_songsPlayedCount/$_adFrequencyFromAdmin');
      
      if (_songsPlayedCount < _adFrequencyFromAdmin) {
        AppLogger.info('[PlaybackNotifier] 📢 [FRECUENCIA] Umbral no alcanzado. No se insertará anuncio.');
        return;
      }
      
      AppLogger.info('[PlaybackNotifier] 📢 [FRECUENCIA] ¡Umbral alcanzado! Iniciando inserción de anuncio...');
      
      // 🎯 INSERTAR ANUNCIO EN LA COLA (Patrón Proxy Source)
      // El anuncio se inserta en currentIndex + 1, el reproductor nativo lo manejará automáticamente
      // ✅ FIX CRÍTICO: Establecer flag ANTES de llamar a _checkAndInsertAd() para evitar múltiples llamadas simultáneas
      if (_isInsertingAd) {
        // Ya hay una inserción en curso, no hacer nada
        return;
      }
      
      _isInsertingAd = true; // ✅ CRÍTICO: Establecer ANTES de la llamada asíncrona
      AppLogger.info('[PlaybackNotifier] 🎯 [PROXY SOURCE] Insertando anuncio en cola al 50% de la canción (posición: ${position.inSeconds}s/${duration.inSeconds}s)');
      
      // ✅ CRÍTICO: Usar try-finally para asegurar que el flag se libere SIEMPRE
      // incluso si _checkAndInsertAd() retorna temprano o hay un error
      _checkAndInsertAd(triggerSongId: triggerId).then((_) {
        // El flag se libera dentro de _insertAdInQueue() si la inserción es exitosa
        // Si retorna temprano, el flag se libera en el catchError
      }).catchError((e) {
        AppLogger.error('[PlaybackNotifier] 🎯 [PROXY SOURCE] Error al insertar anuncio: $e');
        _isInsertingAd = false; // Liberar flag si hay error
      });
      
      return; // No continuar con preparación normal
    }
    
    // ⚡ PREPARAR TRANSICIÓN cuando quedan 3 segundos o menos (para pre-cargar siguiente canción)
    final remainingTime = duration - position;
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
  void _syncQueueWithAudioService(SequenceState? sequenceState, {bool forceSync = false}) {
    if (sequenceState == null) {
      return; // No hay estado
    }

    // 🛡️ PROTECCIÓN: Ignorar sincronización automática durante reemplazo de cola
    // Solo permitir si es una sincronización forzada (después de loadNewQueue)
    if (!forceSync && (_isReplacingQueue || _isUpdatingQueue)) {
      return; // Ignorar sincronización automática durante operaciones críticas
    }
    
    // ✅ PROTECCIÓN CRÍTICA: No sincronizar currentSong si hay un anuncio reproduciéndose
    // Esto evita que se cambie la carátula cuando se presiona play/pause durante un anuncio
    // ✅ FIX CRÍTICO: Con forceSync, SIEMPRE verificar si realmente hay un anuncio reproduciéndose
    // Si forceSync es true, verificar el estado real del reproductor, no solo el estado de la UI
    final currentSource = sequenceState.currentSource;
    final isActuallyPlayingAd = currentSource != null && currentSource.tag is AudioAd;
    
    if (!forceSync && state.isPlayingAd && isActuallyPlayingAd) {
      // Solo sincronizar la cola, pero no currentSong cuando realmente hay un anuncio reproduciéndose
      final audioSources = sequenceState.sequence;
      final songsFromAudio = <Song>[];
      for (final source in audioSources) {
        if (source.tag is Song) {
          songsFromAudio.add(source.tag as Song);
        }
      }
      
      // Actualizar solo la cola, mantener currentSong y currentAd intactos
      if (songsFromAudio.length != state.currentQueue.length) {
        state = state.copyWith(currentQueue: songsFromAudio);
      }
      return; // No actualizar currentSong cuando hay anuncio
    }
    
    // ✅ FIX CRÍTICO: Si forceSync es true pero el estado dice que hay anuncio pero realmente no lo hay,
    // limpiar el estado del anuncio inmediatamente
    if (forceSync && (state.isPlayingAd || state.currentAd != null) && !isActuallyPlayingAd) {
      AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN: forceSync detectó que no hay anuncio pero el estado dice que sí, limpiando estado');
      state = state.copyWith(
        isPlayingAd: false,
        clearCurrentAd: true,
      );
      AppLogger.info('[PlaybackNotifier] ✅ Estado del anuncio limpiado después de forceSync');
    }

    try {
      final audioSources = sequenceState.sequence;
      if (audioSources.isEmpty) {
        // Si la cola de audio está vacía pero el estado tiene canciones, limpiar
        // Solo si no estamos en medio de una operación de reemplazo
        if (!_isReplacingQueue && !_isUpdatingQueue && (state.currentQueue.isNotEmpty || state.currentSong != null)) {
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
        // Solo reportar si la diferencia es significativa y no es una transición esperada
        // Durante loadNewQueue, puede haber un delay temporal normal
        if (forceSync || (!_isReplacingQueue && !_isUpdatingQueue)) {
          // 🛡️ REDUCIR VERBOSIDAD: Solo loggear si la diferencia es > 1 (evitar logs por transiciones menores)
          final difference = (songsFromAudio.length - state.currentQueue.length).abs();
          if (difference > 1 || forceSync) {
            AppLogger.warning('[PlaybackNotifier] ⚠️ Desincronización detectada: audio tiene ${songsFromAudio.length} canciones, estado tiene ${state.currentQueue.length}');
          }
          state = state.copyWith(currentQueue: songsFromAudio);
          if (difference > 1 || forceSync) {
            AppLogger.info('[PlaybackNotifier] ✅ Cola sincronizada con audio service');
          }
        }
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
          // Solo sincronizar si no estamos en medio de una operación de reemplazo
          if (forceSync || (!_isReplacingQueue && !_isUpdatingQueue)) {
            // ✅ FASE 3: Sincronización Incremental - Solo log si hay diferencia significativa
            // Si la diferencia es solo por inserción de anuncio (1 elemento más), usar sincronización incremental
            final audioCount = audioIds.length;
            final stateCount = stateIds.length;
            final difference = (audioCount - stateCount).abs();
            
            if (difference == 1 && (_isInsertingAd || _isHandlingAdInsertion)) {
              // ✅ Sincronización Incremental: Solo actualizar la cola sin log de "desincronización"
              // Esto es normal cuando se inserta un anuncio
              state = state.copyWith(currentQueue: songsFromAudio);
              AppLogger.debug('[PlaybackNotifier] 🔄 Sincronización incremental (inserción de anuncio): ${stateCount} → ${audioCount} canciones');
            } else {
              // Sincronización completa para diferencias mayores o cuando no hay inserción de anuncio
              AppLogger.warning('[PlaybackNotifier] ⚠️ Desincronización de IDs detectada (audio: $audioCount, estado: $stateCount), sincronizando...');
              state = state.copyWith(currentQueue: songsFromAudio);
              AppLogger.info('[PlaybackNotifier] ✅ IDs sincronizados con audio service');
            }
          }
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
        // ✅ PROTECCIÓN CRÍTICA: Verificar que no hay un anuncio reproduciéndose antes de actualizar currentSong
        // Esto evita que se cambie la carátula cuando se presiona play/pause durante o después de un anuncio
        final currentSourceForCheck = sequenceState.currentSource;
        final isCurrentlyPlayingAd = currentSourceForCheck != null && currentSourceForCheck.tag is AudioAd;
        
        // ✅ PROTECCIÓN: No actualizar currentSong si hay un anuncio reproduciéndose
        // ✅ FIX CRÍTICO: Con forceSync, SIEMPRE actualizar incluso si el estado dice que hay anuncio
        // porque forceSync se usa después de que termina un anuncio para sincronizar el estado
        if (isCurrentlyPlayingAd && state.isPlayingAd && !forceSync) {
          // Hay un anuncio reproduciéndose, no actualizar currentSong (solo si no es forceSync)
          AppLogger.debug('[PlaybackNotifier] ⏸️ Omitiendo actualización de currentSong: hay anuncio reproduciéndose');
          return;
        }
        
        // ✅ FIX CRÍTICO: Si forceSync es true y hay una canción pero el estado dice que hay anuncio,
        // limpiar el estado del anuncio antes de actualizar currentSong
        if (forceSync && !isCurrentlyPlayingAd && (state.isPlayingAd || state.currentAd != null)) {
          AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN: forceSync detectó canción pero estado dice anuncio, limpiando antes de actualizar');
          state = state.copyWith(
            isPlayingAd: false,
            clearCurrentAd: true,
          );
        }
        
        // ✅ FUENTE DE VERDAD REAL: Obtener la canción directamente del tag del reproductor
        // Igual que el stream listener, para garantizar consistencia
        Song? songAtIdx;
        final currentSource = sequenceState.currentSource;
        if (currentSource != null && currentSource.tag is Song) {
          // ✅ PRIORIDAD: Usar el tag del reproductor como fuente de verdad
          songAtIdx = currentSource.tag as Song;
          AppLogger.info('[PlaybackNotifier] 🎵 _syncQueue: Canción obtenida del tag del reproductor: ${songAtIdx.title} (índice: $currentIdx)');
        } else if (currentIdx >= 0 && currentIdx < songsFromAudio.length) {
          // Fallback: usar la cola si el tag no está disponible
          songAtIdx = songsFromAudio[currentIdx];
          AppLogger.warning('[PlaybackNotifier] ⚠️ _syncQueue: Usando fallback de cola: ${songAtIdx.title} (índice: $currentIdx)');
        } else {
          // No hay canción disponible
          AppLogger.warning('[PlaybackNotifier] ⚠️ _syncQueue: No se pudo obtener canción: índice=$currentIdx, colaLength=${songsFromAudio.length}');
          return;
        }
        // ✅ PROTECCIÓN OPTIMIZADA: Verificar si hay nueva canción ANTES de aplicar protecciones
        // Esto asegura que la barra de carga se actualice inmediatamente después de cada anuncio
        final isNewSongAfterAd = currentSource != null && currentSource.tag is Song && 
                                 (state.currentSong == null || state.currentSong?.id != songAtIdx.id);
        
        if (_lastAdCompletionTime != null) {
          // ✅ FIX CRÍTICO: Si hay una nueva canción después del anuncio, SIEMPRE actualizar inmediatamente
          // Esto asegura que la barra de carga se actualice inmediatamente después de cada anuncio
          if (isNewSongAfterAd) {
            AppLogger.info('[PlaybackNotifier] 🔄 Nueva canción después del anuncio: limpiando protección y actualizando inmediatamente');
            _lastAdCompletionTime = null; // Limpiar inmediatamente para permitir actualizaciones
            // Continuar con la actualización - NO retornar aquí
          } else {
            final timeSinceAdCompletion = DateTime.now().difference(_lastAdCompletionTime!);
            final isSameSong = state.currentSong?.id == songAtIdx.id;
            
            // ✅ FIX CRÍTICO: Si el usuario está avanzando manualmente, SIEMPRE actualizar el visual
            if (_isProcessingNext) {
              AppLogger.info('[PlaybackNotifier] 🔄 Avance manual detectado: actualizando visual forzadamente');
              // Continuar con la actualización, no retornar aquí
            } else if (forceSync) {
              // ✅ FIX CRÍTICO: Si es forceSync después de un anuncio, SIEMPRE actualizar el visual
              // Esto asegura que el visual se actualice correctamente cuando termina un anuncio
              AppLogger.info('[PlaybackNotifier] 🔄 ForceSync después de anuncio: actualizando visual forzadamente');
              // Continuar con la actualización, no retornar aquí
            } else if (isSameSong && timeSinceAdCompletion < const Duration(milliseconds: 300)) {
              // ✅ OPTIMIZACIÓN: Solo bloquear cambios de canción si es la misma canción y muy reciente
              // Pero permitir actualizaciones de posición y duración para que la barra funcione
              AppLogger.debug('[PlaybackNotifier] ⏳ Protección activa: misma canción después del anuncio (${timeSinceAdCompletion.inMilliseconds}ms), solo bloqueando cambios de canción');
              // NO retornar aquí - permitir actualizaciones de posición y duración
            } else {
              // Si pasó suficiente tiempo, limpiar el timestamp
              _lastAdCompletionTime = null;
            }
          }
        }
        
        // ✅ PROTECCIÓN: No actualizar currentSong si acabamos de terminar un anuncio (fallback)
        // Esperar a que el listener principal detecte el cambio de anuncio a canción
        if (state.isPlayingAd && !isCurrentlyPlayingAd && !forceSync) {
          // El anuncio acaba de terminar, el listener principal manejará la transición
          return;
        }
        
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
        
        // ✅ PROTECCIÓN OPTIMIZADA: Verificar si hay nueva canción ANTES de aplicar protecciones
        // Esto asegura que la barra de carga se actualice inmediatamente después de cada anuncio
        final isNewSongInSync = currentSource != null && currentSource.tag is Song && 
                                 (currentSongId == null || currentSongId != songAtIdx.id);
        final isSameSong = currentSongId != null && currentSongId == songAtIdx.id;
        final isProcessingPlayPause = _isProcessingPlayPause;
        
        // ✅ FIX CRÍTICO: Si hay una nueva canción después del anuncio, SIEMPRE actualizar inmediatamente
        // Esto asegura que la barra de carga se actualice inmediatamente después de cada anuncio
        if (isNewSongInSync && _lastAdCompletionTime != null) {
          AppLogger.info('[PlaybackNotifier] 🔄 Nueva canción detectada en sync: limpiando protección y actualizando inmediatamente');
          _lastAdCompletionTime = null; // Limpiar inmediatamente para permitir actualizaciones
          // Continuar con la actualización - NO retornar aquí
        } else if (isSameSong && _lastAdCompletionTime != null) {
          final timeSinceAdCompletion = DateTime.now().difference(_lastAdCompletionTime!);
          // ✅ FIX CRÍTICO: Si el usuario está avanzando manualmente, SIEMPRE actualizar el visual
          // ✅ FIX: Si es forceSync después de un anuncio, actualizar siempre (no retornar aquí)
          // ✅ FIX CRÍTICO: Si estamos procesando play/pause, solo actualizar posición, NO duración
          if (!_isProcessingNext && !forceSync && timeSinceAdCompletion < const Duration(milliseconds: 300)) {
            // ✅ OPTIMIZACIÓN: Solo actualizar posición si es válida, pero permitir actualizaciones de duración
            // Esto asegura que la barra de carga funcione correctamente
            if (currentPos.inMilliseconds > 0) {
              state = state.copyWith(currentPosition: currentPos);
            }
            // NO retornar aquí - permitir actualizaciones de duración para que la barra funcione
          } else {
            // Si pasó suficiente tiempo o es forceSync/avance manual, limpiar el timestamp
            _lastAdCompletionTime = null;
          }
        }
        
        // ✅ FIX CRÍTICO: Si estamos procesando play/pause y es la misma canción, NO actualizar duración
        // Esto evita que cambien los tiempos cuando se presiona play/pause
        if (isProcessingPlayPause && isSameSong) {
          // Solo actualizar posición si es válida, mantener duración actual
          if (currentPos.inMilliseconds > 0) {
            state = state.copyWith(currentPosition: currentPos);
          }
          return; // No actualizar duración ni canción durante play/pause
        }
        
        // ✅ CORRECCIÓN: Actualizar posición solo si es válida (mayor que 0) o si la canción cambió
        // Esto evita que la barra parpadee cuando se sincroniza
        final shouldUpdatePosition = currentPos.inMilliseconds > 0 || 
                                     (currentSongId != null && currentSongId != songAtIdx.id);
        final positionToUse = shouldUpdatePosition ? currentPos : state.currentPosition;

        // ✅ FIX CRÍTICO: Si es forceSync después de un anuncio o avance manual, SIEMPRE actualizar currentSong y lastConfirmedSong
        // Esto asegura que el visual se actualice correctamente cuando termina un anuncio o cuando el usuario avanza manualmente
        final shouldForceUpdateAfterAd = forceSync && 
                                        _lastAdCompletionTime != null && 
                                        DateTime.now().difference(_lastAdCompletionTime!) < const Duration(seconds: 2);
        final shouldForceUpdateManual = _isProcessingNext; // ✅ FIX CRÍTICO: Avance manual siempre actualiza visual
        
        // ✅ FIX CRÍTICO: Si cambió la canción después del anuncio, SIEMPRE actualizar la duración
        // Esto asegura que la barra de tiempo muestre la duración correcta de la nueva canción
        final songChanged = currentSongId != null && currentSongId != songAtIdx.id;
        final durationToUse = (songChanged || forceSync || shouldForceUpdateAfterAd) 
            ? (currentDuration ?? (songAtIdx.duration != null ? Duration(seconds: songAtIdx.duration!) : null))
            : (currentDuration ?? state.totalDuration);

        // ✅ FIX CRÍTICO: Si hay una canción reproduciéndose, limpiar estado del anuncio inmediatamente
        // Esto asegura que el visual del anuncio se oculte cuando se detecta una canción
        final shouldClearAdState = currentSource != null && currentSource.tag is Song && (state.isPlayingAd || state.currentAd != null);
        
        // ✅ FIX CRÍTICO: Si cambió la canción, SIEMPRE actualizar currentSong y lastConfirmedSong
        // Esto asegura que ambos reproductores muestren la información correcta
        final shouldUpdateSong = songChanged || 
                                 shouldForceUpdateAfterAd || // Si es forceSync después de anuncio, actualizar
                                 shouldForceUpdateManual || // Si es avance manual, actualizar
                                 shouldClearAdState; // Si hay que limpiar estado de anuncio, actualizar
        
        // Si aún no cambia la canción y no hay razón para actualizar, solo actualizar posición y duración
        if (!shouldUpdateSong && currentSongId != null && currentSongId == songAtIdx.id) {
          // ✅ CORRECCIÓN: Aún así actualizar la posición y duración si es válida para mantener la barra fluida
          state = state.copyWith(
            currentPosition: currentPos.inMilliseconds > 0 ? currentPos : state.currentPosition,
            totalDuration: durationToUse ?? state.totalDuration,
          );
          return;
        } else {
          // Solo cambiar currentSong cuando el índice cambia o estaba vacío
          // O cuando es forceSync después de un anuncio o avance manual (para actualizar el visual)
          // ✅ FIX CRÍTICO: Limpiar estado del anuncio cuando se actualiza currentSong
          // #region agent log
          AppLogger.debugLog('playback_notifier.dart:3683', 'BEFORE update currentSong', {
            'shouldClearAdState': shouldClearAdState,
            'currentSongId': songAtIdx.id,
            'isPlayingAd': state.isPlayingAd,
            'currentAdId': state.currentAd?.id
          }, 'F');
          // #endregion
          
          // ✅ FIX CRÍTICO: Si hay que limpiar estado de anuncio, SIEMPRE usar duración y posición de la canción
          // Esto asegura que la barra de carga se actualice inmediatamente con los valores correctos
          // NUNCA usar state.totalDuration cuando se limpia estado de anuncio, ya que podría ser la duración del anuncio
          // ✅ FIX CRÍTICO: Detectar si la duración actual es sospechosamente corta (podría ser del anuncio)
          // Los anuncios suelen ser cortos (≤30 segundos), las canciones son más largas
          // Si forceSync viene después de limpiar el estado del anuncio, la duración ya debería estar correcta
          final currentDurationMightBeAd = state.totalDuration.inSeconds > 0 && 
                                           state.totalDuration.inSeconds <= 30 && 
                                           (songAtIdx.duration == null || songAtIdx.duration! > 30);
          
          // ✅ FIX CRÍTICO: Si forceSync viene después de limpiar el estado del anuncio arriba,
          // la duración ya está correcta y NO debe sobrescribirse
          // Verificar si la duración actual es válida (mayor a 30 segundos = canción, no anuncio)
          final wasJustClearedAbove = forceSync && 
                                      !state.isPlayingAd && 
                                      state.currentAd == null &&
                                      state.currentSong?.id == songAtIdx.id &&
                                      state.totalDuration.inSeconds > 30; // Ya tiene duración correcta de canción
          
          // ✅ FIX CRÍTICO: Si acabamos de limpiar el estado del anuncio y la duración ya es correcta,
          // NO sobrescribirla con currentDuration que podría ser null o incorrecto
          // Si shouldClearAdState es true pero ya tenemos una duración válida (>30s), preservarla
          final finalDurationToUse = shouldClearAdState 
              ? (wasJustClearedAbove 
                  ? state.totalDuration // ✅ Ya está correcta, no sobrescribir
                  : (currentDuration ?? (songAtIdx.duration != null ? Duration(seconds: songAtIdx.duration!) : null) ?? 
                     (state.totalDuration.inSeconds > 30 ? state.totalDuration : Duration.zero))) // Preservar duración válida existente
              : (wasJustClearedAbove
                  ? state.totalDuration // ✅ Ya está correcta, no sobrescribir
                  : (currentDurationMightBeAd
                      ? (currentDuration ?? (songAtIdx.duration != null ? Duration(seconds: songAtIdx.duration!) : null) ?? Duration.zero)
                      : ((shouldUpdateSong || forceSync) 
                          ? (currentDuration ?? (songAtIdx.duration != null ? Duration(seconds: songAtIdx.duration!) : null) ?? state.totalDuration)
                          : (currentDuration ?? (songAtIdx.duration != null ? Duration(seconds: songAtIdx.duration!) : null) ?? state.totalDuration))));
          final finalPositionToUse = shouldClearAdState && currentPos.inMilliseconds > 0
              ? currentPos
              : positionToUse;
          
          state = state.copyWith(
            currentSong: songAtIdx,
            // ✅ FIX CRÍTICO: Limpiar estado del anuncio cuando se detecta una canción usando clearCurrentAd
            isPlayingAd: shouldClearAdState ? false : state.isPlayingAd,
            clearCurrentAd: shouldClearAdState, // ✅ FIX CRÍTICO: Forzar reset a null cuando hay canción
            // ✅ FIX CRÍTICO: Si hay que limpiar estado de anuncio, usar duración y posición de la canción INMEDIATAMENTE
            // 🛡️ SINCRONIZACIÓN SUAVE: No resetear a 0.0 si hay inconsistencia, usar valores actuales o preservados
            currentPosition: finalPositionToUse.inMilliseconds > 0 ? finalPositionToUse : state.currentPosition,
            totalDuration: finalDurationToUse.inMilliseconds > 0 ? finalDurationToUse : state.totalDuration,
            lastConfirmedSong: songAtIdx, // ✅ FUENTE DE VERDAD: Usar canción del tag del reproductor
          );
          // #region agent log
          AppLogger.debugLog('playback_notifier.dart:3690', 'AFTER update currentSong', {
            'isPlayingAd': state.isPlayingAd,
            'currentAdId': state.currentAd?.id,
            'currentSongId': state.currentSong?.id
          }, 'F');
          // #endregion
          final updateReason = shouldForceUpdateManual 
              ? " (avance manual)" 
              : (shouldForceUpdateAfterAd ? " (forceSync después de anuncio)" : "");
          AppLogger.info('[PlaybackNotifier] ✅ Canción sincronizada: ${songAtIdx.title}$updateReason (fuente: tag del reproductor)');
        }
      } else {
        // Sin índice válido: si tenemos una confirmada previa, mantenerla para evitar flashes
        // ✅ CORRECCIÓN: NO resetear currentPosition a 0 si ya hay una posición válida
        // Esto evita que la barra de progreso parpadee cuando se sincroniza
        if (state.currentSong == null && state.lastConfirmedSong != null) {
          // Mantener la posición actual si existe, solo actualizar la canción
          final currentPos = service.player.position;
          state = state.copyWith(
            currentSong: state.lastConfirmedSong,
            currentPosition: currentPos.inMilliseconds > 0 ? currentPos : state.currentPosition,
          );
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

    // 🛡️ PROTECCIÓN CRÍTICA: No deduplicar inmediatamente después de inyección instantánea
    // La inyección puede causar una diferencia temporal de 1 canción, lo cual es normal
    // Si deduplicamos aquí, destruimos el reproductor (loadNewQueue) y anulamos el beneficio de la inyección
    if (_lastInjectionTime != null) {
      final timeSinceInjection = DateTime.now().difference(_lastInjectionTime!);
      if (timeSinceInjection < _injectionProtectionWindow) {
        AppLogger.debug('[PlaybackNotifier] 🛡️ [DEDUP] Omitiendo deduplicación: dentro de ventana de protección post-inyección (${timeSinceInjection.inMilliseconds}ms)');
        return; // Aún en ventana de protección post-inyección
      }
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
        
        // 🚨 CRÍTICO: SIEMPRE intentar eliminación suave primero para evitar Release/Init
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] 🚨 INICIANDO ELIMINACIÓN SUAVE PRIMERO...');
        
        // 🚨 DEBUG: Verificar que llegamos aquí ANTES de calcular índices
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] 🚨 DEBUG 1: Antes de calcular newIndex');
        
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
        
        // 🚨 DEBUG: Verificar que llegamos aquí DESPUÉS de calcular índices
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] 🚨 DEBUG 2: Después de calcular newIndex = $newIndex');
        
        // 🚨 ACTUALIZAR REALMENTE la cola del audio service con canciones únicas
        // Preservar la posición actual si seguimos en la misma canción
        final currentPosition = service.player.position;
        // 🔄 CRÍTICO: Guardar estado de reproducción ANTES de modificar la cola
        final wasPlaying = service.player.playing;
        
        // 🚨 DEBUG: Verificar que llegamos aquí DESPUÉS de obtener estado del player
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] 🚨 DEBUG 3: wasPlaying = $wasPlaying, currentPosition = $currentPosition');
        
        _isUpdatingQueue = true; // Marcar que estamos actualizando para evitar sincronizaciones
        
        // 🚨 DEBUG: Verificar que llegamos aquí ANTES del bloque try
        AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] 🚨 DEBUG 4: Llegamos al bloque try, intentando eliminación suave...');
        
        try {
          // 🛡️ INTENTAR MÉTODO SUAVE PRIMERO: Usar removeDuplicates si es posible
          // Esto preserva el pipeline del reproductor (solo flush/start, sin Release/Init)
          AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] Intentando eliminación suave primero (${duplicateIndices.length} duplicados)...');
          final softRemoveSuccess = await service.removeDuplicates(duplicateIndices);
          AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] Resultado eliminación suave: $softRemoveSuccess');
          
          if (softRemoveSuccess) {
            // ✅ Éxito con método suave: solo actualizar estado, no destruir reproductor
            AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP] ✅ Eliminación suave exitosa (sin Release/Init)');
            
            // Sincronizar el estado con la cola actualizada
            await Future.delayed(const Duration(milliseconds: 50));
            _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
            
            // Actualizar estado con cola deduplicada
            state = state.copyWith(
              currentQueue: songsFromAudio,
              isPlaying: wasPlaying, // Preservar estado de reproducción
            );
          } else {
            // ❌ Fallback a método destructivo: solo si el método suave falla
            AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] ⚠️ Eliminación suave falló, usando loadNewQueue (destructivo)');
            
            // ⚡ OPTIMIZACIÓN: Preservar estado ANTES de loadNewQueue para minimizar pausa
            final wasPlayingBeforeLoad = service.player.playing;
            final positionBeforeLoad = service.player.position;
            
            final uniqueSources = songsFromAudio.map((s) => s.toAudioSource()).toList();
            await service.loadNewQueue(uniqueSources, newIndex);
            
            // ⚡ OPTIMIZACIÓN: Restaurar posición y reproducción INMEDIATAMENTE después de cargar
            // Esto minimiza la pausa perceptible
            if (currentSongId != null && newIndex < songsFromAudio.length && songsFromAudio[newIndex].id == currentSongId) {
              final songDuration = songsFromAudio[newIndex].duration;
              if (songDuration == null || positionBeforeLoad < Duration(seconds: songDuration)) {
                try {
                  await service.player.seek(positionBeforeLoad);
                  AppLogger.debug('[PlaybackNotifier] 🛡️ [DEDUP] ⚡ Posición restaurada: ${positionBeforeLoad.inSeconds}s');
                } catch (_) {
                  // Ignorar si no se puede restaurar
                }
              }
            }
            
            // 🔄 CRÍTICO: Reanudar reproducción INMEDIATAMENTE si estaba reproduciendo antes
            // loadNewQueue pausa el reproductor, necesitamos reanudarlo lo más rápido posible
            if (wasPlayingBeforeLoad) {
              // Intentar reanudar inmediatamente sin delay adicional
              try {
                await service.play();
                AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP] ▶️ Reproducción reanudada inmediatamente después de deduplicación');
              } catch (e) {
                AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] ⚠️ Error al reanudar reproducción: $e');
                // Reintentar después de un pequeño delay
                await Future.delayed(const Duration(milliseconds: 100));
                try {
                  await service.play();
                  AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP] ▶️ Reproducción reanudada después de reintento');
                } catch (_) {
                  // Si falla de nuevo, continuar sin reproducir
                }
              }
            }
            
            // Actualizar estado con cola deduplicada y estado de reproducción
            state = state.copyWith(
              currentQueue: songsFromAudio,
              isPlaying: wasPlayingBeforeLoad, // Preservar estado de reproducción original
            );
          }
        } finally {
          _isUpdatingQueue = false;
          
          // 🔄 SINCRONIZACIÓN FORZADA: Esperar un momento para que just_audio actualice su estado
          Future.delayed(const Duration(milliseconds: 200), () {
            _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
          });
        }
        
        // 📊 CALCULAR IMPACTO DESPUÉS DE ACTUALIZAR
        final queueSizeAfter = songsFromAudio.length;
        final remainingSongsAfter = _getRemainingQueueSize();
        
        AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] 📊 Estado DESPUÉS:');
        AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Total canciones: $queueSizeAfter (${queueSizeBefore - queueSizeAfter} eliminadas)');
        AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Canciones restantes: ${remainingSongsAfter >= 0 ? remainingSongsAfter : "N/A"} ${remainingSongsBefore >= 0 && remainingSongsAfter >= 0 && remainingSongsBefore != remainingSongsAfter ? "(${remainingSongsBefore - remainingSongsAfter} menos)" : ""}');
        AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME]    • Índice actualizado: ${currentIndex ?? "N/A"} → $newIndex');
        AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] ✅ Deduplicación completada: ${songsFromAudio.length} únicas (${duplicateIndices.length} duplicados eliminados del audio service)');
        AppLogger.info('[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] ════════════════════════════════════════');
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
    // ✅ FIX CRÍTICO: Si es la misma canción que está reproduciéndose, solo hacer toggle play/pause
    // Esto evita que se cambie la carátula cuando se presiona play después de un anuncio
    if (song != null && state.currentSong?.id == song.id) {
      AppLogger.info('[PlaybackNotifier] 🎵 Misma canción detectada, solo haciendo toggle play/pause');
      await togglePlayPause();
      return; // Salir aquí, no reiniciar la reproducción
    }
    
    // ✅ PROTECCIÓN: Si acabamos de terminar un anuncio, esperar un poco antes de cambiar de canción
    // Esto da tiempo para que el listener principal sincronice correctamente el estado
    if (_lastAdCompletionTime != null && song != null) {
      final timeSinceAdCompletion = DateTime.now().difference(_lastAdCompletionTime!);
      if (timeSinceAdCompletion < const Duration(milliseconds: 500)) {
        AppLogger.info('[PlaybackNotifier] ⏳ Esperando sincronización después del anuncio (${timeSinceAdCompletion.inMilliseconds}ms)...');
        await Future.delayed(const Duration(milliseconds: 500) - timeSinceAdCompletion);
      }
    }
    
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
    
    // 🚨 PROTECCIÓN CRÍTICA: Si hay un anuncio siendo insertado, cancelar la inserción
    // Esto previene que el anuncio interrumpa la reproducción de la nueva canción
    if (_isInsertingAd || _isHandlingAdInsertion) {
      AppLogger.info('[PlaybackNotifier] 🛑 Cancelando inserción de anuncio porque usuario quiere reproducir canción: ${song?.title ?? "N/A"}');
      _isInsertingAd = false;
      _isHandlingAdInsertion = false;
      
      // Limpiar estado del anuncio para evitar que se muestre en la UI
      if (state.isPlayingAd || state.currentAd != null) {
        state = state.copyWith(
          isPlayingAd: false,
          clearCurrentAd: true,
        );
        AppLogger.info('[PlaybackNotifier] ✅ Estado del anuncio limpiado antes de reproducir canción');
      }
      
      // Verificar si hay un anuncio en la cola y removerlo si es necesario
      if (_service != null) {
        final sequenceState = _service!.player.sequenceState;
        final currentSource = sequenceState.currentSource;
        if (currentSource?.tag is AudioAd) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ Detectado anuncio en cola, será reemplazado por la nueva canción');
        }
      }
    }
    
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
        
        // ⚡ INYECCIÓN INSTANTÁNEA: Si hay una cola activa, usar inserción rápida
        if (service.hasActiveQueue && song.isValidForPlayback) {
          try {
            AppLogger.info('[PlaybackNotifier] ⚡ Usando inyección instantánea para cambio rápido de canción');
            final source = song.toAudioSource();
            final success = await service.insertSongAtStart(source);
            
            if (success) {
              // 🛡️ PROTECCIÓN: Marcar tiempo de inyección para evitar deduplicación inmediata
              _lastInjectionTime = DateTime.now();
              
              // 🔄 SINCRONIZACIÓN INMEDIATA: Esperar que just_audio actualice su estado
              await Future.delayed(const Duration(milliseconds: 50));
              
              // 🔄 CRÍTICO: Sincronizar PRIMERO para actualizar el estado con la nueva cola
              // Esto evita que la deduplicación detecte una desincronización falsa
              _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
              
              // 🔄 ACTUALIZACIÓN EXPLÍCITA: Asegurar que el estado refleje la cola correcta
              // ✅ CORRECCIÓN: NO resetear currentPosition a 0 manualmente
              // Dejar que el stream de posición lo actualice para evitar parpadeos
              final syncedState = state;
              state = syncedState.copyWith(
                currentSong: song,
                lastConfirmedSong: song,
                // NO actualizar currentPosition aquí - el stream lo hará automáticamente
                isBuffering: true,
                // currentQueue ya fue actualizado por _syncQueueWithAudioService
              );
              
              AppLogger.debug('[PlaybackNotifier] 🔄 Estado sincronizado después de inyección: ${state.currentQueue.length} canciones');
              
              // Reproducir inmediatamente
              await service.play();
              
              // Sincronizar una vez más después de reproducir
              _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
              
              AppLogger.info('[PlaybackNotifier] ✅ Cambio instantáneo de canción completado');
              return; // Salir aquí, ya completamos la reproducción
            } else {
              AppLogger.info('[PlaybackNotifier] Inyección instantánea falló, usando método estándar');
              // Continuar con el método estándar
            }
        } catch (e, stackTrace) {
          AppLogger.error('[PlaybackNotifier] Error en inyección instantánea, usando método estándar: $e', e, stackTrace);
          // Continuar con el método estándar
        }
      }
      
      // Método estándar (cuando no hay cola activa o la inyección falló)
      await playSong(song);
      }
      
      // ⚡ OPTIMIZACIÓN: Actualizar estado de buffering de forma asíncrona sin bloquear
      // No esperar delay - actualizar inmediatamente y dejar que el stream maneje el resto
      final actualPlayerState = service.player.playerState;
      final actualIsBuffering = actualPlayerState.processingState == ProcessingState.buffering ||
                               actualPlayerState.processingState == ProcessingState.loading;
      
      state = state.copyWith(
        isBuffering: actualIsBuffering,
      );
      
      AppLogger.info('[PlaybackNotifier] Reproducción desde tarjeta iniciada');
      
    } finally {
      // ⚡ OPTIMIZACIÓN: Reducir delay de liberación de flag para respuesta más rápida
      // El flag solo necesita mantenerse el tiempo mínimo necesario
      Future.delayed(const Duration(milliseconds: 500), () {
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

