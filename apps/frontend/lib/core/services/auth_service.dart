import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../models/auth_models.dart';
import '../config/api_config.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';
import '../utils/retry_handler.dart';
import '../utils/error_handler.dart';
import 'http_client_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final HttpClientService _httpClient = HttpClientService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Claves para el almacenamiento seguro
  static const String _tokenKey = AppConfig.tokenKey;
  static const String _userKey = AppConfig.userKey;
  static const String _refreshTokenKey = AppConfig.refreshTokenKey;

  // Estado de autenticación
  User? _currentUser;
  String? _accessToken;
  bool _isInitialized = false;

  // Getters
  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _currentUser != null && _accessToken != null;
  bool get isInitialized => _isInitialized;

  /// Obtener instancia de Dio del HttpClientService
  Dio get _dio => _httpClient.dio;

  /// Inicializar el servicio de autenticación
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Asegurar que HttpClientService esté inicializado
      if (!_httpClient.isInitialized) {
        await _httpClient.initialize();
      }

      // Cargar datos de autenticación guardados
      try {
        await _loadStoredAuthData();
        // Actualizar token en HttpClientService si existe
        if (_accessToken != null) {
          await _httpClient.updateAuthToken(_accessToken);
        }
      } catch (e) {
        AppLogger.error('Error cargando datos guardados', e);
        // Continuar sin datos guardados
      }

      _isInitialized = true;
    } catch (e) {
      AppLogger.error('Error inicializando AuthService', e);
      _isInitialized = true; // Marcar como inicializado de todos modos
    }
  }

  /// Cargar datos de autenticación guardados
  Future<void> _loadStoredAuthData() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      final userData = await _secureStorage.read(key: _userKey);

      if (token != null && userData != null) {
        _accessToken = token;
        _currentUser = User.fromJson(jsonDecode(userData));
      }
    } catch (e) {
      // Si hay error al cargar datos, limpiar todo
      await _clearAuthData();
    }
  }

  /// Verificar conectividad
  Future<bool> _checkConnectivity() async {
    try {
      
      // Usar instancia temporal de Dio del HttpClientService
      final tempDio = _httpClient.createTemporaryDio();
      
      // Intentar hacer una petición simple al backend para verificar conectividad
      // baseUrl ya incluye /api/v1, así que solo agregamos /health
      final healthUrl = ApiConfig.baseUrl.endsWith('/') 
          ? '${ApiConfig.baseUrl}health'
          : '${ApiConfig.baseUrl}/health';
      
      final response = await tempDio.get(healthUrl);
      return response.statusCode == 200;
    } catch (e) {
      // Error de conectividad silenciado - se intentará de todas formas
      
      // Si falla, intentar verificar conectividad de red básica
      try {
        final tempDio = _httpClient.createTemporaryDio();
        
        // Intentar con un endpoint que siempre existe
        final testUrl = ApiConfig.baseUrl.endsWith('/')
            ? '${ApiConfig.baseUrl}health'
            : '${ApiConfig.baseUrl}/health';
        await tempDio.get(
          testUrl,
          options: Options(validateStatus: (status) => status! < 500),
        );
        return true; // Si responde (aunque sea con error), hay conectividad
      } catch (e2) {
        return false;
      }
    }
  }

  /// Login de usuario
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    // Verificar conectividad pero no bloquear si falla - intentar directamente
    final hasConnectivity = await _checkConnectivity();
    if (!hasConnectivity) {
      // No lanzar error aquí, intentar el login directamente
    }

    try {
      final response = await RetryHandler.retryCritical(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.post(
          '${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}',
          data: LoginRequest(
            email: email,
            password: password,
          ).toJson(),
          options: Options(
            headers: ApiConfig.defaultHeaders,
          ),
        ),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _saveAuthData(authResponse);
        return authResponse;
      } else {
        throw AuthException('Error en el servidor: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final error = ErrorHandler.handleDioError(e, context: 'AuthService.login');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    } catch (e) {
      final error = ErrorHandler.handleGenericError(e, context: 'AuthService.login');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    }
  }

  /// Registro de usuario
  Future<AuthResponse> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    UserRole? role,
    String? stageName,
  }) async {
    // Verificar conectividad pero no bloquear si falla - intentar directamente
    final hasConnectivity = await _checkConnectivity();
    if (!hasConnectivity) {
      // No lanzar error aquí, intentar el registro directamente
    }

    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}';
      
      final response = await RetryHandler.retryCritical(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.post(
          url,
          data: RegisterRequest(
            email: email,
            username: username,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: role,
            stageName: stageName,
          ).toJson(),
          options: Options(
            headers: ApiConfig.defaultHeaders,
          ),
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          // Debug: Verificar estructura antes de parsear
          final data = response.data as Map<String, dynamic>;
          if (kDebugMode) {
            AppLogger.debug('Respuesta del backend: ${response.data}');
            AppLogger.debug('Estructura de datos:');
            AppLogger.debug('  - access_token: ${data['access_token'] != null ? "presente" : "ausente"}');
            AppLogger.debug('  - user: ${data['user'] != null ? "presente" : "ausente"}');
            
            if (data['user'] != null) {
              final userData = data['user'] as Map<String, dynamic>;
              AppLogger.debug('  - user.id: ${userData['id']}');
              AppLogger.debug('  - user.email: ${userData['email']}');
              AppLogger.debug('  - user.username: ${userData['username']}');
              AppLogger.debug('  - user.first_name: ${userData['first_name']}');
              AppLogger.debug('  - user.last_name: ${userData['last_name']}');
              AppLogger.debug('  - user.role: ${userData['role']}');
              AppLogger.debug('  - user.subscription_status: ${userData['subscription_status']}');
            }
          }
          
          // Validar que los campos requeridos del user no sean null
          if (data['user'] != null) {
            final userData = data['user'] as Map<String, dynamic>;
            // Asegurar que los campos requeridos no sean null
            if (userData['first_name'] == null && userData['firstName'] == null) {
              AppLogger.error('Error: first_name/firstName es null');
              throw AuthException('El campo first_name es requerido pero está ausente');
            }
            if (userData['last_name'] == null && userData['lastName'] == null) {
              AppLogger.error('Error: last_name/lastName es null');
              throw AuthException('El campo last_name es requerido pero está ausente');
            }
            
            // Normalizar a snake_case si viene en camelCase
            if (userData.containsKey('firstName') && !userData.containsKey('first_name')) {
              userData['first_name'] = userData['firstName'];
              userData.remove('firstName');
            }
            if (userData.containsKey('lastName') && !userData.containsKey('last_name')) {
              userData['last_name'] = userData['lastName'];
              userData.remove('lastName');
            }
            if (userData.containsKey('avatarUrl') && !userData.containsKey('avatar_url')) {
              userData['avatar_url'] = userData['avatarUrl'];
              userData.remove('avatarUrl');
            }
            if (userData.containsKey('subscriptionStatus') && !userData.containsKey('subscription_status')) {
              userData['subscription_status'] = userData['subscriptionStatus'];
              userData.remove('subscriptionStatus');
            }
            if (userData.containsKey('isVerified') && !userData.containsKey('is_verified')) {
              userData['is_verified'] = userData['isVerified'];
              userData.remove('isVerified');
            }
            if (userData.containsKey('isActive') && !userData.containsKey('is_active')) {
              userData['is_active'] = userData['isActive'];
              userData.remove('isActive');
            }
            if (userData.containsKey('lastLoginAt') && !userData.containsKey('last_login_at')) {
              userData['last_login_at'] = userData['lastLoginAt'];
              userData.remove('lastLoginAt');
            }
            if (userData.containsKey('createdAt') && !userData.containsKey('created_at')) {
              userData['created_at'] = userData['createdAt'];
              userData.remove('createdAt');
            }
            if (userData.containsKey('updatedAt') && !userData.containsKey('updated_at')) {
              userData['updated_at'] = userData['updatedAt'];
              userData.remove('updatedAt');
            }
          }
          
          final authResponse = AuthResponse.fromJson(data);
          await _saveAuthData(authResponse);
          return authResponse;
        } catch (parseError, stackTrace) {
          AppLogger.error('Error parseando JSON', parseError, stackTrace);
          throw AuthException('Error parseando respuesta del servidor: $parseError');
        }
      } else {
        throw AuthException('Error en el servidor: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final error = ErrorHandler.handleDioError(e, context: 'AuthService.register');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    } catch (e) {
      final error = ErrorHandler.handleGenericError(e, context: 'AuthService.register');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    }
  }

  /// Cambiar contraseña
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!isAuthenticated) {
      throw AuthException('Usuario no autenticado');
    }

    // Verificar conectividad pero no bloquear
    final hasConnectivity = await _checkConnectivity();
    if (!hasConnectivity) {
      AppLogger.warning('Verificación de conectividad falló, pero intentando de todas formas...');
    }

    try {
      final response = await RetryHandler.retryCritical(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.post(
          '${ApiConfig.baseUrl}${ApiConfig.changePasswordEndpoint}',
          data: ChangePasswordRequest(
            oldPassword: oldPassword,
            newPassword: newPassword,
          ).toJson(),
          options: Options(
            headers: ApiConfig.defaultHeaders,
          ),
        ),
      );

      if (response.statusCode != 200) {
        throw AuthException('Error al cambiar contraseña: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final error = ErrorHandler.handleDioError(e, context: 'AuthService.changePassword');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    } catch (e) {
      final error = ErrorHandler.handleGenericError(e, context: 'AuthService.changePassword');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    }
  }

  /// Refrescar token
  Future<void> refreshToken() async {
    // Verificar conectividad pero no bloquear
    final hasConnectivity = await _checkConnectivity();
    if (!hasConnectivity) {
      AppLogger.warning('Verificación de conectividad falló, pero intentando de todas formas...');
    }

    try {
      final response = await RetryHandler.retryCritical(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.post(
          '${ApiConfig.baseUrl}${ApiConfig.refreshTokenEndpoint}',
          options: Options(
            headers: ApiConfig.defaultHeaders,
          ),
        ),
      );

      if (response.statusCode == 200) {
        final refreshResponse = RefreshTokenResponse.fromJson(response.data);
        _accessToken = refreshResponse.accessToken;
        await _secureStorage.write(key: _tokenKey, value: _accessToken);
        
        // Actualizar token en HttpClientService
        await _httpClient.updateAuthToken(_accessToken);
      } else {
        throw AuthException('Error al refrescar token: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final error = ErrorHandler.handleDioError(e, context: 'AuthService.refreshToken');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    } catch (e) {
      final error = ErrorHandler.handleGenericError(e, context: 'AuthService.refreshToken');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    }
  }

  /// Obtener perfil del usuario
  Future<User> getProfile() async {
    if (!isAuthenticated) {
      throw AuthException('Usuario no autenticado');
    }

    // Verificar conectividad pero no bloquear
    final hasConnectivity = await _checkConnectivity();
    if (!hasConnectivity) {
      AppLogger.warning('Verificación de conectividad falló, pero intentando de todas formas...');
    }

    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          '${ApiConfig.baseUrl}${ApiConfig.profileEndpoint}',
          options: Options(
            headers: ApiConfig.defaultHeaders,
          ),
        ),
      );

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        _currentUser = user;
        await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
        return user;
      } else {
        throw AuthException('Error al obtener perfil: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final error = ErrorHandler.handleDioError(e, context: 'AuthService.getProfile');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    } catch (e) {
      final error = ErrorHandler.handleGenericError(e, context: 'AuthService.getProfile');
      if (error is AuthException) {
        throw error;
      }
      throw AuthException(error.message, code: error.code);
    }
  }

  /// Cerrar sesión
  Future<void> logout() async {
    await _clearAuthData();
  }

  /// Guardar datos de autenticación
  Future<void> _saveAuthData(AuthResponse authResponse) async {
    _accessToken = authResponse.accessToken;
    _currentUser = authResponse.user;

    await _secureStorage.write(key: _tokenKey, value: _accessToken);
    await _secureStorage.write(key: _userKey, value: jsonEncode(_currentUser!.toJson()));
    
    // Actualizar token en HttpClientService para que se use en futuras peticiones
    await _httpClient.updateAuthToken(_accessToken);
  }

  /// Limpiar datos de autenticación
  Future<void> _clearAuthData() async {
    _accessToken = null;
    _currentUser = null;

    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    
    // Limpiar token en HttpClientService
    await _httpClient.clearAuthToken();
  }

}
