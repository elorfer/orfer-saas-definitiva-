import 'app_config.dart';

class ApiConfig {
  // Configuración de la API
  static final String baseUrl = AppConfig.baseUrl;
  
  // Endpoints de autenticación
  static const String loginEndpoint = AppConfig.loginEndpoint;
  static const String registerEndpoint = AppConfig.registerEndpoint;
  static const String refreshTokenEndpoint = AppConfig.refreshTokenEndpoint;
  static const String changePasswordEndpoint = AppConfig.changePasswordEndpoint;
  static const String profileEndpoint = AppConfig.profileEndpoint;
  
  // Headers por defecto
  static const Map<String, String> defaultHeaders = AppConfig.defaultHeaders;
  
  // Timeouts
  static const Duration connectTimeout = AppConfig.connectTimeout;
  static const Duration receiveTimeout = AppConfig.receiveTimeout;
  static const Duration sendTimeout = AppConfig.sendTimeout;
  
  // Configuración de reintentos
  static const int maxRetries = AppConfig.maxRetries;
  static const Duration retryDelay = AppConfig.retryDelay;
}
