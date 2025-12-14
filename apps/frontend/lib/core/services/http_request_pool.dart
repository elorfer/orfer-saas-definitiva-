import 'dart:async';
import '../utils/logger.dart';

/// 🚀 SPOTIFY-LEVEL: POOL DE REQUESTS HTTP
/// Evita requests duplicados y reutiliza requests pendientes
class HttpRequestPool {
  static final HttpRequestPool _instance = HttpRequestPool._internal();
  factory HttpRequestPool() => _instance;
  HttpRequestPool._internal();

  // Pool de requests pendientes por URL
  final Map<String, Future<dynamic>> _pendingRequests = {};

  // Cache de resultados (para requests idénticos dentro de 1 segundo)
  final Map<String, _CachedResult> _resultCache = {};
  static const int _resultCacheTtlMs = 1000; // 1 segundo

  /// Ejecutar request con pooling (evita duplicados)
  Future<T> executeRequest<T>({
    required String key,
    required Future<T> Function() requestFn,
    bool useCache = true,
  }) async {
    // 1. Verificar si hay un request pendiente para esta key
    if (_pendingRequests.containsKey(key)) {
      AppLogger.debug('[HttpRequestPool] ⏳ Reutilizando request pendiente: $key');
      try {
        final result = await _pendingRequests[key] as Future<T>;
        return result;
      } catch (e) {
        // Si el request pendiente falló, continuar con uno nuevo
        _pendingRequests.remove(key);
        AppLogger.debug('[HttpRequestPool] ⚠️ Request pendiente falló, creando nuevo: $key');
      }
    }

    // 2. Verificar cache de resultados (para requests muy cercanos en el tiempo)
    if (useCache) {
      final cached = _resultCache[key];
      if (cached != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cached.timestamp;
        if (age < _resultCacheTtlMs) {
          AppLogger.debug('[HttpRequestPool] ⚡ Cache hit: $key');
          return cached.result as T;
        } else {
          _resultCache.remove(key);
        }
      }
    }

    // 3. Crear nuevo request
    final requestFuture = requestFn();
    _pendingRequests[key] = requestFuture;

    try {
      final result = await requestFuture;
      
      // Guardar en cache de resultados
      if (useCache) {
        _resultCache[key] = _CachedResult(
          result: result,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
      }

      return result;
    } catch (e) {
      rethrow;
    } finally {
      // Limpiar request pendiente
      _pendingRequests.remove(key);
    }
  }

  /// Limpiar cache de resultados antiguos
  void cleanOldCache() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _resultCache.removeWhere((key, value) => 
      now - value.timestamp > _resultCacheTtlMs
    );
  }

  /// Limpiar todo
  void clear() {
    _pendingRequests.clear();
    _resultCache.clear();
    AppLogger.debug('[HttpRequestPool] 🧹 Pool limpiado');
  }

  /// Obtener estadísticas
  Map<String, dynamic> getStats() {
    return {
      'pendingRequests': _pendingRequests.length,
      'cachedResults': _resultCache.length,
    };
  }
}

class _CachedResult {
  final dynamic result;
  final int timestamp;

  _CachedResult({
    required this.result,
    required this.timestamp,
  });
}














