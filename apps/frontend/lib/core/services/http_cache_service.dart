import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path_lib;

/// Servicio para configurar caché HTTP con Dio
class HttpCacheService {
  static CacheOptions? _cacheOptions;
  static HiveCacheStore? _cacheStore;

  /// Inicializar caché HTTP
  static Future<void> initialize() async {
    try {
      // Obtener directorio de caché
      final cacheDir = await getTemporaryDirectory();
      final cachePath = path_lib.join(cacheDir.path, 'http_cache');

      // Inicializar Hive para caché si no está inicializado
      if (!Hive.isAdapterRegistered(1)) {
        Hive.init(cachePath);
      }

      // Crear store de caché con Hive
      _cacheStore = HiveCacheStore(cachePath);

      // Configurar opciones de caché
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
    } catch (e) {
      // Si falla, continuar sin caché
      _cacheOptions = null;
      _cacheStore = null;
    }
  }

  /// Obtener opciones de caché
  static CacheOptions? get cacheOptions => _cacheOptions;

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

/// CacheManager personalizado para imágenes
class ImageCacheManager {
  static final CacheManager _instance = CacheManager(
    Config(
      'image_cache',
      stalePeriod: const Duration(days: 30), // Imágenes válidas por 30 días
      maxNrOfCacheObjects: 500, // Máximo 500 imágenes en caché
      repo: JsonCacheInfoRepository(databaseName: 'image_cache'),
      fileService: HttpFileService(),
    ),
  );

  static CacheManager get instance => _instance;

  /// Precachear imagen
  static Future<void> precache(String url) async {
    try {
      await _instance.getSingleFile(url);
    } catch (e) {
      // Ignorar errores de precache
    }
  }
}
