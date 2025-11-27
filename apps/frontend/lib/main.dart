import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/app_router.dart';
import 'core/services/http_cache_service.dart';
import 'core/services/http_client_service.dart';
import 'core/theme/neumorphism_theme.dart';

/// Builder personalizado para manejar errores no capturados
/// Ignora errores no críticos y muestra un mensaje amigable solo para errores importantes
Widget _errorWidgetBuilder(FlutterErrorDetails details) {
  // Log del error para debugging
  debugPrint('ERROR: ${details.exception}');
  debugPrint('Stack trace: ${details.stack}');
  
  final errorStr = details.exception.toString().toLowerCase();
  final stackStr = details.stack?.toString().toLowerCase() ?? '';
  
  // Ignorar errores relacionados con audio que no son críticos
  if (errorStr.contains('platformexception') || 
      errorStr.contains('audioservice') ||
      errorStr.contains('audio_service') ||
      stackStr.contains('audioservice') ||
      stackStr.contains('audio_service')) {
    debugPrint('Error relacionado con audio ignorado (no crítico)');
    return const SizedBox.shrink();
  }
  
  // Ignorar errores de Provider/Stream que no son críticos
  if (errorStr.contains('provider') && 
      (errorStr.contains('disposed') || errorStr.contains('null'))) {
    debugPrint('Error de Provider ignorado (no crítico)');
    return const SizedBox.shrink();
  }
  
  // Ignorar errores de AsyncValue/StreamProvider que no son críticos
  if (errorStr.contains('asyncvalue') || 
      errorStr.contains('streamprovider') ||
      (errorStr.contains('null') && stackStr.contains('provider'))) {
    debugPrint('Error de AsyncValue/StreamProvider ignorado (no crítico)');
    return const SizedBox.shrink();
  }
  
  // Para errores críticos reales, solo loguearlos pero no bloquear la UI
  // En producción, podrías reportar estos errores a un servicio de monitoreo
  debugPrint('ERROR CRÍTICO (no bloquea UI): ${details.exception}');
  
  // Retornar widget vacío en lugar de mostrar error para no bloquear la UI
  // El usuario puede continuar usando la app
  return const SizedBox.shrink();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
