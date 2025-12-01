import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/app_router.dart';
import 'core/services/http_cache_service.dart';
import 'core/services/http_client_service.dart';
import 'core/theme/neumorphism_theme.dart';
import 'core/utils/logger.dart';

/// Builder personalizado para manejar errores no capturados
/// Ignora errores no críticos y reporta adecuadamente los errores críticos
Widget _errorWidgetBuilder(FlutterErrorDetails details) {
  final errorStr = details.exception.toString().toLowerCase();
  final stackStr = details.stack?.toString().toLowerCase() ?? '';
  final library = details.library ?? '';
  
  // Categorizar errores para mejor manejo
  final isAudioError = errorStr.contains('platformexception') || 
      errorStr.contains('audioservice') ||
      errorStr.contains('audio_service') ||
      stackStr.contains('audioservice') ||
      stackStr.contains('audio_service');
  
  final isProviderDisposedError = errorStr.contains('provider') && 
      (errorStr.contains('disposed') || errorStr.contains('null'));
  
  final isAsyncValueError = errorStr.contains('asyncvalue') || 
      errorStr.contains('streamprovider') ||
      (errorStr.contains('null') && stackStr.contains('provider'));
  
  final isNetworkError = errorStr.contains('socketexception') ||
      errorStr.contains('network') ||
      errorStr.contains('connection') ||
      errorStr.contains('timeout');
  
  final isRenderingError = errorStr.contains('rendering') ||
      errorStr.contains('layout') ||
      errorStr.contains('overflow') ||
      library.contains('rendering');
  
  // Ignorar errores no críticos (mantener UI funcionando)
  if (isAudioError) {
    // Errores de audio son comunes y no críticos para la UI
    if (kDebugMode) {
      AppLogger.debug('[ErrorHandler] Error de audio ignorado (no crítico): ${details.exception}');
    }
    return const SizedBox.shrink();
  }
  
  if (isProviderDisposedError) {
    // Errores de provider disposed son comunes durante navegación
    if (kDebugMode) {
      AppLogger.debug('[ErrorHandler] Error de Provider disposed ignorado (no crítico): ${details.exception}');
    }
    return const SizedBox.shrink();
  }
  
  if (isAsyncValueError) {
    // Errores de AsyncValue son comunes y se manejan internamente
    if (kDebugMode) {
      AppLogger.debug('[ErrorHandler] Error de AsyncValue ignorado (no crítico): ${details.exception}');
    }
    return const SizedBox.shrink();
  }
  
  // Errores de red: reportar pero no bloquear UI (el usuario puede reintentar)
  if (isNetworkError) {
    AppLogger.warning('[ErrorHandler] Error de red detectado: ${details.exception}');
    // En producción, podrías reportar a un servicio de monitoreo
    return const SizedBox.shrink();
  }
  
  // Errores de renderizado: reportar con más detalle pero no bloquear UI
  if (isRenderingError) {
    AppLogger.error(
      '[ErrorHandler] Error de renderizado detectado',
      details.exception,
      details.stack,
    );
    // En producción, podrías reportar a un servicio de monitoreo
    return const SizedBox.shrink();
  }
  
  // ERRORES CRÍTICOS: Reportar con máximo detalle
  // Estos son errores que no deberían ocurrir y necesitan atención
  AppLogger.error(
    '[ErrorHandler] ERROR CRÍTICO DETECTADO',
    details.exception,
    details.stack,
  );
  
  // Log adicional con información del contexto
  if (kDebugMode) {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('ERROR CRÍTICO - Información detallada:');
    debugPrint('Exception: ${details.exception}');
    debugPrint('Library: ${details.library ?? 'N/A'}');
    debugPrint('Context: ${details.context?.toString() ?? 'N/A'}');
    debugPrint('Information: ${details.informationCollector?.call().join('\n') ?? 'N/A'}');
    debugPrint('═══════════════════════════════════════════════════════════');
  }
  
  // TODO: En producción, reportar a un servicio de monitoreo de errores
  // Ejemplo: Firebase Crashlytics, Sentry, etc.
  // _reportToErrorService(details);
  
  // Retornar widget vacío para no bloquear la UI
  // El usuario puede continuar usando la app
  return const SizedBox.shrink();
}

/// Manejar errores de Flutter framework (errores no capturados)
void _setupErrorHandlers() {
  // Manejar errores de Flutter (widgets, rendering, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    // Usar nuestro builder personalizado
    _errorWidgetBuilder(details);
    
    // En modo debug, también usar el handler por defecto de Flutter
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };
  
  // Manejar errores de zona (async errors no capturados)
  PlatformDispatcher.instance.onError = (error, stack) {
    // Reportar errores críticos de zona
    AppLogger.error(
      '[ErrorHandler] Error de zona no capturado',
      error,
      stack,
    );
    
    // Retornar true para indicar que el error fue manejado
    return true;
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar manejo de errores ANTES de cualquier otra inicialización
  _setupErrorHandlers();
  
  // Inicializar caché HTTP para mejorar rendimiento
  await HttpCacheService.initialize();
  
  // Inicializar HttpClientService (debe ser antes que otros servicios)
  await HttpClientService().initialize();
  
  // 🚀 USANDO PROVIDER UNIFICADO CORREGIDO - ÚNICA FUENTE DE VERDAD
  // Todos los sistemas de audio antiguos han sido reemplazados
  debugPrint('🚀 [MAIN] Usando unifiedAudioProviderFixed como único sistema de audio');
  
  // El provider se inicializa automáticamente cuando se usa por primera vez
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Crear el ProviderContainer
  final container = ProviderContainer();
  
  // El provider unificado se inicializa automáticamente cuando se usa
  debugPrint('🚀 [MAIN] Provider unificado listo para usar');
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VintageMusicApp(),
    ),
  );
}

class VintageMusicApp extends ConsumerWidget {
  const VintageMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    final neumorphismTheme = NeumorphismTheme();
    
    return MaterialApp.router(
      title: 'Vintage Music App',
      debugShowCheckedModeBanner: false,
      // Configurar error builder personalizado para evitar el overlay rojo de Flutter
      builder: (context, child) {
        // Configurar ErrorWidget.builder una sola vez (no en cada build)
        if (ErrorWidget.builder != _errorWidgetBuilder) {
          ErrorWidget.builder = _errorWidgetBuilder;
        }
        return child ?? const SizedBox.shrink();
      },
      theme: neumorphismTheme.theme.copyWith(
        // Configurar transiciones de página estilo Spotify
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      routerConfig: router,
    );
  }
}
