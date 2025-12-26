import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

class AppConfig {
  // Configuración de la aplicación
  static const String appName = 'struky';
  static const String appVersion = '1.0.0';

  // URLs de configuración (usar `--dart-define` para `API_BASE_URL`)

  // Configuración de la API
  // `baseUrl` debe ser `const` para respetar `--dart-define` en tiempo de compilación.
  // Por conveniencia dejamos un `defaultValue` local seguro como respaldo.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // 🌍 HYBRID CONFIG:
    // - DEBUG: Usar 10.0.2.2 (Emulator) porque Prod está dando 503 o es inestable para desarrollo.
    // - RELEASE/PROFILE: Usar PROD por defecto.
    defaultValue: kDebugMode 
        ? 'http://10.0.2.2:3001/api/v1' 
        : 'http://backend-alb-1038609925.us-east-1.elb.amazonaws.com/api/v1',
  );

  // Llamar a este método desde `main()` para imprimir la URL que usa la app.
  static void checkConnection() {
    AppLogger.config('📡 [NETWORK] Intentando conectar a: $baseUrl');
  }
  

  // Platform detection helpers were removed because `baseUrl` is provided at
  // compile time via `--dart-define`. Keep development URLs above for reference.

  // NOTE: Removed unused helper `_buildFinalUrl` after analyzer warning.

  // helper removed: `_removeTrailingSlash` not used after refactor

  // Endpoints de autenticación
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String refreshTokenEndpoint = '/auth/refresh';
  static const String changePasswordEndpoint = '/auth/change-password';
  static const String profileEndpoint = '/auth/profile';
  
  // Headers por defecto
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Timeouts
  // ⏱️ AUMENTADO A 30 SEGUNDOS: Para dar más tiempo en conexiones lentas o redes inestables
  // El timeout anterior de 10s era muy corto para conexiones de red local que pueden ser lentas
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // Configuración de reintentos
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Configuración de almacenamiento
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String refreshTokenKey = 'refresh_token';
  
  // Configuración de validación
  static const int minPasswordLength = 8;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;
  
  // Configuración de UI
  static const double borderRadius = 12.0;
  static const double cardElevation = 4.0;
  static const double buttonHeight = 56.0;
}
