import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/platform_utils.dart';

/// Servicio para configurar caché HTTP con Dio
class HttpCacheService {
  static CacheOptions? _cacheOptions;
  static HiveCacheStore? _cacheStore;
  static bool _isInitialized = false;
  static Future<void>? _initializationFuture;

  /// Inicializar caché HTTP (lazy - solo cuando se necesite)
  static Future<void> initialize() async {
    // Si ya está inicializado, retornar inmediatamente
    if (_isInitialized) return;
    
    // Si hay una inicialización en curso, esperar a que termine
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }
    
    // Iniciar nueva inicialización
    _initializationFuture = _doInitialize();
    await _initializationFuture;
  }
  
  /// Inicialización real del caché
  static Future<void> _doInitialize() async {
    try {
      // Obtener directorio de caché
      final cacheDir = await getTemporaryDirectory();
      final cachePath = '${cacheDir.path}${PlatformUtils.pathSeparator}http_cache';

      // Inicializar Hive para caché si no está inicializado
      if (!Hive.isAdapterRegistered(1)) {
        Hive.init(cachePath);
      }

      // Crear store de caché con Hive
      _cacheStore = HiveCacheStore(cachePath);

      // ✅ OPTIMIZACIÓN: Configurar opciones de caché optimizadas
      // HiveCacheStore extiende CacheStore de dio_cache_interceptor
      _cacheOptions = CacheOptions(
        store: _cacheStore! as CacheStore,
        policy: CachePolicy.request, // Usar caché cuando esté disponible
        hitCacheOnErrorExcept: [401, 403], // Usar caché en errores excepto auth
        maxStale: const Duration(days: 7), // Caché válido por 7 días
        priority: CachePriority.normal,
        cipher: null, // Sin cifrado por ahora
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        allowPostMethod: false, // Solo caché para GET
      );
      _isInitialized = true;
    } catch (e) {
      // Si falla, continuar sin caché
      _cacheOptions = null;
      _cacheStore = null;
      _isInitialized = false;
    } finally {
      _initializationFuture = null;
    }
  }
  
  /// Asegurar que el caché esté inicializado (lazy initialization)
  static Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Obtener opciones de caché (inicializa si es necesario)
  static CacheOptions? get cacheOptions {
    // Lazy initialization: si no está inicializado, inicializar en background
    if (!_isInitialized && _initializationFuture == null) {
      initialize(); // No await - inicializar en background
    }
    return _cacheOptions;
  }

  /// Limpiar caché
  static Future<void> clearCache() async {
    try {
      await _cacheStore?.clean();
    } catch (e) {
      // Ignorar errores al limpiar caché
    }
  }

  /// Limpiar caché expirado
  static Future<void> clearExpiredCache() async {
    try {
      // HiveCacheStore.clean() limpia automáticamente entradas expiradas
      await _cacheStore?.clean();
    } catch (e) {
      // Ignorar errores al limpiar caché expirado
    }
  }
}

/// CacheManager personalizado para imágenes de carátulas de álbumes
/// Configurado para persistir en disco incluso después de reiniciar la app
class AlbumArtCacheManager {
  static CacheManager? _instance;
  static bool _isInitialized = false;
  
  /// Inicializa el cache manager con configuración optimizada para persistencia
  static Future<void> ensureInitialized() async {
    if (_isInitialized && _instance != null) return;
    
    try {
      _instance = CacheManager(
        Config(
          'album_covers_cache', // Clave única para carátulas
          stalePeriod: const Duration(days: 90), // ✅ Carátulas válidas por 90 días (3 meses)
          maxNrOfCacheObjects: 1000, // ✅ Máximo 1000 carátulas en caché
          repo: JsonCacheInfoRepository(databaseName: 'album_covers_cache_db'),
          fileService: HttpFileService(),
        ),
      );
      _isInitialized = true;
    } catch (e) {
      // Fallback a configuración básica si falla
      _instance = CacheManager(
        Config(
          'album_covers_cache',
          stalePeriod: const Duration(days: 90),
          maxNrOfCacheObjects: 1000,
        ),
      );
      _isInitialized = true;
    }
  }

  static CacheManager get instance {
    if (_instance == null) {
      // Inicializar síncronamente con configuración por defecto
      _instance = CacheManager(
        Config(
          'album_covers_cache',
          stalePeriod: const Duration(days: 90),
          maxNrOfCacheObjects: 1000,
          repo: JsonCacheInfoRepository(databaseName: 'album_covers_cache_db'),
          fileService: HttpFileService(),
        ),
      );
      _isInitialized = true;
    }
    return _instance!;
  }

  /// Precachear imagen de carátula
  static Future<void> precache(String url) async {
    try {
      await instance.getSingleFile(url);
    } catch (e) {
      // Ignorar errores de precache
    }
  }
  
  /// Verificar si una imagen está en caché
  static Future<bool> isInCache(String url) async {
    try {
      final fileInfo = await instance.getFileFromCache(url);
      return fileInfo != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Obtener imagen del caché (null si no existe)
  static Future<FileInfo?> getFromCache(String url) async {
    try {
      return await instance.getFileFromCache(url);
    } catch (e) {
      return null;
    }
  }
  
  /// Limpiar caché de imágenes antiguas
  static Future<void> clearOldCache() async {
    try {
      await instance.emptyCache();
    } catch (e) {
      // Ignorar errores
    }
  }
}
