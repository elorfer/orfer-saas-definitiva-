import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../config/app_config.dart';
import 'http_cache_service.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';

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
  
  // ✅ DEDUPLICACIÓN DE REQUESTS: Map<clave, Future>
  // Evita múltiples peticiones idénticas simultáneas
  final Map<String, Future<Response>> _pendingRequests = {};
  
  // ⚡ OPTIMIZACIÓN: Variables para throttling de logs
  DateTime? _lastReuseLogTime;
  String? _lastReusedRequestKey;
  static const Duration _reuseLogThrottle = Duration(seconds: 3); // Throttle de 3 segundos para logs de reutilización
  
  // ⚡ OPTIMIZACIÓN: Throttling para errores de conexión masivos
  DateTime? _lastConnectionErrorLogTime;
  int _connectionErrorCount = 0;
  static const Duration _connectionErrorLogThrottle = Duration(seconds: 10); // Solo loggear errores de conexión cada 10 segundos cuando hay muchos

  /// Obtener la instancia de Dio (singleton con lazy initialization)
  Dio get dio {
    // Lazy initialization: inicializar si no está inicializado
    if (_dio == null) {
      // Inicializar de forma asíncrona en background
      initialize().catchError((e) {
        // Si falla la inicialización, se manejará en el próximo acceso
        AppLogger.error('[HttpClientService] Error en lazy initialization', e);
      });
      // Mientras tanto, crear una instancia temporal básica
      return _createTemporaryDio();
    }
    return _dio!;
  }
  
  /// Crear instancia temporal de Dio mientras se inicializa
  Dio _createTemporaryDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: ApiConfig.defaultHeaders,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
  }
  
  /// Asegurar que el servicio esté inicializado (para uso explícito)
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Verificar si está inicializado
  bool get isInitialized => _isInitialized;

  /// Inicializar el servicio HTTP
  Future<void> initialize() async {
    if (_isInitialized && _dio != null) {
      return;
    }

    try {
      // Limpiar cache de URLs al iniciar para asegurar URLs frescas
      UrlNormalizer.clearCache();
      AppLogger.config('🌐 [HttpClientService] Inicializando con baseUrl: ${ApiConfig.baseUrl}');
      
      // Crear instancia de Dio con configuración base
      _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          sendTimeout: AppConfig.sendTimeout,
          headers: {
            ...ApiConfig.defaultHeaders,
            // ✅ COMPRESIÓN HTTP: Habilitar gzip para reducir tamaño de respuestas
            'Accept-Encoding': 'gzip, deflate',
          },
          // Aceptar todos los códigos de estado para manejo manual
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      // Configurar interceptores
      await _setupInterceptors();

      _isInitialized = true;
    } catch (e, stackTrace) {
      AppLogger.error('[HttpClientService] Error al inicializar', e, stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }

  /// Configurar todos los interceptores
  Future<void> _setupInterceptors() async {
    if (_dio == null) return;

    _dio!.interceptors.clear();

    // 1. Interceptor de caché HTTP (si está disponible)
    // Asegurar que el caché esté inicializado antes de usarlo
    await HttpCacheService.ensureInitialized();
    if (HttpCacheService.cacheOptions != null) {
      _dio!.interceptors.add(
        DioCacheInterceptor(options: HttpCacheService.cacheOptions!),
      );
    }

    // 2. Interceptor de autenticación y headers (DEBE estar antes del retry para inicializar retryCount)
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Inicializar contador de reintentos
          if (!options.extra.containsKey('retryCount')) {
            options.extra['retryCount'] = 0;
          }

          // Agregar headers por defecto
          options.headers.addAll(ApiConfig.defaultHeaders);
          
          // ✅ COMPRESIÓN HTTP: Asegurar que Accept-Encoding esté presente
          if (!options.headers.containsKey('Accept-Encoding')) {
            options.headers['Accept-Encoding'] = 'gzip, deflate';
          }

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

    // 3. Interceptor de retry con exponential backoff
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          // ✅ RETRY CON EXPONENTIAL BACKOFF
          // Solo reintentar en errores de red o timeout (no en errores 4xx/5xx)
          final requestOptions = error.requestOptions;
          final currentRetryCount = (requestOptions.extra['retryCount'] as int?) ?? 0;
          const maxRetries = 3;
          const baseDelay = Duration(milliseconds: 500);

          // Protección contra bucles infinitos: verificar que el retryCount no exceda el máximo
          if (currentRetryCount >= maxRetries) {
            AppLogger.error(
              '[HttpClientService] Máximo de reintentos alcanzado ($maxRetries) para ${requestOptions.method} ${requestOptions.path}. Error: ${error.type} - ${error.message}',
            );
            handler.next(error);
            return;
          }

          // Verificar si es un error que debe reintentarse
          final shouldRetry = _shouldRetry(error, currentRetryCount, maxRetries);

          // ⚡ OPTIMIZACIÓN: Detectar errores de conexión masivos y reducir logs
          final isConnectionError = error.type == DioExceptionType.connectionError || 
              error.type == DioExceptionType.connectionTimeout;
          
          if (isConnectionError) {
            _connectionErrorCount++;
            final now = DateTime.now();
            final shouldLogConnectionError = _lastConnectionErrorLogTime == null ||
                now.difference(_lastConnectionErrorLogTime!) > _connectionErrorLogThrottle;
            
            // Limpiar requests pendientes si hay muchos errores de conexión (probablemente no hay conexión)
            if (_connectionErrorCount > 5 && _pendingRequests.isNotEmpty) {
              final clearedCount = _pendingRequests.length;
              _pendingRequests.clear();
              if (shouldLogConnectionError) {
                AppLogger.warning(
                  '[HttpClientService] ⚠️ Múltiples errores de conexión detectados ($_connectionErrorCount). Limpiando $clearedCount requests pendientes.',
                );
              }
            }
            
            // Solo loggear errores de conexión ocasionalmente para evitar spam
            if (shouldLogConnectionError && currentRetryCount == 0) {
              _lastConnectionErrorLogTime = now;
              AppLogger.warning(
                '[HttpClientService] Error de conexión en ${requestOptions.method} ${requestOptions.path}. Verifica que el backend esté corriendo y accesible en ${ApiConfig.baseUrl}',
              );
              if (_connectionErrorCount > 1) {
                AppLogger.warning(
                  '[HttpClientService] Total de errores de conexión recientes: $_connectionErrorCount',
                );
              }
            } else if (currentRetryCount == 0) {
              // Silenciar logs cuando hay muchos errores de conexión
              // Solo loggear el mensaje de error sin detalles adicionales
            }
          } else {
            // Resetear contador si el error no es de conexión
            _connectionErrorCount = 0;
            _lastConnectionErrorLogTime = null;
          }

          // Log del error para debugging (solo en el primer intento y si no es error de conexión masivo)
          if (currentRetryCount == 0 && (!isConnectionError || _connectionErrorCount <= 1)) {
            AppLogger.warning(
              '[HttpClientService] Error en petición ${requestOptions.method} ${requestOptions.path}: ${error.type} - ${error.message}',
            );
            if (error.response != null) {
              AppLogger.warning(
                '[HttpClientService] Status code: ${error.response?.statusCode}',
              );
            }
          }

          if (shouldRetry) {
            // Calcular delay con exponential backoff: baseDelay * 2^retryCount
            final delay = Duration(
              milliseconds: (baseDelay.inMilliseconds * (1 << currentRetryCount)).clamp(
                baseDelay.inMilliseconds,
                10000, // Máximo 10 segundos
              ),
            );

            // ⚡ OPTIMIZACIÓN: Solo loggear el primer y último reintento para evitar spam
            if (currentRetryCount == 0 || currentRetryCount == maxRetries - 1) {
              AppLogger.debug(
                '[HttpClientService] Reintentando petición (intento ${currentRetryCount + 1}/$maxRetries) después de ${delay.inMilliseconds}ms',
              );
            }

            // Esperar antes de reintentar
            await Future.delayed(delay);

            // Actualizar contador de reintentos en las opciones originales
            requestOptions.extra['retryCount'] = currentRetryCount + 1;

            // Reintentar la petición
            try {
              final response = await _dio!.fetch(requestOptions);
              handler.resolve(response);
              return;
            } catch (e) {
              // Si el reintento falla, verificar si debemos continuar reintentando
              if (e is DioException) {
                final newRetryCount = currentRetryCount + 1;
                if (newRetryCount < maxRetries && _shouldRetry(e, newRetryCount, maxRetries)) {
                  // Continuar con el siguiente handler para que el interceptor se ejecute de nuevo
                  handler.next(e);
                  return;
                }
              }
              // Si no se puede reintentar más, pasar el error
              handler.next(error);
              return;
            }
          }

          // Si no se debe reintentar, pasar el error
          handler.next(error);
        },
      ),
    );

    // 4. Interceptor de deduplicación de requests
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // ✅ DEDUPLICACIÓN: Solo para GET requests (no afecta POST/PUT/DELETE)
          if (options.method.toUpperCase() == 'GET') {
            final requestKey = _generateRequestKey(options);
            final pendingRequest = _pendingRequests[requestKey];
            
            if (pendingRequest != null) {
              // Ya existe una petición idéntica en curso, reutilizar su Future
              // ⚡ OPTIMIZACIÓN: Solo loggear ocasionalmente para evitar spam
              final shouldLogReuse = _lastReusedRequestKey != requestKey || 
                                     _lastReuseLogTime == null ||
                                     DateTime.now().difference(_lastReuseLogTime!) > _reuseLogThrottle;
              if (shouldLogReuse) {
                _lastReusedRequestKey = requestKey;
                _lastReuseLogTime = DateTime.now();
                AppLogger.debug('[HttpClientService] Reutilizando request pendiente: $requestKey');
              }
              try {
                // ✅ OPTIMIZACIÓN: Timeout para requests pendientes (evita esperas infinitas)
                final response = await pendingRequest.timeout(
                  const Duration(seconds: 10), // Timeout máximo para requests pendientes
                  onTimeout: () {
                    // Si el request pendiente está tardando demasiado, eliminarlo y crear uno nuevo
                    _pendingRequests.remove(requestKey);
                    throw TimeoutException('Request pendiente excedió timeout');
                  },
                );
                handler.resolve(response);
                return;
              } catch (e) {
                // Si la petición pendiente falló o expiró, eliminar del cache y continuar
                _pendingRequests.remove(requestKey);
                handler.next(options);
                return;
              }
            }
            
            // Crear nueva petición y guardarla en cache
            final requestFuture = _dio!.fetch(options).then((response) {
              _pendingRequests.remove(requestKey);
              // Resetear contador de errores de conexión si hay una respuesta exitosa
              if (_connectionErrorCount > 0) {
                resetConnectionErrorCount();
              }
              return response;
            }).catchError((error) {
              _pendingRequests.remove(requestKey);
              // Si es un error de conexión, incrementar contador
              if (error is DioException && 
                  (error.type == DioExceptionType.connectionError || 
                   error.type == DioExceptionType.connectionTimeout)) {
                _connectionErrorCount++;
              }
              throw error;
            });
            
            _pendingRequests[requestKey] = requestFuture;
          }
          
          handler.next(options);
        },
      ),
    );

    // 4. Interceptor de logging DESHABILITADO para reducir ruido en logs
    // Los logs de HTTP están deshabilitados - solo se registran errores
  }

  /// Verificar si un error debe reintentarse
  bool _shouldRetry(DioException error, int retryCount, int maxRetries) {
    // No reintentar si ya se alcanzó el máximo
    if (retryCount >= maxRetries) return false;

    // No reintentar errores 4xx (errores del cliente)
    if (error.response?.statusCode != null) {
      final statusCode = error.response!.statusCode!;
      if (statusCode >= 400 && statusCode < 500) {
        // Excepción: 408 (Request Timeout) y 429 (Too Many Requests) pueden reintentarse
        if (statusCode == 408 || statusCode == 429) {
          return true;
        }
        return false;
      }
    }

    // Reintentar errores de red, timeout, y errores 5xx
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.response?.statusCode != null &&
            error.response!.statusCode! >= 500);
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
    _pendingRequests.clear(); // Limpiar requests pendientes
    _connectionErrorCount = 0; // Resetear contador de errores de conexión
    _lastConnectionErrorLogTime = null;
    await initialize();
  }
  
  /// Resetear contador de errores de conexión (útil cuando se detecta que la conexión se restableció)
  void resetConnectionErrorCount() {
    _connectionErrorCount = 0;
    _lastConnectionErrorLogTime = null;
  }

  /// ✅ DEDUPLICACIÓN: Generar clave única para un request
  String _generateRequestKey(RequestOptions options) {
    // Incluir método, URL y parámetros de query
    final queryParams = options.queryParameters.entries
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    final queryString = queryParams.join('&');
    return '${options.method}:${options.path}${queryString.isNotEmpty ? '?$queryString' : ''}';
  }

  /// Cancelar todas las peticiones pendientes (útil para limpieza)
  void cancelAllPendingRequests() {
    _pendingRequests.clear();
  }

  /// Obtener número de peticiones pendientes
  int get pendingRequestsCount => _pendingRequests.length;

  /// ✅ CANCELACIÓN: Crear un CancelToken para cancelar requests
  /// Útil para cancelar requests obsoletos cuando el usuario navega o cambia de pantalla
  CancelToken createCancelToken() {
    return CancelToken();
  }

  /// ✅ CANCELACIÓN: Helper para hacer requests con cancelación automática
  /// Si se proporciona un CancelToken, el request se puede cancelar
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// ✅ CANCELACIÓN: Helper para POST con cancelación
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
}



