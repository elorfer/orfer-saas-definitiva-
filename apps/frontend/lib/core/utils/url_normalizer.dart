import '../config/api_config.dart';
import 'logger.dart';

/// Utilidad centralizada para normalizar URLs de imágenes
/// Maneja conversión de localhost a 10.0.2.2 para emulador Android,
/// corrección de puertos, y construcción de URLs relativas
class UrlNormalizer {
  /// Normaliza una URL de imagen para que funcione correctamente en todas las plataformas
  /// 
  /// - Convierte localhost/127.0.0.1 a 10.0.2.2 para emulador Android
  /// - Corrige puerto 3000 a 3001
  /// - Corrige rutas /covers/ sin /uploads/ antes
  /// - Construye URLs completas desde rutas relativas
  static String? normalizeImageUrl(String? imageUrl, {bool enableLogging = false}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    // Si ya es una URL completa (http:// o https://), normalizarla para el emulador
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      String normalized = imageUrl;
      
      // Reemplazar localhost/127.0.0.1 por 10.0.2.2 para emulador Android
      if (normalized.contains('localhost') || normalized.contains('127.0.0.1')) {
        normalized = normalized.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
      }
      
      // Corregir puerto si viene con 3000 (debe ser 3001)
      normalized = normalized.replaceAll(':3000/', ':3001/').replaceAll(':3000"', ':3001"');
      
      // Corregir rutas que tienen /covers/ sin /uploads/ antes
      // Ejemplo: http://10.0.2.2:3001/covers/xxx.png -> http://10.0.2.2:3001/uploads/covers/xxx.png
      if (normalized.contains('://') && normalized.contains('/covers/') && !normalized.contains('/uploads/covers/')) {
        normalized = normalized.replaceAll('/covers/', '/uploads/covers/');
      }
      
      if (enableLogging) {
        AppLogger.refresh('[UrlNormalizer] URL normalizada: $imageUrl -> $normalized');
      }
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
      return finalUrl;
    }

    // Si es una ruta relativa sin /, agregar /uploads/covers/
    if (!imageUrl.startsWith('/')) {
      final finalUrl = '$cleanBaseUrl/uploads/covers/$imageUrl';
      if (enableLogging) {
        AppLogger.refresh('[UrlNormalizer] URL construida desde nombre de archivo: $imageUrl -> $finalUrl');
      }
      return finalUrl;
    }

    // Si ya tiene / al inicio pero no es /uploads, construir URL completa
    final finalUrl = '$cleanBaseUrl$imageUrl';
    if (enableLogging) {
      AppLogger.refresh('[UrlNormalizer] URL construida desde ruta absoluta: $imageUrl -> $finalUrl');
    }
    return finalUrl;
  }
}

