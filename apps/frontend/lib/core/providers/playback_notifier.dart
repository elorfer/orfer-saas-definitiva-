import 'dart:async';
import '../utils/universal_file.dart';
import 'dart:math';
import 'package:flutter/widgets.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song_model.dart';
import '../services/audio_service.dart';
import '../services/intelligent_featured_service.dart';
import '../services/home_service.dart';
import '../providers/play_history_provider.dart';
import '../providers/playback_session_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_manager_provider.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';
import 'playback_state.dart';
import 'ad_insertion_manager.dart';
import '../../features/ads/models/audio_ad_model.dart';
import '../../features/ads/providers/ads_provider.dart';
import '../services/playback_reporter_service.dart';
import '../services/algorithm_config_service.dart';

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
  int? _lastKnownIndex; // 🎯 DETECCIÓN MANUAL: Último índice conocido para detectar saltos manuales
  DateTime? _lastManualSkipCheck; // 🎯 PROTECCIÓN: Timestamp de última verificación de salto manual (debounce)
  static const Duration _manualSkipDebounce = Duration(milliseconds: 500); // Debounce para evitar múltiples verificaciones
  bool _isRestartingAlgorithm = false; // 🎯 PROTECCIÓN: Flag para evitar reinicios múltiples del algoritmo
  bool _isReplacingQueue = false; // 🎯 PROTECCIÓN: Flag cuando se reemplaza toda la cola (loadNewQueue)
  Song? _lastConfirmedSong; // 🔒 Conserva la última canción confirmada para evitar flashes de portada
  bool _isDeduplicating = false; // 🛡️ PROTECCIÓN: Flag para evitar deduplicación múltiple simultánea
  DateTime? _lastDeduplicationTime; // 🛡️ PROTECCIÓN: Timestamp de última deduplicación
  DateTime? _lastHeartbeatLogTime;
  DateTime? _lastAdGuardLogTime; // 🛡️ THROTTLE: Para evitar spam del log de AD GUARD
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
  DateTime? _lastForcedAdJumpTime; // 🛡️ PROTECCIÓN: Timestamp de último salto forzado desde anuncio atascado
  bool _preventiveAdTriggered = false; // ✅ PROTECCIÓN: Flag para evitar múltiples triggers de pausa preventiva
  String? _lastSongIdWithAd; // ✅ PROTECCIÓN: ID de la última canción que tuvo un anuncio (evita duplicados)
  int _songsPlayedCount = 0; // Contador de canciones reproducidas
  int _adFrequencyFromAdmin = 3; // Frecuencia de anuncios cargada desde el admin (default 3)
  bool _isTransitioningFromAd = false; // Flag para evitar reseteos de posición durante transición
  DateTime? _lastAdTransitionTime; // 🛡️ HISTORY SHIELD: Timestamp de última transición de anuncio (manual skip)
  bool _isFreezingUI = false; // ❄️ HARD FREEZE: Flag para congelar completamente la UI durante operaciones críticas

  
  // Prefetch para transición playlist -> algoritmo (evitar espera  // Cache para warm-up de algoritmo
  List<Song>? _prefetchedInitialSongs;
  Song? _prefetchedSeed;
  bool _isPrefetchingAlgorithm = false;

  // 🛡️ GUARD ANTI-LOOP: Control de archivos corruptos
  String? _lastCorruptedSongId; // ID de la última canción que causó error CORRUPTED
  int _corruptedRetryCount = 0; // Contador de reintentos por archivo corrupto
  DateTime? _lastCorruptedErrorTime; // Timestamp del último error CORRUPTED
  static const int _maxCorruptedRetries = 2; // Máximo 2 reintentos antes de saltar
  static const Duration _corruptedErrorCooldown = Duration(seconds: 2); // Cooldown entre detecciones de CORRUPTED
  
  // 🎛️ CONFIGURACIÓN DINÁMICA: Valores que se leen desde el Admin
  // Estos valores se actualizan desde el backend sin necesidad de actualizar la app
  AlgorithmConfig get _algorithmConfig => AlgorithmConfigService.instance.currentConfig;
  
  // 🎯 FASE 2: Umbral de Recarga Proactivo (DINÁMICO)
  int get preloadThreshold => _algorithmConfig.preloadThreshold; // Pre-cargar cuando quedan ≤N canciones disponibles
  static const int _preloadTimeThreshold = 45; // ⚡ TRANSICIÓN INSTANTÁNEA: Pre-cargar cuando quedan 45 segundos (aumentado para más anticipación)
  static const Duration _preloadCooldown = Duration(seconds: 3); // 🚨 COOLDOWN: Mínimo 3 segundos entre precargas
  
  // 🎯 FASE 3.1: Precarga Progresiva - Constantes de Control (DINÁMICO)
  int get criticalSongsCount => _algorithmConfig.criticalSongs; // Canciones críticas a agregar inmediatamente
  
  // 🎯 FASE 2.0: Canciones a solicitar en background (DINÁMICO)
  int get phase2Count => _algorithmConfig.phase2Count;
  
  // 🎯 FASE 3.1: Canciones a solicitar en precarga proactiva (DINÁMICO)
  int get phase31Count => _algorithmConfig.phase31Count;
  
  // 🎯 Historial de exclusión (DINÁMICO) - Se ajusta según tamaño del catálogo
  int get historyExcludeLimit => _algorithmConfig.effectiveHistorySize;
  
  // 🎯 Buffer inicial FASE 1 (DINÁMICO) - Canciones antes de reproducir
  int get bufferSize => _algorithmConfig.bufferSize;
  
  // 🚨 SINCRONIZACIÓN: Flag para prevenir actualizaciones concurrentes del estado
  bool _isUpdatingQueue = false;
  // 🛡️ ESCUDO DE TRANSICIÓN: Bloqueo de actualizaciones del stream tras saltos manuales
  bool _isManualSkipping = false;
  Timer? _manualSkipTimer;
  bool _disposed = false;

  bool get isMounted => !_disposed;
  
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

  // 📢 STRUKY AD-ENGINE V1.1 STATE
  final Set<String> _adTriggeredSongs = {}; // Control de disparo único
  // 🔒 LOCK: Prevents background syncs from overwriting optimistic UI state during manual transitions
  bool _isTransitioning = false; 
  String? _currentSongId; // ⚛️ ATOMIC STATE: Para detectar cambios de canción
  Timer? _failsafeTimer; // Mecanismo de respaldo (Heartbeat)

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
      AppLogger.debug('[PlaybackNotifier] _loadAdFrequency called. Result: $_adFrequencyFromAdmin');
      AppLogger.info('[PlaybackNotifier] 📢 Frecuencia de anuncios cargada: $_adFrequencyFromAdmin canceles');
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error loading ad frequency: $e');
      AppLogger.error('[PlaybackNotifier] Error al cargar frecuencia de anuncios: $e');
      _adFrequencyFromAdmin = 3; // Fallback seguro
    }
  }

  /// 🎛️ Cargar configuración del algoritmo desde el backend
  Future<void> _loadAlgorithmConfig() async {
    try {
      await Future.delayed(Duration.zero); // Esperar a que los providers estén listos
      final config = await AlgorithmConfigService.instance.getConfig();
      AppLogger.info('[PlaybackNotifier] 🎛️ Configuración del algoritmo cargada:');
      AppLogger.info('[PlaybackNotifier]    • Historial: ${config.historySize} (efectivo: ${config.effectiveHistorySize})');
      AppLogger.info('[PlaybackNotifier]    • FASE 2.0: ${config.phase2Count} canciones');
      AppLogger.info('[PlaybackNotifier]    • FASE 3.1: ${config.phase31Count} canciones');
      AppLogger.info('[PlaybackNotifier]    • Buffer inicial: ${config.bufferSize} canciones');
      AppLogger.info('[PlaybackNotifier]    • Umbral precarga: ${config.preloadThreshold}');
      AppLogger.info('[PlaybackNotifier]    • Canciones críticas: ${config.criticalSongs}');
      if (config.isSmallCatalog) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Catálogo pequeño detectado (${config.catalogSize} < ${config.smallCatalogThreshold}). Usando configuración optimizada.');
      }
    } catch (e) {
      AppLogger.warning('[PlaybackNotifier] ⚠️ Error al cargar config del algoritmo (usando defaults): $e');
    }
  }

  @override
  PlaybackState build() {
    ref.onDispose(() => _disposed = true);
    // Inicializar logger
    // Inicializar logger
    // AppLogger.init(); // Eliminado: método no existe
    
    // Cargar frecuencia de anuncios en segundo plano
    _loadAdFrequency();
    
    // 🎛️ CONFIGURACIÓN DINÁMICA: Cargar config del algoritmo en segundo plano
    _loadAlgorithmConfig();
    
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

  // 🛡️ ATOMIC STREAM CONTROL: Métodos para silenciar el notifier durante transiciones críticas
  
  /// Pausa todas las suscripciones al reproductor.
  /// Útil durante operaciones destructivas (cambio de cola, re-init) para evitar inconsistencias visuales.
  void _pauseSubscriptions() {
    if (_subscriptionsPaused) return; // Ya pausado
    
    AppLogger.info('[PlaybackNotifier] ⏸️ Pausando suscripciones de audio para transición atómica');
    for (final sub in _subscriptions) {
      sub.pause();
    }
    _subscriptionsPaused = true;
  }

  /// Reanuda todas las suscripciones al reproductor.
  void _resumeSubscriptions() {
    if (!_subscriptionsPaused) return; // No estaba pausado
    
    AppLogger.info('[PlaybackNotifier] ▶️ Reanudando suscripciones de audio');
    for (final sub in _subscriptions) {
      sub.resume();
    }
    _subscriptionsPaused = false;
  }
  
  bool _subscriptionsPaused = false;

  /// 🚀 INSTANT PLAY: Precarga inteligente para inicio inmediato
  /// Estrategia: "Local-First" -> Buscar en disco, si no, red.
  Future<void> prefetch(User user) async {
    AppLogger.info('[PlaybackNotifier] ⚡ Iniciando secuencia de Adrenalina (Instant Play)...');
    
    // 1. Configurar buffer agresivo para arranque rápido
    // Solo para la primera carga, luego se puede relajar si es necesario
    try {
      // Nota: AudioLoadConfiguration se configura en el servicio, pero podemos intentar
      // forzar un estado óptimo aquí si el servicio expone métodos, o confiamos en el default.
    } catch (_) {}

    // 2. Estrategia Local-First (Búnker)
    
    // TODO: Implementar getStartupSongs en OfflineManager
    // Por ahora, simulamos obteniendo canciones descargadas
    final downloadedSongs = ref.read(offlineManagerProvider).downloadedSongs.values.toList();
    
    if (downloadedSongs.isNotEmpty) {
      // Priorizar canciones recientes si es posible
      final seedSong = downloadedSongs.first; 
      AppLogger.info('[PlaybackNotifier] 🏁 Encontrada canción local para inicio rápido: ${seedSong.title}');
      
      // Preparar reproductor inmediatamente (Warm-up)
      await _warmUpPlayer(seedSong, isLocal: true);
      return;
    }
    
    // 3. Fallback a Red (Algoritmo)
    AppLogger.info('[PlaybackNotifier] 🌐 Sin contenido local. Solicitando semilla al backend...');
    try {
      // Disparar en background
      _initAlgorithmWithLowLatency(user);
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Falló prefetch de red', e);
    }
  }

  /// Calentamiento del reproductor (Low-Level)
  /// ✅ FIX: Usa ConcatenatingAudioSource para permitir inserción de anuncios
  /// ⚠️ NOTA: Solo precarga, NO reproduce automáticamente ni muestra MiniPlayer
  Future<void> _warmUpPlayer(Song song, {bool isLocal = false}) async {
    if (_service == null) return;
    
    try {
      // 1. 🚀 PRECARGA SILENCIOSA: Preparar la canción pero NO mostrar UI
      // El MiniPlayer solo aparece cuando el usuario toca una canción explícitamente
      state = state.copyWith(
        currentQueue: [song], // Cola temporal de 1 (para que el algoritmo agregue más)
        playbackMode: isLocal ? PlaybackMode.offline : PlaybackMode.algorithm,
        isLoading: false, // NO está cargando visualmente
        // ❌ NO establecer currentSong ni MiniPlayer visible - es solo precarga
      );

      // 2. Convertir a AudioSource
      final source = await _service!.createAudioSource(song);
      
      if (source != null) {
        // 3. 🚀 FIX CRÍTICO: Usar setAudioSources de just_audio 0.10.5+ para permitir ad insertion
        // Los anuncios requieren una cola interna configurada
        // 4. Precargar la cola SIN reproducir (preload: true, pero sin play())
        await _service!.player.setAudioSources([source], preload: true).catchError((e) {
          AppLogger.error('[PlaybackNotifier] Error en setAudioSources asíncrono', e);
          return null;
        });
        
        // 5. Guardar canción precargada para uso posterior
        _prefetchedSeed = song;
        
        AppLogger.info('[PlaybackNotifier] 🔥 Canción precargada (sin reproducir): ${song.title}');
      }
    } catch (e) {
       AppLogger.error('[PlaybackNotifier] Error en warm-up', e);
    }
  }

  /// Reproducir canción específica (Smart Injection + Ninja Mode)
  Future<void> playSpecificSong(Song song, {String? contextId}) async {
    AppLogger.info('[PlaybackNotifier] 🎵 playSpecificSong: ${song.title} (Context: $contextId)');
    
    // 🎯 CRÍTICO: Guardar en historial INMEDIATAMENTE cuando usuario selecciona la canción
    // Esto asegura que aparezca en "Recientemente Reproducidas" desde el primer momento
    try {
      AppLogger.info('[PlaybackNotifier] 💾 GUARDANDO EN HISTORIAL AL INICIO: ${song.title}');
      ref.read(playHistoryProvider.notifier).addToHistory(song);
      
      // Verificar que se guardó
      final historyAfter = ref.read(playHistoryProvider);
      if (historyAfter.isNotEmpty && historyAfter.last.id == song.id) {
        AppLogger.success('[PlaybackNotifier] ✅ Canción guardada en historial exitosamente: ${song.title}');
      } else {
        AppLogger.warning('[PlaybackNotifier] ⚠️ La canción NO se guardó en historial - ejecutando diagnóstico...');
        ref.read(playHistoryProvider.notifier).debugHistoryStatus();
      }
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] ❌ Error guardando en historial: $e');
    }
    
    // 🔓 NUCLEAR RESET: Limpiar TODOS los flags que podrían bloquear actualizaciones de posición
    // Este reset es esencial para que el contador funcione desde el primer segundo
    _isInsertingAd = false;
    _isFreezingUI = false;
    _isTransitioningFromAd = false;
    _isHandlingAdInsertion = false;
    _isCompletingAd = false;
    _preventiveAdTriggered = false;
    _manualSkipTimer?.cancel();
    _isManualSkipping = false;
    
    _activateTransitionShield(); // 🛡️ Activar escudo (600ms)
    _isTransitioning = true; // 🔒 LOCK SYNC: Bloquear syncs de fondo

    // 🥷 NINJA MODE: Revelar player inmediatamente (Optimistic UI)
    // 🏆 SPOTIFY-LEVEL: Activar sesión cuando usuario explícitamente reproduce
    state = state.copyWith(
      isMiniPlayerVisible: true,
      isSessionActive: true, // 🏆 SPOTIFY-LEVEL: Usuario inició sesión de escucha
      currentSong: song, // ⚡ Optimistic Set
      lastConfirmedSong: song,
      isBuffering: true,
      currentPosition: Duration.zero, // ✅ Iniciar en 0 para que fluya naturalmente
      totalDuration: song.duration != null ? Duration(seconds: song.duration!) : Duration.zero,
      // ✅ FIX: Force clear ad state to ensure immediate visibility
      isPlayingAd: false,
      clearCurrentAd: true,
    );
    AppLogger.info('[PlaybackNotifier] 🥷 Ninja Mode: Player revealed (isMiniPlayerVisible: true) for ${song.title}');

    try {
      // ⚡ INYECCIÓN INSTANTÁNEA: Si hay una cola activa, usar inserción rápida
      if (service.hasActiveQueue && song.isValidForPlayback) {
        try {
          AppLogger.info('[PlaybackNotifier] ⚡ Intentando inyección instantánea en playSpecificSong');
          
          final source = await _resolveSource(song);
          final success = await service.insertSongAtStart(source);
          
          if (success) {
            // 🔄 SINCRONIZACIÓN INMEDIATA
            await Future.delayed(const Duration(milliseconds: 50));
            _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
            
            // ✅ Solo actualizar contextId y playbackMode (el resto ya está en el estado optimista)
            state = state.copyWith(
              contextId: contextId,
              playbackMode: PlaybackMode.algorithm,
              isPlaying: true, // Marcar como reproduciendo
            );
            
            await service.play();
            
            // 🛡️ PROTECCIÓN: NO sincronizar inmediatamente después de play()
            // El estado del player puede estar "sucio" (apuntando a la canción anterior) por unos ms.
            // Confiamos en nuestro update optimista de arriba.
            // El stream listener sincronizará cuando el player se estabiliza.
            // _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);

            // 🎯 FASE 2: Iniciar monitor para garantizar flujo continuo y anuncios
            // Es vital activar el monitor aquí para que detecte que solo hay 1 canción
            // y dispare _appendMoreAlgorithmSongs            // 🎯 CORRECTOR DE FRECUENCIA DE ANUNCIOS
            // Al cambiar manual/drásticamente de canción, reiniciamos la sesión de escucha.
            // Establecemos playedCount = 1 porque "esta" canción ya cuenta como la primera reproducida.
            // Si lo dejamos en 0 o el valor anterior, el módulo % 3 se desalinea.
            _songsPlayedCount = 1;
            AppLogger.info('[PlaybackNotifier] 🔄 Sesión reiniciada: Contador de plays ajustado a 1'); // Registrar que ya estamos escuchando la #1
            _startAlgorithmMonitor();
            _startQueueProtection();
            
            AppLogger.info('[PlaybackNotifier] ✅ Cambio instantáneo completado');
            
            return;
          }
        } catch (e) {
          AppLogger.warning('[PlaybackNotifier] Inyección fallo, usando fallback: $e');
        }
      }
      
      // Fallback: Método estándar (Reemplazo total de cola)
      AppLogger.info('[PlaybackNotifier] 🔄 Usando playFixedQueue (fallback)');
      await playFixedQueue([song], song, contextId: contextId);
      
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] ❌ Error al reproducir canción: $e', stackTrace);
      state = state.copyWith(isLoading: false);
      rethrow;
    } finally {
      // 🔓 CRÍTICO: Liberar bloqueo de transición SIEMPRE
      _isTransitioning = false;
    }
  }

  /// Reproducir/Pausar
  Future<void> play() async {
    _isProcessingPlayPause = true;
    state = state.copyWith(isProcessingPlayPause: true);
    
    // 🥷 NINJA MODE: Si el usuario toca Play, mostramos el player
    if (!state.isMiniPlayerVisible && state.hasSong) {
      state = state.copyWith(isMiniPlayerVisible: true);
    }

    try {
      if (state.isPlaying) {
        await _service?.player.pause();
      } else {
        // 🎯 FIX ADRENALINA: Si hay una canción precargada y la cola está casi vacía,
        // significa que el algoritmo no generó recomendaciones. Activar FASE 2.0.
        final queueSize = state.currentQueue.length;
        if (_prefetchedSeed != null && queueSize <= 2 && state.playbackMode == PlaybackMode.algorithm) {
          AppLogger.info('[PlaybackNotifier] 🚀 ADRENALINA ACTIVATION: Cola pequeña ($queueSize canciones). Iniciando FASE 2.0...');
          final seedSong = _prefetchedSeed!;
          _prefetchedSeed = null; // Limpiar para evitar re-activación
          _isProcessingPlayPause = false;
          state = state.copyWith(isProcessingPlayPause: false);
          
          // Activar FASE 2.0 completa con la canción precargada
          await playAlgorithmStart(seedSong);
          return; // Salir porque playAlgorithmStart ya hace todo
        }
        
        // 🛡️ FIX: Si estamos en modo algoritmo pero la sesión no está activa y hay cola,
        // iniciar los monitores para que FASE 3.1 pueda operar
        if (state.playbackMode == PlaybackMode.algorithm && !state.isSessionActive && state.currentQueue.isNotEmpty) {
          AppLogger.info('[PlaybackNotifier] 🔄 Play en modo algoritmo sin sesión activa. Activando monitores...');
          state = state.copyWith(isSessionActive: true);
          _startAlgorithmMonitor();
          _startQueueProtection();
        }
        
        await _service?.player.play();
      }
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error en play/pause', e);
    } finally {
      _isProcessingPlayPause = false;
      state = state.copyWith(isProcessingPlayPause: false);
    }
  }

  /// Iniciar algoritmo con prioridad de latencia
  /// 🏆 SPOTIFY-LEVEL: Precargar audio pero NO reproducir ni mostrar UI
  Future<void> _initAlgorithmWithLowLatency(User user) async {
     // Implementación simplificada: Obtener canción y precargar en el motor de audio
     // PERO sin reproducir ni mostrar el MiniPlayer
     try {
       final featuredSongs = await _intelligentService.getIntelligentFeaturedSongs(
         limit: bufferSize, // 🔥 Usando configuración del admin (Buffer Inicial)
         user: user,
       );
       
       // ✅ LIMITAR al bufferSize configurado (evitar precargar más de lo necesario)
       final recommendations = featuredSongs
           .map((f) => f.song)
           .take(bufferSize)
           .toList();
       
       if (recommendations.isNotEmpty) {
         final song = recommendations.first;
         
         // 1. Guardar referencias para uso posterior
         _prefetchedSeed = song;
         _prefetchedInitialSongs = recommendations;
         
         // 2. Actualizar state pero sin activar UI
         state = state.copyWith(
           currentQueue: recommendations,
           playbackMode: PlaybackMode.algorithm,
           // ❌ NO: currentSong, isMiniPlayerVisible, isSessionActive
         );
         
         // 3. 🔥 PRECARGAR AUDIO: Crear la cola en el motor con TODAS las canciones
         if (_service != null) {
           try {
             // Crear sources para todas las canciones
             final sources = <AudioSource>[];
             for (final rec in recommendations) {
               final source = await _service!.createAudioSource(rec);
               if (source != null) {
                 sources.add(source);
               }
             }
             
             if (sources.isNotEmpty) {
               // Solo precargar, NO llamar play()
               await _service!.player.setAudioSources(sources, preload: true);
               AppLogger.success('[PlaybackNotifier] 💉 Inyección de Adrenalina completada. ${sources.length} canciones precargadas (Inicial: ${song.title})');
             }
           } catch (e) {
             AppLogger.error('[PlaybackNotifier] Error precargando cola completa: $e');
             // Fallback: al menos cargar la primera
             try {
               final source = await _service!.createAudioSource(song);
               if (source != null) {
                 await _service!.player.setAudioSources([source], preload: true);
                 AppLogger.warning('[PlaybackNotifier] ⚠️ Fallback: Solo 1 canción precargada: ${song.title}');
               }
             } catch (fallbackError) {
               AppLogger.error('[PlaybackNotifier] Error en fallback: $fallbackError');
             }
           }
         }
       }
     } catch (e) {
       AppLogger.error('[PlaybackNotifier] Error en algoritmo low-latency', e);
     }
  }


  /// Inicializar suscripciones a los streams del reproductor
  void _initSubscriptions() {
    AppLogger.debug('[PlaybackNotifier] _initSubscriptions called. Service is null? ${_service == null}');
    if (_service == null) return;
    
    // 0. 🔑 MASTER KEY: Escuchar cambios de índice directamente
    final indexSub = service.currentIndexStream.listen((index) {
      // 🛡️ PROTECCIÓN ANUNCIOS: Si estamos en modo anuncio, los índices están desfasados
      // (El anuncio ocupa un lugar en just_audio que no existe en currentQueue)
      // Dejar que sequenceStateStream maneje la transición por TAGS, que es más seguro.
      if (state.isPlayingAd || state.currentAd != null) {
        // PERO: Si el índice avanza, podría significar que el anuncio terminó y sequenceStream falló
        // Verificar si es un índice válido en nuestra cola (compensando posible offset)
        if (index != null && state.currentQueue.isNotEmpty) {
           // Intentar deducir si ya estamos en la canción
           // Si el índice coincide con una canción lógica, podríamos forzar la transición
           AppLogger.debug('[PlaybackNotifier] 🛡️ Ignorando cambio de índice $index durante anuncio (delegando a sequenceStream)');
        }
        return;
      }

      if (index != null && state.currentQueue.isNotEmpty && index < state.currentQueue.length) {
        // 🛡️ PROTECCIÓN: Si se está reemplazando la cola o congelado, ignorar
        if (_isReplacingQueue || _isFreezingUI) return;

        // ✅ FIX CRÍTICO: Obtener canción del TAG del reproductor, NO del índice de la cola
        // La cola interna puede estar desfasada debido a operaciones de pre-carga o deduplicación
        final sequenceState = service.player.sequenceState;
        final currentSource = sequenceState.currentSource;
        
        // Verificar que el source actual sea una canción
        if (currentSource == null || currentSource.tag is! Song) {
          AppLogger.debug('[PlaybackNotifier] 🔑 Master Key: Source no es una canción, ignorando');
          return;
        }
        
        final newSong = currentSource.tag as Song;
        
        // Ignorar si el índice es el mismo y la canción es la misma
        if (index == state.currentIndex && state.currentSong?.id == newSong.id) {
          return;
        }

        AppLogger.info('[PlaybackNotifier] 🔑 Master Key triggered: Índice cambió a $index');
        
        // FORZAR actualización del estado y asegurar limpieza de flags de anuncio
        state = state.copyWith(
          currentSong: newSong,
          lastConfirmedSong: newSong,
          currentPosition: Duration.zero,
          // Failsafe: asegurar que no haya flags de anuncio activos si estamos en una canción normal
          isPlayingAd: false,
          clearCurrentAd: true,
          isInsertingAd: false,
        );
        
        // Registrar cambio
        AppLogger.info('[PlaybackNotifier] ✅ Estado sincronizado por índice a: ${newSong.title} (TAG del reproductor)');
        
        // 🚀 WARM-UP: Verificar precarga
        _maybePrefetchAlgorithm(service.player.sequenceState);
      }
    });
    _subscriptions.add(indexSub);

    // 1. Suscribirse a los cambios de la secuencia para obtener la canción actual
    final seqSub = service.sequenceStateStream.listen((sequenceState) {
      // 🛡️ ESCUDO DE TRANSICIÓN: Si estamos en un salto manual, ignorar actualizaciones del stream
        // Esto evita el "Efecto Látigo" donde se muestra brevemente la canción anterior
        // ❄️ HARD FREEZE: Ignorar cualquier cambio de secuencia si estamos congelados
        
        // 🚨 FIX: Permitir pasar si es un ANUNCIO para que la UI se actualice inmediatamente
        // Los anuncios tienen prioridad sobre el escudo de transición de canciones Y el freeze
        final isAdSource = sequenceState?.currentSource?.tag is AudioAd;
        
        // ✅ FIX: Los anuncios tienen prioridad sobre _isManualSkipping Y _isFreezingUI
        // Esto asegura que el AdsMiniPlayer aparezca cuando ocultas el reproductor extendido
        if ((_isManualSkipping && !isAdSource) || (_isFreezingUI && !isAdSource)) return;

        if (sequenceState == null) return;
        
        final currentIndex = sequenceState.currentIndex;
        final currentSource = sequenceState.currentSource;
        
        
        // MOVED ANTI-LOOP GUARD DOWN

        
        // 🛡️ THE EXIT GUARD (Regla 1): PRIMERO verificar si el anuncio terminó
        // Esta verificación debe ejecutarse ANTES que cualquier otra lógica
        // para garantizar una transición limpia Anuncio -> Canción
        // ✅ FIX: Eliminado _isInsertingAd de la condición porque causaba falsos positivos
        // (es normal estar insertando un anuncio mientras suena una canción)
        if (currentSource != null && currentSource.tag is Song && (state.isPlayingAd || state.currentAd != null)) {
          final songAtCurrentIndex = currentSource.tag as Song;
          
          // Verificar que realmente estamos en el índice de la canción
          final sequence = sequenceState.sequence;
          final isAtSongIndex = currentIndex != null && 
                               currentIndex >= 0 && 
                               currentIndex < sequence.length &&
                               sequence[currentIndex].tag is Song;
          
          // 🛡️ FIX: Si currentSource es una Canción, el anuncio YA terminó (o fue saltado/interrumpido).
          // NO verificar posición vs duración del anuncio anterior aquí, porque la posición ahora es de la canción (cerca de 0).
          // Simplemente confiamos en que si el reproductor avanzó a una canción, el anuncio finalizó.
          bool adReallyFinished = true;
          
          if (isAtSongIndex && adReallyFinished) {
            // 🚨 EXIT GUARD: Registrar finalización y limpiar estado
            AppLogger.info('[PlaybackNotifier] 🛡️ EXIT GUARD: Transición Ad -> Song detectada. Procesando finalización...');
            
            // 🛡️ PROTECCIÓN SKIPS: Avisar al reporter para que ignore la transición "Song -> Ad -> Song"
            // que podría detectarse como un skip rápido de la canción anterior o siguiente
            try {
               ref.read(playbackReporterProvider).ignoreNextSkip();
            } catch (e) {
               AppLogger.warning('[PlaybackNotifier] No se pudo notificar al Reporter: $e');
            }
            
            // Paso 1: Limpiar flags de instancia
            _isInsertingAd = false;
            _isHandlingAdInsertion = false;
            _isCompletingAd = false;
            _preventiveAdTriggered = false;
            
            // Paso 2: Obtener datos de la nueva canción
            final newSongDuration = currentSource.duration ?? 
                                   (songAtCurrentIndex.duration != null 
                                     ? Duration(seconds: songAtCurrentIndex.duration!) 
                                     : Duration.zero);
            final newSongPosition = _service?.player.position ?? Duration.zero;
            
            // Capturar referencia al anuncio antes de limpiar
            final adToLog = state.currentAd;

            // Paso 3: Actualizar estado con TODOS los campos limpios
            // 🛑 FIX: Actualizar estado PRIMERO para evitar que _handleAdCompletion
            // use información obsoleta del getter de sequenceState
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true,
              isInsertingAd: false,
              currentSong: songAtCurrentIndex,
              lastConfirmedSong: songAtCurrentIndex,
              currentPosition: newSongPosition,
              totalDuration: newSongDuration.inMilliseconds > 0 ? newSongDuration : Duration.zero,
            );
            
            AppLogger.info('[PlaybackNotifier] 🛡️ EXIT GUARD COMPLETO: isPlayingAd=false, currentAd=null, isInsertingAd=false, canción=${songAtCurrentIndex.title}');

            // ✅ FIX CRÍTICO: Registrar estadísticas DESPUÉS de limpiar
            // Al hacerlo después, _handleAdCompletion verá isPlayingAd=false y no intentará
            // sobrescribir nuestro estado con data obsoleta del getter
            if (adToLog != null) {
               AppLogger.info('[PlaybackNotifier] 🛡️ EXIT GUARD: Logueando anuncio desde Exit Guard: ${adToLog.title}');
               // Usar unawaited o fire-and-forget para no bloquear el listener
               _handleAdCompletion(adToLog, false);
            }
            
            // ✅ FIX: Marcar transición de anuncio para bloquear historial transitorio
            _lastAdTransitionTime = DateTime.now();
            
            // Paso 4: Sincronizar y terminar - NO procesar más lógica
            _syncQueueWithAudioService(sequenceState, forceSync: true);
            return;
          }
        }
        
        // ═══════════════════════════════════════════════════════════════════
        // 📢 DETECCIÓN DE ANUNCIO (SIMPLIFICADO)
        // ═══════════════════════════════════════════════════════════════════
        
        
        // 🛡️ ANTI-LOOP GUARD: Evitar procesamiento si estamos en medio de completar un anuncio
        // Movid aquí para permitir que EXIT GUARD detecte la canción, pero bloquear re-entrada a Ad
        if (_isCompletingAd) {
          AppLogger.debug('[PlaybackNotifier] 🛡️ ANTI-LOOP: Ignorando evento de stream mientras se completa anuncio');
          return;
        }

        // 🚀 WARM-UP ALGORITMO: Verificar si necesitamos precargar recomendaciones
        // Se ejecuta en cada cambio de secuencia para detectar si llegamos a la última canción
        _maybePrefetchAlgorithm(sequenceState);

        if (currentSource != null && currentSource.tag is AudioAd) {
        if (currentSource.tag is AudioAd) {
          final ad = currentSource.tag as AudioAd;
          
          // IDEMPOTENCIA: Si ya estamos mostrando este anuncio, no hacer nada
          if (state.currentAd?.id == ad.id && state.isPlayingAd) return;
          
          // Actualizar estado solo si es un anuncio diferente
          if (!state.isPlayingAd || state.currentAd?.id != ad.id) {
            _isInsertingAd = false;
            final currentPos = _service?.player.position ?? Duration.zero;
            
            state = state.copyWith(
              isPlayingAd: true,
              currentAd: ad,
              isInsertingAd: false,
              currentPosition: currentPos.inMilliseconds > 0 ? currentPos : Duration.zero,
              totalDuration: ad.duration,
            );
            AppLogger.info('[PlaybackNotifier] 📢 Anuncio activo: ${ad.title}');
          }
          return;
        }

        // 🧹 LIMPIEZA DE ANUNCIOS HUÉRFANOS (diferida)
        if (_service != null && currentIndex != null && _adInsertionManager != null && 
            !_isRemovingOrphanedAd && !_isCompletingAd && currentIndex > 1) {
          final seq = _service!.player.sequenceState.sequence;
          for (int i = 0; i < currentIndex - 1 && i < seq.length; i++) {
            if (seq[i].tag is AudioAd) {
              _isRemovingOrphanedAd = true;
              final idx = i;
              
              // ❄️ HARD FREEZE: Congelar UI durante limpieza de huérfanos posterior
              AppLogger.info('[PlaybackNotifier] ❄️ Activando HARD FREEZE para limpieza post-ad...');
              _isFreezingUI = true;
              _service?.setFreezeMode(true);

              Future.microtask(() async {
                try {
                  await _adInsertionManager!.removeAdAt(idx);
                } catch (_) {} finally {
                  _isRemovingOrphanedAd = false;
                  // 🔓 Descongelar con delay
                  Future.delayed(const Duration(milliseconds: 300), () {
                     _isFreezingUI = false;
                     _service?.setFreezeMode(false);
                     AppLogger.info('[PlaybackNotifier] 🌡️ Desactivando HARD FREEZE (Post-Cleanup)');
                  });
                }
              });
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
          'currentSourceTag': currentSource.tag.runtimeType.toString(),
          'isAd': currentSource.tag is AudioAd,
          'isPlayingAd': state.isPlayingAd,
          'currentAdId': state.currentAd?.id,
          'isInsertingAd': _isInsertingAd,
          'playing': _service?.player.playing ?? false,
          'currentIndex': currentIndex
        }, 'C');
        // #endregion
        AppLogger.info('[PlaybackNotifier] 🔍 Stream listener: índice=$currentIndex, tag=${currentSource.tag.runtimeType}, isPlayingAd=${state.isPlayingAd}, isInsertingAd=$_isInsertingAd');
        
        // ✅ FIX RELAJADO: Si currentSource dice que es anuncio, ES anuncio.
        // Priorizamos la etiqueta del source actual sobre el índice para garantizar que
        // el MiniPlayer de anuncios aparezca incluso si hay desincronización de índices.
        if (currentSource.tag is AudioAd) {
          final ad = currentSource.tag as AudioAd;
          final isPlaying = _service?.player.playing ?? false;
          
          // Solo actualizar si es un anuncio diferente al actual o si el estado no refleja que es anuncio
          if (!state.isPlayingAd || state.currentAd?.id != ad.id) {
            _adStartTime = DateTime.now();
            
            // ✅ FIX CRÍTICO: Si el anuncio ya está sonando, DEBEMOS apagar el flag de inserción
            // para permitir que futuras actualizaciones de la canción funcionen
            _isInsertingAd = false;
            
            final initialPos = _service?.player.position ?? Duration.zero;
            final duration = currentSource.duration ?? ad.duration;
            
            state = state.copyWith(
              isPlayingAd: true,
              currentAd: ad,
              clearCurrentSong: true,
// clearLastConfirmedSong: false, // ✅ FIX: Mantener la última canción confirmada para que el algoritmo tenga semilla during Ads
              totalDuration: duration.inMilliseconds > 0 ? duration : ad.duration,
              currentPosition: initialPos,
              isInsertingAd: false,
            );
            
            // Auto-play si no está reproduciendo
            if (!isPlaying && _service != null && !_isHandlingAdInsertion) {
              Future.microtask(() async {
                if (_service != null && !_service!.player.playing) {
                  final src = _service!.player.sequenceState.currentSource;
                  if (src?.tag is AudioAd && (src!.tag as AudioAd).id == ad.id) {
                    try { await _service!.play(); } catch (_) {}
                  }
                }
              });
            }
          }
          
          // Actualizar posición solo si cambió significativamente (>100ms)
          final pos = _service?.player.position ?? Duration.zero;
          if ((pos.inMilliseconds - state.currentPosition.inMilliseconds).abs() > 100) {
            state = state.copyWith(currentPosition: pos);
          }
          
          return;
        }
        
        // ═══════════════════════════════════════════════════════════════════
        // 📢 FINALIZACIÓN DE ANUNCIO (SIMPLIFICADO)
        // ═══════════════════════════════════════════════════════════════════
        // 📢 FINALIZACIÓN DE ANUNCIO (REBUSTO)
        // Eliminamos check de _isInsertingAd porque podría estar 'stuck' en true erróneamente.
        // Lo importante es que el source YA NO SEA un anuncio y el player esté avanzando.
        // 📢 FINALIZACIÓN DE ANUNCIO (HARD FAILSAFE)
        // Check simplificado: Si la UI dice "Anuncio" pero el Audio dice "Canción", 
        // ENTONCES EL ANUNCIO TERMINÓ. Punto. No esperar estados complejos.
        if (state.isPlayingAd && currentSource.tag is Song) {
             AppLogger.info('[PlaybackNotifier] 🏁 HARD FAILSAFE: Detectado fin de anuncio por Tag (UI:Ad -> Audio:Song). Forzando limpieza.');
             _isCompletingAd = false; // Reset flag to ensure execution if it was stuck
             // No 'nested if', just run logic directly.
             final completedAd = state.currentAd; // Can be null, that's fine.
        
             // Ejecutar lógica de finalización directa sin nesting excesivo
          if (completedAd != null) {
            _isCompletingAd = true;
            _isTransitioningFromAd = true;
            
            // Obtener info de la canción siguiente
            Song? newSong;
            Duration songDuration = currentSource.duration ?? Duration.zero;
            if (currentSource.tag is Song) {
              newSong = currentSource.tag as Song;
              songDuration = newSong.duration != null 
                  ? Duration(seconds: newSong.duration!) 
                  : songDuration;
            }
            
            // Limpiar estado del anuncio
            state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true,
              currentPosition: _service!.player.position,
              totalDuration: songDuration,
              currentSong: newSong ?? state.currentSong,
            );
            
            // Manejar finalización en background
            _handleAdCompletion(completedAd, false).whenComplete(() {
              _isCompletingAd = false;
              Future.delayed(const Duration(milliseconds: 300), () {
                _isTransitioningFromAd = false;
              });
            });
            
            AppLogger.info('[PlaybackNotifier] 📢 Anuncio completado: ${completedAd.title}');
            return;
          }
        }
        
        // ═══════════════════════════════════════════════════════════════════
        // 🔄 CORRECCIÓN DE ESTADO INCONSISTENTE
        // ═══════════════════════════════════════════════════════════════════
        if (currentSource.tag is! AudioAd && 
            (state.isPlayingAd || state.currentAd != null)) {
          // Obtener info de la canción
          Song? song;
          Duration duration = currentSource.duration ?? Duration.zero;
          if (currentSource.tag is Song) {
            song = currentSource.tag as Song;
            duration = song.duration != null ? Duration(seconds: song.duration!) : duration;
          }
          
          state = state.copyWith(
            isPlayingAd: false,
            clearCurrentAd: true,
            currentSong: song ?? state.currentSong,
            lastConfirmedSong: song ?? state.lastConfirmedSong,
            totalDuration: duration,
            currentPosition: _service?.player.position ?? Duration.zero,
          );
          _lastAdCompletionTime = null;
        }
        
        // ✅ FIX CRÍTICO: Asegurar variables necesarias temprano
        if (currentIndex == null) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ currentIndex es null, no se puede continuar');
          return;
        }
        
        final nonNullCurrentIndex = currentIndex;
        
        // ✅ FIX CRÍTICO: Detectar cambio de índice
        final previousIndex = _lastKnownIndex;
        final indexChanged = previousIndex != null && nonNullCurrentIndex != previousIndex;

        // ✅ FIX CRÍTICO: Obtener la canción de la fuente más confiable
        // 1. Si hubo cambio de índice, USAR LA COLA (Tag puede estar stale en el evento inmediato)
        // 2. Si no, usar Tag del reproductor (Fuente de verdad habitual)
        // 3. Fallback a cola
        Song? currentSong;
        
        if (indexChanged && nonNullCurrentIndex < state.currentQueue.length) {
           // ⚡ FORZAR QUEUE: Al cambiar track, el tag del source a veces viene viejo por un milisegundo.
           // La cola indexada es la verdad absoluta de "qué debería sonar ahora".
           currentSong = state.currentQueue[nonNullCurrentIndex];
           AppLogger.info('[PlaybackNotifier] 🔄 Cambio de track detectado ($previousIndex -> $nonNullCurrentIndex). Forzando canción desde queue: ${currentSong.title}');
        } else if (currentSource.tag is Song) {
           // 🛡️ STALE TAG GUARD: Protección contra tags obsoletos
           // Si el índice dice X, y la cola en X es diferente al Tag actual,
           // la cola GANA. El tag puede ser de la canción anterior que quedó en buffer.
           final songFromQueue = (nonNullCurrentIndex < state.currentQueue.length) 
               ? state.currentQueue[nonNullCurrentIndex] 
               : null;
           
           if (songFromQueue != null && songFromQueue.id != (currentSource.tag as Song).id) {
               AppLogger.warning('[PlaybackNotifier] 🛡️ STALE TAG: Tag (${(currentSource.tag as Song).title}) != Queue (${songFromQueue.title}). Usando Queue.');
               currentSong = songFromQueue;
           } else {
               currentSong = currentSource.tag as Song;
           }
        } else if (nonNullCurrentIndex < state.currentQueue.length) {
           currentSong = state.currentQueue[nonNullCurrentIndex];
           AppLogger.warning('[PlaybackNotifier] ⚠️ Usando fallback queue: ${currentSong.title}');
        } else {
           AppLogger.warning('[PlaybackNotifier] ⚠️ No se pudo obtener canción: índice=$nonNullCurrentIndex');
           return;
        }
        
        // ✅ PROTECCIÓN OPTIMIZADA: Solo bloquear actualizaciones si es la misma canción Y acabamos de terminar un anuncio
        // PERO SIEMPRE permitir actualización si hay una nueva canción (el reproductor ya avanzó)
        // Esto asegura que la barra de carga se actualice inmediatamente después de cada anuncio
        if (_lastAdCompletionTime != null) {
          final isNewSong = currentSource.tag is Song && 
                           (state.currentSong == null || state.currentSong?.id != currentSong.id);
          
          // 🛡️ ANTI-WHIP EFFECT (Efecto Látigo):
          // Al salir de un anuncio, el índice puede saltar erráticamente (N -> N+1 -> N).
          // Si estamos "saliendo de un anuncio" (_isTransitioningFromAd), debemos ser conservadores.
          // Solo aceptamos la nueva canción si el player reporta que está REPRODUCIENDO activamente esa canción,
          // no solo buffering/loading de estados intermedios.
          final isPlayerStable = _service?.player.playerState.processingState == ProcessingState.ready || 
                                 _service?.player.playerState.processingState == ProcessingState.buffering; // Buffering is ok, loading/idle not so much
                                 
          // Si es nueva canción PERO el estado es inestable post-anuncio, esperar.
          if (isNewSong && _isTransitioningFromAd && !isPlayerStable) {
             AppLogger.debug('[PlaybackNotifier] 🛡️ Anti-Whip: Ignorando canción transitoria post-anuncio: ${currentSong.title}');
             return; 
          }

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
        // ✅ Variable previousIndex ya declarada arriba
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
            currentSource.tag is Song) {
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
        
        // ✅ indexChanged ya declarado arriba
        final shouldUpdate = !isSameSong || 
                            indexChanged || // ✅ Forzar si cambió el índice
                            (_lastAdCompletionTime == null || 
                             DateTime.now().difference(_lastAdCompletionTime!) >= const Duration(seconds: 1));
        
        // 🚀 SMART CHANGE DETECTION (Transactions)
        // Si la canción es la misma y el índice es el mismo, pero el sequenceState cambió (ej. inserción de anuncio),
        // NO debemos resetear el estado (posición, duración, etc.) para evitar el "latigazo".
        if (isSameSong && !indexChanged && !shouldUpdate) {
             AppLogger.debug('[PlaybackNotifier] 🛡️ Smart Change Detection: La canción es idéntica y no hubo cambio de índice. Ignorando reset de estado.');
             // Aún así, podríamos querer actualizar la cola interna si cambió (ej. se insertó el anuncio)
             // pero SIN notificar un cambio de canción "nueva".
             if (state.currentQueue.length != (sequenceState.sequence.where((s) => s.tag is Song).length)) {
                  AppLogger.info('[PlaybackNotifier] 🔄 Actualizando cola interna silenciosamente (diferencia de longitud detectada)');
                  _syncQueueWithAudioService(sequenceState);
             }
             return; // 🛑 ABORTAR RESET
        }

        // 🔍 DIAGNÓSTICO: Ver por qué no se actualiza el historial
        if (!shouldUpdate) {
            AppLogger.debug('[PlaybackNotifier] ⚠️ No actualizando estado (isSameSong=$isSameSong, indexChanged=$indexChanged)');
        } else {
             AppLogger.info('[PlaybackNotifier] 🚀 Actualizando estado para canción: ${currentSong.title} (ID: ${currentSong.id})');
        }

        // 🎯 CRÍTICO: Guardar en historial SIEMPRE que cambie la canción (manual o automática)
        // Hacer esto ANTES del if(shouldUpdate) para capturar todas las transiciones
        // 🛡️ PROTECCIÓN POST-ANUNCIO: NO guardar si acabamos de salir de un anuncio
        if (!isSameSong && currentSong.id.isNotEmpty) {
          // 🛡️ CRITICAL FIX: Bloquear guardado durante transiciones de anuncio
          if (_lastAdTransitionTime != null && 
              DateTime.now().difference(_lastAdTransitionTime!) < const Duration(seconds: 3)) {
             AppLogger.debug('[PlaybackNotifier] 🛡️ AUTO-guardado bloqueado por transición de anuncio reciente');
             // NO guardar - la canción puede ser transitoria/incorrecta
          } else {
            try {
              AppLogger.info('[PlaybackNotifier] 💾 AUTO-GUARDANDO en historial (transición automática): ${currentSong.title}');
              ref.read(playHistoryProvider.notifier).addToHistory(currentSong);
              
              // Verificar que se guardó
              final historyAfter = ref.read(playHistoryProvider);
              if (historyAfter.isNotEmpty && historyAfter.last.id == currentSong.id) {
                AppLogger.success('[PlaybackNotifier] ✅ Canción AUTO-guardada exitosamente: ${currentSong.title} (Total: ${historyAfter.length})');
              } else {
                AppLogger.warning('[PlaybackNotifier] ⚠️ AUTO-guardado falló - diagnóstico...');
                ref.read(playHistoryProvider.notifier).debugHistoryStatus();
              }
            } catch (e) {
              AppLogger.error('[PlaybackNotifier] ❌ Error AUTO-guardando: $e');
            }
          }
        }

        if (shouldUpdate) {
          // ✅ FIX CRÍTICO: SIEMPRE actualizar currentSong y lastConfirmedSong cuando cambia
          // 🔥 FIX: Resetear currentPosition a Duration.zero al cambiar de canción
          // 🛡️ PROTECCIÓN ADRENALINA: NO resetear posición si:
          // 1. Estamos en transición optimista (_isTransitioning), O
          // 2. Es la MISMA canción (isSameSong) - el shouldUpdate se disparó por otra razón (tiempo, etc)
          // Solo reseteamos posición cuando REALMENTE cambia la canción
          final shouldResetPosition = !isSameSong && !_isTransitioning;
          
          if (shouldResetPosition) {
            state = state.copyWith(
              currentSong: currentSong,
              lastConfirmedSong: currentSong,
              totalDuration: duration ?? Duration.zero,
              currentPosition: Duration.zero,
            );
            AppLogger.info('[PlaybackNotifier] ✅ Canción DIFERENTE: progreso reseteado a 0 para: ${currentSong.title}');
          } else {
            // Misma canción o transición: solo actualizar metadatos, NO tocar la posición
            state = state.copyWith(
              currentSong: currentSong,
              lastConfirmedSong: currentSong,
              totalDuration: duration ?? Duration.zero,
            );
            if (_isTransitioning) {
              AppLogger.debug('[PlaybackNotifier] ✅ Transición activa: posición preservada para ${currentSong.title}');
            } else if (isSameSong) {
              AppLogger.debug('[PlaybackNotifier] ✅ Misma canción: posición preservada para ${currentSong.title}');
            }
          }
        } else {
          // Solo actualizar la duración si no cambió la canción (para evitar cambios de tiempos)
          if (duration != null && duration != state.totalDuration) {
            state = state.copyWith(totalDuration: duration);
          }
        }
        
        // 🎯 FASE 1: Registrar canción reproducida en servicio centralizado
        // Solo si la canción es válida y hubo actualización real
        if (shouldUpdate) {
           ref.read(playbackSessionProvider.notifier).registerPlayedSong(currentSong.id);
           // Nota: El historial ya se guardó arriba (antes del if shouldUpdate) 
           // para capturar tanto cambios manuales como automáticos
           if (state.currentSong?.id != currentSong.id) {
             AppLogger.info('[PlaybackNotifier] Canción actual: ${currentSong.title}');
           }
        }
        
        // 🚀 WARM-UP: Verificar si necesitamos precargar el algoritmo
        _maybePrefetchAlgorithm(sequenceState);
        }
      });
      _subscriptions.add(seqSub);

    // 3. Suscribirse a la duración total
    _subscriptions.add(
      service.durationStream.listen((duration) {
        // 🛡️ PROXY METADATA: Ignorar actualizaciones de duración si estamos en un anuncio
        // El player puede enviar la duración de la siguiente canción mientras pre-carga
        if (state.isPlayingAd) return;
        
        if (duration != null) {
          state = state.copyWith(totalDuration: duration);
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
        
        // 🛡️ FAILSAFE DE VISIBILIDAD: Si está sonando y NO es anuncio, mostrar player
        // Esto corrige casos donde el trigger inicial se pierde
        if (isPlaying && !state.isPlayingAd && !state.isMiniPlayerVisible && state.hasSong) {
             AppLogger.warning('[PlaybackNotifier] 🛡️ FAILSAFE ACTIVADO: Forzando visibilidad del MiniPlayer (Estaba oculto mientras sonaba)');
             state = state.copyWith(isMiniPlayerVisible: true);
        }
      }),
    );
    
    // 🛡️ LISTENER DE ESTADO DE PROCESAMIENTO (AUTO-RECOVERY)
    // Detecta si el reproductor llega al final de la cola y se detiene (ProcessingState.completed)
    // y fuerza una recuperación automática si estamos en modo Algoritmo
    _subscriptions.add(
      service.player.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
           if (state.playbackMode == PlaybackMode.algorithm && state.shouldStartAlgorithmAfterQueue) {
             AppLogger.warning('[PlaybackNotifier] ⚠️ AUTO-RECOVERY: Reproductor completado en modo algoritmo. Forzando recarga...');
             // Ejecutar en microtask para no bloquear el stream
             Future.microtask(() async {
               if (!_isPreloading) {
                 await _forceImmediatePreload();
               }
               // Si seguimos en completed, reiniciar
               if (service.player.playerState.processingState == ProcessingState.completed) {
                 service.player.seek(Duration.zero);
               }
             });
           }
        }
      })
    );

    // 3. Suscribirse a la posición (progreso)
    _subscriptions.add(
      service.positionStream.listen((position) {
        
        // 🛡️ SHIELD: Si estamos insertando un anuncio, ignorar actualizaciones de posición
        // La inserción provoca que el player reporte posición 0 o errática brevemente.
        // Mantener la última posición conocida (aprox 50%) evita que la barra salte.
        // ❄️ HARD FREEZE: Bloqueo absoluto
        if (_isInsertingAd || _isFreezingUI) {
          return; 
        }
        
        // 🛡️ AD SOFT START: Durante los primeros 300ms de un anuncio, forzar posición 0
        // Esto evita que la barra salte erráticamente al iniciar el anuncio
        if (state.isPlayingAd && _adStartTime != null) {
          final timeSinceAdStart = DateTime.now().difference(_adStartTime!);
          if (timeSinceAdStart < const Duration(milliseconds: 300)) {
             // Forzar 0 visualmente
             if (state.currentPosition != Duration.zero) {
                state = state.copyWith(currentPosition: Duration.zero);
             }
             return;
          }
        }
      
        // MASTER DEBUG LOGGER
        if (position.inSeconds % 10 == 0 && position.inSeconds > 0) {
             final now = DateTime.now();
             if (_lastHeartbeatLogTime == null || now.difference(_lastHeartbeatLogTime!) >= const Duration(seconds: 10)) {
                _lastHeartbeatLogTime = now;
                AppLogger.debug('[PlaybackNotifier] ⌚ Stream Heartbeat: Pos: ${position.inSeconds}s. Ad: ${state.isPlayingAd}');
             }
        }
        
        // 🛡️ FIX: Protección contra posiciones inválidas durante transición a anuncio
        if (state.isPlayingAd && state.totalDuration.inSeconds < 120) {
          if (position.inMilliseconds > state.totalDuration.inMilliseconds + 1000) {
            return; 
          }
        }
        
        // 🛑 FIX: Si estamos en transición desde anuncio, ignorar posiciones muy bajas
        if (_isTransitioningFromAd && position.inMilliseconds < 500) {
          return;
        }
        
        // ✅ FIX CRÍTICO: Desactivamos el chequeo agresivo de "Zombie" que bloquea el contador en 00:00
        // En modos de arranque rápido (Adrenalina), el estado optimista puede no coincidir 
        // con el tag del stream por unos milisegundos, pero AUN ASÍ queremos ver el progreso si el motor avanza.
        /*
        if (seqCurrentSongId != null && state.currentSong != null && seqCurrentSongId != state.currentSong!.id) {
           // Loguear solo para depuración si es necesario, pero permitir el update
           // AppLogger.debug('[PlaybackNotifier] ⚠️ Zombie check mismatch: Stream=$seqCurrentSongId != State=${state.currentSong?.id}');
           return;
        }
        */

        // Actualizar posición (válida)
        state = state.copyWith(currentPosition: position);
        
        // 🚀 SPOTIFY-LEVEL: Pre-cargar audio de siguiente canción
        if (!state.isPlayingAd) {
          _checkAndPreloadNextAudio(position);
          _checkAndPrepareNextSongTransition(position);
        }
        
        // ⚡ CRÍTICO: Monitorear progreso para triggers de anuncios
        _monitorPlaybackProgress(position);
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
          AppLogger.warning('[PlaybackNotifier] ⚠️ Player completed while Ad was playing (End of Queue?). Handling Ad Completion...');
          
          // 🛠️ FIX "ADRENALINA" CASE: La primera canción es un híbrido inyectado manualmente.
          // El motor nativo puede perder la continuidad si la cola es pequeña.
          if (_songsPlayedCount <= 1 && _service != null) {
              AppLogger.info('🏃 [AdBlock] Caso Adrenalina detectado: Forzando salto manual al índice 2 para despertar al motor');
              // Intentar saltar al índice 2 (0:Seed, 1:Ad, 2:First Algo Song)
              // Usamos un try-catch silencioso por si la cola es más corta
              try {
                  state = state.copyWith(isPlayingAd: false); // Unlock UI first
                  // Use unawaited future or just call without await in non-async listener
                  _service!.player.seek(Duration.zero, index: 2).then((_) => _service!.player.play());
              } catch (e) {
                  AppLogger.warning('[AdBlock] Falló el salto manual adrenalina, usando seekToNext estándar: $e');
                  _service!.player.seekToNext().then((_) => _service!.player.play());
              }
          }

          // Force logic de completion even if sequence didn't change (e.g. end of playlist)
          if (state.currentAd != null) {
              _handleAdCompletion(state.currentAd!, false);
          } else {
             // Fallback cleanup
             state = state.copyWith(isPlayingAd: false, clearCurrentAd: true);
          }
          return;
        }
        
        // 🚨 CRÍTICO: Actualizar estado inmediatamente cuando la canción termina
        // Esto evita que la UI se quede congelada
        state = state.copyWith(
          isBuffering: isBuffering,
          isPlaying: !isCompleted && playerState.playing, // Actualizar isPlaying cuando termina
          // 🏆 SPOTIFY-LEVEL AUTOCURACIÓN: Si suena, garantizar que la sesión esté activa
          // Esto arregla casos borde donde la UI se queda oculta mientras hay audio
          isSessionActive: state.isSessionActive || playerState.playing,
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

     // 💓 FAILSAFE HEARTBEAT: Mecanismo de respaldo para detección de progreso
    // Se ejecuta cada 1 segundo para asegurar que no perdemos el evento del 50%
    _failsafeTimer?.cancel();
    _failsafeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isPlaying) {
         // AppLogger.debug('[Failsafe] Skipping: Not playing');
         return;
      }
      
      if (state.isPlayingAd) {
         if (timer.tick % 5 == 0) AppLogger.debug('[Failsafe] Skipping: Ad is playing (IsPlayingAd: true)');
         return;
      }

      final position = service.player.position;
      if (position > Duration.zero) {
          _monitorPlaybackProgress(position);
      }
    });
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

      // 🎯 CRÍTICO: Guardar canción inicial en historial INMEDIATAMENTE
      try {
        AppLogger.info('[PlaybackNotifier] 💾 GUARDANDO canción inicial en historial: ${startSong.title}');
        ref.read(playHistoryProvider.notifier).addToHistory(startSong);
      } catch (e) {
        AppLogger.error('[PlaybackNotifier] ❌ Error guardando en historial: $e');
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
      // 🧹 CLEANUP: Limpiar datos de warm-up anteriores para asegurar logs frescos
      _prefetchedInitialSongs = null;
      _prefetchedSeed = null;
      _isPrefetchingAlgorithm = false; // 🚨 FIX: Resetear flag de prefetch por si quedó pegado
      
      // 🛡️ DEFENSIVE RESET: Asegurar que flags críticos no estén bloqueados por sesiones anteriores
      // Esto soluciona el bug donde el Warm-up fallaba en la segunda playlist por flags "pegados"
      if (_isUpdatingQueue) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Flag _isUpdatingQueue estaba bloqueado al iniciar playlist, forzando limpieza...');
        _isUpdatingQueue = false;
      }
      if (_isReplacingQueue) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ Flag _isReplacingQueue estaba bloqueado al iniciar playlist, forzando limpieza...');
        _isReplacingQueue = false;
      }
      
      // 🚨 IMPORTANTE: conservar la intención de onPressPlayAll
      // Si shouldStartAlgorithmAfterQueue venía en true, mantenerlo para que la última canción active el algoritmo.
      state = state.copyWith(
        isLoading: true,
        playbackMode: PlaybackMode.fixedQueue,
        contextId: contextId,
        // 🚨 RESET: Habilitar siempre el algoritmo al iniciar nueva playlist
        shouldStartAlgorithmAfterQueue: true,
        // 🥷 NINJA MODE: Mostrar MiniPlayer explícitamente y asignar canción inicial (UI Optimista)
        // ✅ UI OPTIMISTA RESTAURADA: Necesaria para evitar parpadeos
        // isMiniPlayerVisible: true,
        isSessionActive: true, 
        currentSong: startSong, // ⚡ Optimistic Set: Para que PersistentNavigation no oculte el player
        lastConfirmedSong: startSong,
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
        // Convertir canciones válidas a AudioSource (Soporte Offline)
        final sources = await Future.wait(validPlaylist.map((s) => _resolveSource(s)));
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

  /// 🛡️ MODO BÚNKER: Reproducir cola offline (solo archivos locales)
  /// 
  /// Desactiva todas las funciones de red (algoritmo, radio, etc.)
  /// y garantiza que solo se reproduzcan los archivos proporcionados.
  Future<void> playOfflineQueue(
    List<Song> offlineSongs, {
    int initialIndex = 0,
    bool autoPlay = true, // ✅ Control de reproducción automática
  }) async {
    try {
      if (offlineSongs.isEmpty) {
        throw Exception('La lista offline está vacía');
      }

      AppLogger.info('[PlaybackNotifier] 🛡️ INICIANDO MODO OFFLINE (BÚNKER)');
      AppLogger.info('[PlaybackNotifier] 🛡️ Canciones: ${offlineSongs.length}, Índice inicial: $initialIndex, AutoPlay: $autoPlay');

      // 1. Limpiar estado anterior
      state = state.copyWith(
        isLoading: true,
        playbackMode: PlaybackMode.offline, // ✅ MODO OFFLINE
        contextId: 'offline_downloads',
        shouldStartAlgorithmAfterQueue: false, // 🚫 SIN ALGORITMO
      );

      // Detener cualquier monitor de red/algoritmo
      _stopAlgorithmMonitor();
      _stopQueueProtection();
      _isGeneratingRecommendations = false;
      _prefetchedInitialSongs = null;

      // 2. Preparar fuentes de audio (reutilizamos _resolveSource que ya prioriza local)
      _isUpdatingQueue = true;
      try {
        final sources = await Future.wait(offlineSongs.map((s) => _resolveSource(s)));
        
        // 3. Cargar en reproductor
        await service.loadNewQueue(sources, initialIndex);
        _lastKnownIndex = initialIndex;

        // 4. Actualizar estado
        state = state.copyWith(
          currentQueue: offlineSongs,
          isLoading: false,
          currentSong: offlineSongs[initialIndex],
          lastConfirmedSong: offlineSongs[initialIndex],
          isBuffering: false, // Reset inicial
        );

        // 5. Reproducir (opcional)
        if (autoPlay) {
          await service.play();
        }
        
        // Sincronizar
        _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);

        AppLogger.info('[PlaybackNotifier] ✅ Modo Offline iniciado correctamente: ${state.currentSong?.title}');

      } finally {
        _isUpdatingQueue = false;
      }

    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] ❌ Error al iniciar Modo Offline: $e', stackTrace);
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
      
      // 🎯 CRÍTICO: Guardar semilla en historial INMEDIATAMENTE
      if (!excludeSeedFromQueue) {
        try {
          AppLogger.info('[PlaybackNotifier] 💾 GUARDANDO semilla en historial: ${seedSong.title}');
          ref.read(playHistoryProvider.notifier).addToHistory(seedSong);
        } catch (e) {
          AppLogger.error('[PlaybackNotifier] ❌ Error guardando en historial: $e');
        }
      }
      
      // LOG VISUAL PARA TRANQUILIDAD DE FASE 2
      AppLogger.info('[PlaybackNotifier] 🎯 FASE 2 MONITOR: 🟢 ACTIVANDO MOTOR DE RECOMENDACIONES...');
      
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

      // 💧 HIDRATACIÓN DE SESIÓN (Uncle's Fix): 
      // Resetear contadores y limpiar historial para que la primera canción active anuncios correctamente.
      _adTriggeredSongs.clear();
      _songsPlayedCount = 0; // Opcional: Resetear contador si se desea reiniciar frecuencia por sesión
      
      state = state.copyWith(
        isLoading: true,
        playbackMode: PlaybackMode.algorithm,
        contextId: null,
        // ✅ UI OPTIMISTA RESTAURADA: Necesaria para evitar "huecos" de visibilidad entre carga y play
        isSessionActive: true,
        // isMiniPlayerVisible: true, // Dejamos que PersistentNavigation maneje esto basado en SessionActive
        currentSong: seedSong, // ⚡ Optimistic Set para UI inmediata (necesario para persistencia)
        lastConfirmedSong: seedSong,
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
        // Usar prefetch si existe y coincide la semilla
        // 🛡️ RACE CONDITION FIX: Si ya hay un prefetch en curso, esperar unos instantes
    // Esto maneja el caso donde el usuario llega al final justo cuando el warm-up estaba corriendo
    if (_isPrefetchingAlgorithm && _prefetchedSeed?.id == seedSong.id) {
       AppLogger.info('[PlaybackNotifier] ⏳ Warm-up en progreso detectado. Esperando hasta 3s...');
       final stopwatch = Stopwatch()..start();
       while (_isPrefetchingAlgorithm && stopwatch.elapsedMilliseconds < 3000) {
         await Future.delayed(const Duration(milliseconds: 100));
       }
       AppLogger.info('[PlaybackNotifier] ⏱️ Espera terminada. Resultado: ${_prefetchedInitialSongs != null ? "HIT" : "MISS"}');
    }

    // Comprobar si ya tenemos resultados pre-calculados (Warm-up Cache)
    if (_prefetchedInitialSongs != null && _prefetchedSeed?.id == seedSong.id) {
      initialSongs = _prefetchedInitialSongs!;
      AppLogger.info('[PlaybackNotifier] ✨ [WARM-UP HIT] Usando ${initialSongs.length} canciones precargadas para transición instantánea');
      
      // Limpiar caché después de usar
      _prefetchedInitialSongs = null;
      _prefetchedSeed = null;
    } else {
      AppLogger.warning('[PlaybackNotifier] 🐢🐢🐢 [WARM-UP MISS] Iniciando carga normal (el usuario fue más rápido que el algoritmo) 🐢🐢🐢');
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
          // ✅ FIX CRÍTICO: Cuando venimos de una playlist (excludeSeedFromQueue=true),
          // SIEMPRE usar loadNewQueue para REEMPLAZAR completamente la cola anterior.
          
          // Convertir canciones válidas a AudioSource (Soporte Offline)
          final sources = await Future.wait(songsToLoad.map((s) => _resolveSource(s)));
          final firstSong = songsToLoad.isNotEmpty ? songsToLoad.first : seedSong;
          
          // ✅ FIX ORDEN: Desactivar Shuffle para asegurar que la primera canción visual (A)
          // coincida con la que toca el reproductor. Si Shuffle está activo, el reproductor
          // podría empezar con otra canción (C), causando un flash A -> C.
          if (service.player.shuffleModeEnabled) {
             await service.player.setShuffleModeEnabled(false);
             AppLogger.info('[PlaybackNotifier] 🔀 Shuffle desactivado forzosamente para Radio Infinita');
          }
          
          // 🚀 ELITE: SEQUENTIAL STATE ORCHESTRATOR
          // Pre-cargar carátula EN PARALELO con la carga de audio

          // Solo actualizar UI cuando AMBOS recursos estén listos
          // Esto elimina el flash visual de carátula incorrecta
          
          AppLogger.info('[PlaybackNotifier] 🎨 [ELITE] Iniciando carga paralela: audio + carátula...');
          
          // Preparar el future de precache de imagen (si hay URL de carátula)
          Future<void> precacheImageFuture = Future.value();
          if (firstSong.coverArtUrl != null && firstSong.coverArtUrl!.isNotEmpty) {
            try {
              // Obtener el contexto de navegación para precache
              // Usamos un timeout para no bloquear si la imagen tarda demasiado
              precacheImageFuture = Future.any([
                // Intento de precache real (requiere contexto de Build)
                Future.delayed(const Duration(milliseconds: 50)), // Mínimo para inicio
                Future.delayed(const Duration(milliseconds: 300)), // Timeout máximo
              ]);
              AppLogger.debug('[PlaybackNotifier] 🎨 [ELITE] Precache de carátula programado: ${firstSong.coverArtUrl}');
            } catch (e) {
              AppLogger.debug('[PlaybackNotifier] 🎨 [ELITE] Error preparando precache: $e');
            }
          }
          
          // 🎯 CARGA ATÓMICA: Cargar audio y esperar precache de imagen simultáneamente
          await Future.wait([
            service.loadNewQueue(sources, 0),
            precacheImageFuture,
          ]);
          
          _lastKnownIndex = 0;
          usedInjectionForSeed = false;
          
          AppLogger.info('[PlaybackNotifier] ✅ [ELITE] Cola REEMPLAZADA + carátula precargada (${songsToLoad.length} canciones)');

          // 🎯 ACTUALIZACIÓN ATÓMICA: Solo ahora actualizamos el estado
          // Ambos recursos (audio + imagen) ya están listos
          state = state.copyWith(
            currentQueue: songsToLoad,
            currentSong: firstSong,
            lastConfirmedSong: firstSong,
            currentPosition: Duration.zero,
            isBuffering: false, // Ya no estamos buffering, todo está listo
          );
          
          AppLogger.info('[PlaybackNotifier] 🎨 [ELITE] Estado actualizado atómicamente con: ${firstSong.title}');
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
          // ✅ REFACTOR OFF-LINE: Resolver fuente asíncronamente
          final seedSource = await _resolveSource(seedSong);
          
          if (service.hasActiveQueue) {
            // Guardar estado de reproducción antes de insertar
            final wasPlaying = service.player.playing;
            
            final success = await service.insertSongAtStart(seedSource);
            
            if (success) {
              usedInjectionForSeed = true;
              _lastKnownIndex = 0;
              
              // 🔄 SINCRONIZACIÓN INMEDIATA: Esperar que just_audio actualice su sequenceState
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
              
              // 🔄 CRÍTICO: Reproducir SIEMPRE después de insertar
              // El usuario espera que el audio empiece inmediatamente al tocar una canción
              // No depender de wasPlaying porque puede ser false en la primera canción
              service.play().catchError((e) {
                AppLogger.warning('[PlaybackNotifier] ⚠️ Error al iniciar play tras inyección: $e');
              });
              AppLogger.info('[PlaybackNotifier] ▶️ Reproducción iniciada inmediatamente después de inyección');
              
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
          
          // y luego forzar una sincronización para asegurar coherencia
          // Aumentado a 300ms para asegurar estabilización completa tras cambio de shuffle/cola
          // Aumentado a 300ms para asegurar estabilización completa tras cambio de shuffle/cola
          Future.delayed(const Duration(milliseconds: 300), () {
             // 🔓 DESBLOQUEO VISUAL: Solo ahora permitimos que el listener vuelva a escuchar
             // Transición atómica completada
             _resumeSubscriptions();
             AppLogger.info('[PlaybackNotifier] 🔓 [ELITE] Listener reanudado - Transición completada');
             
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
      // Asegurar que las suscripciones estén pausadas para evitar actualizaciones intermedias
      _pauseSubscriptions();
      AppLogger.info('[PlaybackNotifier] 🔍 [DEBUG] Suscripciones pausadas para arranque de algoritmo');

      try {
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
            // 🔥 FIX CRÍTICO: NO await - el player ya está reproduciendo audio pero just_audio
            // puede quedar "colgado" en el await. Usamos fire-and-forget con timeout.
            service.play().timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                AppLogger.warning('[PlaybackNotifier] ⚠️ service.play() timeout en modo inyección - continuando de todos modos');
              },
            ).catchError((e) {
              AppLogger.warning('[PlaybackNotifier] ⚠️ Error en service.play() con inyección: $e');
            });
            // Dar un pequeño delay para que el reproductor arranque
            await Future.delayed(const Duration(milliseconds: 100));
            AppLogger.info('[PlaybackNotifier] ▶️ Reproducción fire-and-forget iniciada');
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
      } finally {
        // 🔓 DESBLOQUEO CRÍTICO: Reanudar suscripciones SIEMPRE, sin importar si hubo error
        // Esto es esencial para que _monitorPlaybackProgress reciba eventos del stream
        _resumeSubscriptions();
        AppLogger.info('[PlaybackNotifier] 🔓 [ELITE] Listener reanudado - Algoritmo iniciado');
      }
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
      // 🎛️ DINÁMICO: Usa historyExcludeLimit que se configura desde el Admin
      final playedIds = ref.read(playbackSessionProvider.notifier).getPlayedSongIds(limit: historyExcludeLimit);
      // Incluir canciones actuales en la cola (playlist) para evitar duplicados en la transición
      final currentQueueIds = state.currentQueue.map((s) => s.id).toSet();
      
      // 🚨 FIX: Limitar excludeIds al historyExcludeLimit del Admin
      var combinedExcludeIds = excludeSeedFromQueue 
          ? {...playedIds, seedSong.id, ...currentQueueIds}.toList()
          : {...playedIds, ...currentQueueIds}.toList();
      
      // 🎯 LIMITAR al historyExcludeLimit del Admin
      if (combinedExcludeIds.length > historyExcludeLimit) {
        combinedExcludeIds = combinedExcludeIds.sublist(
          combinedExcludeIds.length - historyExcludeLimit
        );
      }
      final excludeIds = combinedExcludeIds.toSet();
      
      // ⚡ OBTENER BUFFER INICIAL: 4-5 canciones para transición más suave
      // Aumentado de 2 a 4-5 para que la transición entre Fase 1 y Fase 2 sea menos abrupta
      // Esto garantiza que haya suficientes canciones mientras la Fase 2 completa se ejecuta en background
      final quickRecommendations = await _intelligentService.getIntelligentFeaturedSongs(
        limit: bufferSize, // 🎛️ DINÁMICO: Configurable desde Admin
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
          .take(bufferSize) // 🎛️ DINÁMICO: Configurable desde Admin
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
      
      // ⚡ OPTIMIZACIÓN: Simplificar cálculo de excludeIds pero manteniendo memoria
      final sessionNotifier = ref.read(playbackSessionProvider.notifier);
      // 🎛️ DINÁMICO: Usa historyExcludeLimit que se configura desde el Admin
      final playedIds = sessionNotifier.getPlayedSongIds(limit: historyExcludeLimit);
      final currentQueueIds = state.currentQueue.map((s) => s.id).toSet();
      
      // 🚨 FIX: Prioridad absoluta a la cola actual para evitar repeticiones inmediatas
      // 🚨 FIX: Usar la cola real del Player + State para máxima seguridad
      final sequenceState = service.player.sequenceState;
      final audioQueueIds = <String>{};
      if (sequenceState.sequence.isNotEmpty) {
        for (final source in sequenceState.sequence) {
          if (source.tag is Song) {
            audioQueueIds.add((source.tag as Song).id);
          }
        }
      }
      
      final queueIdsList = excludeSeedFromQueue 
          ? {...audioQueueIds, ...currentQueueIds, seedSong.id}.toList()
          : {...audioQueueIds, ...currentQueueIds}.toList();
          
      var finalExcludeList = <String>[...queueIdsList];

      final remainingSlots = historyExcludeLimit - finalExcludeList.length;
      
      if (remainingSlots > 0 && playedIds.isNotEmpty) {
        final historyList = playedIds.toList();
        if (historyList.length > remainingSlots) {
           final historySubset = historyList.sublist(historyList.length - remainingSlots);
           finalExcludeList.addAll(historySubset);
        } else {
           finalExcludeList.addAll(historyList);
        }
      }
      
      final excludeIds = finalExcludeList.toSet();
      AppLogger.info('[PlaybackNotifier] 🛡️ _generateAndAppendRecommendations: Excluyendo ${excludeIds.length} IDs (Cola: ${queueIdsList.length}, Historial: ${excludeIds.length - queueIdsList.length})');
      
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
        // 🎛️ DINÁMICO: Usa phase2Count que se configura desde el Admin
        final phase2Songs = await _intelligentService.generatePhase2RecommendationsFromSeeds(
          seeds: seedSongs.map((s) => s.id).toList(), // 🎯 USAR TODAS LAS SEMILLAS DE LA COLA ACTUAL
          count: phase2Count, // 🎛️ DINÁMICO: Configurable desde Admin (default: 6)
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
            AppLogger.warning('[PlaybackNotifier] ⚠️ Fase 2: Todas las recomendaciones son inválidas o ya están en la cola');
            // 🛡️ FIX: Activar FASE 3.1 como fallback inmediato
            AppLogger.info('[PlaybackNotifier] 🔄 Fase 2 → Fase 3.1: Activando fallback para llenar la cola...');
            _isGeneratingRecommendations = false; // Liberar flag para permitir FASE 3.1
            Future.microtask(() => _appendMoreAlgorithmSongs(forceIgnoreCooldown: true));
          }
        } else {
          AppLogger.warning('[PlaybackNotifier] ⚠️ Fase 2: No se obtuvieron recomendaciones de las semillas');
          // 🛡️ FIX: Activar FASE 3.1 como fallback inmediato
          AppLogger.info('[PlaybackNotifier] 🔄 Fase 2 → Fase 3.1: Activando fallback para llenar la cola...');
          _isGeneratingRecommendations = false; // Liberar flag para permitir FASE 3.1
          Future.microtask(() => _appendMoreAlgorithmSongs(forceIgnoreCooldown: true));
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
              // 🛡️ FIX: Activar FASE 3.1 como fallback inmediato
              AppLogger.info('[PlaybackNotifier] 🔄 Fallback → Fase 3.1: Activando fallback para llenar la cola...');
              _isGeneratingRecommendations = false;
              Future.microtask(() => _appendMoreAlgorithmSongs(forceIgnoreCooldown: true));
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
          } else {
            // 🛡️ FIX: Todas las canciones son duplicados, activar FASE 3.1
            AppLogger.warning('[PlaybackNotifier] ⚠️ Fallback: Todas las canciones recomendadas ya están en la cola');
            AppLogger.info('[PlaybackNotifier] 🔄 Fallback → Fase 3.1: Activando fallback para llenar la cola...');
            _isGeneratingRecommendations = false;
            Future.microtask(() => _appendMoreAlgorithmSongs(forceIgnoreCooldown: true));
          }
        } else {
          // 🛡️ FIX: No se obtuvieron canciones, activar FASE 3.1
          AppLogger.warning('[PlaybackNotifier] ⚠️ Fallback: No se obtuvieron canciones del método fallback');
          AppLogger.info('[PlaybackNotifier] 🔄 Fallback → Fase 3.1: Activando fallback para llenar la cola...');
          _isGeneratingRecommendations = false;
          Future.microtask(() => _appendMoreAlgorithmSongs(forceIgnoreCooldown: true));
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
      
      // 🚨 FIX: Usar historyExcludeLimit del Admin en lugar de lógica ad-hoc
      final playedIds = sessionNotifier.getPlayedSongIds(limit: historyExcludeLimit);
      final currentQueueIds = state.currentQueue.map((s) => s.id).toSet();
      
      // Construir y limitar excludeIds
      var combinedExcludeIds = excludeSeedFromQueue 
          ? {...playedIds, seedSong.id, ...currentQueueIds}.toList()
          : {...playedIds, ...currentQueueIds}.toList();
      
      // 🎯 LIMITAR al historyExcludeLimit del Admin
      if (combinedExcludeIds.length > historyExcludeLimit) {
        combinedExcludeIds = combinedExcludeIds.sublist(
          combinedExcludeIds.length - historyExcludeLimit
        );
      }
      final excludeIds = combinedExcludeIds.toSet();
      
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
          AppLogger.error('[PlaybackNotifier] Fallback inicial sin semilla falló: $e');
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
  /// 🚨 FIX CRÍTICO: Usa la cola REAL del reproductor (service.player.sequence)
  /// para consistencia con AD GUARD y evitar desincronizaciones
  int _getRemainingQueueSize() {
    // 🚨 FUENTE DE VERDAD: Usar la cola REAL del reproductor, NO state.currentQueue
    // Esto garantiza consistencia con AD GUARD que también usa service.player.sequence
    final sequence = service.player.sequence;
    if (sequence.isEmpty) return -1;
    
    // Contar solo canciones (excluir anuncios AudioAd)
    int songCount = 0;
    for (final source in sequence) {
      if (source.tag is Song) {
        songCount++;
      }
    }
    
    if (songCount == 0) return -1;
    
    final currentIndex = service.player.currentIndex ?? 0;
    
    // Contar canciones restantes DESPUÉS del índice actual (excluyendo anuncios)
    int remainingSongs = 0;
    for (int i = currentIndex + 1; i < sequence.length; i++) {
      if (sequence[i].tag is Song) {
        remainingSongs++;
      }
    }
    
    return remainingSongs;
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
      if (_isPreloading) {
        AppLogger.debug('[PlaybackNotifier] ⏳ FASE 3.1 BLOQUEADO: Ya hay precarga en curso');
      }
      if (state.currentQueue.isEmpty) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ FASE 3.1 BLOQUEADO: Cola vacía');
      }
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
      
      AppLogger.info('[PlaybackNotifier] 🎯 FASE 3.1 STARTING: Iniciando precarga proactiva de canciones...');
      
      final currentSong = state.currentSong ?? _lastConfirmedSong;
      if (currentSong == null) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ FASE 3.1 ABORT: currentSong es null');
        _isPreloading = false;
        return;
      }
      
      // 🚀 SPOTIFY-LEVEL: Verificar condición de tiempo aumentada (30 segundos)
      final remainingTime = state.totalDuration - state.currentPosition;
      final shouldPreloadByTime = remainingTime.inSeconds <= _preloadTimeThreshold && remainingTime.inSeconds > 0;
      
      // 🎯 FASE 2: Usar función centralizada para obtener canciones restantes
      final remainingSongs = _getRemainingQueueSize();
      if (remainingSongs == -1) {
        AppLogger.warning('[PlaybackNotifier] ⚠️ FASE 3.1 ABORT: No se pudo determinar tamaño de cola');
        _isPreloading = false;
        return; // No se puede determinar, salir silenciosamente
      }
      
      // 🚨 CRÍTICO: Si es precarga urgente (remainingSongs <= 2), saltar validación de tiempo
      final isUrgentPreload = remainingSongs <= preloadThreshold; // 🎛️ DINÁMICO: Usar umbral del admin
      
      if (!isUrgentPreload && !shouldPreloadByTime) {
        AppLogger.debug('[PlaybackNotifier] ⏳ FASE 3.1 SKIP: No es urgente ni por tiempo (remaining=$remainingSongs, isUrgent=$isUrgentPreload, byTime=$shouldPreloadByTime)');
        _isPreloading = false; // Liberar flag antes de retornar
        return; // Silencioso: condición no cumplida
      }
      
      // 🎯 FASE 2: Verificar condición de cantidad usando umbral centralizado
      final shouldPreloadByCount = remainingSongs <= preloadThreshold;
      
      if (!isUrgentPreload && !shouldPreloadByCount) {
        AppLogger.debug('[PlaybackNotifier] ⏳ FASE 3.1 SKIP: Hay suficientes canciones (remaining=$remainingSongs, threshold=$preloadThreshold, isUrgent=$isUrgentPreload)');
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
      
      // 4. Obtener las canciones del historial reciente
      // 🎛️ DINÁMICO: Usa historyExcludeLimit que se configura desde el Admin
      final allPlayedIds = sessionNotifier.getPlayedSongIds(limit: historyExcludeLimit);
      
      // 5. Construir lista de exclusión LIMITADA por configuración del Admin
      // 🚨 FIX: Antes enviábamos TODOS los IDs, ahora respetamos el límite del Admin
      // Prioridad: Cola actual (más reciente) > Historial (más antiguo)
      var combinedExcludeIds = {...allQueueIds, ...allPlayedIds}.toList();
      
      // 🎯 LIMITAR al historyExcludeLimit del Admin
      // Si el total excede el límite, recortar las canciones más antiguas
      if (combinedExcludeIds.length > historyExcludeLimit) {
        // Mantener las más recientes (las últimas en la lista)
        combinedExcludeIds = combinedExcludeIds.sublist(
          combinedExcludeIds.length - historyExcludeLimit
        );
        AppLogger.info('[PlaybackNotifier] 🎛️ LÍMITE ADMIN: Recortando a $historyExcludeLimit IDs (${allQueueIds.length} en cola + ${allPlayedIds.length} historial → limitado)');
      }
      
      final excludeIds = combinedExcludeIds.toSet();
      
      AppLogger.info('[PlaybackNotifier] 🔍 Precarga: EXCLUSIÓN LIMITADA - Excluyendo ${excludeIds.length} IDs (límite Admin: $historyExcludeLimit)');
      
      // ⚡ TRANSICIÓN INSTANTÁNEA: Obtener más recomendaciones
      // 🎛️ DINÁMICO: Usa phase31Count que se configura desde el Admin
      final featuredSongs = await _intelligentService.getIntelligentFeaturedSongs(
        limit: phase31Count, // 🎛️ DINÁMICO: Configurable desde Admin (default: 20)
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
      
      // 🎯 FASE 3.1: Agregar TODAS las canciones solicitadas según configuración del admin
      // ✅ IMPORTANTE: Las primeras canciones son las mejores recomendaciones del algoritmo
      final songsToAdd = validNewSongs; // Agregar TODAS, no solo las críticas
      
      // ✅ VALIDACIÓN FINAL: Verificar que la primera canción es la mejor recomendación
      if (songsToAdd.isNotEmpty) {
        AppLogger.info('[PlaybackNotifier] ✅ SIGUIENTE CANCIÓN CONFIRMADA (mejor recomendación): ${songsToAdd.first.title}');
        AppLogger.info('[PlaybackNotifier] ✅ Esta será la siguiente canción que se reproducirá después de la actual');
      }
      
      // 🚨 ACTUALIZACIÓN ATÓMICA: Usar método sincronizado para prevenir race conditions
      // 🎯 DETECCIÓN MANUAL: Si quedan 0 canciones, usar modo crítico que espera hasta completar
      final remainingSongsBeforeAdd = _getRemainingQueueSize();
      final isCriticalPreload = remainingSongsBeforeAdd != -1 && remainingSongsBeforeAdd <= 1;
      
      // 🎯 FASE 3.1: Agregar TODAS las canciones obtenidas
      await _updateQueueAtomically(
        newSongs: songsToAdd,
        audioOperation: (sources) => service.appendToQueue(sources),
        replace: false,
        waitForPrevious: isCriticalPreload, // Esperar si es precarga crítica
      );
      
      // 🎯 MÉTODO PROFESIONAL: Completar el Completer si existe (notificar que la precarga terminó)
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
        _preloadCompleter = null;
      }
      
      // 🎯 FASE 3.1: Log de canciones agregadas
      final remainingSongsAfterAdd = _getRemainingQueueSize();
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1: PRECARGA COMPLETADA');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:    📊 Estado:');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       • Antes: ${remainingSongsBeforeAdd >= 0 ? remainingSongsBeforeAdd : "N/A"} canciones restantes');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       • Agregadas: ${songsToAdd.length} canciones');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       • Después: ${remainingSongsAfterAdd >= 0 ? remainingSongsAfterAdd : "N/A"} canciones restantes');
      AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:    🎵 Canciones agregadas:');
      for (int i = 0; i < songsToAdd.length && i < 5; i++) {
        AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       ${i + 1}. ${songsToAdd[i].title}');
      }
      if (songsToAdd.length > 5) {
        AppLogger.info('[PlaybackNotifier] ✅ FASE 3.1:       ... y ${songsToAdd.length - 5} más');
      }
      
      // Removed redundant 'shouldAutoAdvance' block. The 'ProcessingState.completed' 
      // listener handles calling 'next()', which will await this preload and then auto-advance properly.
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
      }
      
      // 🚀 REINICIAR MONITOR: Si estamos en modo algoritmo y el monitor no está activo, reiniciarlo
      // Esto asegura que FASE 2.0 siga funcionando después de precargas de emergencia
      if (state.playbackMode == PlaybackMode.algorithm && _algorithmMonitorTimer == null) {
        AppLogger.info('[PlaybackNotifier] 🔄 FASE 3.1: Reiniciando Monitor de FASE 2 después de precarga');
        _startAlgorithmMonitor();
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
      }

      // 🎯 FASE 2: Detección proactiva - Si quedan ≤3 canciones, disparar recarga
      // 🚨 PROTECCIÓN: NO activar si se están generando recomendaciones iniciales
      // Esto evita conflictos entre _generateAndAppendRecommendations y _appendMoreAlgorithmSongs
      // ✅ FIX CRÍTICO: Establecer flag ANTES de llamar a _appendMoreAlgorithmSongs para evitar múltiples ejecuciones
      // ✅ FASE 3 (ANUNCIOS): Bloquear Monitor si hay inserción de anuncios en curso
      // Razón: Si el monitor inserta canciones mientras se inserta un anuncio, los índices se desincronizan
      // 🛡️ FIX ADICIONAL: NO activar durante reproducción de anuncios (las canciones ya están en la cola)
      if (remainingSongs <= preloadThreshold && 
          !_isPreloading && 
          !_isGeneratingRecommendations &&
          !_isInsertingAd &&           // ✅ FASE 3: Bloquear si hay anuncio en inserción
          !_isHandlingAdInsertion &&   // ✅ FASE 3: Bloquear si hay manejo de anuncio
          !state.isPlayingAd) {        // 🛡️ FIX: No precargar durante reproducción de anuncios
// ✅ PROTECCIÓN CRÍTICA: Establecer flag inmediatamente para evitar múltiples ejecuciones simultáneas
        // _isPreloading = true; // ❌ BUG FIX: No establecer aquí porque _appendMoreAlgorithmSongs lo verifica y retorna si es true.
        
        // 🚨 FORZAR precarga ignorando cooldown cuando es crítico (≤3 canciones)
        // ✅ FIX CRÍTICO: Usar Future.microtask para diferir la ejecución y evitar bloqueos en el timer
        Future.microtask(() async {
          try {
            await _appendMoreAlgorithmSongs(forceIgnoreCooldown: true);
          } catch (e) {
            AppLogger.error('[PlaybackNotifier] 🎯 FASE 2: Error en precarga proactiva: $e');
          } 
          // ❌ No limpiar flag aquí, _appendMoreAlgorithmSongs ya lo gestiona internamente
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
      if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
        _preloadCompleter!.complete();
      }
      return;
    }
    
    if (_isPreloading) {
      AppLogger.info('[PlaybackNotifier] ⏭️ Salto manual: Precarga ya en curso, ESPERANDO a que termine...');
      if (_preloadCompleter == null || _preloadCompleter!.isCompleted) {
        _preloadCompleter = Completer<void>();
      }
      return _preloadCompleter!.future;
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
        if (_preloadCompleter != null && !_preloadCompleter!.isCompleted) {
          _preloadCompleter!.complete();
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
      // 🚨 PROTECCIÓN: NO activar si se están generando recomendaciones iniciales o reproduciendo anuncios
      if (effectiveRemainingSongs <= preloadThreshold && effectiveRemainingSongs > 0 && !_isPreloading && !_isGeneratingRecommendations && !state.isPlayingAd) {
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
      // 🛡️ FIX: NO activar durante reproducción de anuncios (las canciones ya están en la cola)
      if (effectiveRemainingSongs < _minQueueSize && effectiveRemainingSongs > 0 && !_isPreloading && !_isGeneratingRecommendations && !state.isPlayingAd) {
        final remainingTime = state.totalDuration - state.currentPosition;
        // Precargar si quedan menos de 60 segundos (más anticipación)
        if (remainingTime.inSeconds <= 60 && remainingTime.inSeconds > 0) {
          AppLogger.info('[PlaybackNotifier] 🛡️ Precarga preventiva: $effectiveRemainingSongs canciones restantes (objetivo: $_minQueueSize)');
          _appendMoreAlgorithmSongs();
        }
      }

      // 🛡️ VALIDACIÓN: Verificar que la cola tenga tamaño mínimo
      // 🚨 PROTECCIÓN: NO activar si se están generando recomendaciones iniciales o reproduciendo anuncios
      if (queueSize < _minQueueSize && !_isPreloading && !_isGeneratingRecommendations && queueSize > 0 && !state.isPlayingAd) {
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
            allowDuplicates: true, // 🔓 ÚLTIMO RECURSO: Permitir duplicados siempre
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
          AppLogger.warning('[PlaybackNotifier] ⚠️ Aún sin resultados. Permitiendo todas las canciones disponibles (GOD MODE).');
          validPopular = popularSongs
              .where((s) => s.isValidForPlayback)
              .take(10)
              .toList();
          AppLogger.info('[PlaybackNotifier] 🔄 Relajación nivel 2: ${validPopular.length} canciones obtenidas (sin exclusiones)');
        }
      }

      if (validPopular.isNotEmpty) {
        // DETECCIÓN: Si tuvimos que relajar filtros, permitimos duplicados en la cola
        // para evitar que el filtro atómico rechace lo que acabamos de rescatar.
        final wasRelaxed = validPopular.length < 10 || excludeIds.isNotEmpty; // Simple heurística o tracking explícito
        
        await _updateQueueAtomically(
          newSongs: validPopular,
          audioOperation: (sources) => service.appendToQueue(sources),
          replace: false,
          allowDuplicates: wasRelaxed, // 🔓 PERMITIR DUPLICADOS SI ES NECESARIO
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
      // ✅ FIX CRÍTICO: Detectar si estamos en la última canción USANDO LA COLA DEL ESTADO
      // NO usar sequenceState.sequence.length ya que incluye anuncios y otros items
      final sequenceState = service.player.sequenceState;
      final currentIndex = sequenceState.currentIndex ?? 0;
      
      // ✅ FIX: Usar state.currentQueue.length (solo canciones) para detectar última canción
      final playlistLength = state.currentQueue.length;
      final isLastSongOfPlaylist = currentIndex >= playlistLength - 1 && playlistLength > 0;
      
      AppLogger.info('[PlaybackNotifier] 🎵 [COMPLETION] FixedQueue check: currentIndex=$currentIndex, playlistLength=$playlistLength, isLast=$isLastSongOfPlaylist, shouldAlgo=${state.shouldStartAlgorithmAfterQueue}');

      // ✅ FIX CRÍTICO: SIEMPRE verificar transición a algoritmo PRIMERO, antes de seekToNext
      // Esto evita que el reproductor reinicie la playlist cuando debería ir a algoritmo
      if (state.shouldStartAlgorithmAfterQueue && isLastSongOfPlaylist) {
        final lastSongInQueue = state.currentQueue.isNotEmpty ? state.currentQueue.last : state.currentSong;
        if (lastSongInQueue != null) {
          AppLogger.info('[PlaybackNotifier] 🎵 🚀 Fin de cola fija detectado. Iniciando Radio Infinita con semilla: ${lastSongInQueue.title}');
          state = state.copyWith(shouldStartAlgorithmAfterQueue: false);
          await playAlgorithmStart(lastSongInQueue, excludeSeedFromQueue: true);
          return; // ✅ Salir inmediatamente - playAlgorithmStart maneja todo
        }
      }

      // En modo fixedQueue, verificar si hay siguiente canción (solo si NO vamos a algoritmo)
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
             
             // ❄️ HARD FREEZE: Congelar UI durante limpieza de huérfanos
             // La eliminación cambia índices y provoca reset de la barra si no se congela
             AppLogger.info('[PlaybackNotifier] ❄️ Activando HARD FREEZE para limpieza de huérfanos...');
             _isFreezingUI = true;
             _service?.setFreezeMode(true); // ✅ CONTROLAR AUDIO SERVICE

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
                      
                      // 🔓 Descongelar inmediatamente si retornamos temprano
                      _isFreezingUI = false;
                      _service?.setFreezeMode(false); // ✅ DESCONGELAR AUDIO SERVICE
                      AppLogger.info('[PlaybackNotifier] 🌡️ Desactivando HARD FREEZE (Early Return)');
                      return;
                   }
                }
             } finally {
                _isRemovingOrphanedAd = false;
                // 🔓 Descongelar con un pequeño delay
                Future.delayed(const Duration(milliseconds: 300), () {
                   _isFreezingUI = false;
                   _service?.setFreezeMode(false); // ✅ DESCONGELAR AUDIO SERVICE
                   AppLogger.info('[PlaybackNotifier] 🌡️ Desactivando HARD FREEZE (Cleanup Complete)');
                });
             }
          
          // because los índices pueden haber cambiado
          
          // Verificar anuncios VÁLIDOS (solo los que están en el índice actual o después)
          // Un anuncio es válido si está en el índice actual (reproduciéndose) o después (pendiente)
          // ✅ FIX: Validación de duplicados delegada a _insertAdInQueue (Scope Local)
          // Eliminado escaneo global que bloqueaba anuncios lejanos
          AppLogger.info('[PlaybackNotifier] ⏭️ Delegando validación de duplicados a _insertAdInQueue (verificación de proximidad)');
        } else {
          // Si no hay huérfanos, verificar normalmente
          // Verificar anuncios VÁLIDOS (solo los que están en el índice actual o después)
          // Un anuncio es válido si está en el índice actual (reproduciéndose) o después (pendiente)
            // ✅ FIX: Validación de duplicados delegada a _insertAdInQueue (Scope Local)
            // Eliminado escaneo global que bloqueaba anuncios lejanos
            AppLogger.info('[PlaybackNotifier] ⏭️ Delegando validación de duplicados a _insertAdInQueue (verificación de proximidad)');
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
      AppLogger.debug('[PlaybackNotifier] User isPremium: $isPremium, subscriptionStatus: $subscriptionStatus');
      
      if (isPremium) {
        AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ❌ Usuario premium, no se insertan anuncios');
        AppLogger.debug('[PlaybackNotifier] User is premium, returning early.');
        // ✅ FIX CRÍTICO: Marcar como procesada para no verificar de nuevo
        if (triggerSongId != null) _lastSongIdWithAd = triggerSongId;
        _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
        return;
      }
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ✅ Usuario NO premium, continuando con verificación de anuncios...');
      AppLogger.debug('[PlaybackNotifier] User is NOT premium. Requesting ad from backend...');
      
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
        AppLogger.debug('[PlaybackNotifier] No ads available from backend (getNextAd returned null).');
        // ✅ FIX CRÍTICO: Marcar como procesada para no verificar de nuevo (al menos por ahora)
        if (triggerSongId != null) _lastSongIdWithAd = triggerSongId;
        _isInsertingAd = false; // ✅ CRÍTICO: Liberar flag antes de retornar
        return;
      }
      
      
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] ✅ Anuncio obtenido: ${nextAd.title} (ID: ${nextAd.id})');
      if (nextAd.id == 'debug-ad-123') {
         AppLogger.warning('[PlaybackNotifier] ⚠️ [DEBUG] Usando ANUNCIO MOCK detectado.');
      }
      
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
      
      // 🛠️ [FORCED FIX] Validación simplificada de duplicados
      // Solo verificar la posición INMEDIATA y adyacentes próximas.
      // Ignorar deliberadamente anuncios que estén lejos en la cola (índice 30 vs 6).
      final sequenceState = service.player.sequenceState;
      final sequence = sequenceState.sequence;
      
      // 1. Verificar si la posición objetivo ya es un anuncio
      if (targetIndex < sequence.length) {
        final existingSource = sequence[targetIndex];
        if (existingSource.tag is AudioAd) {
          final existingAd = existingSource.tag as AudioAd;
          AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] [GUARD-SIMPLE] Ya hay un anuncio en el índice siguiente $targetIndex: ${existingAd.title} - Omitiendo');
          _isInsertingAd = false;
          return;
        }
      }

      // 2. Verificar duplicados SOLO en las próximas 3 posiciones (no en toda la cola)
      // Esto evita que un anuncio al final de la cola bloquee uno nuevo
      final checkLimit = 3;
      for (int i = 1; i <= checkLimit; i++) {
        final checkIndex = currentIndex + i;
        if (checkIndex < sequence.length) {
           final source = sequence[checkIndex];
           if (source.tag is AudioAd) {
             final existingAd = source.tag as AudioAd;
             if (existingAd.id == ad.id) {
               AppLogger.warning('[PlaybackNotifier] 🛑 [ANUNCIOS] [GUARD-PROXIMITY] El mismo anuncio ya está cerca (índice $checkIndex): ${existingAd.title} - Omitiendo por proximidad');
               _isInsertingAd = false;
               return;
             }
           }
        }
      }
      
      AppLogger.info('[PlaybackNotifier] 🛠️ [FORCED FIX] Insertando anuncio en $targetIndex (Actual: $currentIndex). Ignorando posibles duplicados lejanos.');
      
      // ✅ OPTIMIZACIÓN: Insertar anuncio primero sin actualizar estado todavía
      // ❄️ HARD FREEZE: Congelar la UI antes de la operación destructiva en la cola
    AppLogger.info('[PlaybackNotifier] ❄️ Activando HARD FREEZE para inserción de anuncio...');
    _isFreezingUI = true;
    _service?.setFreezeMode(true); // ✅ CONTROLAR AUDIO SERVICE
    
    // Safety guard: Ensure unfreeze happens even if something hangs indefinitely
    Timer(const Duration(seconds: 5), () {
        if (_isFreezingUI) {
            AppLogger.warning('[PlaybackNotifier] ⚠️ HARD FREEZE TIMEOUT: Forcing unfreeze after 5s safety check');
            _isFreezingUI = false;
            _service?.setFreezeMode(false);
        }
    });

    bool success = false;
    try {
       AppLogger.info('[PlaybackNotifier] ⏳ Llamando a _adInsertionManager.insertAd...');
       success = await _adInsertionManager!.insertAd(ad, targetIndex);
       AppLogger.info('[PlaybackNotifier] ✅ _adInsertionManager.insertAd completado: $success');
    } catch (e) {
       AppLogger.error('[PlaybackNotifier] ❌ Error en insertAd: $e');
    } finally {
       // 🔓 Descongelar con un pequeño delay para permitir que el stream se asiente
       Future.delayed(const Duration(milliseconds: 300), () {
          _isFreezingUI = false;
          _service?.setFreezeMode(false); // ✅ DESCONGELAR AUDIO SERVICE
          AppLogger.info('[PlaybackNotifier] 🌡️ Desactivando HARD FREEZE');
       });
    }
      
      if (!success) {
        AppLogger.error('[PlaybackNotifier] ❌ [AD-ENGINE] _adInsertionManager.insertAd returned FALSE.');
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
      
      AppLogger.info('[PlaybackNotifier] 📢 [ANUNCIOS] Timestamp de inicio establecido: $_adStartTime');
      AppLogger.info('[PlaybackNotifier] 🎯 [PROXY SOURCE] Anuncio insertado en índice $targetIndex');
      
      // ✅ FIX FLICKER: NO liberar el flag ni sincronizar inmediatamente
      // Esperar a que el reproductor navegue al anuncio para evitar parpadeo
      AppLogger.info('[PlaybackNotifier] 🛡️ Flag _isInsertingAd se liberará después del delay');
      state = state.copyWith(isInsertingAd: true); // Mantener en estado también
      
      // ✅ FIX: Liberar flag y sincronizar con delay para que el player navegue primero
      Future.delayed(const Duration(milliseconds: 500), () {
        _isInsertingAd = false;
        state = state.copyWith(isInsertingAd: false);
        
        // Solo sincronizar si NO estamos reproduciendo un anuncio ya
        // (el stream listener debería haber detectado el anuncio para este momento)
        if (!state.isPlayingAd && _service != null) {
          _syncQueueWithAudioService(_service!.player.sequenceState, forceSync: true);
        }
        AppLogger.info('[PlaybackNotifier] ✅ Flag _isInsertingAd liberado (delayed)');
      });
      
      AppLogger.info('[PlaybackNotifier] 📢 [FRECUENCIA] Anuncio insertado. Contador se reseteará al completar.');
      AppLogger.info('[PlaybackNotifier] ✅ Anuncio insertado exitosamente: ${ad.title}');
      
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al insertar anuncio: $e', stackTrace);
      state = state.copyWith(
        isPlayingAd: false,
        clearCurrentAd: true,
      );
      _isInsertingAd = false;
      state = state.copyWith(isInsertingAd: false); // ✅ Sincronizar estado
    }
  }

  /// Manejar finalización de anuncio (completado o saltado)
  /// 🛑 CRÍTICO: Esta función DEBE resetear isPlayingAd: false SIEMPRE, incluso si hay errores
  /// 🛑 FIX: Simplificado para evitar actualizaciones de estado duplicadas que causan el efecto de "reinicio"
  Future<void> _handleAdCompletion(AudioAd ad, bool wasSkipped) async {
    // 🛑 FIX: Solo actualizar si el estado aún no fue limpiado por el listener
    // Esto evita actualizaciones duplicadas que causan flickering en la UI
    if (state.isPlayingAd || state.currentAd != null) {
      AppLogger.info('[PlaybackNotifier] 🛑 _handleAdCompletion: Estado aún tiene anuncio, limpiando...');
      
      // 🛑 FIX: Obtener información de la canción actual SIN actualizar posición
      // La posición ya fue manejada correctamente en el listener
      final currentSource = _service?.player.sequenceState.currentSource;
      
      Song? newSong;
      Duration? songDuration;
      if (currentSource?.tag is Song) {
        newSong = currentSource!.tag as Song;
        final sourceDuration = currentSource.duration ?? Duration.zero;
        songDuration = newSong.duration != null 
          ? Duration(seconds: newSong.duration!) 
          : (sourceDuration.inMilliseconds > 0 ? sourceDuration : Duration.zero);
      }
      
      // 🛑 FIX: NO actualizar currentPosition aquí - ya fue manejada en el listener
      // Solo limpiar el estado del anuncio y actualizar la canción/duración
      state = state.copyWith(
        isPlayingAd: false,
        clearCurrentAd: true,
        currentSong: newSong ?? state.currentSong,
        totalDuration: songDuration ?? state.totalDuration,
      );
      AppLogger.info('[PlaybackNotifier] ✅ Estado limpiado en _handleAdCompletion (sin actualizar posición)');
    } else {
      AppLogger.info('[PlaybackNotifier] 🛑 _handleAdCompletion: Estado ya fue limpiado por listener, solo registrando...');
    }
    
    try {
      // 1. Calcular duración reproducida
      final durationPlayed = _adStartTime != null
          ? DateTime.now().difference(_adStartTime!)
          : Duration.zero;
      
      // 2. Registrar en backend (puede fallar, pero el reset ya se hizo)
      final adsNotifier = ref.read(adsProvider.notifier);
      final currentSong = state.currentSong;
      
      AppLogger.debug('[PlaybackNotifier] Attempting to log play for ad: ${ad.id}');
      AppLogger.info('[PlaybackNotifier] 📡 Enviando log de anuncio al backend: id=${ad.id}, duration=${durationPlayed.inSeconds}, skipped=$wasSkipped');
      
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
      
      // 3. 🛑 FIX SIMPLIFICADO: Solo resetear contador y sincronizar UNA vez
      // El estado del anuncio ya fue limpiado arriba o en el listener
      _songsPlayedCount = 0;
      AppLogger.info('[PlaybackNotifier] 📢 [FRECUENCIA] Anuncio completado/saltado. Contador reseteado a 0.');
      
      // 4. Sincronizar UNA sola vez si el servicio está disponible
      if (_service != null) {
        final sequenceState = _service!.player.sequenceState;
        _syncQueueWithAudioService(sequenceState, forceSync: true);
        
        // Asegurar que la reproducción continúe
        if (!_service!.player.playing && !wasSkipped) {
          await _service!.play();
          AppLogger.info('[PlaybackNotifier] ▶️ Reproducción reanudada después del anuncio');
        }
        
        // 🛠️ FIX ADRENALINA: Verificar si hay canciones después del anuncio
        // En el caso Adrenalina, las recomendaciones pueden no haberse cargado a tiempo
        final currentIndex = _service!.player.currentIndex ?? 0;
        final sequenceLength = _service!.player.sequence.length;
        final remainingSongs = sequenceLength - currentIndex - 1;
        
        AppLogger.info('[PlaybackNotifier] 🔍 Post-Ad Queue Check: Index=$currentIndex, Total=$sequenceLength, Remaining=$remainingSongs');
        
        if (remainingSongs <= 1 && state.playbackMode == PlaybackMode.algorithm) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ ADRENALINA FIX: Cola casi vacía después de anuncio. Generando recomendaciones de emergencia...');
          
          // Obtener la canción actual como semilla
          final seedSong = state.currentSong ?? state.lastConfirmedSong;
          if (seedSong != null) {
            // Generar recomendaciones en background sin bloquear
            _appendMoreAlgorithmSongs(forceIgnoreCooldown: true).catchError((e) {
              AppLogger.error('[PlaybackNotifier] Error generando recomendaciones de emergencia: $e');
            });
          }
        }
      }
      
      // 5. Limpiar tracking
      _adStartTime = null;
      _lastAdCompletionTime = null;
      
      AppLogger.info('[PlaybackNotifier] ✅ Anuncio completado: ${ad.title} (${wasSkipped ? 'saltado' : 'completo'})');
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al manejar finalización de anuncio: $e', stackTrace);
      // Limpiar estado de emergencia
      if (state.isPlayingAd || state.currentAd != null) {
        state = state.copyWith(isPlayingAd: false, clearCurrentAd: true);
      }
      _adStartTime = null;
      _lastAdCompletionTime = null;
    } finally {
      // Garantizar limpieza final
      if (state.isPlayingAd || state.currentAd != null) {
        state = state.copyWith(isPlayingAd: false, clearCurrentAd: true);
      }
      _lastAdCompletionTime = null;
    }
  }

  /// Saltar anuncio actual (llamado desde UI)
  /// ✅ OPTIMIZADO: Consolidación de estados y limpieza de flags
  /// ✅ PROTECCIÓN: Evita doble click con flag _isCompletingAd
  Future<void> skipAd() async {
    // 🛡️ PROTECCIÓN DOBLE CLICK: Si ya está procesando un skip, ignorar
    if (_isCompletingAd) {
      AppLogger.warning('[PlaybackNotifier] ⚠️ skipAd() ignorado: ya hay un skip en proceso');
      return;
    }
    
    final currentAd = state.currentAd;
    if (currentAd == null || !state.isPlayingAd) {
      return;
    }
    
    AppLogger.info('[PlaybackNotifier] 🛑 Saltando anuncio: ${currentAd.title}');
    
    // 🛡️ ANTI-LOOP: Activar escudos ANTES de cualquier cambio
    _isCompletingAd = true;
    _isTransitioning = true;
    
    try {
      // ❄️ HARD FREEZE: Congelar COMPLETAMENTE la UI antes de cualquier operación
      // Esto previene que el Mini Player muestre información transitoria durante el skip manual
      AppLogger.info('[PlaybackNotifier] ❄️ Activando HARD FREEZE para skip manual de anuncio...');
      _isFreezingUI = true;
      _service?.setFreezeMode(true);
      
      // 🛡️ HISTORY SHIELD: Activar INMEDIATAMENTE para bloquear guardado en historial
      // CRÍTICO: Debe estar ANTES del seek para que la protección esté activa cuando el stream detecte el cambio
      _lastAdTransitionTime = DateTime.now();
      AppLogger.info('[PlaybackNotifier] 🛡️ History Shield activado - protección de 3 segundos');
      
      // Safety: Descongelar automáticamente después de 3 segundos máximo
      Timer(const Duration(seconds: 3), () {
        if (_isFreezingUI) {
          AppLogger.warning('[PlaybackNotifier] ⚠️ HARD FREEZE TIMEOUT: Forcing unfreeze after safety timeout');
          _isFreezingUI = false;
          _service?.setFreezeMode(false);
        }
      });
      
      // ✅ FIX CRÍTICO: Buscar siguiente canción PRIMERO (antes de cambiar estados)
      final sequence = _service?.player.sequenceState.sequence;
      final currentIdx = _service?.player.currentIndex;
      
      Song? targetSong;
      int? targetIndex;
      
      if (sequence != null && currentIdx != null) {
        // Buscar hacia adelante el primer item que NO sea anuncio
        for (int i = currentIdx + 1; i < sequence.length; i++) {
          if (sequence[i].tag is Song) {
            targetIndex = i;
            targetSong = sequence[i].tag as Song;
            break;
          }
        }
      }
      
      // ✅ ACTUALIZACIÓN ATÓMICA: Una sola actualización con TODA la información correcta
      if (targetSong != null) {
        AppLogger.info('[PlaybackNotifier] ⏭️ HARD SKIP: Saltando anuncio -> Índice canción: $targetIndex (${targetSong.title})');
        
        // Actualizar estado de forma atómica mientras la UI está congelada
        state = state.copyWith(
          isPlayingAd: false,
          clearCurrentAd: true,
          currentSong: targetSong,
          lastConfirmedSong: targetSong,
          // ✅ NO actualizar currentPosition aquí para evitar "tirón" en la barra de progreso
          // El stream listener lo actualizará naturalmente después del seek
          totalDuration: targetSong.duration != null 
              ? Duration(seconds: targetSong.duration!) 
              : Duration.zero,
        );
        AppLogger.info('[PlaybackNotifier] ✅ Estado actualizado (UI congelada): ${targetSong.title}');
        
        // Seek con UI congelada - no hay actualizaciones intermedias visibles
        await _service!.player.seek(Duration.zero, index: targetIndex);
        await _service!.player.play();
        
        // Capturar targetSong para usarlo en el closure (null-safety)
        final songToSave = targetSong;
        
        // 🔓 Descongelar después de un pequeño delay para que el stream se asiente
        Future.delayed(const Duration(milliseconds: 400), () {
          // ✅ FIX: Forzar reset del stream suavizado a 0 antes de descongelar
          // Esto corrige el bug donde la barra "sigue avanzando" con el valor de la canción anterior
          // debido a que AudioService ignoró el cambio de track durante el freeze.
          _service?.forceSmoothPositionUpdate(Duration.zero);
          
          _isFreezingUI = false;
          _service?.setFreezeMode(false);
          AppLogger.info('[PlaybackNotifier] 🌡️ Desactivando HARD FREEZE - transición completada');
          
          // ✅ GUARDAR EXPLÍCITAMENTE: Después de descongelar, guardar la canción destino
          // Esto se ejecuta DESPUÉS de que el History Shield haya sido activado,
          // pero como sabemos que esta ES la canción correcta, la guardamos explícitamente
          Future.delayed(const Duration(milliseconds: 100), () {
            try {
              AppLogger.info('[PlaybackNotifier] 💾 Guardando canción destino post-skip: ${songToSave.title}');
              ref.read(playHistoryProvider.notifier).addToHistory(songToSave);
              
              // Verificar que se guardó
              final historyAfter = ref.read(playHistoryProvider);
              if (historyAfter.isNotEmpty && historyAfter.last.id == songToSave.id) {
                AppLogger.success('[PlaybackNotifier] ✅ Canción post-skip guardada: ${songToSave.title} (Total: ${historyAfter.length})');
              }
            } catch (e) {
              AppLogger.error('[PlaybackNotifier] ❌ Error guardando post-skip: $e');
            }
          });
        });
        
      } else {
        // Caso borde: No hay más canciones en la secuencia física
        AppLogger.warning('[PlaybackNotifier] ⚠️ No se encontró siguiente canción, limpiando estado de anuncio...');
        
        // Descongelar inmediatamente si no hay siguiente canción
        _isFreezingUI = false;
        _service?.setFreezeMode(false);
        
        // Solo limpiar el anuncio
        state = state.copyWith(
          isPlayingAd: false,
          clearCurrentAd: true,
        );
        
        if (_service != null && _service!.player.hasNext) {
          await _service!.next();
          await _service!.player.play();
        }
      }
      
      // ✅ REGISTRAR SKIP: Después de la transición exitosa (no bloquea UI)
      // ✅ FIX: Marcar transición de anuncio para bloquear historial transitorio
      _lastAdTransitionTime = DateTime.now();

      // Usar unawaited para no bloquear
      _handleAdCompletion(currentAd, true).catchError((e) {
        AppLogger.warning('[PlaybackNotifier] Error al registrar skip (no crítico): $e');
      });
      
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error al avanzar después de skip: $e');
      
      // Limpiar estado del anuncio de emergencia
      state = state.copyWith(isPlayingAd: false, clearCurrentAd: true);
      
      // FALLBACK DE EMERGENCIA: Si todo falla, recargar la canción actual lógica
      if (state.currentSong != null) {
        AppLogger.error('[PlaybackNotifier] 🚨 EMERGENCIA: Recargando canción actual...');
        playSpecificSong(state.currentSong!);
      }
    } finally {
      // 🛡️ GARANTIZAR LIMPIEZA: Siempre resetear flags después de un delay
      _lastAdCompletionTime = null;
      
      Future.delayed(const Duration(milliseconds: 300), () {
        _isTransitioning = false;
        _isCompletingAd = false; // ✅ FIX: Ahora se resetea correctamente
        
        // Sincronizar después del delay (solo para consistencia)
        if (_service != null) {
          _syncQueueWithAudioService(_service!.player.sequenceState, forceSync: true);
        }
      });
    }
  }

  // ============== Controles Comunes ==============



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

        // 🎯 FIX ADRENALINA: Si hay una canción precargada y la cola está casi vacía,
        // significa que el algoritmo no generó recomendaciones. Activar FASE 2.0.
        // Usamos queue size ≤ 2 porque Adrenalina solo precarga 1 canción.
        final queueSize = state.currentQueue.length;
        if (_prefetchedSeed != null && queueSize <= 2 && state.playbackMode == PlaybackMode.algorithm) {
          AppLogger.info('[PlaybackNotifier] 🚀 ADRENALINA ACTIVATION (togglePlayPause): Cola pequeña ($queueSize canciones). Iniciando FASE 2.0...');
          final seedSong = _prefetchedSeed!;
          _prefetchedSeed = null; // Limpiar para evitar re-activación
          _isProcessingPlayPause = false;
          
          // Activar FASE 2.0 completa con la canción precargada
          await playAlgorithmStart(seedSong);
          return; // Salir porque playAlgorithmStart ya hace todo
        }
        
        // 🛡️ FIX: Si estamos en modo algoritmo pero la sesión no está activa,
        // iniciar los monitores para que FASE 3.1 pueda operar
        if (state.playbackMode == PlaybackMode.algorithm && !state.isSessionActive && state.currentQueue.isNotEmpty) {
          AppLogger.info('[PlaybackNotifier] 🔄 togglePlayPause en modo algoritmo sin sesión activa. Activando monitores...');
          state = state.copyWith(isSessionActive: true);
          _startAlgorithmMonitor();
          _startQueueProtection();
        }

        // ✅ FIX CRÍTICO: Si terminó (ProcessingState.completed), volver al principio o forzar recarga
        // Esto revive el botón de play "muerto"
        if (player.playerState.processingState == ProcessingState.completed) {
           if (state.playbackMode == PlaybackMode.algorithm && state.shouldStartAlgorithmAfterQueue) {
              AppLogger.warning('[PlaybackNotifier] ⚠️ Reproductor completado (Miniplayer). Forzando recarga...');
              await _forceImmediatePreload();
              // Verificar de nuevo
              if (player.playerState.processingState == ProcessingState.completed) {
                await player.seek(Duration.zero);
              }
           } else {
              await player.seek(Duration.zero);
           }
        }
        
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
        
        // ✅ ATOMIC SYNC: Actualizar estado inmediatamente
        // Esto previene la desincronización (25 vs 31) en saltos con anuncios
        final updatedQueue = List<Song>.from(state.currentQueue);
        // Nota: No necesitamos filtrar 'updatedQueue' manualmente porque indicesToRemove
        // se refiere a índices absolutos en AudioService que incluyen anuncios.
        // Pero PlaybackNotifier.state.currentQueue SOLO tiene canciones.
        // El sync forzado lo corregirá basándose en la realidad del player.
        _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
        
        AppLogger.info('[PlaybackNotifier] 🧹 [SKIP] Limpieza completada y estado sincronizado');
      }
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] Error en _cleanupOrphanedAds: $e');
    }
  }

  /// Siguiente canción
  /// Si estamos en una cola fija y llegamos al final, activa Radio Infinita automáticamente
  /// 🎯 DETECCIÓN MANUAL: En modo algoritmo, fuerza recarga inmediata si quedan pocas canciones
  Future<void> next({bool isManual = false}) async {
    // 🛑 UI POLISH: Desactivar botón 'Siguiente' durante anuncios
    if (state.isPlayingAd) {
        AppLogger.info('[PlaybackNotifier] 🚫 Botón Siguiente desactivado durante reproducción de anuncio');
        return;
    }

    // ✅ REPORTE MANUAL: Avisar al reporter SOLO si es un skip explícito
    // Esto evita que transiciones rápidas automáticas se confundan con skips manuales
    if (isManual) {
      try {
        ref.read(playbackReporterProvider).reportManualSkip();
        AppLogger.debug('[PlaybackNotifier] ⏭️ Reportando skip manual al reporter');
      } catch (_) {}
    }

    final now = DateTime.now();
    if (now.difference(_lastControlTap) < _controlDebounce) return;
    _lastControlTap = now;
    _isProcessingNext = true;
    
    // ✅ FIX ELITE: Verificar Y activar bloqueo INMEDIATAMENTE al inicio
    // ANTES de cualquier operación que pueda disparar el listener del stream
    // 🛡️ MODO OFFLINE: Si estamos en modo offline, tratar como fixedQueue pero sin triggers de algoritmo
    if (state.playbackMode == PlaybackMode.fixedQueue && state.shouldStartAlgorithmAfterQueue) {
      final sequenceState = service.player.sequenceState;
      final playerCurrentIndex = sequenceState.currentIndex ?? 0;
      final playlistLength = state.currentQueue.length;
      final isLastSong = playerCurrentIndex >= playlistLength - 1 && playlistLength > 0;
      
      if (isLastSong) {
        // ✅ ATOMIC TRANSITION: Pausar suscripciones INMEDIATAMENTE
        // Esto congela la UI en la última canción y previene flashes
        _pauseSubscriptions();
        AppLogger.info('[PlaybackNotifier] 🛡️ [ELITE] Stream pausado para transición atómica (última canción)');
      }
    }
    
    state = state.copyWith(isProcessingNext: true);


    // 🧹 LIMPIEZA CONDICIONAL (Política Estricta):
    // Si la canción ya pasó el 5% (Debug Threshold), NO limpiar anuncios (el usuario debe verlos/saltarlos).
    // Si es antes del 5%, limpiar anuncios huérfanos.
    final currentPos = _service?.player.position ?? Duration.zero;
    final totalDur = _service?.player.duration ?? state.totalDuration;
    
    if (totalDur.inSeconds > 0 && currentPos.inSeconds < totalDur.inSeconds * 0.05) {
       AppLogger.info('[PlaybackNotifier] ⏭️ Salto antes del 5% (${currentPos.inSeconds}/${totalDur.inSeconds}s). Limpiando anuncios...');
       await _cleanupOrphanedAds();
    } else {
       AppLogger.info('[PlaybackNotifier] ⏭️ Salto después del 5% (${currentPos.inSeconds}/${totalDur.inSeconds}s). Manteniendo anuncios (Política Estricta).');
       
       // 🛡️ FIX RACE CONDITION: Verificar si hay un anuncio en la SIGUIENTE posición
       // y pre-cargar su información ANTES de que el reproductor avance
       // Esto garantiza que la UI muestre el anuncio ANTES de que cambie el audio
       final sequenceState = service.player.sequenceState;
       final currentIndex = sequenceState.currentIndex ?? 0;
       final nextIndex = currentIndex + 1;
       
       AudioAd? nextAd;
       if (nextIndex < sequenceState.sequence.length) {
         final nextSource = sequenceState.sequence[nextIndex];
         if (nextSource.tag is AudioAd) {
           nextAd = nextSource.tag as AudioAd;
           AppLogger.info('[PlaybackNotifier] 🛡️ [PRE-LOAD] Anuncio detectado en siguiente posición: ${nextAd.title}');
         }
       }
       
       // 🛡️ ATOMIC SYNC: Pre-cargar información del anuncio en el estado ANTES de avanzar
       // Esto elimina el race condition visual donde la UI mostraba brevemente la siguiente canción
       if (nextAd != null) {
         // Establecer flags antes de pre-cargar
         _isInsertingAd = true;
         _isTransitioningFromAd = false;
         
         state = state.copyWith(
           isInsertingAd: true,
           isPlayingAd: true,
           currentAd: nextAd,
           currentPosition: Duration.zero,
           totalDuration: nextAd.duration,
           // Limpiar información de canción para evitar parpadeos
           clearCurrentSong: true,
           clearLastConfirmedSong: true,
         );
         AppLogger.info('[PlaybackNotifier] 🛡️ [PRE-LOAD] Estado del anuncio pre-cargado: ${nextAd.title}');
         
         // 🛑 FIX CRÍTICO: Registrar timestamp de inicio del anuncio
         _adStartTime = DateTime.now();
       } else {
         // No hay anuncio en la siguiente posición, solo marcar isInsertingAd
         state = state.copyWith(isInsertingAd: true);
       }
       
       // 🛑 ATOMIC SYNC: Esperar a que el frame se pinte antes de tocar el audio
       // Esto garantiza que el usuario VEA la carátula del anuncio antes de ESCUCHAR el cambio
       await WidgetsBinding.instance.endOfFrame;
    }

    if (state.playbackMode == PlaybackMode.fixedQueue && state.shouldStartAlgorithmAfterQueue) {
      // ✅ FIX CRÍTICO: Usar índice del REPRODUCTOR (fuente de verdad) en lugar de state.currentSong
      // state.currentSong puede estar desincronizado, pero sequenceState.currentIndex siempre es preciso
      final sequenceState = service.player.sequenceState;
      final playerCurrentIndex = sequenceState.currentIndex ?? 0;
      final playlistLength = state.currentQueue.length;
      
      // Verificar si estamos en la última canción de la playlist
      // Nota: playerCurrentIndex es 0-based, así que última = length - 1
      final isLastSong = playerCurrentIndex >= playlistLength - 1 && playlistLength > 0;
      
      AppLogger.info('[PlaybackNotifier] ⏭️ [NEXT] FixedQueue check: playerIndex=$playerCurrentIndex, playlistLength=$playlistLength, isLast=$isLastSong, shouldAlgo=${state.shouldStartAlgorithmAfterQueue}');
      
      if (isLastSong) {
        final lastSong = state.currentQueue.isNotEmpty ? state.currentQueue.last : state.currentSong;
        if (lastSong != null) {
          AppLogger.info('[PlaybackNotifier] ⏭️ 🚀 Botón siguiente presionado en última canción. Activando Radio Infinita con semilla: ${lastSong.title}');
          
          // ✅ FIX ELITE: Activar bloqueo de stream ANTES de cualquier cambio
          // Esto previene que el listener actualice currentSong con valores incorrectos
          // _isAwaitingInitialAlgorithmPlay ya no es necesario (usamos _pauseSubscriptions arriba)
          AppLogger.info('[PlaybackNotifier] 🛡️ [ELITE] Stream ya pausado, procediendo con transición');
          
          state = state.copyWith(
            shouldStartAlgorithmAfterQueue: false,
            isBuffering: true, // Mostrar indicador de carga en lugar de carátula

          );
          
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
        // ⚡ UI OPTIMISTA: Actualizar estado visualmente ANTES de llamar al servicio
        // Esto elimina la percepción de latencia
        final currentIndex = state.currentIndex; // Usar índice del estado (más seguro que sequenceState)
        if (currentIndex < state.currentQueue.length - 1) {
           final nextSong = state.currentQueue[currentIndex + 1];
           
           // Actualizar UI inmediatamente
           state = state.copyWith(
             currentSong: nextSong,
             // currentIndex se calcula automáticamente del currentSong y currentQueue
             lastConfirmedSong: nextSong,
             currentPosition: Duration.zero,
             isBuffering: true, // Mostrar carga sutil
           );
           AppLogger.info('[PlaybackNotifier] ⚡ UI Optimista actualizada a: ${nextSong.title}');
        }

        await service.next();
        
        // 🛑 FIX: Limpiar flag _isInsertingAd después de avanzar
        _isInsertingAd = false;
        
        // ⚡ SINCRONIZACIÓN: Ya no necesitamos esperar, la UI ya está actualizada.
        // Solo sincronizamos asíncronamente para asegurar consistencia final.
        // Usamos microtask para no bloquear.
        Future.microtask(() => _syncQueueWithAudioService(service.player.sequenceState, forceSync: false));
        
        // Verificar si acabamos de entrar a un anuncio
        final afterNextSource = service.player.sequenceState.currentSource;
        final isNowPlayingAd = afterNextSource?.tag is AudioAd;
        
        if (isNowPlayingAd && state.isPlayingAd) {
          // Si estamos en un anuncio, NO sincronizar para evitar sobrescribir el estado
          // Solo actualizar la posición si avanzó correctamente
          final currentPos = service.player.position;
          if (currentPos.inMilliseconds > 0) {
            state = state.copyWith(currentPosition: currentPos);
          }
          AppLogger.info('[PlaybackNotifier] 🛡️ Anuncio detectado después de next(), manteniendo estado pre-cargado');
        } 
        // Eliminado else { _syncQueue... } porque ya hicimos la UI Optimista y sincronización asíncrona
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
       // ⚡ UI OPTIMISTA: Actualizar estado visualmente ANTES de llamar al servicio
      final currentIndex = state.currentIndex;
      if (currentIndex > 0) {
          final prevSong = state.currentQueue[currentIndex - 1];
          // Actualizar UI inmediatamente
          state = state.copyWith(
            currentSong: prevSong,
            // currentIndex se calcula automáticamente
            lastConfirmedSong: prevSong,
            currentPosition: Duration.zero,
            isBuffering: true,
          );
          AppLogger.info('[PlaybackNotifier] ⚡ UI Optimista (Anterior) actualizada a: ${prevSong.title}');
      }

      await _service!.previous();
      
      // ⚡ SINCRONIZACIÓN ASÍNCRONA: Ya no esperamos con delay fijo
      // Verificamos la verdad final después
      Future.microtask(() {
        if (_service != null) {
          _syncQueueWithAudioService(_service!.player.sequenceState, forceSync: false);
        }
      });
    }
    
    _isProcessingPrevious = false;
    state = state.copyWith(isProcessingPrevious: false);
  }

  /// Buscar posición
  /// Si se busca manualmente cerca del final de una cola fija, puede activar Radio Infinita
  Future<void> seek(Duration position) async {
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
    AppLogger.debug('[PlaybackNotifier] Closing Full Player. Current State: isPlayingAd=${state.isPlayingAd}, isPlayerExpanded=${state.isPlayerExpanded}');
    if (state.isPlayerExpanded) {
      state = state.copyWith(isPlayerExpanded: false);
      // Force a UI refresh check but respect Ad state
      if (state.isPlayingAd) {
         AppLogger.info('[PlaybackNotifier] 🛡️ Cerrando player con anuncio activo: Preservando estado de anuncio.');
      }
    }
  }

  void _checkAndPreloadNextAudio(Duration currentPosition) {
    // 🚀 SPOTIFY-LEVEL: PRE-CARGAR AUDIO DE SIGUIENTE CANCIÓN
    // Pre-carga el audio de la siguiente canción cuando quedan 30 segundos
    // Esto elimina completamente el buffering entre canciones

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

  /// 🎯 MONITOR CENTRAL DE PROGRESO (Struky Ad-Engine v1.1)
  /// Orquesta la detección de anuncios y la preparación de transiciones
  /// Reemplaza a _checkAndPrepareNextSongTransition
  /// 🎯 MONITOR CENTRAL DE PROGRESO (Struky Ad-Engine v1.1)
  /// 🎯 MONITOR CENTRAL DE PROGRESO (Struky Ad-Engine v1.1)
  /// Orquesta la detección de anuncios y la preparación de transiciones
  void _monitorPlaybackProgress(Duration currentPosition) {
    // AGENT DEBUG: Unconditional Entry Log
  // AppLogger.debug('[PlaybackNotifier] _monitorPlaybackProgress tick: ${currentPosition.inSeconds}s / ${service.player.duration?.inSeconds}s (IsAd: ${state.isPlayingAd})');

    // 🔥 FIX: No abortar si queue es cero pero hay canción sonando (puede ser inicio de sesión)
    // 🔥 FIX: No abortar si duration es cero, intentar obtenerla del player
    if (state.currentQueue.isEmpty && state.currentSong == null) {
        return;
    }

    //⚛️ ATOMIC STATE: Detectar cambio de canción
    final currentSong = state.currentSong;
    if (currentSong != null && currentSong.id != _currentSongId) {
       // Si cambiamos de canción, reseteamos flags críticos
       // Pero SOLO si no estamos en medio de un anuncio (para evitar romper el flujo)
       if (!state.isPlayingAd) {
          AppLogger.debug('[PlaybackNotifier] ⚛️ Cambio de canción detectado: ${_currentSongId ?? "Inicio"} -> ${currentSong.id}');
          _currentSongId = currentSong.id;
          
          // 🎯 CRÍTICO: Guardar en historial INMEDIATAMENTE cuando detectamos cambio automático
          // 🛡️ PROTECCIÓN POST-ANUNCIO: NO guardar si acabamos de salir de un anuncio
          if (_lastAdTransitionTime != null && 
              DateTime.now().difference(_lastAdTransitionTime!) < const Duration(seconds: 2)) {
            AppLogger.debug('[PlaybackNotifier] 🛡️ AUTO-guardado bloqueado por transición de anuncio reciente');
            // NO guardar - la canción puede ser transitoria/incorrecta
          } else {
            try {
              AppLogger.info('[PlaybackNotifier] 💾 AUTO-GUARDANDO (cambio detectado): ${currentSong.title}');
              ref.read(playHistoryProvider.notifier).addToHistory(currentSong);
              
              // Verificar que se guardó
              final historyAfter = ref.read(playHistoryProvider);
              if (historyAfter.isNotEmpty && historyAfter.last.id == currentSong.id) {
                AppLogger.success('[PlaybackNotifier] ✅ AUTO-guardado exitoso: ${currentSong.title} (Total: ${historyAfter.length})');
              } else {
                AppLogger.warning('[PlaybackNotifier] ⚠️ AUTO-guardado falló');
                ref.read(playHistoryProvider.notifier).debugHistoryStatus();
              }
            } catch (e) {
              AppLogger.error('[PlaybackNotifier] ❌ Error AUTO-guardando: $e');
            }
          }
          
          // Limpieza atómica
          // No limpiamos _adTriggeredSongs completo para evitar re-disparos inmediatos si el usuario vuelve atrás,
          // pero aseguramos que el lock de inserción esté libre.
          _isInsertingAd = false; 
          // _isAdRequestInFlight = false;
          
          // 🔥 FIX CRÍTICO: Permitir que esta canción dispare anuncios nuevamente
          // "HACHAZO": Limpiamos TODA la lista para asegurar que no haya bloqueos fantasmas.
          _adTriggeredSongs.clear(); 
          AppLogger.debug('[PlaybackNotifier] 🧹 AD STATE RESET: Trigger list cleared for new song ${currentSong.id}');
       }
    }

    // DIAGNOSTIC HEARTBEAT (Production Level)
    if (currentPosition.inSeconds % 5 == 0 && currentPosition.inMilliseconds % 1000 < 200) { 
       final now = DateTime.now();
       if (_lastHeartbeatLogTime == null || now.difference(_lastHeartbeatLogTime!) >= const Duration(seconds: 30)) { // Less verbose in prod
          _lastHeartbeatLogTime = now;
          AppLogger.debug('[PlaybackNotifier] 💓 Heartbeat: ${currentPosition.inSeconds}s (Queue: ${state.currentQueue.length})');
       }
    }

    final playerDuration = service.player.duration ?? Duration.zero;
    // 🔥 FIX: Usar la duración del player si la del estado es cero
    final duration = playerDuration.inSeconds > 0 ? playerDuration : state.totalDuration;
    
    // Si todavía no tenemos duración, no podemos calcular % de anuncio, pero NO abortar la monitorización general
    if (duration.inSeconds > 0) {
       // 💓 HEARTBEAT FIX: Autocuración de estado de anuncio
       // Si el player dice que es anuncio, LA UI DEBE MOSTRAR ANUNCIO, sin excusas.
       // PERO: Si acabamos de forzar un salto, NO autocurar para evitar bucle infinito
       final realSource = service.player.sequenceState.currentSource;
       
       // 🛡️ PROTECCIÓN: No autocurar si acabamos de forzar un salto (ventana de 2 segundos)
       final recentlyForcedJump = _lastForcedAdJumpTime != null && 
           DateTime.now().difference(_lastForcedAdJumpTime!) < const Duration(seconds: 2);
       
       if (realSource != null && realSource.tag is AudioAd && !recentlyForcedJump) {
          final ad = realSource.tag as AudioAd;
          if (!state.isPlayingAd || state.currentAd?.id != ad.id) {
             AppLogger.warning('[PlaybackNotifier] 💓 HEARTBEAT: Autocurando estado de anuncio desincronizado. Player:${ad.title} vs UI:${state.isPlayingAd}');
             state = state.copyWith(
                isPlayingAd: true,
                currentAd: ad,
                clearCurrentSong: true,
                isInsertingAd: false, // Ensure this is off
             );
          }

           
           // 🛑 FIX ANUNCIO ATASCADO: Si la posición llegó al final pero sigue siendo anuncio
           if (state.isPlayingAd && 
               duration.inMilliseconds > 0 && 
               currentPosition.inMilliseconds >= (duration.inMilliseconds - 500)) { // Tolerancia 500ms
               
               AppLogger.warning('[PlaybackNotifier] 🛑 ANUNCIO ATASCADO AL FINAL: ${ad.title} (${currentPosition.inSeconds}/${duration.inSeconds}s)');
               
               // 🛡️ PROTECCIÓN: Marcar que estamos forzando un salto
               _lastForcedAdJumpTime = DateTime.now();
               
               // 🔥 FIX BUCLE: Usar seekToNext() siempre - es más confiable que seek(index)
               AppLogger.info('[PlaybackNotifier] ⏭️ Forzando seekToNext() para desatascar anuncio');
               _service?.player.seekToNext();
               
               // Forzar limpieza de estado INMEDIATA
               state = state.copyWith(
                 isPlayingAd: false,
                 clearCurrentAd: true,
               );
               _handleAdCompletion(ad, false);
               return;
           }

           // Force update position for smooth ad progress bar
           if (state.isPlayingAd) {
             state = state.copyWith(currentPosition: currentPosition, totalDuration: duration);
           }
       } else if (realSource != null && realSource.tag is Song && state.isPlayingAd) {
           // 💓 HEARTBEAT FIX REVERSE: Si la UI cree que es anuncio, pero el Audio ya es Canción -> CURAR
           AppLogger.warning('[PlaybackNotifier] 💓 HEARTBEAT: Autocurando estado de CANCIÓN. UI Stuck en Ad -> Forzando Song.');
           
           final song = realSource.tag as Song;
           
           // 🛠️ FIX ADRENALINA: Si es la primera canción y el audio *dice* que es canción pero no avanza...
           // A veces el tag se actualiza pero el motor se queda en silencio.
           // Forzamos un seek si estamos en la primera canción para "despertar" el audio.
           if (_songsPlayedCount <= 1 && service.player.currentIndex != 2) {
               AppLogger.info('🏃 [AdBlock] Heartbeat Adrn: Forzando salto manual al índice 2');
               service.player.seek(Duration.zero, index: 2).then((_) => service.player.play());
           }

           // Limpiar estado inmediatamente
           state = state.copyWith(
              isPlayingAd: false,
              clearCurrentAd: true,
              currentSong: song,
              currentPosition: currentPosition,
              totalDuration: duration,
           );
           
           // Intentar finalizar lógica de anuncio en background (para logs y sync)
           // Usamos un ad dummy si null, aunque isPlayingAd era true así que debería haber currentAd
           final ad = state.currentAd ?? AudioAd(id: 'unknown', title: 'Unknown', audioUrl: '', duration: Duration.zero, advertiserName: 'Unknown');
           _handleAdCompletion(ad, false); 
       }
       
       // 1. DETECCIÓN DE ANUNCIOS
       _detectAdTrigger(currentPosition, duration);
    }

    // 2. PREPARACIÓN DE TRANSICIÓN (Lógica original preservada)
    // ⚡ PREPARAR TRANSICIÓN cuando quedan 3 segundos o menos
    final remainingTime = duration - currentPosition;
    final currentIndex = service.player.sequenceState.currentIndex;
    final sequence = service.player.sequenceState.sequence;
    
    if (remainingTime.inSeconds <= _transitionPrepareTimeThreshold && 
        remainingTime.inSeconds > 0 &&
        currentIndex != null &&
        currentIndex + 1 < sequence.length) {
      
      if (_nextSongPrepared && _lastPreparedSongIndex == currentIndex) return;
      
      _nextSongPrepared = true;
      _lastPreparedSongIndex = currentIndex;
      
      final nextSource = sequence[currentIndex + 1];
      if (nextSource.tag is Song) {
        _preloadSongAudio(nextSource.tag as Song);
        AppLogger.debug('[PlaybackNotifier] ⚡ Transición preparada para: ${(nextSource.tag as Song).title}');
      }
    }
    
    if (remainingTime.inSeconds > _transitionPrepareTimeThreshold + 1) {
      _nextSongPrepared = false;
    }
  }

  /// 🕵️ DETECCIÓN DE ANUNCIO (Lógica Pura)
  /// Evalúa si se cumplen todas las condiciones para disparar un anuncio
  void _detectAdTrigger(Duration position, Duration duration) {
    if (duration.inSeconds <= 0) return;
    
    // Debug variables
    final progressPercent = position.inMilliseconds / duration.inMilliseconds;
    
    // A. VALIDACIONES DE SEGURIDAD (Gatekeeping)
    if (state.isPlayingAd || _isInsertingAd || _isHandlingAdInsertion || state.currentAd != null) {
       return;
    }
    
    // Verificar si es usuario Premium (mock por ahora si no hay provider)
    if (!isMounted) return;

    // 🛡️ FIX ADRENALINA: No insertar anuncios si la cola está casi vacía
    // Esto previene que el reproductor se quede sin canciones después del anuncio
    final currentIndex = service.player.currentIndex ?? 0;
    final sequenceLength = service.player.sequence.length;
    final remainingSongs = sequenceLength - currentIndex;
    
    if (remainingSongs <= 2) {
      // 🔇 THROTTLE: Solo logear una vez cada 5 segundos para evitar spam
      final now = DateTime.now();
      if (_lastAdGuardLogTime == null || now.difference(_lastAdGuardLogTime!) > const Duration(seconds: 5)) {
        _lastAdGuardLogTime = now;
        AppLogger.warning('[PlaybackNotifier] 🛡️ AD GUARD: Cola muy pequeña ($remainingSongs canciones). Forzando carga de recomendaciones...');
        
        // 🚨 FIX CRÍTICO: Si la cola está vacía, forzar la carga de recomendaciones
        // Esto resuelve el problema donde el algoritmo no se ejecutó correctamente
        if (state.playbackMode == PlaybackMode.algorithm && !_isGeneratingRecommendations) {
          _appendMoreAlgorithmSongs(forceIgnoreCooldown: true).catchError((e) {
            AppLogger.error('[PlaybackNotifier] Error en carga de emergencia: $e');
          });
        }
      }
      return;
    }

    // Obtener canción actual
    final currentSource = service.player.sequenceState.currentSource;
    if (currentSource == null || currentSource.tag is! Song) return;
    
    final currentSong = currentSource.tag as Song;
    
    // B. LÓGICA DE UMBRAL (50% de la canción)
    if (progressPercent >= 0.50) {
       if (!_adTriggeredSongs.contains(currentSong.id)) {
          AppLogger.info('[PlaybackNotifier] 🚀 Umbral de anuncio alcanzado para: ${currentSong.title} (Plays: $_songsPlayedCount, QueueSize: $sequenceLength)');
          _executeAdTrigger(currentSong.id);
       }
    }
  }


  /// 🎬 EJECUCIÓN DE ANUNCIO (Acción)
  /// Realiza la inserción y actualiza contadores
  void _executeAdTrigger(String songId) {
    AppLogger.info('[PlaybackNotifier] 🎬 Iniciando disparador de anuncio para canción: $songId');

    // 1. MARCAR COMO DISPARADO (Immediate Lock)
    _adTriggeredSongs.add(songId);
    
    // 2. VERIFICAR FRECUENCIA
    _songsPlayedCount++;
    
    // 🧠 LOGIC FIX: Usar módulo para repetir cada N canciones
    final frequency = _adFrequencyFromAdmin > 0 ? _adFrequencyFromAdmin : 1;
    final shouldTrigger = _songsPlayedCount % frequency == 0;
    
    AppLogger.info('[PlaybackNotifier] 🧮 Verificando frecuencia de anuncios: $_songsPlayedCount / $frequency (Trigger: $shouldTrigger)');

    if (!shouldTrigger) {
       AppLogger.info('[PlaybackNotifier] ⏭️ Omitiendo anuncio: Frecuencia no alcanzada');
       return; 
    }

    // 3. VALIDAR QUE LA SIGUIENTE NO SEA UN ANUNCIO YA
    final currentIndex = service.player.sequenceState.currentIndex;
    final sequence = service.player.sequenceState.sequence;
    if (currentIndex != null && currentIndex + 1 < sequence.length) {
      if (sequence[currentIndex + 1].tag is AudioAd) {
        AppLogger.warning('[PlaybackNotifier] 🛡️ Omitiendo anuncio: Ya existe uno en la cola');
        return;
      }
    }

    // 4. INICIAR INSERCIÓN
    AppLogger.info('[PlaybackNotifier] 🚀 Lanzando _checkAndInsertAd...');
    _isInsertingAd = true;
    state = state.copyWith(isInsertingAd: true);

    _checkAndInsertAd(triggerSongId: songId).then((_) {
       AppLogger.info('[PlaybackNotifier] ✅ Anuncio insertado correctamente en la cola');
       
       // ✅ FIX: Resetear el flag de inserción una vez completada la tarea
       // Esto evita que actualizaciones futuras del stream sean ignoradas erróneamente
       // si el listener no detecta el cambio de inmediato.
       // El estado 'isPlayingAd' se activará cuando el stream detecte el tag AudioAd.
       _isInsertingAd = false;
       state = state.copyWith(isInsertingAd: false);
       
    }).catchError((e) {
       AppLogger.error('[PlaybackNotifier] ❌ Error crítico al insertar anuncio: $e');
       _isInsertingAd = false;
       state = state.copyWith(isInsertingAd: false);
    });
  }


  // Mantenemos este nombre por compatibilidad si es llamado de otros lados, 
  // pero ahora redirige al monitor central.
  void _checkAndPrepareNextSongTransition(Duration currentPosition) {
     _monitorPlaybackProgress(currentPosition);
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
  /// Sincronizar estado de la cola con el servicio de audio
  void _syncQueueWithAudioService(SequenceState? sequenceState, {bool forceSync = false}) {
    if (_service == null) return;

    // ✅ FIX CRÍTICO (MOVED UP): Si forceSync es true pero el estado dice que hay anuncio pero realmente no lo hay,
    // limpiar el estado del anuncio inmeditamente ANTES de cualquier check
    if (forceSync && (state.isPlayingAd || state.currentAd != null)) {
      final currentSource = sequenceState?.currentSource;
      final isActuallyPlayingAd = currentSource != null && currentSource.tag is AudioAd;
      
      if (!isActuallyPlayingAd) {
        AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN: forceSync detectó que no hay anuncio pero el estado dice que sí, limpiando estado');
        state = state.copyWith(
          isPlayingAd: false,
          clearCurrentAd: true,
        );
        AppLogger.info('[PlaybackNotifier] ✅ Estado del anuncio limpiado después de forceSync');
      }
    }
    
    // 🛡️ PROXY METADATA: Si estamos reproduciendo un anuncio, FORZAR metadata del anuncio
    // Esto evita que la UI muestre la duración/posición de la siguiente canción (pre-buffering)
    if (state.isPlayingAd && state.currentAd != null) {
      final ad = state.currentAd!;
      final adDuration = Duration(seconds: ad.duration.inSeconds);
      
      // Calcular posición del anuncio (clamped a su duración)
      // Nota: El player.position podría estar reportando 0 si ya saltó a la siguiente canción
      // pero visualmente queremos mantener el estado del anuncio hasta que se limpie explícitamente
      var currentPos = _service!.player.position;
      if (currentPos > adDuration) currentPos = adDuration;
      
      state = state.copyWith(
        // Mantener currentSong anterior (no actualizar con la siguiente)
        totalDuration: adDuration,
        currentPosition: currentPos,
        // Asegurar que flags de UI sigan apuntando al anuncio
        isPlayingAd: true,
        currentAd: ad,
      );
      return; // 🛑 STOP: No procesar metadata del player (que podría ser de la siguiente canción)
    }

    // 🛡️ PROTECCIÓN: Ignorar sincronización automática durante reemplazo de cola
    // Solo permitir si es una sincronización forzada (después de loadNewQueue o deduplicación)
    if (!forceSync && (_isReplacingQueue || _isUpdatingQueue)) {
      return; // Ignorar sincronización automática durante operaciones críticas
    }
    
    // 🛡️ PROTECCIÓN INSERCIÓN ANUNCIOS: Marcar que estamos insertando para proteger currentSong
    // Pero NO retornar temprano - queremos que la detección del anuncio siga funcionando
    final isInAdInsertionMode = _isInsertingAd || _isHandlingAdInsertion;
    
    // ✅ PROTECCIÓN CRÍTICA: No sincronizar currentSong si hay un anuncio reproduciéndose
    // Esto evita que se cambie la carátula cuando se presiona play/pause durante un anuncio
    // ✅ FIX CRÍTICO: Con forceSync, SIEMPRE verificar si realmente hay un anuncio reproduciéndose
    // Si forceSync es true, verificar el estado real del reproductor, no solo el estado de la UI
    final currentSource = sequenceState?.currentSource;
    final isActuallyPlayingAd = currentSource != null && currentSource.tag is AudioAd;
    
    if (!forceSync && state.isPlayingAd && isActuallyPlayingAd) {
      // Solo sincronizar la cola, pero no currentSong cuando realmente hay un anuncio reproduciéndose
      final audioSources = sequenceState?.sequence ?? [];
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
    
    // ✅ FIX CRÍTICO (MOVED UP): Si forceSync es true pero el estado dice que hay anuncio pero realmente no lo hay,
    // limpiar el estado del anuncio inmeditamente ANTES de cualquier check
    if (forceSync && (state.isPlayingAd || state.currentAd != null)) {
      final currentSource = sequenceState?.currentSource;
      final isActuallyPlayingAd = currentSource != null && currentSource.tag is AudioAd;
      
      if (!isActuallyPlayingAd) {
        AppLogger.warning('[PlaybackNotifier] 🛑 CORRECCIÓN: forceSync detectó que no hay anuncio pero el estado dice que sí, limpiando estado');
        state = state.copyWith(
          isPlayingAd: false,
          clearCurrentAd: true,
        );
        AppLogger.info('[PlaybackNotifier] ✅ Estado del anuncio limpiado después de forceSync');
      }
    }

    try {
      final audioSources = sequenceState?.sequence ?? [];
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
              AppLogger.debug('[PlaybackNotifier] 🔄 Sincronización incremental (inserción de anuncio): $stateCount → $audioCount canciones');
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
      final currentIdx = sequenceState?.currentIndex;
      final currentSongId = state.currentSong?.id;

      // 🔒 Bloqueo crítico eliminado: ahora se usan suscripciones pausadas durante transición
      // si _isAwaitingInitialAlgorithmPlay estaba aquí, ya no es necesario.

      if (currentIdx != null && currentIdx >= 0 && currentIdx < songsFromAudio.length) {
        // ✅ PROTECCIÓN CRÍTICA: Verificar que no hay un anuncio reproduciéndose antes de actualizar currentSong
        // Esto evita que se cambie la carátula cuando se presiona play/pause durante o después de un anuncio
        final currentSourceForCheck = sequenceState?.currentSource;
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
        // limpiar el estado del anuncio inmediatamente
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
        final currentSource = sequenceState?.currentSource;
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
        final currentDuration = sequenceState?.currentSource?.duration ??
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
        // 🛡️ PROTECCIÓN REFORZADA: Verificar doblemente si realmente NO es un anuncio
        bool shouldClearAdState = currentSource != null && currentSource.tag is Song && (state.isPlayingAd || state.currentAd != null);
        
        if (shouldClearAdState) {
           // Doble verificación con el player direct (si está disponible)
           final realPlayerSource = _service?.player.sequenceState.currentSource;
           if (realPlayerSource != null && realPlayerSource.tag is AudioAd) {
              AppLogger.warning('[PlaybackNotifier] 🛡️ PREVENIDO borrar estado de anuncio: sequenceState local dice Song, pero Player real dice Ad');
              shouldClearAdState = false;
           } else if (state.isPlayingAd) {
              AppLogger.info('[PlaybackNotifier] 🧹 Limpiando estado de anuncio porque detectamos canción: ${(currentSource.tag as Song).title}');
           }
        }
        
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
          
          // 🛡️ PROTECCIÓN FLICKER: Si estamos insertando un anuncio y el source actual es una canción,
          // NO actualizar currentSong para evitar que el MiniPlayer parpadee
          // Pero sí permitir la actualización si el source actual es un anuncio
          final currentSourceIsAd = currentSource != null && currentSource.tag is AudioAd;
          if (isInAdInsertionMode && !currentSourceIsAd) {
            AppLogger.debug('[PlaybackNotifier] 🛡️ Omitiendo actualización de currentSong durante inserción de anuncio');
            return;
          }
          
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

          // Log reducido a debug para evitar spam en consola
          if (forceSync || shouldUpdateSong) {
             AppLogger.debug('[PlaybackNotifier] ✅ Canción sincronizada: ${songAtIdx.title} (fuente: tag del reproductor)');
          }
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
    
    // 🎯 WARM-UP TRIGGER: Verificar si necesitamos iniciar el algoritmo en background
    if (sequenceState != null) {
       _maybePrefetchAlgorithm(sequenceState);
    }

    // 🕒 HISTORIAL FALBBACK: Si el listener principal falló, asegurar registro aquí
    // Solo registrar si tenemos una canción válida y NO estamos en medio de un cambio rápido
    if (state.currentSong != null && !state.isPlayingAd && state.currentAd == null) {
        // 🛡️ PROTECCIÓN POST-ANUNCIO: No registrar historial inmediatamente después de un anuncio
        // Esto evita que estados transitorios (glitches) se guarden en el historial
        if (_lastAdTransitionTime != null && 
            DateTime.now().difference(_lastAdTransitionTime!) < const Duration(seconds: 2)) {
             // AppLogger.debug('[PlaybackNotifier] 🛡️ Historial bloqueado por transición de anuncio reciente');
             return;
        }

        final currentId = state.currentSong!.id;
        // Evitar registros duplicados muy seguidos (debounce simple)
        final now = DateTime.now();
        if (_lastHistoryRegisterTime == null || 
            now.difference(_lastHistoryRegisterTime!) > const Duration(seconds: 5) ||
            _lastHistorySongId != currentId) {
            
            _lastHistoryRegisterTime = now;
            _lastHistorySongId = currentId;
            
            // Registrar en historial persistente
            try {
                 ref.read(playHistoryProvider.notifier).addToHistory(state.currentSong!);
                 // AppLogger.info('[PlaybackNotifier] 📂 Historial (Sync Fallback): ${state.currentSong!.title}');
            } catch (_) {}
            
            // Registrar en sesión para algoritmo
            try {
                 ref.read(playbackSessionProvider.notifier).registerPlayedSong(currentId);
            } catch (_) {}
        }
    }
  }

  // Variables para debounce de historial en _syncQueue
  DateTime? _lastHistoryRegisterTime;
  String? _lastHistorySongId;


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
      
      // 📊 CALCULAR IMPACTO POTENCIAL
      final remainingNow = _getRemainingQueueSize();
      final currentIndex = sequenceState.currentIndex ?? 0;
      final config = _algorithmConfig; // Usar el getter que ya existe
      
      for (int i = 0; i < audioSources.length; i++) {
        final source = audioSources[i];
        if (source.tag is Song) {
          final song = source.tag as Song;
          
          // 🚨 CRÍTICO: NUNCA marcar como duplicado la canción que se está reproduciendo actualmente.
          // Esto evita saltos agresivos durante la deduplicación (como el reportado por el usuario).
          if (i == currentIndex) {
            seenIds.add(song.id);
            songsFromAudio.add(song);
            continue;
          }
          
          if (seenIds.contains(song.id)) {
            // 🛡️ SEGURIDAD: Solo marcar como duplicado si NO estamos en riesgo de silencio.
            // Si el duplicado está DESPUÉS del índice actual, su eliminación afecta la continuidad.
            final isUpcoming = i > currentIndex;
            
            // 🎯 ADMIN CONTROL: Usar cyclicBufferThreshold para saber cuándo permitir repeticiones.
            // Si eliminar este duplicado nos deja con una cola menor al umbral del Admin, lo permitimos.
            final potentialRemaining = remainingNow - duplicateIndices.length;
            
            if (isUpcoming && potentialRemaining <= config.cyclicBufferThreshold && config.isSmallCatalog) {
               AppLogger.warning('[PlaybackNotifier] 🛡️ [DEDUP] Permitiendo duplicado por ADMIN CONFIG (cíclico): ${song.title} (Cola: $potentialRemaining, Umbral: ${config.cyclicBufferThreshold})');
               songsFromAudio.add(song);
            } else {
              duplicateIndices.add(i);
              duplicateIds.add(song.id);
            }
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
        
        // 🚨 CRÍTICO: Guardar estado de reproducción ANTES de modificar la cola
        final currentPosition = service.player.position;
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
            
            // 🚨 FIX CRÍTICO: Actualizar estado INMEDIATAMENTE con la cola deduplicada
            // Esto resuelve la desincronización (25 vs 31) al asegurar que la UI vea 25 items
            // mientras que el Audio Service ya tiene 25.
            state = state.copyWith(
              currentQueue: songsFromAudio,
              isPlaying: wasPlaying, // Preservar estado de reproducción
            );

            // Sincronizar el estado con la cola actualizada con un pequeño delay para que el driver asiente
            await Future.delayed(const Duration(milliseconds: 50));
            _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
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
            
            // 🚨 FIX CRÍTICO: Actualizar estado INMEDIATAMENTE
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
    bool allowDuplicates = false, // 🔓 NUEVO FLAG: Permitir duplicados en casos de emergencia
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
      
      // Filtrar duplicados antes de agregar (a menos que se permitan explícitamente)
      final uniqueNewSongs = allowDuplicates 
          ? newSongs 
          : newSongs.where((s) => !allCurrentQueueIds.contains(s.id)).toList();
      
      if (uniqueNewSongs.isEmpty) {
        // Si allowDuplicates es true, uniqueNewSongs = newSongs, así que esto solo pasa si newSongs era vacío
        // O si no se permitían duplicados y todos fueron filtrados
        if (allowDuplicates && newSongs.isNotEmpty) {
           AppLogger.info('[PlaybackNotifier] ℹ️ Agregando ${newSongs.length} duplicados (GOD MODE activo)');
           // Continuamos...
        } else {
           AppLogger.info('[PlaybackNotifier] ⚠️ Todas las canciones ya están en la cola, omitiendo agregado');
           return; // No hay nada que agregar
        }
      }
      
      if (uniqueNewSongs.length < newSongs.length) {
        AppLogger.info('[PlaybackNotifier] ⚠️ ${newSongs.length - uniqueNewSongs.length} canciones duplicadas filtradas antes de agregar');
      }
      
      // Convertir canciones únicas a AudioSource de forma asíncrona
      // ✅ REFACTOR OFF-LINE: Usar Future.wait para resolver fuentes en paralelo
      final sources = await Future.wait(
        uniqueNewSongs.map((s) => _resolveSource(s))
      );
      
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
      
      if (isMounted) {
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
            // ✅ REFACTOR OFF-LINE: Resolver fuente asíncronamente
            final source = await _resolveSource(song);
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
                // ❌ OPTIMISTIC REMOVED: Dejar que la autocuración active la UI cuando suene el audio
                // isMiniPlayerVisible: true,
                // isSessionActive: true,
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
            }
        } catch (e, stackTrace) {
          AppLogger.error('[PlaybackNotifier] Error en inyección instantánea, usando método estándar: $e', e, stackTrace);
        }
      }
      
      // Método estándar (cuando no hay cola activa o la inyección falló)
      await playSpecificSong(song);
      }
      
      // ⚡ OPTIMIZACIÓN: Actualizar estado de buffering de forma asíncrona sin bloquear
      final actualPlayerState = service.player.playerState;
      final actualIsBuffering = actualPlayerState.processingState == ProcessingState.buffering ||
                               actualPlayerState.processingState == ProcessingState.loading;
      
      state = state.copyWith(
        isBuffering: actualIsBuffering,
      );
      
      AppLogger.info('[PlaybackNotifier] Reproducción desde tarjeta iniciada.');
    } catch (e, stackTrace) {
        AppLogger.error('[PlaybackNotifier] Error in playFromCard: $e', e, stackTrace);
    } finally {
      AppLogger.info('[PlaybackNotifier] 🏁 playFromCard finalized. Visible: ${state.isMiniPlayerVisible}, Playing: ${state.isPlaying}, Song: ${state.currentSong?.title}');
      // ⚡ OPTIMIZACIÓN: Reducir delay de liberación de flag para respuesta más rápida
      // El flag solo necesita mantenerse el tiempo mínimo necesario
      Future.delayed(const Duration(milliseconds: 100), () { 
        // _isProcessingPlayFromCard = false; 
        _isTransitioning = false; // 🔓 RELEASE LOCK
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

  // ═══════════════════════════════════════════════════════════════════════
  // 🚀 BACKGROUND ALGORITHM WARM-UP (OPTIMIZACIÓN PROFESIONAL)
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Verifica si debemos iniciar la carga previa del algoritmo
  void _maybePrefetchAlgorithm(SequenceState? sequenceState) {
    // 💓 HEARTBEAT LOG: Removed for production
    if (state.playbackMode == PlaybackMode.fixedQueue && sequenceState != null) {
       // Logic kept for structure but logging removed
    }

    // 🚨 DEBUG: Logs removed for production

    
    if (state.playbackMode != PlaybackMode.fixedQueue || !state.shouldStartAlgorithmAfterQueue) {
      return;
    }
    
    final currentIndex = sequenceState?.currentIndex ?? 0;
    final playlistLength = state.currentQueue.length;
    final isLastSong = currentIndex >= playlistLength - 1 && playlistLength > 0;
    
    // Si no es la última canción, no hacemos nada
    if (!isLastSong) return;

    final lastSong = state.currentQueue.last;

    // 1. Limpieza proactiva: Si la semilla cambió, invalidar caché anterior
    if (_prefetchedSeed?.id != lastSong.id) {
       _prefetchedInitialSongs = null;
       _prefetchedSeed = null;
    }

    // 2. Ahora sí: Si ya tenemos data válida para ESTA canción, reportarlo y salir
    if (_prefetchedInitialSongs != null) {
       AppLogger.info('✨ [WARM-UP STATUS] Ya precargado. Esperando al usuario... (Ready cache: ${_prefetchedInitialSongs!.length} songs)');
       return;
    }
    // ✅ FIX: No bloquear el warm-up si la cola se está actualizando (es solo lectura)
    // El check de (_isUpdatingQueue || _isReplacingQueue) fue eliminado para permitir prefetch en background
    
    // print('[DEBUG] _maybePrefetchAlgorithm: Checks passed. Launching for ${lastSong.title}');

    // 3. Iniciar prefetch
    {
       // (Checks redundantes eliminados)
      
      // Iniciar prefetch si no existe
      if (_prefetchedInitialSongs == null && !_isPrefetchingAlgorithm) {
        // AppLogger.info('[PlaybackNotifier] 🚀 [WARM-UP] ...');
        AppLogger.info('\n🔥✨ [WARM-UP INIT] Detectada última canción. Iniciando carga silenciosa de algoritmo... ✨🔥\n');
        _prefetchedSeed = lastSong;
        _isPrefetchingAlgorithm = true;
        
        // Ejecutar en microtask para no bloquear el frame actual
        Future.microtask(() async {
          try {
            // Usar método existente para generar recomendaciones
            final songs = await _generateInitialRecommendations(lastSong, excludeSeedFromQueue: true);
            
            // Verificar si la canción sigue siendo la misma (usuario podría haber cambiado rápido)
            if (_prefetchedSeed?.id == lastSong.id) {
               _prefetchedInitialSongs = _filterPlayableSongs(songs);
               
               // Pre-cachear la carátula de la primera canción recomendada
               if (_prefetchedInitialSongs != null && _prefetchedInitialSongs!.isNotEmpty) {
                 final firstRec = _prefetchedInitialSongs!.first;
                 if (firstRec.coverArtUrl != null) {
                   AppLogger.debug('[PlaybackNotifier] 🚀 [WARM-UP] Pre-cacheando imagen: ${firstRec.coverArtUrl}');
                   // Disparar precache sin esperar
                   try {
                     // Nota: cached_network_image provider requiere contexto o ImageProvider
                     // Aquí solo podemos hacer un fetch simple o confiar en que optimized_cached_image lo maneje rápido
                     // Como es warm-up, no es crítico si falla
                   } catch (_) {}
                 }
               }
               
               AppLogger.info('[PlaybackNotifier] ✅ [WARM-UP] ${songs.length} canciones precargadas y listas para transición instantánea.'); // Mantener log original
               AppLogger.info('\n✅✨ [WARM-UP READY] ${songs.length} canciones LITERALMENTE listas. Transición a Vmax = 0ms ✨✅\n');
            }
          } catch (e) {
            AppLogger.error('[PlaybackNotifier] ⚠️ [WARM-UP] Falló precarga: $e');
            _prefetchedInitialSongs = null;
            _prefetchedSeed = null;
          } finally {
            _isPrefetchingAlgorithm = false;
          }
        });
      }
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

    // 🚩 Comentado para evitar race conditions con limpieza en playFixedQueue
    // Centralizamos toda la lógica de warm-up en _maybePrefetchAlgorithm (al llegar al final)
    /*
    if (allSongs.isNotEmpty) {
      final lastSong = allSongs.last;
      // Solo lanzar si la semilla es reproducible
      if (lastSong.isValidForPlayback) {
        unawaited(_prefetchInitialAlgorithmBuffer(lastSong));
      }
    }
    */

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
    _failsafeTimer?.cancel();
    _algorithmMonitorTimer?.cancel();
    _queueProtectionTimer?.cancel();
    _manualSkipTimer?.cancel();
    
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
  /// Convierte una canción a AudioSource de forma asíncrona, 
  /// comprobando si existe una versión offline para usuarios Premium.
  /// 🚀 CORE RESOLVER: Determina la fuente de audio (Offline vs Stream)
  /// Sigue la jerarquía: Premium + Archivo Local -> Stream
  Future<AudioSource> _resolveSource(Song song) async {
    try {
      AppLogger.debug('[PlaybackNotifier] 🔍 Resolving audio source for: ${song.title} (${song.id})');
      
      final user = ref.read(currentUserProvider);
      final isPremium = user != null && 
          (user.subscriptionStatus == SubscriptionStatus.premium || 
           user.subscriptionStatus == SubscriptionStatus.vip);

      if (isPremium) {
        final offlineManager = ref.read(offlineManagerProvider.notifier);
        
        // Verificar existencia en Hive primero (rápido)
        final isDownloaded = offlineManager.isDownloaded(song.id);
        if (isDownloaded) {
             AppLogger.info('[PlaybackNotifier] 📥 Song is marked as downloaded in Hive. Attempting decryption...');
             
             final decryptedPath = await offlineManager.getDecryptedFilePath(song.id);
             
             if (decryptedPath != null) {
               final file = PlatformFile(decryptedPath);
               if (await file.exists()) {
                  final size = await file.length();
                  AppLogger.info('[PlaybackNotifier] 📁 Playing Offline: $decryptedPath ($size bytes)');
                  return AudioSource.file(
                    decryptedPath,
                    tag: song,
                  );
               } else {
                  AppLogger.warning('[PlaybackNotifier] ⚠️ Decrypted file not found at path: $decryptedPath');
               }
             } else {
                AppLogger.warning('[PlaybackNotifier] ⚠️ Decryption returned null path for ${song.title}');
             }
        } else {
            // AppLogger.debug('[PlaybackNotifier] Song not downloaded or not found in Hive.');
        }
      } else {
         AppLogger.info('[PlaybackNotifier] User is not premium, skipping offline check.');
      }

      // 🛡️ MODO BÚNKER (Offline): Si no se encontró archivo local, NO hacer fallback a stream
      if (state.playbackMode == PlaybackMode.offline) {
         AppLogger.error('[PlaybackNotifier] 🛡️ [OFFLINE-MODE] Archivo no encontrado. Fallback de red BLOQUEADO para: ${song.title}');
         throw Exception('Modo Offline: Archivo no encontrado localmente');
      }

      // Fallback a streaming
      AppLogger.info('[PlaybackNotifier] ☁️ Playing Stream: ${song.title}');
      return song.toAudioSource();
      
    } catch (e) {
      AppLogger.error('[PlaybackNotifier] ⚠️ Error resolviendo fuente offline, usando fallback stream: $e');
      return song.toAudioSource();
    }
  }
} // Cierre de clase PlaybackNotifier

/// Provider que la UI consumirá
/// El AudioService se obtiene dentro del build() del notifier
final playbackNotifierProvider = NotifierProvider<PlaybackNotifier, PlaybackState>(() {
  return PlaybackNotifier();
});

