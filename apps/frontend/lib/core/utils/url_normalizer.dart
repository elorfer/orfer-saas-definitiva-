import '../config/api_config.dart';
import 'logger.dart';

/// Utilidad centralizada para normalizar URLs de imágenes
/// Maneja conversión de localhost a 10.0.2.2 para emulador Android,
/// corrección de puertos, y construcción de URLs relativas
class UrlNormalizer {
  // OPTIMIZACIÓN: Cache simple para URLs normalizadas (evita recalcular en cada build)
  static final Map<String, String> _urlCache = {};
  static const int _maxCacheSize = 100; // Limitar tamaño del cache

  /// Normaliza una URL de imagen para que funcione correctamente en todas las plataformas
  /// 
  /// - Convierte localhost/127.0.0.1 a 10.0.2.2 para emulador Android
  /// - Corrige puerto 3000 a 3001
  /// - Corrige rutas /covers/ sin /uploads/ antes
  /// - Construye URLs completas desde rutas relativas
  /// - OPTIMIZACIÓN: Usa cache para evitar recalcular URLs ya normalizadas
  static String? normalizeImageUrl(String? imageUrl, {bool enableLogging = false}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    // OPTIMIZACIÓN: Verificar cache primero
    final cached = _urlCache[imageUrl];
    if (cached != null) {
      return cached;
    }

    // Si ya es una URL completa, usar la lógica centralizada
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      String normalized = _applyBaseNormalization(imageUrl);
      
      // Corregir rutas específicas de imágenes
      if (normalized.contains('/covers/') && !normalized.contains('/uploads/covers/')) {
        normalized = normalized.replaceAll('/covers/', '/uploads/covers/');
      }
      
      if (enableLogging) {
        AppLogger.refresh('[UrlNormalizer] URL de imagen normalizada: $imageUrl -> $normalized');
      }
      
      // OPTIMIZACIÓN: Guardar en cache y limpiar si es necesario
      _addToCache(imageUrl, normalized);
      return normalized;
    }

    // Extraer el dominio base de ApiConfig
    final baseUrl = ApiConfig.baseUrl;
    String cleanBaseUrl = baseUrl.replaceAll('/api/v1', '').replaceAll(RegExp(r'/$'), '');
    
    // Asegurar que use 10.0.2.2 en lugar de localhost para emulador
    if (cleanBaseUrl.contains('localhost') || cleanBaseUrl.contains('127.0.0.1')) {
      cleanBaseUrl = cleanBaseUrl.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
    }

    // Si es una ruta relativa que empieza con /uploads, construir URL completa
    if (imageUrl.startsWith('/uploads/')) {
      final finalUrl = '$cleanBaseUrl$imageUrl';
      if (enableLogging) {
        AppLogger.refresh('[UrlNormalizer] URL construida desde ruta relativa: $imageUrl -> $finalUrl');
      }
      
      // OPTIMIZACIÓN: Guardar en cache
      _addToCache(imageUrl, finalUrl);
      return finalUrl;
    }

    // Si es una ruta relativa sin /, agregar /uploads/covers/
    if (!imageUrl.startsWith('/')) {
      final finalUrl = '$cleanBaseUrl/uploads/covers/$imageUrl';
      if (enableLogging) {
        AppLogger.refresh('[UrlNormalizer] URL construida desde nombre de archivo: $imageUrl -> $finalUrl');
      }
      
      // OPTIMIZACIÓN: Guardar en cache
      _addToCache(imageUrl, finalUrl);
      return finalUrl;
    }

    // Si ya tiene / al inicio pero no es /uploads, construir URL completa
    final finalUrl = '$cleanBaseUrl$imageUrl';
      if (enableLogging) {
        AppLogger.refresh('[UrlNormalizer] URL construida desde ruta absoluta: $imageUrl -> $finalUrl');
      }
      
      // OPTIMIZACIÓN: Guardar en cache
      _addToCache(imageUrl, finalUrl);
      return finalUrl;
  }

  /// Normaliza una URL de archivo (audio, video, etc.) para que funcione correctamente en todas las plataformas
  /// Similar a normalizeImageUrl pero para URLs de archivos
  /// Valida que la URL sea válida y la construye correctamente
  static String normalizeUrl(String url, {bool enableLogging = true}) {
    if (url.isEmpty) {
      throw Exception('[UrlNormalizer] URL vacía o nula');
    }

    // Validar formato básico de URL
    if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('/') && !url.startsWith('./')) {
      // Intentar construir desde ApiConfig si parece ser una ruta relativa
      AppLogger.info('[UrlNormalizer] URL no parece ser absoluta ni relativa: $url');
    }

    // Si ya es una URL completa (http:// o https://), normalizarla para el emulador
    if (url.startsWith('http://') || url.startsWith('https://')) {
      String normalized = _applyBaseNormalization(url);
      
      // CORREGIR RUTA: Si la URL tiene /songs/ pero debería ser /uploads/songs/
      if (normalized.contains('/songs/') && !normalized.contains('/uploads/songs/')) {
        normalized = normalized.replaceAll('/songs/', '/uploads/songs/');
        if (enableLogging) {
          AppLogger.refresh('[UrlNormalizer] Ruta corregida (/songs/ -> /uploads/songs/): $normalized');
        }
      }
      
      // Validar que la URL sea válida
      try {
        final uri = Uri.parse(normalized);
        if (uri.host.isEmpty) {
          throw Exception('[UrlNormalizer] URL sin host válido: $normalized');
        }
        if (enableLogging) {
          AppLogger.info('[UrlNormalizer] URL absoluta validada: $normalized');
        }
        return normalized;
      } catch (e) {
        AppLogger.error('[UrlNormalizer] Error al parsear URL: $normalized - $e');
        rethrow;
      }
    }

    // Si es una ruta relativa, construir URL completa usando ApiConfig
    final baseUrl = ApiConfig.baseUrl;
    String cleanBaseUrl = baseUrl.replaceAll('/api/v1', '').replaceAll(RegExp(r'/$'), '');
    
    // Asegurar que use 10.0.2.2 en lugar de localhost para emulador
    if (cleanBaseUrl.contains('localhost') || cleanBaseUrl.contains('127.0.0.1')) {
      cleanBaseUrl = cleanBaseUrl.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
    }

    // Construir URL completa
    String finalUrl;
    if (url.startsWith('/')) {
      finalUrl = '$cleanBaseUrl$url';
    } else if (url.startsWith('./')) {
      // Quitar ./ si existe
      finalUrl = '$cleanBaseUrl/${url.substring(2)}';
    } else {
      finalUrl = '$cleanBaseUrl/$url';
    }
    
    if (enableLogging) {
      AppLogger.refresh('[UrlNormalizer] URL construida desde ruta relativa: $url -> $finalUrl');
    }
    
    // Validar URL final
    try {
      final uri = Uri.parse(finalUrl);
      if (uri.host.isEmpty) {
        throw Exception('[UrlNormalizer] URL construida sin host válido: $finalUrl');
      }
      return finalUrl;
    } catch (e) {
      AppLogger.error('[UrlNormalizer] Error al validar URL construida: $finalUrl - $e');
      rethrow;
    }
  }
  
  /// Método centralizado para aplicar normalizaciones básicas de URL
  /// Evita duplicación de código entre normalizeUrl y normalizeImageUrl
  static String _applyBaseNormalization(String url) {
    String normalized = url;
    
    // Reemplazar localhost/127.0.0.1 por 10.0.2.2 para emulador Android
    if (normalized.contains('localhost') || normalized.contains('127.0.0.1')) {
      normalized = normalized.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
    }
    
    // Corregir puerto si viene con 3000 (debe ser 3001)
    if (normalized.contains(':3000/') || normalized.endsWith(':3000')) {
      normalized = normalized.replaceAll(':3000/', ':3001/').replaceAll(':3000', ':3001');
    }
    
    return normalized;
  }

  /// Agrega una URL al cache y limpia entradas antiguas si es necesario
  static void _addToCache(String original, String normalized) {
    // Limpiar cache si excede el tamaño máximo (FIFO simple)
    if (_urlCache.length >= _maxCacheSize) {
      final firstKey = _urlCache.keys.first;
      _urlCache.remove(firstKey);
    }
    _urlCache[original] = normalized;
  }

  /// Limpia el cache de URLs (útil para testing o cuando cambia la configuración)
  static void clearCache() {
    _urlCache.clear();
  }
}

