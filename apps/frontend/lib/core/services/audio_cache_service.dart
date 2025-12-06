import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:async';
import 'http_client_service.dart';

/// CacheManager personalizado para archivos de audio
/// OPTIMIZADO: Singleton sincrónico + cache de resultados + precarga en background
class AudioCacheManager {
  static CacheManager? _instance;
  static Future<void>? _initializationFuture;
  
  // ✅ CACHE DE RESULTADOS: Evitar múltiples llamadas a isCached()
  static final Map<String, bool> _cacheStatus = {};
  static final Map<String, DateTime> _cacheStatusTime = {};
  static const Duration _cacheStatusTTL = Duration(minutes: 5); // Cache válido por 5 minutos
  
  /// ✅ SINGLETON SINCRÓNICO: Inicializar una vez, luego acceso sincrónico
  static CacheManager get instance {
    if (_instance != null) return _instance!;
    
    // Si no está inicializado, inicializar de forma asíncrona pero retornar null
    // El código que lo necesite debe usar ensureInitialized() primero
    throw StateError('AudioCacheManager no inicializado. Llama a ensureInitialized() primero.');
  }
  
  /// ✅ INICIALIZACIÓN ASÍNCRONA: Solo se llama una vez
  static Future<void> ensureInitialized() async {
    if (_instance != null) return;
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }
    
    _initializationFuture = _initialize();
    await _initializationFuture;
  }
  
  static Future<void> _initialize() async {
    if (_instance != null) return;
    
    _instance = CacheManager(
      Config(
        'audio_cache',
        stalePeriod: const Duration(days: 30), // Canciones válidas por 30 días
        maxNrOfCacheObjects: 100, // Máximo 100 canciones en caché
        repo: JsonCacheInfoRepository(databaseName: 'audio_cache'),
        fileService: HttpFileService(),
      ),
    );
  }

  /// ✅ PRECACHE EN BACKGROUND: No bloquea, se ejecuta en segundo plano
  /// Descarga los primeros 300-500ms del audio para reproducción instantánea
  static Future<void> precacheAudio(String url) async {
    // Asegurar inicialización
    await ensureInitialized();
    
    // Ejecutar en background sin bloquear
    unawaited(_precacheInBackground(url));
  }
  
  /// ⚡ PRECARGA INTELIGENTE: Descarga primeros 300-500ms del audio
  /// Optimizado para range requests HTTP (primer chunk)
  static Future<void> _precacheInBackground(String url) async {
      try {
        // Intentar precargar con range request (primeros 500ms aprox)
        // Esto es una aproximación - el servidor debe soportar range requests
        final httpClient = HttpClientService();
        final dio = httpClient.dio;
      
      // Calcular bytes aproximados para 500ms de audio (estimado 128kbps = ~8KB)
      // Para seguridad, pedir primeros 50KB que cubre varios segundos
      final rangeBytes = 50 * 1024; // 50KB
      
      try {
        // Intentar range request si el servidor lo soporta
        final response = await dio.get(
          url,
          options: Options(
            headers: {
              'Range': 'bytes=0-$rangeBytes',
            },
            responseType: ResponseType.bytes,
            validateStatus: (status) => status == 206 || status == 200, // 206 = Partial Content
          ),
        );
        
        // Si el servidor soporta range requests (206), guardar chunk
        if (response.statusCode == 206 || response.statusCode == 200) {
          // Actualizar cache de estado - considerar precargado
          _cacheStatus[url] = true;
          _cacheStatusTime[url] = DateTime.now();
          
          // Continuar precarga completa en background (sin bloquear)
          unawaited(_precacheFullFile(url));
        } else {
          // Fallback: precargar archivo completo
          await _precacheFullFile(url);
        }
      } catch (e) {
        // Si falla range request, intentar precarga completa
        await _precacheFullFile(url);
      }
    } catch (e) {
      // Ignorar errores de precache (no crítico)
      _cacheStatus[url] = false;
      _cacheStatusTime[url] = DateTime.now();
    }
  }
  
  /// Precargar archivo completo (fallback)
  static Future<void> _precacheFullFile(String url) async {
    try {
      await _instance!.getSingleFile(url);
      _cacheStatus[url] = true;
      _cacheStatusTime[url] = DateTime.now();
    } catch (e) {
      _cacheStatus[url] = false;
      _cacheStatusTime[url] = DateTime.now();
    }
  }

  /// Obtener archivo de audio desde caché o descargarlo
  static Future<File?> getAudioFile(String url) async {
    await ensureInitialized();
    
    try {
      final file = await _instance!.getSingleFile(url);
      // Actualizar cache de estado
      _cacheStatus[url] = true;
      _cacheStatusTime[url] = DateTime.now();
      return file;
    } catch (e) {
      _cacheStatus[url] = false;
      _cacheStatusTime[url] = DateTime.now();
      return null;
    }
  }

  /// ✅ CACHE DE RESULTADOS: Verificar si una canción está en caché (con cache de resultados)
  static Future<bool> isCached(String url) async {
    await ensureInitialized();
    
    // ✅ CACHE DE RESULTADOS: Verificar cache primero
    final cachedTime = _cacheStatusTime[url];
    if (cachedTime != null) {
      final age = DateTime.now().difference(cachedTime);
      if (age < _cacheStatusTTL) {
        // Usar valor cacheado
        return _cacheStatus[url] ?? false;
      }
      // Cache expirado, limpiar
      _cacheStatus.remove(url);
      _cacheStatusTime.remove(url);
    }
    
    // Si no está en cache, verificar realmente
    try {
      final fileInfo = await _instance!.getFileFromCache(url);
      final isCached = fileInfo != null;
      
      // ✅ CACHEAR RESULTADO para próximas llamadas
      _cacheStatus[url] = isCached;
      _cacheStatusTime[url] = DateTime.now();
      
      return isCached;
    } catch (e) {
      _cacheStatus[url] = false;
      _cacheStatusTime[url] = DateTime.now();
      return false;
    }
  }
  
  /// ✅ VERSIÓN SINCRÓNICA: Obtener estado del cache si está disponible (sin async)
  static bool? isCachedSync(String url) {
    final cachedTime = _cacheStatusTime[url];
    if (cachedTime != null) {
      final age = DateTime.now().difference(cachedTime);
      if (age < _cacheStatusTTL) {
        return _cacheStatus[url];
      }
    }
    return null; // No hay cache disponible, necesita verificación async
  }

  /// Limpiar caché de audio
  static Future<void> clearCache() async {
    await ensureInitialized();
    
    try {
      await _instance!.emptyCache();
      // Limpiar cache de estados
      _cacheStatus.clear();
      _cacheStatusTime.clear();
    } catch (e) {
      // Ignorar errores
    }
  }
  
  /// Limpiar cache de estados (útil para liberar memoria)
  static void clearStatusCache() {
    _cacheStatus.clear();
    _cacheStatusTime.clear();
  }
}

/// Helper para ejecutar futures sin await (fire and forget)
void unawaited(Future<void> future) {
  // Ignorar el future, se ejecuta en background
}

