import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// Handler para reintentos automáticos con backoff exponencial
/// Mejora la robustez de la app ante errores de red intermitentes
class RetryHandler {
  /// Ejecuta una operación con reintentos automáticos
  /// 
  /// [operation] - La función async a ejecutar
  /// [maxRetries] - Número máximo de reintentos (default: 3)
  /// [initialDelay] - Delay inicial antes del primer retry (default: 1 segundo)
  /// [maxDelay] - Delay máximo entre reintentos (default: 10 segundos)
  /// [backoffMultiplier] - Multiplicador para backoff exponencial (default: 2.0)
  /// [retryableErrors] - Lista de tipos de errores que deben reintentarse
  /// 
  /// Retorna el resultado de la operación si tiene éxito
  /// Lanza la última excepción si todos los reintentos fallan
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 10),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;
    
    while (attempt <= maxRetries) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        // Si es el último intento, lanzar el error
        if (attempt >= maxRetries) {
          AppLogger.error(
            '[RetryHandler] Todos los reintentos fallaron ($maxRetries intentos)',
            error,
            stackTrace,
          );
          rethrow;
        }
        
        // Verificar si el error es retryable
        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }
        
        // Esperar antes del siguiente intento con backoff exponencial
        await Future.delayed(delay);
        
        // Calcular delay para el siguiente intento (backoff exponencial con jitter)
        delay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
        
        // Agregar jitter aleatorio (0-20% del delay) para evitar thundering herd
        final jitter = Random().nextInt((delay.inMilliseconds * 0.2).round());
        delay = Duration(milliseconds: delay.inMilliseconds + jitter);
        
        attempt++;
      }
    }
    
    // Esto no debería ejecutarse nunca, pero por seguridad
    throw Exception('RetryHandler: Máximo de reintentos excedido');
  }

  /// Verifica si un error de Dio es retryable
  /// 
  /// Errores retryables:
  /// - Connection timeout
  /// - Receive timeout
  /// - Connection error (sin internet, servidor no disponible)
  /// - Bad gateway (502)
  /// - Service unavailable (503)
  /// - Gateway timeout (504)
  static bool isDioErrorRetryable(dynamic error) {
    if (error is! DioException) {
      // Si no es DioException, verificar por string
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('timeout') || 
          errorStr.contains('connection') ||
          errorStr.contains('network')) {
        return true;
      }
      return false;
    }
    
    final dioError = error;
    
    // Errores de timeout siempre son retryables
    if (dioError.type == DioExceptionType.connectionTimeout ||
        dioError.type == DioExceptionType.receiveTimeout ||
        dioError.type == DioExceptionType.sendTimeout) {
      return true;
    }
    
    // Errores de conexión son retryables
    if (dioError.type == DioExceptionType.connectionError ||
        dioError.type == DioExceptionType.unknown) {
      return true;
    }
    
    // Verificar códigos de estado HTTP retryables
    final statusCode = dioError.response?.statusCode;
    if (statusCode != null) {
      // 5xx errors (server errors) son retryables
      if (statusCode >= 500 && statusCode < 600) {
        return true;
      }
      // 408 Request Timeout
      if (statusCode == 408) {
        return true;
      }
      // 429 Too Many Requests (con retry)
      if (statusCode == 429) {
        return true;
      }
    }
    
    // Errores 4xx (client errors) generalmente NO son retryables
    // excepto algunos casos específicos
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      // 408 y 429 ya fueron manejados arriba
      return false;
    }
    
    return false;
  }

  /// Configuración predefinida para operaciones críticas
  static Future<T> retryCritical<T>({
    required Future<T> Function() operation,
    bool Function(dynamic error)? shouldRetry,
  }) {
    return retry(
      operation: operation,
      maxRetries: 5, // Más reintentos para operaciones críticas
      initialDelay: const Duration(milliseconds: 500), // Delay inicial más corto
      maxDelay: const Duration(seconds: 15), // Delay máximo más largo
      backoffMultiplier: 2.0,
      shouldRetry: shouldRetry,
    );
  }

  /// Configuración predefinida para operaciones rápidas (UI)
  static Future<T> retryQuick<T>({
    required Future<T> Function() operation,
    bool Function(dynamic error)? shouldRetry,
  }) {
    return retry(
      operation: operation,
      maxRetries: 2, // Menos reintentos para no bloquear UI
      initialDelay: const Duration(milliseconds: 300), // Delay muy corto
      maxDelay: const Duration(seconds: 2), // Delay máximo corto
      backoffMultiplier: 1.5, // Backoff menos agresivo
      shouldRetry: shouldRetry,
    );
  }

  /// Configuración predefinida para operaciones de carga de datos
  static Future<T> retryDataLoad<T>({
    required Future<T> Function() operation,
    bool Function(dynamic error)? shouldRetry,
  }) {
    return retry(
      operation: operation,
      maxRetries: 3, // Reintentos estándar
      initialDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 8),
      backoffMultiplier: 2.0,
      shouldRetry: shouldRetry,
    );
  }
}

