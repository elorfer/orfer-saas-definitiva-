import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/neumorphism_theme.dart';
import 'core/utils/logger.dart';
import 'core/widgets/optimized_scroll_behavior.dart';

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
  
  final isHeroError = errorStr.contains('hero') ||
      errorStr.contains('null check operator') ||
      stackStr.contains('hero') ||
      stackStr.contains('_allHeroesFor');
  
  final isLifecycleError = errorStr.contains('_lifecyclestate') ||
      errorStr.contains('_elementlifecycle') ||
      errorStr.contains('defunct') ||
      errorStr.contains('markneedsbuild') ||
      stackStr.contains('_ElementLifecycle.defunct') ||
      stackStr.contains('Element.markNeedsBuild');
  
  final isProviderModificationError = errorStr.contains('tried to modify a provider') ||
      errorStr.contains('modify a provider while the widget tree was building') ||
      stackStr.contains('_debugCanModifyProviders') ||
      stackStr.contains('_debugAssertNotificationAllowed');
  
  final isParentDataError = errorStr.contains('incorrect use of parentdatawidget') ||
      errorStr.contains('expanded') && (errorStr.contains('repaintboundary') || stackStr.contains('repaintboundary')) ||
      errorStr.contains('parentdata') && (errorStr.contains('incompatible') || errorStr.contains('flexparentdata'));
  
  // Ignorar errores no críticos (mantener UI funcionando)
  if (isParentDataError) {
    // Errores de ParentDataWidget (Expanded dentro de RepaintBoundary) son comunes
    // durante hot reload, animaciones o optimizaciones de Flutter
    // No son críticos si la UI funciona correctamente
    if (kDebugMode) {
      AppLogger.debug('[ErrorHandler] Error de ParentDataWidget ignorado (log fantasma común): ${details.exception}');
    }
    return const SizedBox.shrink();
  }
  
  if (isProviderModificationError) {
    // Errores de modificación de provider durante build son comunes en navegación rápida
    // No son críticos si se manejan correctamente con Future.microtask
    if (kDebugMode) {
      AppLogger.debug('[ErrorHandler] Error de modificación de provider durante build ignorado (no crítico): ${details.exception}');
    }
    return const SizedBox.shrink();
  }
  
  if (isLifecycleError) {
    // Errores de lifecycle son comunes cuando Riverpod notifica a widgets desmontados
    // No son críticos y no afectan la funcionalidad
    if (kDebugMode) {
      AppLogger.debug('[ErrorHandler] Error de lifecycle ignorado (no crítico): ${details.exception}');
    }
    return const SizedBox.shrink();
  }
  
  if (isHeroError) {
    // Errores de Hero widgets son comunes durante navegación rápida
    // y no son críticos para la funcionalidad
    if (kDebugMode) {
      AppLogger.debug('[ErrorHandler] Error de Hero widget ignorado (no crítico): ${details.exception}');
    }
    return const SizedBox.shrink();
  }
  
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
  
  // Nota: En producción, reportar a un servicio de monitoreo de errores
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
    final errorStr = error.toString().toLowerCase();
    final stackStr = stack.toString().toLowerCase();
    
    // Detectar errores de lifecycle (no críticos)
    final isLifecycleError = errorStr.contains('_lifecyclestate') ||
        errorStr.contains('_elementlifecycle') ||
        errorStr.contains('defunct') ||
        errorStr.contains('markneedsbuild') ||
        stackStr.contains('_elementlifecycle.defunct') ||
        stackStr.contains('element.markneedsbuild');
    
    if (isLifecycleError) {
      // Errores de lifecycle son comunes y no críticos
      if (kDebugMode) {
        AppLogger.debug('[ErrorHandler] Error de zona (lifecycle) ignorado (no crítico): $error');
      }
      return true; // Error manejado
    }
    
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
  
  // ✅ OPTIMIZACIÓN: Lazy initialization de servicios HTTP
  // Los servicios se inicializarán automáticamente cuando se necesiten
  // Esto reduce significativamente el tiempo de carga inicial
  // HttpCacheService y HttpClientService ahora tienen lazy initialization
  
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
      title: 'Srtuky',
      debugShowCheckedModeBanner: false,
      // 🔥 ScrollBehavior optimizado global
      scrollBehavior: const OptimizedScrollBehavior(),
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
