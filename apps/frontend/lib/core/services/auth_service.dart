import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/auth_models.dart';
import '../config/api_config.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';
import '../utils/retry_handler.dart';
import '../utils/error_handler.dart';
import '../utils/data_normalizer.dart';
import '../exceptions/auth_exception.dart';
import 'http_client_service.dart';
import 'revenuecat_service.dart'; // 🎯 RevenueCat integration

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final HttpClientService _httpClient = HttpClientService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      sharedPreferencesName: 'vintage_auth_store', // ✅ FIX: Usar archivo dedicado para evitar conflictos
      resetOnError: true, 
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

  /// Construir URL completa asegurando que tenga la barra correcta
  String _buildUrl(String endpoint) {
    final baseUrl = ApiConfig.baseUrl.endsWith('/') 
        ? ApiConfig.baseUrl 
        : '${ApiConfig.baseUrl}/';
    // Remover la barra inicial del endpoint si existe
    final cleanEndpoint = endpoint.startsWith('/') 
        ? endpoint.substring(1) 
        : endpoint;
    return '$baseUrl$cleanEndpoint';
  }

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
      AppLogger.debug('[AuthService] 📂 Cargando datos de autenticación guardados...');
      
      // Intentar primero con SecureStorage
      String? token = await _secureStorage.read(key: _tokenKey);
      String? userData = await _secureStorage.read(key: _userKey);

      // Si falla SecureStorage, intentar con SharedPreferences (Fallback)
      if (token == null || userData == null) {
        AppLogger.warning('[AuthService] ⚠️ SecureStorage vacío/falló. Intentando SharedPreferences (Fallback)...');
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString(_tokenKey);
        userData = prefs.getString(_userKey);
        
        if (token != null) AppLogger.info('[AuthService] ✅ Token recuperado desde SharedPreferences');
      }

      if (token != null && userData != null) {
        AppLogger.debug('[AuthService] 🔑 Token encontrado (longitud: ${token.length})');
        
        _accessToken = token;
        
        try {
          // Normalizar datos del usuario al cargar desde almacenamiento
          final userJson = jsonDecode(userData) as Map<String, dynamic>;
          final normalizedData = DataNormalizer.normalizeUser(userJson);
          
          _currentUser = User.fromJson(normalizedData);
          AppLogger.info('[AuthService] ✅ Sesión restaurada exitosamente para: ${_currentUser?.email}');
          
          // 🎯 INICIALIZAR REVENUECAT después de restaurar sesión
          try {
            final revenueCat = RevenueCatService();
            if (!revenueCat.isInitialized && _currentUser != null) {
              await revenueCat.initialize(
                userId: _currentUser!.id,
                email: _currentUser!.email,
              );
              AppLogger.info('[AuthService] 🎉 RevenueCat inicializado después de restaurar sesión');
            }
          } catch (e, stackTrace) {
            // No fallar la carga de sesión si RevenueCat falla
            AppLogger.error('[AuthService] ⚠️ Error inicializando RevenueCat al restaurar sesión', e, stackTrace);
          }
          
        } catch (parseError, stackTrace) {
          AppLogger.error('[AuthService] ❌ Error parseando datos de usuario guardados', parseError, stackTrace);
          rethrow; // Relanzar para limpiar datos corruptos
        }
      } else {
         AppLogger.info('[AuthService] ℹ️ No hay sesión guardada en ningún almacenamiento');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[AuthService] ❌ Error fatal cargando persistencia', e, stackTrace);
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
          _buildUrl(ApiConfig.loginEndpoint),
          data: LoginRequest(
            email: email,
            password: password,
          ).toJson(),
          options: Options(
            headers: ApiConfig.defaultHeaders,
          ),
        ),
      );

      // Manejar códigos de estado de error antes de procesar la respuesta
      if (response.statusCode == 401) {
        final errorMessage = response.data?['message'] ?? 'Credenciales inválidas';
        throw AuthException(
          errorMessage,
          code: 'INVALID_CREDENTIALS',
          statusCode: 401,
        );
      }
      
      if (response.statusCode == 403) {
        throw const AuthException(
          'Acceso denegado',
          code: 'ACCESS_DENIED',
          statusCode: 403,
        );
      }

      if (response.statusCode == 200) {
        // Normalizar datos del usuario antes de parsear (maneja nulls y valores por defecto)
        final responseData = Map<String, dynamic>.from(response.data);
        if (responseData['user'] != null) {
          final userData = responseData['user'] as Map<String, dynamic>;
          // Normalizar completamente los datos del usuario
          responseData['user'] = DataNormalizer.normalizeUser(userData);
        }
        
        final authResponse = AuthResponse.fromJson(responseData);
        await _saveAuthData(authResponse);
        return authResponse;
      } else {
        // Otros códigos de error
        final errorMessage = response.data?['message'] ?? 
                           'Error en el servidor: ${response.statusCode}';
        throw AuthException(
          errorMessage,
          code: 'SERVER_ERROR',
          statusCode: response.statusCode,
        );
      }
    } on AuthException {
      // Re-lanzar AuthException sin modificar
      rethrow;
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'AuthService.login');
      throw AuthException.fromDioError(e, context: 'AuthService.login');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.login');
      throw AuthException.fromGenericError(e, context: 'AuthService.login');
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
      final url = _buildUrl(ApiConfig.registerEndpoint);
      
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
          
          // Normalizar datos del usuario antes de parsear (maneja nulls y valores por defecto)
          if (data['user'] != null) {
            final userData = data['user'] as Map<String, dynamic>;
            // Normalizar completamente los datos del usuario
            data['user'] = DataNormalizer.normalizeUser(userData);
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
      ErrorHandler.handleDioError(e, context: 'AuthService.register');
      throw AuthException.fromDioError(e, context: 'AuthService.register');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.register');
      throw AuthException.fromGenericError(e, context: 'AuthService.register');
    }
  }

  /// 🌐 LOGIN SOCIAL (Google/Facebook)
  Future<AuthResponse> socialLogin({
    required String provider,
    required String accessToken,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    // Verificar conectividad pero no bloquear si falla
    final hasConnectivity = await _checkConnectivity();
    if (!hasConnectivity) {
      AppLogger.warning('Verificación de conectividad falló, pero intentando de todas formas...');
    }

    try {
      final url = _buildUrl('auth/social/login');
      
      final response = await RetryHandler.retryCritical(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.post(
          url,
          data: {
            'provider': provider,
            'accessToken': accessToken,
            'email': email,
            'displayName': displayName,
            'photoUrl': photoUrl,
          },
          options: Options(
            headers: ApiConfig.defaultHeaders,
          ),
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          // Normalizar datos del usuario antes de parsear
          final data = response.data as Map<String, dynamic>;
          
          if (data['user'] != null) {
            final userData = data['user'] as Map<String, dynamic>;
            data['user'] = DataNormalizer.normalizeUser(userData);
          }
          
          final authResponse = AuthResponse.fromJson(data);
          await _saveAuthData(authResponse);
          return authResponse;
        } catch (parseError, stackTrace) {
          AppLogger.error('Error parseando respuesta de social login', parseError, stackTrace);
          throw AuthException('Error parseando respuesta del servidor: $parseError');
        }
      } else {
        throw AuthException('Error en el servidor: ${response.statusCode}');
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'AuthService.socialLogin');
      throw AuthException.fromDioError(e, context: 'AuthService.socialLogin');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.socialLogin');
      throw AuthException.fromGenericError(e, context: 'AuthService.socialLogin');
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
          _buildUrl(ApiConfig.changePasswordEndpoint),
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
      ErrorHandler.handleDioError(e, context: 'AuthService.changePassword');
      throw AuthException.fromDioError(e, context: 'AuthService.changePassword');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.changePassword');
      throw AuthException.fromGenericError(e, context: 'AuthService.changePassword');
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
          _buildUrl(ApiConfig.refreshTokenEndpoint),
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
      ErrorHandler.handleDioError(e, context: 'AuthService.refreshToken');
      throw AuthException.fromDioError(e, context: 'AuthService.refreshToken');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.refreshToken');
      throw AuthException.fromGenericError(e, context: 'AuthService.refreshToken');
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
          _buildUrl(ApiConfig.profileEndpoint),
          options: Options(
            headers: ApiConfig.defaultHeaders,
          ),
        ),
      );

      if (response.statusCode == 200) {
        // Normalizar datos del usuario antes de parsear (maneja nulls y valores por defecto)
        final responseData = Map<String, dynamic>.from(response.data);
        
        // El backend devuelve { user: {...} }, necesitamos extraer el objeto user
        Map<String, dynamic> userData;
        if (responseData.containsKey('user') && responseData['user'] is Map<String, dynamic>) {
          userData = Map<String, dynamic>.from(responseData['user'] as Map<String, dynamic>);
        } else {
          // Si no viene en formato { user: {...} }, usar responseData directamente
          userData = responseData;
        }
        
        // Debug: Ver qué viene del backend
        if (kDebugMode) {
          AppLogger.debug('📥 AuthService.getProfile - Datos del backend:');
          AppLogger.debug('  - responseData completo: $responseData');
          AppLogger.debug('  - userData extraído: $userData');
          AppLogger.debug('  - subscription_status (raw): ${userData['subscription_status']}');
        }
        
        final normalizedData = DataNormalizer.normalizeUser(userData);
        
        // Debug: Ver qué queda después de normalizar
        if (kDebugMode) {
          AppLogger.debug('📤 AuthService.getProfile - Datos normalizados:');
          AppLogger.debug('  - normalizedData: $normalizedData');
          AppLogger.debug('  - subscription_status (normalized): ${normalizedData['subscription_status']}');
        }
        
        final user = User.fromJson(normalizedData);
        
        // Debug: Ver el estado final del usuario
        if (kDebugMode) {
          AppLogger.debug('✅ AuthService.getProfile - Usuario parseado:');
          AppLogger.debug('  - subscriptionStatus: ${user.subscriptionStatus}');
          AppLogger.debug('  - isPremium: ${user.isPremium}');
        }
        
        _currentUser = user;
        await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
        return user;
      } else {
        throw AuthException('Error al obtener perfil: ${response.statusCode}');
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'AuthService.getProfile');
      throw AuthException.fromDioError(e, context: 'AuthService.getProfile');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.getProfile');
      throw AuthException.fromGenericError(e, context: 'AuthService.getProfile');
    }
  }

  /// Cerrar sesión
  Future<void> logout() async {
    await _clearAuthData();
  }

  /// Guardar datos de autenticación
  Future<void> _saveAuthData(AuthResponse authResponse) async {
    try {
      AppLogger.debug('[AuthService] 💾 Guardando datos de autenticación...');
      _accessToken = authResponse.accessToken;
      _currentUser = authResponse.user;

      // 1. Guardar en SecureStorage (Principal)
      await _secureStorage.write(key: _tokenKey, value: _accessToken);
      final userJson = jsonEncode(_currentUser!.toJson());
      await _secureStorage.write(key: _userKey, value: userJson);
      
      // 2. Guardar en SharedPreferences (Backup/Fallback)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _accessToken!);
        await prefs.setString(_userKey, userJson);
        AppLogger.debug('[AuthService] ✅ Backup guardado en SharedPreferences');
      } catch (e) {
        AppLogger.warning('[AuthService] ⚠️ Falló backup en SharedPreferences: $e');
      }

      AppLogger.debug('[AuthService] ✅ Datos guardados exitosamente');
      
      // Actualizar token en HttpClientService para que se use en futuras peticiones
      await _httpClient.updateAuthToken(_accessToken);

      // 🎯 INICIALIZAR REVENUECAT después de login exitoso
      try {
        final revenueCat = RevenueCatService();
        await revenueCat.initialize(
          userId: _currentUser!.id,
          email: _currentUser!.email,
        );
        AppLogger.debug('[AuthService] 🎉 RevenueCat inicializado correctamente');
      } catch (e, stackTrace) {
        // No fallar el login si RevenueCat falla
        AppLogger.error('[AuthService] ⚠️ Error inicializando RevenueCat', e, stackTrace);
      }
    } catch (e, stackTrace) {
      AppLogger.error('[AuthService] ❌ Error guardando datos de autenticación', e, stackTrace);
      rethrow;
    }
  }

  /// Limpiar datos de autenticación
  Future<void> _clearAuthData() async {
    AppLogger.warning('[AuthService] 🧹 Limpiando datos de autenticación...');
    _accessToken = null;
    _currentUser = null;

    try {
      // 1. Limpiar SecureStorage
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      
      // 2. Limpiar SharedPreferences (Backup)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_refreshTokenKey);
      
      AppLogger.debug('[AuthService] ✅ Storage limpiado (Secure + Shared)');
    } catch (e) {
      AppLogger.error('[AuthService] ⚠️ Error limpiando storage (ignorable)', e);
    }
    
    // Limpiar token en HttpClientService
    await _httpClient.clearAuthToken();
    
    // 🎯 Limpiar RevenueCat
    try {
      final revenueCat = RevenueCatService();
      // Solo hacer logout si RevenueCat fue inicializado
      if (revenueCat.isInitialized) {
        await revenueCat.logout();
        AppLogger.debug('[AuthService] ✅ RevenueCat cerrado correctamente');
      } else {
        AppLogger.debug('[AuthService] ℹ️ RevenueCat no estaba inicializado, skip logout');
      }
    } catch (e) {
      AppLogger.warning('[AuthService] ⚠️ Error cerrando RevenueCat (ignorable): $e');
    }
  }

  /// 🔒 Limpiar datos offline del usuario actual
  /// CRÍTICO: Debe ser llamado cuando el usuario cierra sesión para evitar que
  /// las descargas de un usuario sean visibles para otros usuarios
  Future<void> clearOfflineData() async {
    try {
      AppLogger.info('[AuthService] 🧹 Limpiando datos offline (descargas)...');
      
      // Nota: No podemos usar ref.read aquí porque AuthService no tiene acceso a WidgetRef.
      // En su lugar, vamos a limpiar directamente usando la lógica de OfflineManager
      // Esta limpieza se debe hacer desde el AuthProvider donde sí tenemos acceso a ref.
      
      AppLogger.debug('[AuthService] ℹ️ La limpieza de descargas debe hacerse desde AuthProvider');
    } catch (e) {
      AppLogger.warning('[AuthService] ⚠️ Error preparando limpieza offline: $e');
    }
  }

  /// Verificar disponibilidad de nombre de usuario
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      // Limpiar y normalizar el username antes de enviarlo
      final cleanUsername = username.trim();
      
      // Permitir verificación desde 1 carácter (el backend validará el mínimo)
      if (cleanUsername.isEmpty) {
        return false; // No disponible si está vacío
      }
      
      final encodedUsername = Uri.encodeComponent(cleanUsername);
      final url = '${_buildUrl('auth/check-username')}/$encodedUsername';
      AppLogger.debug('Verificando disponibilidad de username - URL: $url');
      AppLogger.debug('Username limpio: "$cleanUsername", Encodificado: "$encodedUsername"');
      
      final response = await _dio.get(
        url,
        options: Options(
          headers: ApiConfig.defaultHeaders,
          validateStatus: (status) => status! < 500, // Aceptar 4xx como válidos
        ),
      );
      
      AppLogger.debug('Respuesta recibida - Status: ${response.statusCode}, Data: ${response.data}');

      if (response.statusCode == 200) {
        final available = response.data['available'] ?? false;
        AppLogger.debug('Username "$cleanUsername" - Respuesta del servidor: available=$available');
        AppLogger.debug('Respuesta completa: ${response.data}');
        return available;
      } else {
        AppLogger.warning('Error verificando username: ${response.statusCode} - ${response.data}');
        // En caso de error del servidor, asumir NO disponible para ser más seguro
        return false;
      }
    } on DioException catch (e) {
      AppLogger.error('Error de red verificando disponibilidad de username', e);
      // En caso de error de red, asumir NO disponible para ser más seguro
      return false;
    } catch (e) {
      AppLogger.error('Error verificando disponibilidad de username', e);
      // En caso de error, asumir NO disponible para ser más seguro
      return false;
    }
  }

  /// Verificar disponibilidad de email
  Future<bool> checkEmailAvailability(String email) async {
    try {
      // Limpiar y normalizar el email antes de enviarlo
      final cleanEmail = email.trim();
      
      // Permitir verificación desde 1 carácter (el backend validará el formato)
      if (cleanEmail.isEmpty) {
        return false; // No disponible si está vacío
      }
      
      final encodedEmail = Uri.encodeComponent(cleanEmail);
      final url = '${_buildUrl('auth/check-email')}/$encodedEmail';
      AppLogger.debug('Verificando disponibilidad de email - URL: $url');
      AppLogger.debug('Email limpio: "$cleanEmail", Encodificado: "$encodedEmail"');
      
      final response = await _dio.get(
        url,
        options: Options(
          headers: ApiConfig.defaultHeaders,
          validateStatus: (status) => status! < 500, // Aceptar 4xx como válidos
        ),
      );
      
      AppLogger.debug('Respuesta recibida - Status: ${response.statusCode}, Data: ${response.data}');

      if (response.statusCode == 200) {
        final available = response.data['available'] ?? false;
        AppLogger.debug('Email "$cleanEmail" - Respuesta del servidor: available=$available');
        AppLogger.debug('Respuesta completa: ${response.data}');
        return available;
      } else {
        AppLogger.warning('Error verificando email: ${response.statusCode} - ${response.data}');
        // En caso de error del servidor, asumir NO disponible para ser más seguro
        return false;
      }
    } on DioException catch (e) {
      AppLogger.error('Error de red verificando disponibilidad de email', e);
      // En caso de error de red, asumir NO disponible para ser más seguro
      return false;
    } catch (e) {
      AppLogger.error('Error verificando disponibilidad de email', e);
      // En caso de error, asumir NO disponible para ser más seguro
      return false;
    }
  }

  /// Verificar si un usuario existe (para login)
  Future<bool> checkUserExists(String emailOrUsername) async {
    try {
      // Intentar verificar como email primero
      if (emailOrUsername.contains('@')) {
        final available = await checkEmailAvailability(emailOrUsername);
        return !available; // Si no está disponible, existe
      } else {
        // Verificar como username
        final available = await checkUsernameAvailability(emailOrUsername);
        return !available; // Si no está disponible, existe
      }
    } catch (e) {
      AppLogger.error('Error verificando existencia de usuario', e);
      return false;
    }
  }

  /// Solicitar recuperación de contraseña
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        _buildUrl('auth/forgot-password'),
        data: {'email': email},
        options: Options(
          headers: ApiConfig.defaultHeaders,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Manejar respuesta como Map o convertir si es necesario
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          return {'message': response.data};
        } else {
          return {'message': 'Solicitud procesada exitosamente'};
        }
      } else {
        throw AuthException('Error al solicitar recuperación de contraseña');
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'AuthService.forgotPassword');
      throw AuthException.fromDioError(e, context: 'AuthService.forgotPassword');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.forgotPassword');
      throw AuthException.fromGenericError(e, context: 'AuthService.forgotPassword');
    }
  }

  /// Restablecer contraseña con token
  Future<void> resetPassword(String token, String newPassword) async {
    try {
      final response = await _dio.post(
        _buildUrl('auth/reset-password'),
        data: {
          'token': token,
          'newPassword': newPassword,
        },
        options: Options(
          headers: ApiConfig.defaultHeaders,
        ),
      );

      if (response.statusCode != 200) {
        throw AuthException('Error al restablecer contraseña');
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'AuthService.resetPassword');
      throw AuthException.fromDioError(e, context: 'AuthService.resetPassword');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.resetPassword');
      throw AuthException.fromGenericError(e, context: 'AuthService.resetPassword');
    }
  }

  /// Verificar email con código de 6 dígitos (OTP)
  Future<AuthResponse> verifyEmailByCode({required String email, required String code}) async {
    try {
      final response = await _dio.post(
        _buildUrl('auth/verify-email-code'),
        data: {
          'email': email,
          'code': code,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        
        // Normalizar datos del usuario
        if (data['user'] != null) {
          data['user'] = DataNormalizer.normalizeUser(data['user']);
        }
        
        final authResponse = AuthResponse.fromJson(data);
        await _saveAuthData(authResponse);
        return authResponse;
      } else {
        throw AuthException('Código de verificación incorrecto o expirado');
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'AuthService.verifyEmailByCode');
      throw AuthException.fromDioError(e, context: 'AuthService.verifyEmailByCode');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'AuthService.verifyEmailByCode');
      throw AuthException.fromGenericError(e, context: 'AuthService.verifyEmailByCode');
    }
  }
}
