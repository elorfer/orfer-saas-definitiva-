import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import '../providers/offline_manager_provider.dart';
import '../providers/playback_notifier.dart';
import 'package:audio_service/audio_service.dart';
import 'struky_audio_handler.dart';

/// Servicio centralizado para la inicialización paralela de la app.
/// Objetivo: "Instant Play" - Reducir el tiempo de arranque al mínimo.
class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  factory AppInitializer() => _instance;
  AppInitializer._internal();

  bool _isInitialized = false;

  /// Inicialización crítica: Bloquea el splash screen pero paraleliza todo lo posible.
  static Future<void> init() async {
    if (_instance._isInitialized) return;

    final stopwatch = Stopwatch()..start();
    AppLogger.info('[AppInitializer] 🚀 Iniciando secuencia de arranque paralela...');

    try {
      // 1. Paralelización de servicios críticos
      // Hive y AuthService son independientes en gran medida, pueden arrancar juntos.
      // RevenueCat se excluye explícitamente por ahora.
      await Future.wait([
        _initHive(),
        _initAuth(),
        _initAudioHandler(),
      ]);
      
      // 🚀 PARALLEL START: Iniciar audio handler completado.

      _instance._isInitialized = true;
      stopwatch.stop();
      AppLogger.info('[AppInitializer] ✅ Inicialización crítica completada en ${stopwatch.elapsedMilliseconds}ms');

    } catch (e, stack) {
      AppLogger.error('[AppInitializer] ❌ Error fatal durante inicialización', e, stack);
      // No rethrow aquí para permitir que la app intente arrancar aunque sea con errores limitados
    }
  }

  static Future<void> _initHive() async {
    try {
      await Hive.initFlutter();
      AppLogger.info('[AppInitializer] 📦 Hive inicializado');
    } catch (e) {
      AppLogger.error('[AppInitializer] Error inicializando Hive', e);
      throw e; // Hive es crítico
    }
  }

  static Future<void> _initAuth() async {
    try {
      await AuthService().initialize();
      AppLogger.info('[AppInitializer] 🔐 AuthService inicializado');
    } catch (e) {
      AppLogger.error('[AppInitializer] Error inicializando AuthService', e);
      // AuthService maneja sus propios estados de error
    }
  }

  /// Flag para evitar inicializaciones duplicadas del audio handler
  static bool _audioInitInProgress = false;
  static bool _audioInitCompleted = false;

  static Future<void> _initAudioHandler() async {
    AppLogger.info('[AppInitializer] 🎧 _initAudioHandler llamado');
    if (_audioInitCompleted) {
      AppLogger.info('[AppInitializer] 🎧 AudioHandler ya inicializado, saliendo');
      return;
    }
    if (_audioInitInProgress) {
      AppLogger.debug('[AppInitializer] Audio init ya en progreso, esperando...');
      // Esperar hasta 15 segundos a que termine la inicialización en curso
      for (int i = 0; i < 150; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_audioInitCompleted) return;
      }
      AppLogger.warning('[AppInitializer] ⚠️ Timeout esperando init en progreso');
      return;
    }
    
    _audioInitInProgress = true;
    AppLogger.info('[AppInitializer] 🎧 Iniciando AudioService.init() con timeout de 10s');
    
    try {
      // 🛡️ TIMEOUT: 10 segundos para Android 12 (más generoso)
      await Future.any([
        _initServiceInner(),
        Future.delayed(const Duration(seconds: 10)).then((_) {
          AppLogger.warning('[AppInitializer] ⏱️ Timeout de 10s alcanzado');
          throw TimeoutException('Audio init timed out after 10s');
        }),
      ]);
      _audioInitCompleted = true;
      _audioInitInProgress = false;
      AppLogger.info('[AppInitializer] ✅ AudioHandler inicializado exitosamente dentro del timeout');
    } catch (e, stack) {
      if (e is TimeoutException) {
        AppLogger.error('[AppInitializer] ❌ TIMEOUT: AudioService.init() no completó en 10s', e, stack);
        AppLogger.warning('[AppInitializer] 🔄 Continuando sin notificaciones nativas');
        AppLogger.warning('[AppInitializer] 💡 Posible causa: audio_service incompatible con este dispositivo');
        _audioInitInProgress = false;
        // NO hacer rethrow - dejar que la app continúe con reproductor de respaldo
      } else {
        _audioInitInProgress = false;
        AppLogger.error('[AppInitializer] ❌ ERROR inicializando AudioHandler', e, stack);
        // NO hacer rethrow - dejar que la app continúe
      }
    }
  }

  static Future<void> _initServiceInner() async {
    AppLogger.info('[AppInitializer] 🎵 Iniciando AudioService.init()...');
    try {
      globalAudioHandler = await AudioService.init(
        builder: () {
          AppLogger.info('[AppInitializer] 🎵 Builder de StrukyAudioHandler llamado');
          return StrukyAudioHandler();
        },
        config: AudioServiceConfig(
          androidResumeOnClick: true,
          androidNotificationChannelId: 'com.struky.app.channel.audio.v2',
          androidNotificationChannelName: 'Struky Audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'drawable/ic_stat_music_note',  // XML vector drawable (white on transparent)
        ),
      );
      AppLogger.info('[AppInitializer] 🎵 AudioHandler inicializado correctamente');
      AppLogger.info('[AppInitializer] 🎵 globalAudioHandler es null? ${globalAudioHandler == null}');
    } catch (e, stack) {
      AppLogger.error('[AppInitializer] ❌ Error en AudioService.init()', e, stack);
      rethrow;
    }
  }

  /// Fase "Post-Splash": Se llama desde el provider/main cuando la UI ya está montando.
  /// Aquí disparamos la "Inyección de Adrenalina" (Pre-fetch).
  static void onUserAuthenticated(Ref ref) {
    AppLogger.info('[AppInitializer] 💉 Disparando Inyección de Adrenalina (Post-Auth)...');
    
    // 1. Inicializar OfflineManager (Fire and forget, pero necesario para local-first)
    // Usamos read porque es una acción única
    // init() del OfflineManager ya debería ser robusto
    ref.read(offlineManagerProvider.notifier); // Esto dispara el build() y _init()
    
    // 2. Pre-fetch de audio (El núcleo de Instant Play)
    // Esto buscará canciones locales o pedirá al backend
    final user = AuthService().currentUser;
    if (user != null) {
      // Usamos microtask para no bloquear el frame actual de navegación
      Future.microtask(() {
         // Disparar prefetch de "Instant Play"
         ref.read(playbackNotifierProvider.notifier).prefetch(user);
      });
    }
  }
}
