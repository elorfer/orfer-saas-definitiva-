import 'package:dio/dio.dart';
import 'logger.dart';

/// Clase para representar errores estructurados
class ErrorInfo {
  final String message;
  final String? code;
  final int? statusCode;

  const ErrorInfo({
    required this.message,
    this.code,
    this.statusCode,
  });
}

/// Utilidad centralizada para manejo de errores
/// Evita duplicación de código en try-catch blocks
class ErrorHandler {
  /// Maneja errores de servicios con logging automático
  static T handleServiceError<T>(
    String context,
    T Function() operation, {
    T? fallbackValue,
    bool shouldRethrow = false,
  }) {
    try {
      return operation();
    } catch (e, stackTrace) {
      AppLogger.error('[$context] Error: $e', stackTrace);
      
      if (shouldRethrow) {
        rethrow;
      }
      
      if (fallbackValue != null) {
        return fallbackValue;
      }
      
      rethrow;
    }
  }
  
  /// Maneja errores async de servicios con logging automático
  static Future<T> handleServiceErrorAsync<T>(
    String context,
    Future<T> Function() operation, {
    T? fallbackValue,
    bool shouldRethrow = false,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      AppLogger.error('[$context] Error: $e', stackTrace);
      
      if (shouldRethrow) {
        rethrow;
      }
      
      if (fallbackValue != null) {
        return fallbackValue;
      }
      
      rethrow;
    }
  }
  
  /// Maneja errores silenciosos (solo logging, no rethrow)
  static void handleSilentError(String context, void Function() operation) {
    try {
      operation();
    } catch (e) {
      AppLogger.warning('[$context] Error silencioso: $e');
    }
  }
  
  /// Maneja errores async silenciosos (solo logging, no rethrow)
  static Future<void> handleSilentErrorAsync(String context, Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e) {
      AppLogger.warning('[$context] Error silencioso: $e');
    }
  }
  
  /// Maneja errores de Dio (red/HTTP) - VERSIÓN VOID para compatibilidad
  static void handleDioError(dynamic error, {String? context, bool logError = true}) {
    if (logError) {
      final contextStr = context != null ? '[$context]' : '[DioError]';
      AppLogger.error('$contextStr Error de red: $error');
    }
  }
  
  /// Maneja errores genéricos - VERSIÓN VOID para compatibilidad
  static void handleGenericError(dynamic error, {String? context, bool logError = true}) {
    if (logError) {
      final contextStr = context != null ? '[$context]' : '[GenericError]';
      AppLogger.error('$contextStr Error genérico: $error');
    }
  }

  /// Maneja errores de Dio y devuelve ErrorInfo estructurado
  static ErrorInfo processDioError(dynamic error, {String? context}) {
    final contextStr = context != null ? '[$context]' : '[DioError]';
    
    if (error is DioException) {
      final message = error.response?.data?['message'] ?? 
                     error.message ?? 
                     'Error de conexión';
      final statusCode = error.response?.statusCode;
      
      AppLogger.error('$contextStr Error de red: $message (${statusCode ?? 'sin código'})');
      
      return ErrorInfo(
        message: message,
        code: 'DIO_ERROR',
        statusCode: statusCode,
      );
    }
    
    AppLogger.error('$contextStr Error de red: $error');
    return ErrorInfo(
      message: error.toString(),
      code: 'NETWORK_ERROR',
    );
  }
  
  /// Maneja errores genéricos y devuelve ErrorInfo estructurado
  static ErrorInfo processGenericError(dynamic error, {String? context}) {
    final contextStr = context != null ? '[$context]' : '[GenericError]';
    AppLogger.error('$contextStr Error genérico: $error');
    
    return ErrorInfo(
      message: error.toString(),
      code: 'GENERIC_ERROR',
    );
  }
  
  /// Maneja errores con callback de fallback
  static T handleErrorWithFallback<T>(
    String context,
    T Function() operation,
    T Function() fallback,
  ) {
    try {
      return operation();
    } catch (e) {
      AppLogger.warning('[$context] Error, usando fallback: $e');
      return fallback();
    }
  }
  
  /// Maneja errores async con callback de fallback
  static Future<T> handleErrorWithFallbackAsync<T>(
    String context,
    Future<T> Function() operation,
    Future<T> Function() fallback,
  ) async {
    try {
      return await operation();
    } catch (e) {
      AppLogger.warning('[$context] Error, usando fallback: $e');
      return await fallback();
    }
  }
}