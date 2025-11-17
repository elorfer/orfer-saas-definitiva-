import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

class AppConfig {
  // Configuración de la aplicación
  static const String appName = 'Vintage Music';
  static const String appVersion = '1.0.0';

  // URLs de configuración
  static const String _productionUrl = 'http://backend-alb-1038609925.us-east-1.elb.amazonaws.com';
  static const String _developmentUrlAndroid = 'http://10.0.2.2:3001'; // Emulador Android y dispositivos móviles (ajustado al puerto expuesto)
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
    
    // Para móvil, usar la URL de Android por defecto (funciona en emulador)
    // En dispositivos físicos, el usuario puede usar --dart-define si necesita otra IP
    return _developmentUrlAndroid;
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
