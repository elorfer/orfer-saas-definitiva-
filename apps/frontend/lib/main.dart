import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/neumorphism_theme.dart';
import 'core/utils/logger.dart';
import 'core/utils/url_normalizer.dart';
import 'core/widgets/optimized_scroll_behavior.dart';
import 'core/providers/page_storage_provider.dart';
import 'core/widgets/premium_status_listener.dart';
import 'core/services/http_cache_service.dart';
import 'core/services/playback_reporter_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/app_initializer.dart';

// #region Error Handling

/// Builder personalizado para manejar errores no capturados
Widget _errorWidgetBuilder(FlutterErrorDetails details) {
  final errorStr = details.exception.toString().toLowerCase();
  
  if (errorStr.contains('socketexception') || errorStr.contains('clientexception') || errorStr.contains('google_fonts')) {
    return const SizedBox.shrink();
  }
  
  AppLogger.error('[ErrorHandler] Error detectado', details.exception, details.stack);
  return const SizedBox.shrink();
}

void _setupErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    _errorWidgetBuilder(details);
    if (kDebugMode) FlutterError.presentError(details);
  };
  
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('[ErrorHandler] Error de zona', error, stack);
    return true;
  };
}

// #endregion

// #endregion

Future<void> main() async {
  // ⚡ SUPER ROBUSTO: Mínimo trabajo antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 OPTIMIZACIÓN "INSTANT PLAY": Inicialización paralela
  // Carga Hive y AuthService simultáneamente sin bloquear innecesariamente
  await AppInitializer.init();
  
  // 🚀 OPTIMIZACIÓN DE MEMORIA: Limitar caché de imágenes
  // Evita que la app consuma GBs de RAM en sesiones largas
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB
  PaintingBinding.instance.imageCache.maximumSize = 50; // 50 Imágenes

  
  // Inicialización diferida (no bloquea el primer frame)
  Future.microtask(() async {
    _setupErrorHandlers();
    try {
      UrlNormalizer.cleanDuplicateUrlsFromCache();
    } catch (_) {}
    
    // Configuraciones de UI diferidas
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  });

  runApp(
    const ProviderScope(
      child: VintageMusicApp(),
    ),
  );
}

class VintageMusicApp extends ConsumerStatefulWidget {
  const VintageMusicApp({super.key});

  @override
  ConsumerState<VintageMusicApp> createState() => _VintageMusicAppState();
}

class _VintageMusicAppState extends ConsumerState<VintageMusicApp> {
  @override
  void initState() {
    super.initState();
    // Inicializaciones que necesitan context o son asíncronas
    _initAsync();
  }

  Future<void> _initAsync() async {
    try {
      // Intentar configurar 120Hz en Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterDisplayMode.setHighRefreshRate();
      }
    } catch (_) {}
    
    try {
      await AlbumArtCacheManager.ensureInitialized();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeProvider); // Escuchar cambios de tema
    
    // 🕵️ Servicio de reportes de reproducción (background)
    ref.watch(playbackReporterProvider);
    final pageStorageBucket = ref.watch(sharedPageStorageBucketProvider);
    final neumorphismTheme = NeumorphismTheme(); // Ahora devuele valores dinámicos
    
    return PremiumStatusListener(
      child: PageStorage(
        bucket: pageStorageBucket,
        child: MaterialApp.router(
          title: 'struky',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const OptimizedScrollBehavior(),
          themeMode: themeMode, // 👈 Controlado por Riverpod
          builder: (context, child) {
            // Asegurar que el builder de errores esté configurado
            if (ErrorWidget.builder != _errorWidgetBuilder) {
              ErrorWidget.builder = _errorWidgetBuilder;
            }
            return child ?? const SizedBox.shrink();
          },
          // Tema Claro (Default)
          theme: neumorphismTheme.theme.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          // Tema Oscuro (Misma estructura, la lógica interna de NeumorphismTheme maneja los colores)
          // Nota: Como NeumorphismTheme.theme ya lee el flag estático isDark, 
          // y themeProvider actualiza ese flag, al reconstruirse MaterialApp
          // llamará a neumorphismTheme.theme que devolverá los colores correctos.
          // Sin embargo, para mayor corrección con MaterialApp, definimos darkTheme también.
          // Pero dado que nuestro NeumorphismTheme depende del Singleton flag para TODAS
          // las referencias estáticas, confiamos en el rebuild.
          // Para forzar el "Dark Mode" real de Flutter, pasamos el theme con brightness dark.
          darkTheme: neumorphismTheme.theme.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          routerConfig: router,
        ),
      ),
    );
  }
}
