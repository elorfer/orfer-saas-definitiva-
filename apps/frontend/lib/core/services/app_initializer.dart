import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import '../providers/offline_manager_provider.dart';
import '../providers/playback_notifier.dart';

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
      ]);
      
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
