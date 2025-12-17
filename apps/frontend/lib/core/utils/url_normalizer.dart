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

    // ✅ FIX: Limpiar duplicaciones ANTES de verificar cache
    // Esto asegura que URLs duplicadas no se guarden en cache
    String cleanUrl = imageUrl;
    if (cleanUrl.contains('/uploads/uploads/')) {
      cleanUrl = cleanUrl.replaceAll('/uploads/uploads/', '/uploads/');
    }

    // OPTIMIZACIÓN: Verificar cache con URL limpia
    final cached = _urlCache[cleanUrl];
    if (cached != null) {
      // Verificar que el cache no tenga duplicaciones
      if (cached.contains('/uploads/uploads/')) {
        // Cache corrupto, limpiarlo y recalcular
        _urlCache.remove(cleanUrl);
      } else {
        return cached;
      }
    }

    // Si ya es una URL completa, usar la lógica centralizada
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      String normalized = _applyBaseNormalization(cleanUrl);
      
      // ✅ FIX: Corregir duplicaciones de forma exhaustiva
      // Reemplazar todas las ocurrencias de /uploads/uploads/ por /uploads/
      while (normalized.contains('/uploads/uploads/')) {
        normalized = normalized.replaceAll('/uploads/uploads/', '/uploads/');
      }
      
      // ✅ FIX: Solo agregar /uploads/ si NO está presente antes de /covers/
      final coversIndex = normalized.indexOf('/covers/');
      if (coversIndex != -1) {
        // Verificar si hay /uploads/ antes de /covers/
        final beforeCovers = normalized.substring(0, coversIndex);
        
        // Verificar si ya tiene /uploads/ antes de /covers/
        if (!beforeCovers.contains('/uploads/')) {
          // No hay /uploads/ antes, agregar /uploads/ antes de /covers/
          normalized = normalized.replaceFirst('/covers/', '/uploads/covers/');
        }
        // Si ya tiene /uploads/ antes, no hacer nada
      }
      
      // ✅ FIX: Verificación final - asegurar que no haya duplicaciones
      if (normalized.contains('/uploads/uploads/')) {
        normalized = normalized.replaceAll('/uploads/uploads/', '/uploads/');
      }
      
      if (enableLogging) {
        AppLogger.refresh('[UrlNormalizer] URL de imagen normalizada: $imageUrl -> $normalized');
      }
      
      // OPTIMIZACIÓN: Guardar en cache y limpiar si es necesario
      _addToCache(cleanUrl, normalized);
      return normalized;
    }

    // Extraer el dominio base de ApiConfig
    final baseUrl = ApiConfig.baseUrl;
    String cleanBaseUrl = baseUrl.replaceAll('/api/v1', '').replaceAll(RegExp(r'/$'), '');
    
    // Solo convertir localhost a 10.0.2.2 si la URL base también es localhost
    // Si la URL base ya tiene una IP de red, mantenerla
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
  static String normalizeUrl(String url, {bool enableLogging = false}) {
    if (url.isEmpty) {
      throw Exception('[UrlNormalizer] URL vacía o nula');
    }

    // Validar formato básico de URL (sin logs verbosos)

    // Si ya es una URL completa (http:// o https://), normalizarla para el emulador
    if (url.startsWith('http://') || url.startsWith('https://')) {
      String normalized = _applyBaseNormalization(url);
      
      // CORREGIR RUTA: Si la URL tiene /songs/ pero debería ser /uploads/songs/
      if (normalized.contains('/songs/') && !normalized.contains('/uploads/songs/')) {
        normalized = normalized.replaceAll('/songs/', '/uploads/songs/');
      }
      
      // Validar que la URL sea válida
      try {
        final uri = Uri.parse(normalized);
        if (uri.host.isEmpty) {
          throw Exception('[UrlNormalizer] URL sin host válido: $normalized');
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
    
    // Solo convertir localhost a 10.0.2.2 si la URL base también es localhost
    // Si la URL base ya tiene una IP de red, mantenerla
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
    
    // Sin logs verbosos - solo errores
    
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
    final baseUrl = ApiConfig.baseUrl;
    final cleanBaseUrl = baseUrl.replaceAll('/api/v1', '').replaceAll(RegExp(r'/$'), '');
    
    // Solo convertir localhost a 10.0.2.2 si la URL base también es localhost
    // Si la URL base ya tiene una IP de red, mantenerla
    if (cleanBaseUrl.contains('localhost') || cleanBaseUrl.contains('127.0.0.1')) {
      // Solo convertir si la URL también contiene localhost
      if (normalized.contains('localhost') || normalized.contains('127.0.0.1')) {
        normalized = normalized.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
      }
    } else if (cleanBaseUrl.contains('192.168.')) {
      // Si la baseUrl tiene una IP de red local, reemplazar localhost con esa IP
      final ipMatch = RegExp(r'192\.168\.\d+\.\d+').firstMatch(cleanBaseUrl);
      if (ipMatch != null && (normalized.contains('localhost') || normalized.contains('127.0.0.1'))) {
        final ip = ipMatch.group(0);
        normalized = normalized.replaceAll('localhost', ip!).replaceAll('127.0.0.1', ip);
      }
    }
    
    // Corregir puerto si viene con 3000 (debe ser 3001)
    if (normalized.contains(':3000/') || normalized.endsWith(':3000')) {
      normalized = normalized.replaceAll(':3000/', ':3001/').replaceAll(':3000', ':3001');
    }
    
    return normalized;
  }

  /// Agrega una URL al cache y limpia entradas antiguas si es necesario
  static void _addToCache(String original, String normalized) {
    // ✅ FIX: Verificar que la URL normalizada no tenga duplicaciones antes de cachear
    String finalNormalized = normalized;
    
    // Limpiar duplicaciones de forma exhaustiva
    while (finalNormalized.contains('/uploads/uploads/')) {
      finalNormalized = finalNormalized.replaceAll('/uploads/uploads/', '/uploads/');
    }
    
    // Limpiar cache si excede el tamaño máximo (FIFO simple)
    if (_urlCache.length >= _maxCacheSize) {
      final firstKey = _urlCache.keys.first;
      _urlCache.remove(firstKey);
    }
    
    // Solo guardar si no tiene duplicaciones
    if (!finalNormalized.contains('/uploads/uploads/')) {
      _urlCache[original] = finalNormalized;
    }
  }

  /// Limpia el cache de URLs (útil para testing o cuando cambia la configuración)
  static void clearCache() {
    _urlCache.clear();
  }
  
  /// Limpia URLs duplicadas del cache (útil para corregir cache corrupto)
  static void cleanDuplicateUrlsFromCache() {
    final keysToRemove = <String>[];
    _urlCache.forEach((key, value) {
      if (value.contains('/uploads/uploads/')) {
        keysToRemove.add(key);
      }
    });
    for (final key in keysToRemove) {
      _urlCache.remove(key);
    }
  }
}

