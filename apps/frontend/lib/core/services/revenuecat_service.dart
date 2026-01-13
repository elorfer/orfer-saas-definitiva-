// 🎯 RevenueCat Service - Singleton Pattern
// Gestiona suscripciones premium de Struky con RevenueCat

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:dio/dio.dart';
import 'http_client_service.dart';

/// Servicio centralizado para gestionar suscripciones premium con RevenueCat
/// 
/// Implementa el patrón Singleton para garantizar una única instancia
/// y manejo consistente del estado de suscripción en toda la app.
/// 
/// **Características:**
/// - ✅ Inicialización automática con userId
/// - ✅ Verificación de estado premium en tiempo real
/// - ✅ Restauración de compras
/// - ✅ Listeners para cambios de suscripción
/// - ✅ Manejo robusto de errores
/// - ✅ Logs detallados para debugging
class RevenueCatService {
  // ========================================================================
  // SINGLETON PATTERN
  // ========================================================================
  
  static final RevenueCatService _instance = RevenueCatService._internal();
  
  /// Constructor factory que siempre devuelve la misma instancia
  factory RevenueCatService() => _instance;
  
  /// Constructor privado
  RevenueCatService._internal();
  
  // ========================================================================
  // DEPENDENCIAS
  // ========================================================================
  
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );
  
  // ========================================================================
  // CONFIGURACIÓN
  // ========================================================================
  
  /// API Key de RevenueCat (obtenerla desde el dashboard)
  /// ⚠️ CRÍTICO: Debe estar en variables de entorno o flutter_dotenv
  static const String _androidApiKey = 'test_dlszADZNjJepsuXJHyLnzuRMydh';
  
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: '', // Para iOS cuando lo necesites
  );
  
  /// Identificador del offering de suscripción premium
  /// (configurado en el dashboard de RevenueCat)
  static const String _premiumOfferingId = 'premium_monthly';
  
  /// Identificador del entitlement (permiso) de premium
  static const String _premiumEntitlementId = 'Struky Premium';
  
  // ========================================================================
  // ESTADO
  // ========================================================================
  
  /// Si el servicio está inicializado
  bool _isInitialized = false;
  
  /// ID del usuario actual en RevenueCat
  String? _currentUserId;
  
  /// Información del cliente actual (CustomerInfo de RevenueCat)
  CustomerInfo? _customerInfo;
  
  /// Stream controller para notificar cambios en el estado premium
  final StreamController<bool> _premiumStatusController = 
      StreamController<bool>.broadcast();
  
  /// Stream público para escuchar cambios de premium
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;
  
  // ========================================================================
  // GETTERS
  // ========================================================================
  
  /// Si el servicio está inicializado
  bool get isInitialized => _isInitialized;
  
  /// Verifica si el usuario tiene una suscripción premium activa
  bool get isPremium {
    if (_customerInfo == null) return false;
    
    final entitlement = _customerInfo!.entitlements.all[_premiumEntitlementId];
    final isActive = entitlement?.isActive ?? false;
    
    _logger.d('🎯 isPremium: $isActive');
    return isActive;
  }
  
  /// Fecha de expiración de la suscripción (si existe)
  DateTime? get premiumExpirationDate {
    final entitlement = _customerInfo?.entitlements.all[_premiumEntitlementId];
    return entitlement?.expirationDate != null 
        ? DateTime.parse(entitlement!.expirationDate!)
        : null;
  }
  
  /// Si la suscripción está en periodo de gracia
  bool get isInGracePeriod {
    // La versión 8.x no tiene isInGracePeriod
    return false;
  }
  
  /// Si el usuario tiene una suscripción pero ha cancelado la renovación
  bool get willRenew {
    final entitlement = _customerInfo?.entitlements.all[_premiumEntitlementId];
    return entitlement?.willRenew ?? false;
  }
  
  /// Información completa del cliente (para debugging o analytics)
  CustomerInfo? get customerInfo => _customerInfo;
  
  // ========================================================================
  // INICIALIZACIÓN
  // ========================================================================
  
  /// Inicializa RevenueCat con el ID del usuario
  /// 
  /// **IMPORTANTE:** Llamar este método inmediatamente después del login exitoso
  /// 
  /// [userId] - ID único del usuario en tu sistema (debe coincidir con el backend)
  /// [email] - Email del usuario (opcional, útil para soporte)
  /// 
  /// Retorna `true` si la inicialización fue exitosa
  Future<bool> initialize({
    required String userId,
    String? email,
  }) async {
    if (_isInitialized && _currentUserId == userId) {
      _logger.i('✅ RevenueCat ya inicializado para usuario: $userId');
      return true;
    }
    
    try {
      _logger.i('🚀 Inicializando RevenueCat para usuario: $userId');
      
      // 1. Configurar RevenueCat con la nueva API
      final configuration = PurchasesConfiguration(_getApiKey())
        ..appUserID = userId; // Vincula con tu sistema de usuarios
      
      await Purchases.configure(configuration);
      
      // 2. Configurar el log level (método separado en v8.x)
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      } else {
        await Purchases.setLogLevel(LogLevel.info);
      }
      
      // 3. Establecer atributos del usuario si se proporciona email
      if (email != null && email.isNotEmpty) {
        await Purchases.setEmail(email);
        _logger.d('📧 Email asociado: $email');
      }
      
      // 4. Obtener información inicial del cliente
      _customerInfo = await Purchases.getCustomerInfo();
      _currentUserId = userId;
      _isInitialized = true;
      
      // 5. Configurar listener de actualizaciones
      _setupCustomerInfoListener();
      
      // 6. Notificar estado inicial
      _notifyPremiumStatus();
      
      _logger.i('✅ RevenueCat inicializado correctamente');
      _logPremiumStatus();
      
      return true;
      
    } on PlatformException catch (e) {
      _logger.e('❌ Error de plataforma al inicializar RevenueCat', error: e);
      _isInitialized = false;
      return false;
      
    } catch (e) {
      _logger.e('❌ Error inesperado al inicializar RevenueCat', error: e);
      _isInitialized = false;
      return false;
    }
  }
  
  /// Obtiene la API key correcta según la plataforma
  String _getApiKey() {
    if (Platform.isAndroid) {
      if (_androidApiKey.isEmpty) {
        throw Exception(
          '⚠️ REVENUECAT_ANDROID_KEY no configurada. '
          'Agrégala en las variables de entorno o en el código.'
        );
      }
      return _androidApiKey;
    } else if (Platform.isIOS) {
      if (_iosApiKey.isEmpty) {
        throw Exception(
          '⚠️ REVENUECAT_IOS_KEY no configurada. '
          'Agrégala en las variables de entorno o en el código.'
        );
      }
      return _iosApiKey;
    } else {
      throw UnsupportedError('Plataforma no soportada para RevenueCat');
    }
  }
  
  /// Configura el listener para cambios en CustomerInfo
  void _setupCustomerInfoListener() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _logger.i('🔔 CustomerInfo actualizado desde RevenueCat');
      _customerInfo = customerInfo;
      _notifyPremiumStatus();
      _logPremiumStatus();
    });
  }
  
  // ========================================================================
  // VERIFICACIÓN DE ESTADO PREMIUM
  // ========================================================================
  
  /// Verifica el estado premium actual (fuerza una sincronización con RevenueCat)
  /// 
  /// Útil para verificar el estado después de una compra o restauración
  Future<bool> checkPremiumStatus() async {
    if (!_isInitialized) {
      _logger.w('⚠️ RevenueCat no inicializado. Llama a initialize() primero.');
      return false;
    }
    
    try {
      _logger.d('🔄 Verificando estado premium...');
      
      // Obtener información actualizada del servidor de RevenueCat
      _customerInfo = await Purchases.getCustomerInfo();
      
      final premium = isPremium;
      _notifyPremiumStatus();
      _logPremiumStatus();
      
      return premium;
      
    } on PlatformException catch (e) {
      _logger.e('❌ Error al verificar estado premium', error: e);
      return false;
      
    } catch (e) {
      _logger.e('❌ Error inesperado al verificar premium', error: e);
      return false;
    }
  }
  
  /// Sincroniza el estado local con el servidor de RevenueCat
  /// (alias de checkPremiumStatus para mayor claridad)
  Future<bool> syncPremiumStatus() => checkPremiumStatus();
  
  // ========================================================================
  // RESTAURACIÓN DE COMPRAS
  // ========================================================================
  
  /// Restaura las compras del usuario desde Google Play o App Store
  /// 
  /// **Casos de uso:**
  /// - Usuario reinstala la app
  /// - Usuario cambia de dispositivo
  /// - Usuario reclama que perdió su suscripción
  /// 
  /// Retorna `true` si se encontraron compras activas
  Future<bool> restorePurchases() async {
    if (!_isInitialized) {
      _logger.w('⚠️ RevenueCat no inicializado. Llama a initialize() primero.');
      return false;
    }
    
    try {
      _logger.i('🔄 Restaurando compras...');
      
      // Restaurar compras desde la tienda
      _customerInfo = await Purchases.restorePurchases();
      
      final premium = isPremium;
      _notifyPremiumStatus();
      
      if (premium) {
        _logger.i('✅ Compras restauradas exitosamente - Usuario es premium');
      } else {
        _logger.i('ℹ️ Restauración completada - No se encontraron suscripciones activas');
      }
      
      _logPremiumStatus();
      
      return premium;
      
    } on PlatformException catch (e) {
      _logger.e('❌ Error al restaurar compras', error: e);
      
      // Errores comunes
      if (e.code == 'NETWORK_ERROR') {
        throw Exception('No hay conexión a internet. Intenta nuevamente.');
      }
      
      return false;
      
    } catch (e) {
      _logger.e('❌ Error inesperado al restaurar compras', error: e);
      return false;
    }
  }
  
  // ========================================================================
  // OBTENER OFFERINGS (PLANES DE SUSCRIPCIÓN)
  // ========================================================================
  
  /// Obtiene los planes de suscripción disponibles configurados en RevenueCat
  /// 
  /// Retorna una lista de [Package] que contienen la información de cada plan
  /// (precio, duración, etc.)
  Future<List<Package>> getAvailablePackages() async {
    if (!_isInitialized) {
      _logger.w('⚠️ RevenueCat no inicializado. Llama a initialize() primero.');
      return [];
    }
    
    try {
      _logger.d('📦 Obteniendo planes de suscripción...');
      
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current != null && 
          offerings.current!.availablePackages.isNotEmpty) {
        
        final packages = offerings.current!.availablePackages;
        _logger.i('✅ Encontrados ${packages.length} planes disponibles');
        
        // Log de cada plan para debugging
        for (final package in packages) {
          _logger.d(
            '📦 Plan: ${package.identifier} - '
            '${package.storeProduct.priceString} / '
            '${package.storeProduct.subscriptionPeriod}'
          );
        }
        
        return packages;
        
      } else {
        _logger.w('⚠️ No hay offerings configurados en RevenueCat');
        return [];
      }
      
    } on PlatformException catch (e) {
      _logger.e('❌ Error al obtener planes de suscripción', error: e);
      return [];
      
    } catch (e) {
      _logger.e('❌ Error inesperado al obtener offerings', error: e);
      return [];
    }
  }
  
  // ========================================================================
  // REALIZAR COMPRA
  // ========================================================================
  
  /// Inicia el proceso de compra de un paquete de suscripción
  /// 
  /// [package] - El paquete a comprar (obtenido de getAvailablePackages)
  /// 
  /// Retorna `true` si la compra fue exitosa
  Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) {
      _logger.w('⚠️ RevenueCat no inicializado. Llama a initialize() primero.');
      return false;
    }
    
    try {
      _logger.i('💳 Iniciando compra de: ${package.identifier}');
      
      // En SDK 8.x, purchasePackage retorna CustomerInfo directamente
      final customerInfo = await Purchases.purchasePackage(package);
      
      _customerInfo = customerInfo;
      _notifyPremiumStatus();
      
      final success = isPremium;
      
      if (success) {
        _logger.i('✅ Compra exitosa - Usuario ahora es premium');
      } else {
        _logger.w('⚠️ Compra procesada pero usuario no es premium (puede estar pendiente)');
      }
      
      _logPremiumStatus();
      
      return success;
      
    } on PlatformException catch (e) {
      _logger.e('❌ Error durante la compra', error: e);
      
      // Errores específicos de compra
      if (e.code == 'PURCHASE_CANCELLED') {
        _logger.i('ℹ️ Usuario canceló la compra');
        throw Exception('Compra cancelada');
      } else if (e.code == 'PRODUCT_ALREADY_PURCHASED') {
        _logger.i('ℹ️ Usuario ya tiene este producto');
        // Sincronizar estado
        await checkPremiumStatus();
        throw Exception('Ya tienes una suscripción activa');
      } else if (e.code == 'NETWORK_ERROR') {
        throw Exception('Error de conexión. Verifica tu internet.');
      }
      
      return false;
      
    } catch (e) {
      _logger.e('❌ Error inesperado durante la compra', error: e);
      return false;
    }
  }
  
  // ========================================================================
  // UTILIDADES PRIVADAS
  // ========================================================================
  
  /// Notifica a los listeners sobre el cambio de estado premium
  void _notifyPremiumStatus() {
    if (_premiumStatusController.isClosed) return;
    _premiumStatusController.add(isPremium);
    
    // 🔄 SINCRONIZAR CON EL BACKEND
    // Como el webhook no funciona en localhost, sincronizamos manualmente
    _syncPremiumStatusToBackend();
  }
  
  /// Sincroniza el estado premium con el backend
  /// (Alternativa al webhook que no funciona en localhost)
  Future<void> _syncPremiumStatusToBackend() async {
    try {
      if (!isPremium || _currentUserId == null) return;
      
      _logger.i('🔄 Sincronizando estado premium con el backend...');
      
      // Usar el HttpClientService que ya está disponible globalmente
      // Importar: import 'package:get/get.dart';
      // import '../services/http_client_service.dart';
      
      try {
        // ✅ CAMBIO: Usar endpoint específico de RevenueCat que marca subscription_source='revenuecat'
        final response = await _makeHttpRequest(
          'POST',
          '/users/$_currentUserId/sync-revenuecat',
          body: {
            'expiresAt': premiumExpirationDate?.toIso8601String(),
          },
        );
        
        if (response != null) {
          _logger.i('✅ Estado premium sincronizado con backend (RevenueCat)');
        }
      } catch (e) {
        _logger.w('⚠️ Error en sincronización HTTP (no crítico)', error: e);
      }
      
    } catch (e) {
      _logger.w('⚠️ Error sincronizando con backend (no crítico)', error: e);
    }
  }
  
  /// Helper para hacer requests HTTP al backend usando el cliente global
  Future<Map<String, dynamic>?> _makeHttpRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final httpClient = HttpClientService();
      Response response;
      
      if (method == 'POST') {
        response = await httpClient.post(
          path,
          data: body,
        );
      } else if (method == 'GET') {
        response = await httpClient.get(
          path,
        );
      } else {
        throw UnsupportedError('Método HTTP no soportado: $method');
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data is Map<String, dynamic> 
            ? response.data as Map<String, dynamic>
            : {'data': response.data};
      }
      
      return null;
      
    } catch (e) {
      if (e is DioException) {
        _logger.w('⚠️ Error HTTP en sincronización: ${e.message} (${e.response?.statusCode})');
      } else {
        _logger.w('⚠️ Error inesperado en sincronización HTTP: $e');
      }
      return null;
    }
  }
  
  /// Log detallado del estado premium (solo en modo debug)
  void _logPremiumStatus() {
    if (!kDebugMode) return;
    
    _logger.d('═' * 40);
    _logger.d('📊 ESTADO DE SUSCRIPCIÓN');
    _logger.d('═' * 40);
    _logger.d('User ID: $_currentUserId');
    _logger.d('Is Premium: ${isPremium ? '✅' : '❌'}');
    
    if (isPremium) {
      _logger.d('Expires: ${premiumExpirationDate ?? 'N/A'}');
      _logger.d('Will Renew: ${willRenew ? '✅' : '❌'}');
      _logger.d('In Grace Period: ${isInGracePeriod ? '⚠️ SÍ' : 'No'}');
    }
    
    _logger.d('═' * 40);
  }
  
  // ========================================================================
  // LIMPIEZA
  // ========================================================================
  
  /// Limpia recursos cuando el usuario cierra sesión
  Future<void> logout() async {
    try {
      _logger.i('🚪 Cerrando sesión de RevenueCat...');
      
      // RevenueCat permite cambiar de usuario con logIn() o logOut()
      await Purchases.logOut();
      
      _customerInfo = null;
      _currentUserId = null;
      _isInitialized = false;
      
      _logger.i('✅ Sesión cerrada correctamente');
      
    } catch (e) {
      _logger.e('❌ Error al cerrar sesión de RevenueCat', error: e);
    }
  }
  
  /// Libera recursos (llamar al dispose() de tu app)
  void dispose() {
    _premiumStatusController.close();
  }
}
