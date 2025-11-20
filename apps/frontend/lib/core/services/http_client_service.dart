import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../config/app_config.dart';
import 'http_cache_service.dart';
import '../utils/logger.dart';

/// Servicio centralizado para manejar todas las peticiones HTTP
/// Proporciona una instancia única de Dio con interceptores configurados
class HttpClientService {
  static final HttpClientService _instance = HttpClientService._internal();
  factory HttpClientService() => _instance;
  HttpClientService._internal();

  Dio? _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  bool _isInitialized = false;

  /// Obtener la instancia de Dio (singleton)
  Dio get dio {
    if (_dio == null) {
      throw StateError(
        'HttpClientService no está inicializado. Llama a initialize() primero.',
      );
    }
    return _dio!;
  }

  /// Verificar si está inicializado
  bool get isInitialized => _isInitialized;

  /// Inicializar el servicio HTTP
  Future<void> initialize() async {
    if (_isInitialized && _dio != null) {
      return;
    }

    try {
      
      // Crear instancia de Dio con configuración base
      _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          sendTimeout: AppConfig.sendTimeout,
          headers: ApiConfig.defaultHeaders,
          // Aceptar todos los códigos de estado para manejo manual
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      // Configurar interceptores
      _setupInterceptors();

      _isInitialized = true;
    } catch (e, stackTrace) {
      AppLogger.error('[HttpClientService] Error al inicializar', e, stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }

  /// Configurar todos los interceptores
  void _setupInterceptors() {
    if (_dio == null) return;

    _dio!.interceptors.clear();

    // 1. Interceptor de caché HTTP (si está disponible)
    if (HttpCacheService.cacheOptions != null) {
      _dio!.interceptors.add(
        DioCacheInterceptor(options: HttpCacheService.cacheOptions!),
      );
    }

    // 2. Interceptor de autenticación y headers
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Agregar headers por defecto
          options.headers.addAll(ApiConfig.defaultHeaders);

          // Agregar token de autenticación si existe
          try {
            final token = await _secureStorage.read(key: AppConfig.tokenKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            // Si falla al leer el token, continuar sin él
            // Error al leer token - continuar sin él
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          // Manejar errores de autenticación (401)
          if (error.response?.statusCode == 401) {
            // Limpiar token inválido
            try {
              await _secureStorage.delete(key: AppConfig.tokenKey);
            } catch (_) {
              // Error al limpiar token - ignorar
            }
          }
          handler.next(error);
        },
      ),
    );

    // 3. Interceptor de logging (solo en modo debug)
    if (kDebugMode) {
      _dio!.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          requestHeader: false,
          responseHeader: false,
          logPrint: (object) {
            AppLogger.network('[HttpClientService] $object');
          },
        ),
      );
    }
  }

  /// Actualizar token de autenticación
  /// Esto actualiza el token almacenado que se usa en las peticiones
  Future<void> updateAuthToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _secureStorage.delete(key: AppConfig.tokenKey);
    } else {
      await _secureStorage.write(key: AppConfig.tokenKey, value: token);
    }
  }

  /// Limpiar token de autenticación
  Future<void> clearAuthToken() async {
    await _secureStorage.delete(key: AppConfig.tokenKey);
  }

  /// Obtener token actual
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: AppConfig.tokenKey);
  }

  /// Crear una instancia temporal de Dio para casos especiales
  /// (por ejemplo, verificación de conectividad)
  Dio createTemporaryDio({
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) {
    return Dio(
      BaseOptions(
        connectTimeout: connectTimeout ?? const Duration(seconds: 15),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 15),
        validateStatus: (status) => status != null && status < 600,
      ),
    );
  }

  /// Reinicializar el servicio (útil para cambios de configuración)
  Future<void> reinitialize() async {
    _isInitialized = false;
    _dio = null;
    await initialize();
  }
}



