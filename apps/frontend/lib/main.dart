import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/neumorphism_theme.dart';
import 'core/utils/logger.dart';
import 'core/utils/url_normalizer.dart';
import 'core/widgets/optimized_scroll_behavior.dart';
import 'core/providers/page_storage_provider.dart';
import 'core/widgets/premium_status_listener.dart';

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
  
  // 🔥 OPTIMIZACIÓN: Errores de precache de imágenes cuando no hay conexión
  // Estos son errores esperados y no deberían mostrarse como errores críticos
  final isImagePrecacheError = (errorStr.contains('clientexception') || 
      errorStr.contains('socketexception')) &&
      (errorStr.contains('connection refused') || 
       errorStr.contains('failed to connect') ||
       errorStr.contains('connection timed out')) &&
      (stackStr.contains('precache') || 
       stackStr.contains('image resource service') ||
       library.contains('image resource service'));
  
  // 🔥 OPTIMIZACIÓN: Errores de google_fonts cuando no hay conexión
  // La app usará fuentes del sistema como fallback automáticamente
  final isGoogleFontsError = (errorStr.contains('google_fonts') ||
      errorStr.contains('fonts.gstatic.com') ||
      errorStr.contains('failed to load font')) &&
      (errorStr.contains('socketexception') ||
       errorStr.contains('failed host lookup') ||
       errorStr.contains('no address associated')) &&
      (stackStr.contains('google_fonts') ||
       stackStr.contains('_httpFetchFontAndSaveToDevice') ||
       stackStr.contains('loadFontIfNecessary'));
  
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
      (errorStr.contains('expanded') && (errorStr.contains('repaintboundary') || stackStr.contains('repaintboundary'))) ||
      (errorStr.contains('parentdata') && (errorStr.contains('incompatible') || errorStr.contains('flexparentdata')));
  
  // ✅ MOSTRAR TODOS LOS ERRORES - Ya no se silencian
  if (isParentDataError) {
    // Errores de ParentDataWidget (Expanded dentro de RepaintBoundary)
    AppLogger.error(
      '[ErrorHandler] ⚠️ ERROR DE PARENTDATAWIDGET DETECTADO',
      details.exception,
      details.stack,
    );
    if (kDebugMode) {
      debugPrint('📍 [ParentDataError] Library: ${details.library ?? 'N/A'}');
      debugPrint('📍 [ParentDataError] Context: ${details.context?.toString() ?? 'N/A'}');
    }
    return const SizedBox.shrink();
  }
  
  if (isProviderModificationError) {
    // Errores de modificación de provider durante build
    AppLogger.warning(
      '[ErrorHandler] ⚠️ Error de modificación de provider durante build: ${details.exception}',
    );
    if (kDebugMode) {
      debugPrint('📍 [ProviderModification] Stack: ${details.stack}');
    }
    return const SizedBox.shrink();
  }
  
  if (isLifecycleError) {
    // Errores de lifecycle cuando Riverpod notifica a widgets desmontados
    AppLogger.warning(
      '[ErrorHandler] ⚠️ Error de lifecycle: ${details.exception}',
    );
    if (kDebugMode) {
      debugPrint('📍 [Lifecycle] Stack: ${details.stack}');
    }
    return const SizedBox.shrink();
  }
  
  if (isHeroError) {
    // Errores de Hero widgets durante navegación rápida
    AppLogger.warning(
      '[ErrorHandler] ⚠️ Error de Hero widget: ${details.exception}',
    );
    if (kDebugMode) {
      debugPrint('📍 [Hero] Stack: ${details.stack}');
    }
    return const SizedBox.shrink();
  }
  
  if (isAudioError) {
    // Errores de audio
    AppLogger.warning(
      '[ErrorHandler] ⚠️ Error de audio: ${details.exception}',
    );
    if (kDebugMode) {
      debugPrint('📍 [Audio] Stack: ${details.stack}');
    }
    return const SizedBox.shrink();
  }
  
  if (isProviderDisposedError) {
    // Errores de provider disposed durante navegación
    AppLogger.warning(
      '[ErrorHandler] ⚠️ Error de Provider disposed: ${details.exception}',
    );
    if (kDebugMode) {
      debugPrint('📍 [ProviderDisposed] Stack: ${details.stack}');
    }
    return const SizedBox.shrink();
  }
  
  if (isAsyncValueError) {
    // Errores de AsyncValue
    AppLogger.warning(
      '[ErrorHandler] ⚠️ Error de AsyncValue: ${details.exception}',
    );
    if (kDebugMode) {
      debugPrint('📍 [AsyncValue] Stack: ${details.stack}');
    }
    return const SizedBox.shrink();
  }
  
  // 🔥 OPTIMIZACIÓN: Errores de precache de imágenes cuando no hay conexión
  // Estos son errores esperados y no deberían mostrarse como errores críticos
  if (isImagePrecacheError) {
    // Silenciar errores de precache cuando no hay conexión (son esperados)
    // No loggear para mantener la consola limpia
    return const SizedBox.shrink();
  }
  
  // 🔥 OPTIMIZACIÓN: Errores de google_fonts cuando no hay conexión
  // La app usará fuentes del sistema como fallback automáticamente
  if (isGoogleFontsError) {
    // Silenciar errores de google_fonts cuando no hay conexión (son esperados)
    // No loggear para mantener la consola limpia
    return const SizedBox.shrink();
  }
  
  // Errores de red: reportar con detalle (pero no los de precache de imágenes o google_fonts)
  if (isNetworkError) {
    AppLogger.error(
      '[ErrorHandler] ⚠️ ERROR DE RED DETECTADO',
      details.exception,
      details.stack,
    );
    if (kDebugMode) {
      debugPrint('📍 [Network] Library: ${details.library ?? 'N/A'}');
    }
    return const SizedBox.shrink();
  }
  
  // Errores de renderizado: reportar con más detalle
  if (isRenderingError) {
    AppLogger.error(
      '[ErrorHandler] ⚠️ ERROR DE RENDERIZADO DETECTADO',
      details.exception,
      details.stack,
    );
    if (kDebugMode) {
      debugPrint('📍 [Rendering] Library: ${details.library ?? 'N/A'}');
      debugPrint('📍 [Rendering] Context: ${details.context?.toString() ?? 'N/A'}');
    }
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
/// 
/// NOTA: Los warnings "WindowOnBackDispatcher" que aparecen en los logs
/// son mensajes informativos del sistema Android sobre el manejo del botón
/// de retroceso. No son errores y no afectan la funcionalidad de la app.
/// Estos warnings vienen directamente del sistema Android y no pueden ser
/// silenciados desde Flutter, pero son completamente normales y seguros.
void _setupErrorHandlers() {
  // Manejar errores de Flutter (widgets, rendering, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    // Verificar si es un error de precache de imágenes antes de procesar
    final errorStr = details.exception.toString().toLowerCase();
    final stackStr = details.stack?.toString().toLowerCase() ?? '';
    final library = details.library ?? '';
    
    final isImagePrecacheError = (errorStr.contains('clientexception') || 
        errorStr.contains('socketexception')) &&
        (errorStr.contains('connection refused') || 
         errorStr.contains('failed to connect') ||
         errorStr.contains('connection timed out')) &&
        (stackStr.contains('precache') || 
         stackStr.contains('image resource service') ||
         stackStr.contains('cached_network_image') ||
         library.contains('image resource service'));
    
    // Si es error de precache, usar el builder pero no mostrar en debug
    if (isImagePrecacheError) {
      _errorWidgetBuilder(details);
      // NO llamar a FlutterError.presentError para estos errores
      return;
    }
    
    // 🔥 OPTIMIZACIÓN: Detectar errores de google_fonts cuando no hay conexión
    final isGoogleFontsError = (errorStr.contains('google_fonts') ||
        errorStr.contains('fonts.gstatic.com') ||
        errorStr.contains('failed to load font')) &&
        (errorStr.contains('socketexception') ||
         errorStr.contains('failed host lookup') ||
         errorStr.contains('no address associated')) &&
        (stackStr.contains('google_fonts') ||
         stackStr.contains('_httpFetchFontAndSaveToDevice') ||
         stackStr.contains('loadFontIfNecessary'));
    
    // Si es error de google_fonts, usar el builder pero no mostrar en debug
    if (isGoogleFontsError) {
      _errorWidgetBuilder(details);
      // NO llamar a FlutterError.presentError para estos errores
      return;
    }
    
    // Usar nuestro builder personalizado
    _errorWidgetBuilder(details);
    
    // En modo debug, también usar el handler por defecto de Flutter (solo para errores no silenciados)
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };
  
  // Manejar errores de zona (async errors no capturados)
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString().toLowerCase();
    final stackStr = stack.toString().toLowerCase();
    
    // 🔥 OPTIMIZACIÓN: Detectar errores de precache de imágenes cuando no hay conexión
    // Estos son errores esperados y no deberían mostrarse
    final isImagePrecacheError = (errorStr.contains('clientexception') || 
        errorStr.contains('socketexception')) &&
        (errorStr.contains('connection refused') || 
         errorStr.contains('failed to connect') ||
         errorStr.contains('connection timed out')) &&
        (stackStr.contains('precache') || 
         stackStr.contains('image resource service') ||
         stackStr.contains('cached_network_image'));
    
    if (isImagePrecacheError) {
      // Silenciar errores de precache cuando no hay conexión (son esperados)
      // No loggear para mantener la consola limpia
      return true; // Error manejado silenciosamente
    }
    
    // Detectar errores de google_fonts cuando no hay conexión (no críticos)
    final isGoogleFontsError = (errorStr.contains('google_fonts') ||
        errorStr.contains('fonts.gstatic.com') ||
        errorStr.contains('failed to load font')) &&
        (errorStr.contains('socketexception') ||
         errorStr.contains('failed host lookup') ||
         errorStr.contains('no address associated'));
    
    if (isGoogleFontsError) {
      // Errores de google_fonts cuando no hay conexión - usar fuentes del sistema como fallback
      AppLogger.warning(
        '[ErrorHandler] ⚠️ Error de Google Fonts (sin conexión): $error',
      );
      if (kDebugMode) {
        debugPrint('📍 [GoogleFonts] La app usará fuentes del sistema como fallback');
      }
      return true; // Error manejado
    }
    
    // Detectar errores de lifecycle (no críticos)
    final isLifecycleError = errorStr.contains('_lifecyclestate') ||
        errorStr.contains('_elementlifecycle') ||
        errorStr.contains('defunct') ||
        errorStr.contains('markneedsbuild') ||
        stackStr.contains('_elementlifecycle.defunct') ||
        stackStr.contains('element.markneedsbuild');
    
    if (isLifecycleError) {
      // Errores de lifecycle - ahora se muestran
      AppLogger.warning(
        '[ErrorHandler] ⚠️ Error de zona (lifecycle): $error',
      );
      if (kDebugMode) {
        debugPrint('📍 [ZoneLifecycle] Stack: $stack');
      }
      return true; // Error manejado
    }
    
    // Reportar errores críticos de zona
    AppLogger.error(
      '[ErrorHandler] ⚠️ ERROR DE ZONA NO CAPTURADO',
      error,
      stack,
    );
    
    // Retornar true para indicar que el error fue manejado
    return true;
  };
}

/// ⚡ 120 FPS: Configurar el modo de visualización óptimo para alcanzar 120 FPS
/// Solo funciona en dispositivos con pantallas de 120Hz (iPhone Pro, Android flagships)
Future<void> _setOptimalDisplayMode() async {
  try {
    // Verificar si el paquete está disponible (solo Android)
    final supported = await FlutterDisplayMode.supported;
    if (supported.isEmpty) {
      debugPrint('⚡ [DisplayMode] Dispositivo no soporta múltiples refresh rates');
      return;
    }
    
    final active = await FlutterDisplayMode.active;
    debugPrint('⚡ [DisplayMode] Modo activo actual: ${active.width}x${active.height}@${active.refreshRate}Hz');
    
    // Filtrar modos con la misma resolución
    final sameResolution = supported
        .where((mode) => mode.width == active.width && mode.height == active.height)
        .toList()
      ..sort((a, b) => b.refreshRate.compareTo(a.refreshRate));
    
    if (sameResolution.isEmpty) {
      debugPrint('⚡ [DisplayMode] No se encontraron modos con la misma resolución');
      return;
    }
    
    // Seleccionar el modo con mayor refresh rate (idealmente 120Hz)
    final optimalMode = sameResolution.first;
    debugPrint('⚡ [DisplayMode] Modo óptimo encontrado: ${optimalMode.width}x${optimalMode.height}@${optimalMode.refreshRate}Hz');
    
    if (optimalMode.refreshRate > active.refreshRate) {
      await FlutterDisplayMode.setPreferredMode(optimalMode);
      debugPrint('⚡ [DisplayMode] ✅ Configurado a ${optimalMode.refreshRate}Hz para 120 FPS');
    } else {
      debugPrint('⚡ [DisplayMode] Ya está en el modo óptimo (${active.refreshRate}Hz)');
    }
  } catch (e) {
    // Si falla (ej. en iOS o dispositivos sin soporte), continuar normalmente
    debugPrint('⚡ [DisplayMode] No se pudo configurar (normal en iOS o dispositivos sin soporte): $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ FIX: Limpiar cache de URLs duplicadas al inicio
  UrlNormalizer.cleanDuplicateUrlsFromCache();
  if (kDebugMode) {
    debugPrint('🧹 [MAIN] Cache de URLs limpiado de duplicaciones');
  }
  
  // Configurar manejo de errores ANTES de cualquier otra inicialización
  _setupErrorHandlers();
  
  // ⚡ 120 FPS: Configurar refresh rate óptimo para dispositivos con pantallas de 120Hz
  await _setOptimalDisplayMode();
  
  // ✅ OPTIMIZACIÓN: Lazy initialization de servicios HTTP
  // Los servicios se inicializarán automáticamente cuando se necesiten
  // Esto reduce significativamente el tiempo de carga inicial
  // HttpCacheService y HttpClientService ahora tienen lazy initialization
  
  // 🚀 USANDO PROVIDER UNIFICADO CORREGIDO - ÚNICA FUENTE DE VERDAD
  // Todos los sistemas de audio antiguos han sido reemplazados
  // ✅ OPTIMIZACIÓN PRODUCCIÓN: Solo log en modo debug
  if (kDebugMode) {
    debugPrint('🚀 [MAIN] Usando unifiedAudioProviderFixed como único sistema de audio');
  }
  
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
  
  // ✅ OPTIMIZACIÓN PRODUCCIÓN: Solo log en modo debug
  if (kDebugMode) {
    debugPrint('🚀 [MAIN] Provider unificado listo para usar');
  }
  
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
    // 🔥 PERSISTENCIA: Obtener PageStorageBucket compartido
    final pageStorageBucket = ref.watch(sharedPageStorageBucketProvider);

    final neumorphismTheme = NeumorphismTheme();
    
    return PremiumStatusListener(
      child: PageStorage(
        bucket: pageStorageBucket,
        child: MaterialApp.router(
        title: 'struky',
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
      ),
    ),
    );
  }
}
