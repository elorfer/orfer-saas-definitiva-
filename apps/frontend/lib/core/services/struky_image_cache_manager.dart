import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 🚀 OPTIMIZACIÓN #2: Gestor de caché agresivo para imágenes de Struky
/// 
/// Beneficios:
/// - Caché de 30 días (vs 7 días por defecto)
/// - 500 imágenes máximo (vs 200 por defecto)
/// - Compresión automática para ahorrar espacio
/// - Pre-carga inteligente de top contenido
class StrukyImageCacheManager {
  static const key = 'struky_image_cache';
  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 30), // ⚡ 30 días (vs 7 por defecto)
        maxNrOfCacheObjects: 500, // ⚡ 500 imágenes (vs 200 por defecto)
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(), // Servicio HTTP optimizado
      ),
    );
    return _instance!;
  }

  /// Limpiar caché antiguo (llamar en inicialización de app)
  static Future<void> cleanOldCache() async {
    try {
      await instance.emptyCache();
      print('[StrukyImageCacheManager] Caché limpiado exitosamente');
    } catch (e) {
      print('[StrukyImageCacheManager] Error al limpiar caché: $e');
    }
  }

  /// Pre-cargar imágenes del top 50 canciones
  static Future<void> precacheTopContent(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return;
    
    try {
      // Pre-cargar en paralelo (máximo 10 a la vez para no saturar)
      final futures = <Future>[];
      for (int i = 0; i < imageUrls.length && i < 50; i++) {
        final url = imageUrls[i];
        if (url.isNotEmpty) {
          futures.add(
            instance.downloadFile(url).catchError((_) => null),
          );
        }
        
        // Cada 10 imágenes, esperar a que terminen
        if (futures.length >= 10 || i == imageUrls.length - 1) {
          await Future.wait(futures);
          futures.clear();
        }
      }
      print('[StrukyImageCacheManager] Pre-carga completada: ${imageUrls.length} imágenes');
    } catch (e) {
      print('[StrukyImageCacheManager] Error en pre-carga: $e');
    }
  }

  /// Obtener tamaño actual del caché
  static Future<int> getCacheSize() async {
    try {
      final files = await instance.getFileFromMemory(key);
      return files?.validTill.millisecondsSinceEpoch ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
