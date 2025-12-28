import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎵 AUDIO SERVICE PROFESIONAL
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Características profesionales:
/// - Gapless Playback con ConcatenatingAudioSource
/// - AudioSession: ducking, interrupciones, foco de audio
/// - Stream de posición suavizado (sin parpadeo)
/// - Persistencia de estado (resume playback)
/// - Buffer inteligente con precarga al 80%
/// ═══════════════════════════════════════════════════════════════════════════

class AudioService {
  // Instancia única del reproductor
  final AudioPlayer player = AudioPlayer();
  
  // ═══════════════════════════════════════════════════════════════════════
  // 🎛️ AUDIO SESSION - Manejo de foco e interrupciones
  // ═══════════════════════════════════════════════════════════════════════
  AudioSession? _audioSession;
  bool _wasPlayingBeforeInterruption = false;
  double _volumeBeforeDucking = 1.0;
  final List<StreamSubscription> _sessionSubscriptions = [];
  
  // ═══════════════════════════════════════════════════════════════════════
  // � GLOBAL POSITION NOTIFIER - Single Source of Truth
  // ═══════════════════════════════════════════════════════════════════════
  /// ValueNotifier global - más rápido que Stream para UI
  /// Ambos widgets (Mini y Extendido) escuchan el mismo notifier
  final ValueNotifier<Duration> globalPosition = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> globalDuration = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> globalBuffered = ValueNotifier(Duration.zero);
  
  /// Timestamp de última actualización (para recalcular tras background)
  DateTime _lastPositionUpdate = DateTime.now();
  bool _wasPlayingWhenBackgrounded = false;
  
  // ═══════════════════════════════════════════════════════════════════════
  // 🎚️ STREAM DE POSICIÓN SUAVIZADO (legacy, aún usado por algunos widgets)
  // ═══════════════════════════════════════════════════════════════════════
  Timer? _smoothPositionTimer;
  Duration _smoothPosition = Duration.zero;
  Duration _targetPosition = Duration.zero;
  Duration _lastEmittedPosition = Duration.zero; // Para distinct
  final _smoothPositionController = StreamController<Duration>.broadcast();
  StreamSubscription? _positionSub;
  static const _smoothUpdateInterval = Duration(milliseconds: 50); // 20 FPS
  static const _smoothInterpolationFactor = 0.15;
  
  // ❄️ HARD FREEZE: Modo congelado (ignora actualizaciones de UI durante operaciones críticas)
  bool _freezeMode = false;
  
  // 🛡️ SEEKING GUARD: Bloqueo durante seek
  bool _isSeeking = false;
  Timer? _seekingGuardTimer;
  Duration? _userSeekPosition; // Posición del usuario durante seek
  static const _seekingGuardDuration = Duration(milliseconds: 500);
  
  // 🔄 TRACK CHANGE DETECTION: Para resetear seekbar
  int? _lastKnownIndex;
  StreamSubscription? _indexChangeSub;
  bool _trackJustChanged = false; // Permite emitir Duration.zero
  bool _zeroJumpMode = false; // 🎯 ZERO-JUMP: Deshabilita interpolación durante cambio de track
  
  /// 📍 PERSISTENT STATE: Última posición conocida (para valor inicial de UI)
  /// Esto evita el salto visual al reabrir la pantalla del reproductor
  Duration get lastKnownPosition => _lastEmittedPosition;
  
  /// 📍 Verificar si hay una posición válida guardada en memoria
  bool get hasValidPosition => _lastEmittedPosition > Duration.zero;
  
  // ═══════════════════════════════════════════════════════════════════════
  // 💾 PERSISTENCIA DE ESTADO
  // ═══════════════════════════════════════════════════════════════════════
  Box<dynamic>? _persistenceBox;
  static const _persistenceBoxName = 'audio_playback_state';
  Timer? _persistenceDebouncer;
  bool _persistenceBlockedAfterSeek = false; // Bloquear persistencia después de seek
  static const _persistenceDelayAfterSeek = Duration(seconds: 2); // Delay post-seek
  
  // ═══════════════════════════════════════════════════════════════════════
  // ⚡ SKIP INSTANTÁNEO - Debounce de ráfaga y UI optimista
  // ═══════════════════════════════════════════════════════════════════════
  Timer? _skipDebounceTimer;
  int _pendingSkipCount = 0;
  bool _isSkipping = false;
  static const _skipDebounceDelay = Duration(milliseconds: 150); // Esperar 150ms para ráfagas
  DateTime _lastSkipRequest = DateTime.now();
  
  // ═══════════════════════════════════════════════════════════════════════
  // 📥 PRECARGA INTELIGENTE
  // ═══════════════════════════════════════════════════════════════════════
  Timer? _preloadMonitorTimer;
  bool _isPreloading = false;
  final Set<String> _preloadedSongIds = {};
  static const _preloadThreshold = 0.80; // Precargar al 80%

  /// Stream de posición suavizado (para Seekbar sin parpadeo)
  Stream<Duration> get smoothPositionStream => _smoothPositionController.stream;

  /// Stream de estado de reproducción (playing/paused)
  Stream<bool> get isPlayingStream => player.playingStream;

  /// Stream de posición actual
  Stream<Duration> get positionStream => player.positionStream;

  /// Stream de duración total
  Stream<Duration?> get durationStream => player.durationStream;

  /// Stream del estado de la secuencia (para obtener la canción actual)
  Stream<SequenceState?> get sequenceStateStream => player.sequenceStateStream;

  /// Stream del índice actual (Master Key para sincronización)
  Stream<int?> get currentIndexStream => player.currentIndexStream;

  /// Stream del estado del reproductor (para buffering, etc.)
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  
  /// Stream de posición buffered
  Stream<Duration> get bufferedPositionStream => player.bufferedPositionStream;

  /// 🛡️ GUARD ANTI-LOOP: Verificar si hay error en el reproductor
  bool get hasError {
    try {
      final playerState = player.playerState;
      return playerState.processingState == ProcessingState.idle;
    } catch (e) {
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  // 🚀 INICIALIZACIÓN PROFESIONAL
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Inicializar características profesionales
  /// Llamar después de crear el servicio
  Future<void> initProfessionalFeatures() async {
    await _initAudioSession();
    await _initPersistence();
    _initSmoothPositionStream();
    _startPreloadMonitor();
    AppLogger.info('[AudioService] ✅ Características profesionales inicializadas');
  }
  
  /// Configurar AudioSession para manejo de foco e interrupciones
  Future<void> _initAudioSession() async {
    try {
      _audioSession = await AudioSession.instance;
      
      await _audioSession!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false, // Control manual del ducking
      ));

      // Escuchar interrupciones (llamadas, notificaciones)
      _sessionSubscriptions.add(
        _audioSession!.interruptionEventStream.listen(_handleInterruption),
      );

      // Escuchar cambios de dispositivo (auriculares desconectados)
      _sessionSubscriptions.add(
        _audioSession!.becomingNoisyEventStream.listen((_) {
          AppLogger.info('[AudioService] 🎧 Auriculares desconectados, pausando...');
          pause();
        }),
      );

      AppLogger.info('[AudioService] 🎛️ AudioSession configurado correctamente');
    } catch (e) {
      AppLogger.error('[AudioService] Error configurando AudioSession: $e');
    }
  }

  /// Manejar interrupciones de audio
  void _handleInterruption(AudioInterruptionEvent event) {
    AppLogger.info('[AudioService] 🔔 Interrupción: ${event.type}, begin=${event.begin}');

    if (event.begin) {
      // Interrupción comenzó
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Bajar volumen (ducking) - notificaciones
          _volumeBeforeDucking = player.volume;
          player.setVolume(_volumeBeforeDucking * 0.3);
          AppLogger.info('[AudioService] 🔉 Ducking activado (volumen al 30%)');
          break;
          
        case AudioInterruptionType.pause:
          // Pausar (llamada entrante, etc.)
          _wasPlayingBeforeInterruption = player.playing;
          if (_wasPlayingBeforeInterruption) {
            pause();
            AppLogger.info('[AudioService] ⏸️ Pausado por interrupción (llamada/etc)');
          }
          break;
          
        case AudioInterruptionType.unknown:
          // Interrupción desconocida, pausar por seguridad
          _wasPlayingBeforeInterruption = player.playing;
          if (_wasPlayingBeforeInterruption) {
            pause();
          }
          break;
      }
    } else {
      // Interrupción terminó
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Restaurar volumen
          player.setVolume(_volumeBeforeDucking);
          AppLogger.info('[AudioService] 🔊 Ducking desactivado (volumen restaurado)');
          break;
          
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          // Reanudar si estaba reproduciendo
          if (_wasPlayingBeforeInterruption) {
            play();
            AppLogger.info('[AudioService] ▶️ Reanudado después de interrupción');
          }
          break;
      }
    }
  }
  
  /// Inicializar stream de posición suavizado
  void _initSmoothPositionStream() {
    // 🔄 TRACK CHANGE: Escuchar cambios de índice para resetear seekbar
    _indexChangeSub = player.currentIndexStream.listen((newIndex) {
      // ✅ FIX: También disparar reset cuando _lastKnownIndex es null (primer cambio de sesión)
      if (newIndex != null && (newIndex != _lastKnownIndex || _lastKnownIndex == null)) {
        _onTrackChanged(newIndex);
      }
      _lastKnownIndex = newIndex;
    });
    
    // Escuchar posición real del player
    _positionSub = player.positionStream.listen((position) {
      // 🛡️ SEEKING GUARD: Ignorar posiciones del motor durante seek
      if (_isSeeking) return;
      // 🎯 ZERO-JUMP: Ignorar posiciones durante cambio de track
      if (_zeroJumpMode) return;
      // ❄️ HARD FREEZE: Ignorar posiciones si estamos congelados
      if (_freezeMode) return;
      _targetPosition = position;
    });

    // Timer de interpolación suave (20 FPS)
    _smoothPositionTimer = Timer.periodic(_smoothUpdateInterval, (_) {
      if (_smoothPositionController.isClosed) return;
      
      // 🎯 ZERO-JUMP: Durante cambio de track, no hacer nada
      if (_zeroJumpMode) return;
      // ❄️ HARD FREEZE: Si estamos congelados, no emitir NADA
      if (_freezeMode) return;
      
      // 🛡️ SEEKING GUARD: Durante seek, usar posición del usuario
      if (_isSeeking && _userSeekPosition != null) {
        _emitIfDistinct(_userSeekPosition!);
        return;
      }

      final diff = _targetPosition.inMilliseconds - _smoothPosition.inMilliseconds;
      
      if (diff.abs() < 100) {
        // Muy cerca, usar posición exacta
        _smoothPosition = _targetPosition;
      } else if (diff.abs() > 2000) {
        // Seek detectado (salto grande), ir directo
        _smoothPosition = _targetPosition;
      } else {
        // Interpolación suave
        final increment = (diff * _smoothInterpolationFactor).round();
        _smoothPosition = Duration(
          milliseconds: _smoothPosition.inMilliseconds + increment,
        );
      }
      
      // 🎯 DISTINCT: No emitir valores menores si está playing (evita retrocesos)
      // ✅ FIX: Permitir "retroceso" si es al inicio de la canción (track change o seek to 0)
      if (player.playing && 
          _smoothPosition < _lastEmittedPosition && 
          !_trackJustChanged &&
          _smoothPosition.inMilliseconds > 1000) { // Solo bloquear si estamos avanzados (>1s)
        // No emitir retroceso involuntario durante playback
        return;
      }

      _emitIfDistinct(_smoothPosition);
    });
    
    AppLogger.info('[AudioService] 🎚️ Stream de posición suavizado inicializado');
  }
  
  /// Emitir solo si es diferente (distinct)
  void _emitIfDistinct(Duration position) {
    // 🔄 TRACK CHANGE: Siempre permitir Duration.zero si cambió de track
    if (_trackJustChanged && position == Duration.zero) {
      _updateAllPositionSources(position);
      _trackJustChanged = false; // Reset flag después de emitir
      return;
    }
    
    // Solo emitir si hay diferencia significativa (>50ms)
    final diffFromLast = (position.inMilliseconds - _lastEmittedPosition.inMilliseconds).abs();
    if (diffFromLast > 50) {
      _updateAllPositionSources(position);
    }
  }
  
  /// 🌐 Actualizar TODAS las fuentes de posición (Single Source of Truth)
  void _updateAllPositionSources(Duration position) {
    _lastEmittedPosition = position;
    _lastPositionUpdate = DateTime.now();
    
    // Actualizar ValueNotifiers (para UI sincronizada)
    globalPosition.value = position;
    
    // Actualizar Stream (legacy)
    if (!_smoothPositionController.isClosed) {
      _smoothPositionController.add(position);
    }
    
    // Actualizar duración y buffer si cambiaron
    final duration = player.duration;
    if (duration != null && duration != globalDuration.value) {
      globalDuration.value = duration;
    }
    
    final buffered = player.bufferedPosition;
    if ((buffered.inMilliseconds - globalBuffered.value.inMilliseconds).abs() > 100) {
      globalBuffered.value = buffered;
    }
  }
  
  /// 🔄 TRACK CHANGE: Resetear estado al cambiar de canción
  void _onTrackChanged(int newIndex) {
    // ❄️ HARD FREEZE: Si estamos congelados, ignorar cambios de track (limpieza de anuncios)
    if (_freezeMode) {
      AppLogger.info('[AudioService] ❄️ HARD FREEZE: Ignorando cambio de track ($newIndex) - UI protegida');
      return;
    }
    
    AppLogger.debug('[AudioService] 🔄 Track changed: $_lastKnownIndex -> $newIndex');
    
    // Si `Zero-Jump` ya fue activado por la ruta optimista
    // (via `_resetPositionForTrackChange`), evitamos hacer un hard-reset
    // doble que provoca el salto visual. En ese caso confirmamos el cambio
    // de track y actualizamos la duración, pero omitimos resets agresivos.
    if (_trackJustChanged) {
      _trackJustChanged = false;
      AppLogger.debug('[AudioService] Zero-Jump confirmado: omitiendo reset agresivo en _onTrackChanged');

      // Actualizar duración si está disponible
      Future.microtask(() {
        final newDuration = player.duration;
        if (newDuration != null) {
          globalDuration.value = newDuration;
        }
      });

      // Cancelar persistencia pendiente de la canción anterior
      _persistenceDebouncer?.cancel();
      _persistenceBlockedAfterSeek = false;

      return;
    }

    // Si no venimos del camino optimista, aplicar el reset tradicional
    // (esto mantiene compatibilidad con eventos de cambio originados
    // directamente por el reproductor)
    
    // 🎯 ZERO-JUMP: Activar modo salto seco (sin interpolación)
    _zeroJumpMode = true;

    // 1. HARD RESET INMEDIATO: Forzar todos los valores a cero ANTES de cualquier otra cosa
    _isSeeking = false;
    _seekingGuardTimer?.cancel();
    _userSeekPosition = Duration.zero;
    _smoothPosition = Duration.zero;
    _targetPosition = Duration.zero;
    _lastEmittedPosition = Duration.zero;

    // 2. HARD RESET ValueNotifiers (síncrono, sin esperar tick)
    globalPosition.value = Duration.zero;
    globalBuffered.value = Duration.zero;
    _lastPositionUpdate = DateTime.now();

    // 3. Marcar que el track cambió (permite emitir Duration.zero)
    _trackJustChanged = true;

    // 4. STREAM DRAIN: Limpiar cualquier valor residual del stream
    // Emitir Duration.zero inmediatamente al Stream
    if (!_smoothPositionController.isClosed) {
      _smoothPositionController.add(Duration.zero);
    }

    // 5. Actualizar duración de la nueva canción (puede tardar un poco)
    Future.microtask(() {
      final newDuration = player.duration;
      if (newDuration != null) {
        globalDuration.value = newDuration;
      }
    });

    // 6. Cancelar persistencia pendiente de la canción anterior
    _persistenceDebouncer?.cancel();
    _persistenceBlockedAfterSeek = false;

    // 7. Desactivar ZERO-JUMP después de 200ms (permitir interpolación normal)
    Future.delayed(const Duration(milliseconds: 200), () {
      _zeroJumpMode = false;
    });

    AppLogger.info('[AudioService] 🎚️ Seekbar reseteado a 0:00 (Zero-Jump)');
  }
  
  /// Forzar actualización de posición suavizada (para seek)
  void forceSmoothPositionUpdate(Duration position) {
    _smoothPosition = position;
    _targetPosition = position;
    _lastEmittedPosition = position;
    _userSeekPosition = position;
    
    // Actualizar ValueNotifier inmediatamente
    globalPosition.value = position;
    _lastPositionUpdate = DateTime.now();
    
    if (!_smoothPositionController.isClosed) {
      _smoothPositionController.add(position);
    }
  }
  
  /// 🛡️ SEEKING GUARD: Iniciar bloqueo de seek
  void startSeekingGuard(Duration userPosition) {
    _isSeeking = true;
    _userSeekPosition = userPosition;
    _persistenceBlockedAfterSeek = true;
    _seekingGuardTimer?.cancel();
    AppLogger.debug('[AudioService] 🛡️ Seeking guard activado @ ${userPosition.inSeconds}s');
  }
  
  /// 🛡️ SEEKING GUARD: Finalizar bloqueo de seek (con delay)
  void endSeekingGuard(Duration finalPosition) {
    _userSeekPosition = finalPosition;
    _smoothPosition = finalPosition;
    _targetPosition = finalPosition;
    _lastEmittedPosition = finalPosition;
    
    // Actualizar ValueNotifier inmediatamente
    globalPosition.value = finalPosition;
    _lastPositionUpdate = DateTime.now();
    
    // Emitir posición final al stream (legacy)
    if (!_smoothPositionController.isClosed) {
      _smoothPositionController.add(finalPosition);
    }
    
    // Mantener guard activo 500ms más para evitar flicker del stream
    _seekingGuardTimer?.cancel();
    _seekingGuardTimer = Timer(const Duration(milliseconds: 600), () {
      _isSeeking = false;
      _userSeekPosition = null;
      _persistenceBlockedAfterSeek = false;
      AppLogger.debug('[AudioService] 🛡️ Seeking guard liberado (final: ${finalPosition.inSeconds}s)');
    });
  }
  
  /// ❄️ HARD FREEZE: Activar/Desactivar modo congelado
  /// Esto "tapa los ojos" a toda la UI (Seekbar, notificadores)
  void setFreezeMode(bool freeze) {
    if (_freezeMode == freeze) return;
    _freezeMode = freeze;
    AppLogger.info('[AudioService] ❄️ HARD FREEZE: ${freeze ? "ACTIVADO" : "DESACTIVADO"}');
  }  

  
  /// Verificar si está en modo seeking
  bool get isSeeking => _isSeeking;
  
  // ═══════════════════════════════════════════════════════════════════════
  // 🔄 BACKGROUND SYNC - Recalcular posición tras volver del background
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Notificar que la app entró en background
  void onAppPaused() {
    _wasPlayingWhenBackgrounded = player.playing;
    _lastPositionUpdate = DateTime.now();
    AppLogger.debug('[AudioService] 📱 App en background, playing=$_wasPlayingWhenBackgrounded');
  }
  
  /// Notificar que la app volvió del background - recalcular posición
  void onAppResumed() {
    if (!_wasPlayingWhenBackgrounded) return;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastPositionUpdate);
    
    if (elapsed.inSeconds < 1) return; // No hacer nada si pasó poco tiempo
    
    // Usar playbackEvent.updatePosition para posición exacta
    final currentPosition = player.position;
    final duration = player.duration;
    
    if (duration != null && currentPosition < duration) {
      // Recalcular posición basada en tiempo transcurrido si está reproduciendo
      Duration calculatedPosition;
      if (player.playing) {
        calculatedPosition = currentPosition;
      } else {
        // Si está pausado, usar la posición guardada
        calculatedPosition = Duration(
          milliseconds: _lastEmittedPosition.inMilliseconds + elapsed.inMilliseconds,
        );
        // Clamp al máximo
        if (calculatedPosition > duration) {
          calculatedPosition = duration;
        }
      }
      
      // Actualizar todas las fuentes
      _smoothPosition = currentPosition;
      _targetPosition = currentPosition;
      _updateAllPositionSources(currentPosition);
      
      AppLogger.debug('[AudioService] 📱 App resumed, synced to ${currentPosition.inSeconds}s');
    }
    
    _lastPositionUpdate = now;
  }
  
  /// 🤝 INSTANT HAND-OFF: Obtener estado actual para traspaso entre widgets
  /// Usado cuando el Mini Player se cierra para abrir el Extendido
  ({Duration position, Duration duration, Duration buffered, bool isPlaying}) getInstantState() {
    return (
      position: globalPosition.value,
      duration: globalDuration.value,
      buffered: globalBuffered.value,
      isPlaying: player.playing,
    );
  }
  
  /// Inicializar persistencia con Hive
  Future<void> _initPersistence() async {
    try {
      if (!Hive.isBoxOpen(_persistenceBoxName)) {
        _persistenceBox = await Hive.openBox(_persistenceBoxName);
      } else {
        _persistenceBox = Hive.box(_persistenceBoxName);
      }
      AppLogger.info('[AudioService] 💾 Persistencia inicializada');
    } catch (e) {
      AppLogger.error('[AudioService] Error inicializando persistencia: $e');
    }
  }
  
  /// Guardar estado de reproducción (debounced)
  /// ⚠️ No guarda si hay seek reciente (evita guardar posición inestable)
  void schedulePersistence(String? songId, int positionMs, List<String> queueIds, int currentIndex) {
    // 🛡️ DEBOUNCE POST-SEEK: No guardar si hubo seek reciente
    if (_persistenceBlockedAfterSeek) {
      AppLogger.debug('[AudioService] 💾 Persistencia bloqueada (seek reciente)');
      return;
    }
    
    _persistenceDebouncer?.cancel();
    _persistenceDebouncer = Timer(const Duration(seconds: 3), () {
      // Verificar de nuevo antes de persistir
      if (_persistenceBlockedAfterSeek || _isSeeking) {
        AppLogger.debug('[AudioService] 💾 Persistencia cancelada (estado inestable)');
        return;
      }
      _persistState(songId, positionMs, queueIds, currentIndex);
    });
  }
  
  Future<void> _persistState(String? songId, int positionMs, List<String> queueIds, int currentIndex) async {
    if (_persistenceBox == null || songId == null) return;

    try {
      await _persistenceBox!.put('playback_state', {
        'songId': songId,
        'positionMs': positionMs,
        'queueIds': queueIds,
        'currentIndex': currentIndex,
        'timestamp': DateTime.now().toIso8601String(),
      });
      AppLogger.debug('[AudioService] 💾 Estado persistido: $songId @ ${positionMs}ms');
    } catch (e) {
      AppLogger.error('[AudioService] Error persistiendo estado: $e');
    }
  }
  
  /// Obtener estado persistido
  /// 🎯 SYNC EN RESUME: Solo devuelve estado si el player está detenido
  Future<Map<String, dynamic>?> getPersistedState({bool forceGet = false}) async {
    if (_persistenceBox == null) return null;
    
    // 🛡️ SYNC EN RESUME: Si el audio ya está reproduciendo, ignorar persistencia
    // Esto evita saltos hacia atrás al minimizar/maximizar
    if (!forceGet && player.playing) {
      AppLogger.debug('[AudioService] 💾 Ignorando estado persistido (audio activo)');
      return null;
    }

    try {
      final data = _persistenceBox!.get('playback_state');
      if (data == null) return null;

      final map = Map<String, dynamic>.from(data as Map);
      final timestamp = DateTime.tryParse(map['timestamp'] as String? ?? '');
      
      // Válido por 7 días
      if (timestamp != null && DateTime.now().difference(timestamp).inDays < 7) {
        return map;
      }
      return null;
    } catch (e) {
      AppLogger.error('[AudioService] Error leyendo estado persistido: $e');
      return null;
    }
  }
  
  /// Limpiar estado persistido
  Future<void> clearPersistedState() async {
    try {
      await _persistenceBox?.delete('playback_state');
    } catch (e) {
      AppLogger.error('[AudioService] Error limpiando estado persistido: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  // 📥 PRECARGA INTELIGENTE
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Iniciar monitor de precarga
  void _startPreloadMonitor() {
    _preloadMonitorTimer?.cancel();
    _preloadMonitorTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkPreloadConditions(),
    );
  }
  
  /// Verificar condiciones de precarga
  void _checkPreloadConditions() {
    if (_isPreloading || !player.playing) return;
    
    final duration = player.duration;
    final position = player.position;
    if (duration == null || duration.inMilliseconds == 0) return;

    final progress = position.inMilliseconds / duration.inMilliseconds;
    
    // Si estamos al 80% o más, notificar para precarga
    if (progress >= _preloadThreshold) {
      _notifyPreloadNeeded();
    }
  }
  
  /// Callback para notificar que se necesita precarga
  void Function()? onPreloadNeeded;
  
  void _notifyPreloadNeeded() {
    if (_isPreloading) return;
    _isPreloading = true;
    
    onPreloadNeeded?.call();
    
    // Reset después de 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      _isPreloading = false;
    });
  }
  
  /// Marcar canción como precargada
  void markAsPreloaded(String songId) {
    _preloadedSongIds.add(songId);
  }
  
  /// Verificar si canción ya fue precargada
  bool isPreloaded(String songId) => _preloadedSongIds.contains(songId);
  
  /// Limpiar caché de precargas
  void clearPreloadCache() => _preloadedSongIds.clear();

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

  /// Buscar posición (con actualización del stream suavizado)
  Future<void> seek(Duration position) async {
    try {
      await player.seek(position);
      // 🎚️ Actualizar inmediatamente el stream suavizado para evitar salto visual
      forceSmoothPositionUpdate(position);
      AppLogger.info('[AudioService] Buscando a: ${position.inSeconds}s');
    } catch (e) {
      AppLogger.error('[AudioService] Error al buscar: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ⚡ SKIP INSTANTÁNEO - Transiciones de track profesionales
  // ═══════════════════════════════════════════════════════════════════════
  
  /// ⚡ TRANSICIÓN INSTANTÁNEA: Siguiente canción optimizado
  /// - UI Optimista: Resetea posición ANTES de esperar al reproductor
  /// - Debounce de ráfaga: Si se presiona 5 veces rápido, salta directo al final
  /// - Sin fade-out: Corte limpio de audio
  Future<void> next() async {
    // ⚡ UI OPTIMISTA: Resetear posición INMEDIATAMENTE (antes de await)
    _resetPositionForTrackChange();
    
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
  
  /// ⚡ SKIP CON DEBOUNCE: Para ráfagas de clics rápidos
  /// Si el usuario presiona 'Siguiente' múltiples veces rápido, 
  /// salta directamente a la canción N sin cargar las intermedias
  Future<void> nextWithDebounce({int skipCount = 1}) async {
    final now = DateTime.now();
    
    // Acumular skips si están en ráfaga (menos de 150ms entre clics)
    if (now.difference(_lastSkipRequest) < _skipDebounceDelay) {
      _pendingSkipCount += skipCount;
      _skipDebounceTimer?.cancel();
      
      // Esperar un poco más por si vienen más clics
      _skipDebounceTimer = Timer(_skipDebounceDelay, () async {
        await _executeAccumulatedSkips();
      });
      
      AppLogger.debug('[AudioService] ⚡ Skip acumulado: $_pendingSkipCount total');
    } else {
      // Primer clic o clic después del debounce - ejecutar inmediatamente
      _pendingSkipCount = skipCount;
      await _executeAccumulatedSkips();
    }
    
    _lastSkipRequest = now;
  }
  
  /// Ejecutar los skips acumulados de una sola vez
  Future<void> _executeAccumulatedSkips() async {
    if (_isSkipping || _pendingSkipCount <= 0) return;
    _isSkipping = true;
    
    final skipsToExecute = _pendingSkipCount;
    _pendingSkipCount = 0;
    _skipDebounceTimer?.cancel();
    
    // ⚡ UI OPTIMISTA: Resetear posición INMEDIATAMENTE
    _resetPositionForTrackChange();
    
    try {
      final sequenceState = player.sequenceState;
      final currentIndex = sequenceState.currentIndex ?? 0;
      final targetIndex = currentIndex + skipsToExecute;
      final maxIndex = sequenceState.sequence.length - 1;
      
      if (targetIndex <= maxIndex) {
        // Saltar directamente al índice objetivo (sin cargar intermedias)
        AppLogger.info('[AudioService] ⚡ Saltando $skipsToExecute canciones: índice $currentIndex → $targetIndex');
        await player.seek(Duration.zero, index: targetIndex);
        await player.play();
      } else if (player.hasNext) {
        // Si el objetivo excede la cola, ir a la última
        AppLogger.info('[AudioService] ⚡ Skip a última canción disponible');
        await player.seek(Duration.zero, index: maxIndex);
        await player.play();
      }
    } catch (e) {
      AppLogger.error('[AudioService] Error en skip acumulado: $e');
    } finally {
      _isSkipping = false;
    }
  }
  
  /// ⚡ Resetear posición para cambio de track (UI Optimista)
  /// ✅ FIX CRÍTICO: Ahora hace hard-reset INMEDIATO de ValueNotifiers
  void _resetPositionForTrackChange() {
    // Activar modo Zero-Jump para deshabilitar interpolación
    _zeroJumpMode = true;
    _trackJustChanged = true;

    // ✅ FIX CRÍTICO: Hard-reset INMEDIATO de todos los estados de posición
    // Esto asegura que la UI muestre 0:00 instantáneamente al cambiar de canción
    _smoothPosition = Duration.zero;
    _targetPosition = Duration.zero;
    _lastEmittedPosition = Duration.zero;
    _userSeekPosition = null;
    
    // ✅ Actualizar ValueNotifier INMEDIATAMENTE (la UI escucha este valor)
    globalPosition.value = Duration.zero;
    _lastPositionUpdate = DateTime.now();
    
    // ✅ Emitir también al stream legacy para widgets que lo usen
    if (!_smoothPositionController.isClosed) {
      _smoothPositionController.add(Duration.zero);
    }

    // Desactivar Zero-Jump después de 200ms (permitir interpolación normal)
    Future.delayed(const Duration(milliseconds: 200), () {
      _zeroJumpMode = false;
    });

    AppLogger.debug('[AudioService] ⚡ Zero-Jump + Hard-reset inmediato aplicado');
  }

  /// ⚡ Canción anterior optimizada
  Future<void> previous() async {
    // ⚡ UI OPTIMISTA: Resetear posición INMEDIATAMENTE
    _resetPositionForTrackChange();
    
    try {
      if (player.hasPrevious) {
        await player.seekToPrevious();
        await player.play();
        AppLogger.info('[AudioService] ⚡ Transición instantánea a canción anterior');
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

  /// 🎛️ VIBE SELECTOR: Limpiar la cola futura desde un índice específico
  /// 
  /// Útil cuando el usuario cambia de género/modo en el Vibe Selector.
  /// Elimina todas las canciones después del índice especificado.
  /// 
  /// [fromIndex]: Índice desde el cual empezar a eliminar (inclusive)
  Future<void> clearFutureQueue({required int fromIndex}) async {
    try {
      final currentSource = player.audioSource;
      if (currentSource is ConcatenatingAudioSource) {
        final totalLength = currentSource.length;
        
        if (fromIndex >= totalLength) {
          AppLogger.debug('[AudioService] 🎛️ clearFutureQueue: No hay canciones para eliminar (fromIndex=$fromIndex >= length=$totalLength)');
          return;
        }

        // Eliminar desde el final hacia fromIndex para evitar problemas de índices
        final itemsToRemove = totalLength - fromIndex;
        for (int i = totalLength - 1; i >= fromIndex; i--) {
          await currentSource.removeAt(i);
        }
        
        AppLogger.info('[AudioService] 🎛️ clearFutureQueue: Eliminadas $itemsToRemove canciones futuras');
      } else {
        AppLogger.warning('[AudioService] 🎛️ clearFutureQueue: No hay ConcatenatingAudioSource activo');
      }
    } catch (e) {
      AppLogger.error('[AudioService] 🎛️ Error en clearFutureQueue: $e');
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
      // Cancelar timers
      _smoothPositionTimer?.cancel();
      _preloadMonitorTimer?.cancel();
      _persistenceDebouncer?.cancel();
      _seekingGuardTimer?.cancel(); // 🛡️ Timer del seeking guard
      
      // Cancelar suscripciones
      await _positionSub?.cancel();
      await _indexChangeSub?.cancel(); // 🔄 Suscripción de cambio de índice
      for (final sub in _sessionSubscriptions) {
        await sub.cancel();
      }
      _sessionSubscriptions.clear();
      
      // Cerrar stream controller
      await _smoothPositionController.close();
      
      // Desactivar sesión de audio
      try {
        await _audioSession?.setActive(false);
      } catch (_) {}
      
      // Liberar player
      await player.dispose();
      AppLogger.info('[AudioService] 🧹 Recursos liberados correctamente');
    } catch (e) {
      AppLogger.error('[AudioService] Error al liberar recursos: $e');
    }
  }
}

/// Provider que gestiona el ciclo de vida del AudioService
/// Se limpia automáticamente cuando el provider se dispose
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  
  // 🚀 Inicializar características profesionales
  Future.microtask(() async {
    await service.initProfessionalFeatures();
  });
  
  // Limpieza nativa al morir el Provider
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

// ═══════════════════════════════════════════════════════════════════════════
// 🔌 PROVIDERS ADICIONALES PARA UI
// ═══════════════════════════════════════════════════════════════════════════

/// 🌐 GLOBAL POSITION NOTIFIER PROVIDER: Single Source of Truth
/// Más rápido que Stream, ambos widgets (Mini y Extendido) lo escuchan
final globalPositionNotifierProvider = Provider<ValueNotifier<Duration>>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.globalPosition;
});

/// 🌐 GLOBAL DURATION NOTIFIER PROVIDER
final globalDurationNotifierProvider = Provider<ValueNotifier<Duration>>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.globalDuration;
});

/// 🌐 GLOBAL BUFFERED NOTIFIER PROVIDER
final globalBufferedNotifierProvider = Provider<ValueNotifier<Duration>>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.globalBuffered;
});

/// 📍 PERSISTENT STATE PROVIDER: Última posición conocida en memoria
/// Usado como valor inicial del Seekbar para evitar saltos visuales
final lastKnownPositionProvider = Provider<Duration>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.lastKnownPosition;
});

/// Provider del stream de posición suavizado (para Seekbar sin parpadeo)
final smoothAudioPositionProvider = StreamProvider<Duration>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.smoothPositionStream;
});

/// Provider del stream de posición buffered
final bufferedPositionProvider = StreamProvider<Duration>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.bufferedPositionStream;
});

/// Provider del progreso de reproducción (0.0 - 1.0)
final playbackProgressProvider = Provider<double>((ref) {
  final positionAsync = ref.watch(smoothAudioPositionProvider);
  final service = ref.watch(audioServiceProvider);
  final duration = service.player.duration;
  
  if (duration == null || duration.inMilliseconds == 0) return 0.0;
  
  return positionAsync.when(
    data: (position) => (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider del progreso de buffer (0.0 - 1.0)
final bufferProgressProvider = Provider<double>((ref) {
  final bufferedAsync = ref.watch(bufferedPositionProvider);
  final service = ref.watch(audioServiceProvider);
  final duration = service.player.duration;
  
  if (duration == null || duration.inMilliseconds == 0) return 0.0;
  
  return bufferedAsync.when(
    data: (buffered) => (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});
