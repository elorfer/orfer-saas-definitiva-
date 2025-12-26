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
import 'core/services/http_cache_service.dart';

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

void main() {
  // ⚡ SUPER ROBUSTO: Mínimo trabajo antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  
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
    final pageStorageBucket = ref.watch(sharedPageStorageBucketProvider);
    final neumorphismTheme = NeumorphismTheme();
    
    return PremiumStatusListener(
      child: PageStorage(
        bucket: pageStorageBucket,
        child: MaterialApp.router(
          title: 'struky',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const OptimizedScrollBehavior(),
          builder: (context, child) {
            // Asegurar que el builder de errores esté configurado
            if (ErrorWidget.builder != _errorWidgetBuilder) {
              ErrorWidget.builder = _errorWidgetBuilder;
            }
            return child ?? const SizedBox.shrink();
          },
          theme: neumorphismTheme.theme.copyWith(
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
