import 'dart:async';
import 'dart:math';
import '../utils/logger.dart';

/// 🚀 SPOTIFY-LEVEL: SERVICIO DE RETRY CON EXPONENTIAL BACKOFF
/// Maneja reintentos automáticos para requests HTTP con backoff exponencial
class RetryService {
  static final RetryService _instance = RetryService._internal();
  factory RetryService() => _instance;
  RetryService._internal();

  /// Ejecutar función con retry automático
  Future<T> executeWithRetry<T>({
    required Future<T> Function() fn,
    int maxRetries = 3,
    int initialDelayMs = 500,
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    int delayMs = initialDelayMs;

    while (attempt < maxRetries) {
      try {
        return await fn();
      } catch (e, stackTrace) {
        attempt++;

        // Verificar si debemos reintentar
        if (shouldRetry != null && !shouldRetry(e)) {
          AppLogger.debug('[RetryService] ❌ Error no retryable: $e');
          rethrow;
        }

        // Si es el último intento, lanzar error
        if (attempt >= maxRetries) {
          AppLogger.error('[RetryService] ❌ Máximo de reintentos alcanzado ($maxRetries): $e', stackTrace);
          rethrow;
        }

        // Calcular delay con exponential backoff
        final jitter = Random().nextInt(100); // Jitter aleatorio para evitar thundering herd
        final finalDelay = delayMs + jitter;

        AppLogger.debug('[RetryService] ⚠️ Intento $attempt/$maxRetries falló: $e. Reintentando en ${finalDelay}ms...');

        // Esperar antes de reintentar
        await Future.delayed(Duration(milliseconds: finalDelay));

        // Calcular siguiente delay (exponential backoff)
        delayMs = (delayMs * backoffMultiplier).round();
      }
    }

    // Nunca debería llegar aquí, pero por si acaso
    throw Exception('RetryService: Error inesperado');
  }

  /// Verificar si un error es retryable
  static bool isRetryableError(dynamic error) {
    // Errores de red son retryables
    if (error.toString().contains('SocketException') ||
        error.toString().contains('TimeoutException') ||
        error.toString().contains('Connection') ||
        error.toString().contains('Network')) {
      return true;
    }

    // Errores 5xx del servidor son retryables
    if (error.toString().contains('500') ||
        error.toString().contains('502') ||
        error.toString().contains('503') ||
        error.toString().contains('504')) {
      return true;
    }

    // Errores 429 (Too Many Requests) son retryables
    if (error.toString().contains('429')) {
      return true;
    }

    return false;
  }
}










