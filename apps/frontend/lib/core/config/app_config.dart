import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

class AppConfig {
  // Configuración de la aplicación
  static const String appName = 'Srtuky';
  static const String appVersion = '1.0.0';

  // URLs de configuración
  static const String _productionUrl = 'http://backend-alb-1038609925.us-east-1.elb.amazonaws.com';
  
  // URL para emulador Android (10.0.2.2 es el alias del localhost del host en el emulador)
  static const String _developmentUrlAndroidEmulator = 'http://10.0.2.2:3001';
  
  // URL para dispositivos físicos Android conectados por USB
  // Si usas 'adb reverse tcp:3001 tcp:3001', puedes usar localhost
  // Si prefieres usar la IP de red, cambia esto a tu IP local
  static const String _developmentUrlAndroidPhysical = 'http://localhost:3001';
  
  // URL alternativa para dispositivos físicos por WiFi (IP local de tu computadora)
  // IMPORTANTE: Reemplaza 192.168.1.100 con la IP local de tu computadora
  // Para encontrar tu IP: Windows: ipconfig | Linux/Mac: ifconfig o ip addr
  static const String _developmentUrlAndroidWiFi = 'http://192.168.1.100:3001';
  
  static const String _developmentUrlWeb = 'http://localhost:3001'; // Flutter Web

  // Configuración de la API
  // En modo DEBUG: usa localhost/10.0.2.2 automáticamente
  // En modo RELEASE: usa producción (o variable de entorno si está definida)
  static final String baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    // 1. Prioridad: Variable de entorno (siempre tiene precedencia)
    final rawBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    if (rawBaseUrl.isNotEmpty) {
      AppLogger.config('Usando URL desde variable de entorno: $rawBaseUrl');
      return _buildFinalUrl(rawBaseUrl);
    }

    // 2. Si está en modo DEBUG, usar desarrollo automáticamente
    if (kDebugMode) {
      final devUrl = _getDevelopmentUrl();
      AppLogger.config('MODO DEBUG: Usando URL de desarrollo: $devUrl');
      AppLogger.config('NOTA: Si estás en un dispositivo físico conectado por USB:');
      AppLogger.config('  1. Ejecuta: adb reverse tcp:3001 tcp:3001');
      AppLogger.config('  2. Luego ejecuta: flutter run');
      AppLogger.config('Si estás usando WiFi, usa: flutter run --dart-define=USE_WIFI=true');
      return _buildFinalUrl(devUrl);
    }

    // 3. Si está en modo RELEASE, usar producción
    AppLogger.config('MODO RELEASE: Usando URL de producción: $_productionUrl');
    return _buildFinalUrl(_productionUrl);
  }

  static String _getDevelopmentUrl() {
    // Detectar plataforma sin usar dart:io (compatible con web)
    if (kIsWeb) {
      return _developmentUrlWeb;
    }
    
    // Para Android, detectar si está en emulador o dispositivo físico
    if (!kIsWeb) {
      try {
        // Verificar si hay una IP configurada manualmente
        final manualIp = String.fromEnvironment('DEV_IP', defaultValue: '');
        if (manualIp.isNotEmpty) {
          AppLogger.config('Usando IP manual para desarrollo: $manualIp');
          return 'http://$manualIp:3001';
        }
        
        // Verificar si se especifica usar WiFi en lugar de USB
        final useWiFi = String.fromEnvironment('USE_WIFI', defaultValue: 'false') == 'true';
        if (useWiFi) {
          AppLogger.config('Usando conexión WiFi (IP de red)');
          return _developmentUrlAndroidWiFi;
        }
        
        // Verificar si se especifica usar dispositivo físico explícitamente
        final usePhysical = String.fromEnvironment('USE_PHYSICAL', defaultValue: 'false') == 'true';
        if (usePhysical) {
          AppLogger.config('Usando URL para dispositivo físico: $_developmentUrlAndroidPhysical');
          AppLogger.config('NOTA: Requiere ejecutar: adb reverse tcp:3001 tcp:3001');
          return _developmentUrlAndroidPhysical;
        }
        
        // Por defecto, asumir que es emulador (más común en desarrollo)
        // Para emulador Android, usar 10.0.2.2 que es el alias de localhost del host
        AppLogger.config('Usando URL para emulador: $_developmentUrlAndroidEmulator');
        AppLogger.config('Si es dispositivo físico, usa: flutter run --dart-define=USE_PHYSICAL=true');
        return _developmentUrlAndroidEmulator;
      } catch (e) {
        AppLogger.warning('Error detectando plataforma: $e');
        // Fallback: usar emulador por defecto
        return _developmentUrlAndroidEmulator;
      }
    }
    
    // Para iOS u otras plataformas, usar localhost
    return _developmentUrlAndroidPhysical;
  }

  static String _buildFinalUrl(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      // Siempre agregar api/v1 al final
      final segments = <String>[
        for (final segment in uri.pathSegments)
          if (segment.isNotEmpty) segment,
      ];
      
      // Solo agregar api/v1 si no está ya presente
      if (!segments.contains('api') || !segments.contains('v1')) {
        segments.addAll(['api', 'v1']);
      }

      final finalUrl = _removeTrailingSlash(
        uri.replace(pathSegments: segments).toString(),
      );
      
      return finalUrl;
    } catch (e) {
      AppLogger.warning('Error al parsear URL: $e');
      // Fallback seguro: usar desarrollo si está en debug, producción si no
      final fallbackUrl = kDebugMode 
          ? _getDevelopmentUrl()
          : _productionUrl;
      return '$fallbackUrl/api/v1';
    }
  }

  static String _removeTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

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
