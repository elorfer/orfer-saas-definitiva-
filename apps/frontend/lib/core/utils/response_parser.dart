import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// Utilidad centralizada para parsear respuestas HTTP de forma consistente
/// Elimina duplicación de código en múltiples servicios
class ResponseParser {
  /// Extraer lista de datos de una respuesta HTTP
  /// Maneja diferentes formatos de respuesta:
  /// - Lista directa: [data]
  /// - Objeto con lista: { "items": [data] } o { "data": [data] }
  /// - Objeto con clave específica: { "songs": [data] }, { "artists": [data] }, etc.
  static List<dynamic> extractList(
    Response response, {
    String? listKey,
    bool logErrors = true,
  }) {
    if (response.statusCode != 200 || response.data == null) {
      return [];
    }

    final data = response.data;

    // Si ya es una lista, retornarla directamente
    if (data is List) {
      return data;
    }

    // Si es un Map, buscar la lista dentro
    if (data is Map<String, dynamic>) {
      // Si se especificó una clave, usarla
      if (listKey != null && data.containsKey(listKey)) {
        final list = data[listKey];
        if (list is List) {
          return list;
        }
        return [];
      }

      // Intentar encontrar la lista en claves comunes
      final commonKeys = ['items', 'data', 'songs', 'artists', 'playlists', 'users'];
      for (final key in commonKeys) {
        if (data.containsKey(key) && data[key] is List) {
          return data[key] as List;
        }
      }
    }

    return [];
  }

  /// Extraer objeto único de una respuesta HTTP
  /// Maneja diferentes formatos de respuesta:
  /// - Objeto directo: { data }
  /// - Objeto envuelto: { "data": { data } } o { "item": { data } }
  static Map<String, dynamic>? extractObject(
    Response response, {
    String? objectKey,
    bool logErrors = true,
  }) {
    if (response.statusCode != 200 || response.data == null) {
      return null;
    }

    final data = response.data;

    // Si ya es un Map, retornarlo directamente
    if (data is Map<String, dynamic>) {
      // Si se especificó una clave, buscar dentro
      if (objectKey != null && data.containsKey(objectKey)) {
        final obj = data[objectKey];
        if (obj is Map<String, dynamic>) {
          return obj;
        }
        return null;
      }

      // Intentar encontrar el objeto en claves comunes
      final commonKeys = ['data', 'item', 'user', 'artist', 'song', 'playlist'];
      for (final key in commonKeys) {
        if (data.containsKey(key) && data[key] is Map<String, dynamic>) {
          return data[key] as Map<String, dynamic>;
        }
      }

      // Si no se encontró en claves comunes, retornar el objeto completo
      return data;
    }

    return null;
  }

  /// Validar y filtrar lista de datos
  /// Elimina elementos nulos o inválidos
  static List<Map<String, dynamic>> validateList(
    List<dynamic> data, {
    bool logErrors = true,
  }) {
    return data
        .where((item) => item != null && item is Map<String, dynamic>)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Parsear lista de objetos con manejo de errores individual
  /// Retorna solo los objetos que se pudieron parsear correctamente
  static List<T> parseList<T>({
    required List<dynamic> data,
    required T Function(Map<String, dynamic>) parser,
    bool logErrors = true,
  }) {
    final result = <T>[];
    
    for (var i = 0; i < data.length; i++) {
      try {
        final item = data[i];
        if (item is! Map<String, dynamic>) {
          continue;
        }
        
        final parsed = parser(item);
        result.add(parsed);
      } catch (e, stackTrace) {
        if (logErrors) {
          AppLogger.error('[ResponseParser] Error al parsear item $i: $e', e, stackTrace);
        }
        // Continuar con el siguiente item
      }
    }
    
    return result;
  }

  /// Verificar si la respuesta es exitosa
  static bool isSuccess(Response response) {
    return response.statusCode != null && 
           response.statusCode! >= 200 && 
           response.statusCode! < 300;
  }

  /// Extraer mensaje de error de una respuesta
  static String? extractErrorMessage(Response? response) {
    if (response == null) {
      return 'Sin respuesta del servidor';
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      // Intentar encontrar mensaje de error en diferentes formatos
      return data['message'] as String? ?? 
             data['error'] as String? ?? 
             data['errorMessage'] as String? ??
             data['error_message'] as String?;
    }

    return 'Error ${response.statusCode}';
  }

  /// Extraer código de error de una respuesta
  static String? extractErrorCode(Response? response) {
    if (response == null) {
      return null;
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data['code'] as String? ?? 
             data['errorCode'] as String? ??
             data['error_code'] as String?;
    }

    return response.statusCode?.toString();
  }
}



