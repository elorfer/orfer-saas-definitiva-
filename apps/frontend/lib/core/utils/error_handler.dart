import 'package:dio/dio.dart';
import '../utils/logger.dart';
import 'response_parser.dart';

/// Excepción base para errores de la aplicación
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => message;
}

/// Excepción de red/conectividad
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.details});
}

/// Excepción de autenticación/autorización
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.details});
}

/// Excepción de validación
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.details});
}

/// Excepción de servidor
class ServerException extends AppException {
  final int? statusCode;
  const ServerException(super.message, {super.code, super.details, this.statusCode});
}

/// Excepción de datos no encontrados
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code, super.details});
}

/// Utilidad centralizada para manejar errores de forma consistente
class ErrorHandler {
  /// Manejar errores de Dio y convertirlos en excepciones de la aplicación
  static AppException handleDioError(
    DioException error, {
    String? context,
    bool logError = true,
  }) {
    if (logError) {
      _logDioError(error, context);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          'Tiempo de espera agotado. Verifica tu conexión a internet.',
          code: 'TIMEOUT',
        );

      case DioExceptionType.connectionError:
        return _handleConnectionError(error);

      case DioExceptionType.badResponse:
        return _handleBadResponse(error);

      case DioExceptionType.cancel:
        return NetworkException(
          'Operación cancelada',
          code: 'CANCELLED',
        );

      case DioExceptionType.unknown:
      default:
        return _handleUnknownError(error);
    }
  }

  /// Manejar errores de conexión
  static NetworkException _handleConnectionError(DioException error) {
    final message = error.message ?? '';

    if (message.contains('Failed host lookup') ||
        message.contains('Unable to resolve host')) {
      return NetworkException(
        'No se puede resolver el servidor. Verifica tu conexión a internet.',
        code: 'DNS_ERROR',
      );
    } else if (message.contains('Connection refused')) {
      return NetworkException(
        'El servidor rechazó la conexión. Verifica que el backend esté ejecutándose.',
        code: 'CONNECTION_REFUSED',
      );
    } else if (message.contains('Network is unreachable')) {
      return NetworkException(
        'Red no disponible. Verifica tu conexión a internet.',
        code: 'NETWORK_UNREACHABLE',
      );
    } else {
      return NetworkException(
        'Error de conexión: ${message.isEmpty ? "Desconocido" : message}. Verifica tu internet.',
        code: 'CONNECTION_ERROR',
      );
    }
  }

  /// Manejar respuestas HTTP con errores
  static AppException _handleBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;
    final response = error.response;

    // Extraer mensaje de error de la respuesta
    final errorMessage = ResponseParser.extractErrorMessage(response);
    final errorCode = ResponseParser.extractErrorCode(response);

    switch (statusCode) {
      case 400:
        return ValidationException(
          errorMessage ?? 'Datos inválidos',
          code: errorCode ?? 'BAD_REQUEST',
        );

      case 401:
        return AuthException(
          errorMessage ?? 'Credenciales inválidas',
          code: errorCode ?? 'UNAUTHORIZED',
        );

      case 403:
        return AuthException(
          errorMessage ?? 'No tienes permisos para realizar esta acción',
          code: errorCode ?? 'FORBIDDEN',
        );

      case 404:
        return NotFoundException(
          errorMessage ?? 'Recurso no encontrado',
          code: errorCode ?? 'NOT_FOUND',
        );

      case 409:
        return ValidationException(
          errorMessage ?? 'Conflicto en los datos',
          code: errorCode ?? 'CONFLICT',
        );

      case 422:
        return ValidationException(
          errorMessage ?? 'Error de validación',
          code: errorCode ?? 'UNPROCESSABLE_ENTITY',
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          errorMessage ?? 'Error interno del servidor',
          code: errorCode ?? 'SERVER_ERROR',
          statusCode: statusCode,
        );

      default:
        return ServerException(
          errorMessage ?? 'Error del servidor: $statusCode',
          code: errorCode ?? 'UNKNOWN_ERROR',
          statusCode: statusCode,
        );
    }
  }

  /// Manejar errores desconocidos
  static AppException _handleUnknownError(DioException error) {
    final message = error.message ?? '';

    if (message.contains('Failed host lookup')) {
      return NetworkException(
        'No se puede conectar al servidor. Verifica tu internet y que el backend esté ejecutándose.',
        code: 'HOST_LOOKUP_FAILED',
      );
    } else if (message.contains('Connection refused')) {
      return NetworkException(
        'El servidor no está disponible. Verifica que el backend esté ejecutándose.',
        code: 'CONNECTION_REFUSED',
      );
    } else {
      return NetworkException(
        'Error desconocido: ${message.isEmpty ? "Sin detalles" : message}',
        code: 'UNKNOWN',
      );
    }
  }

  /// Loggear error de Dio de forma estructurada
  static void _logDioError(DioException error, String? context) {
    final prefix = context != null ? '[$context]' : '';
    
    AppLogger.error('$prefix Error Dio: ${error.type}');
    AppLogger.error('$prefix Mensaje: ${error.message}');
    AppLogger.error('$prefix URL: ${error.requestOptions.uri}');
    
    if (error.response != null) {
      AppLogger.error('$prefix Status: ${error.response?.statusCode}');
      AppLogger.error('$prefix Data: ${error.response?.data}');
    } else {
      AppLogger.warning('$prefix Sin respuesta del servidor (posible problema de conexión)');
    }
  }

  /// Manejar errores genéricos y convertirlos en excepciones
  static AppException handleGenericError(
    dynamic error, {
    String? context,
    bool logError = true,
  }) {
    if (logError) {
      final prefix = context != null ? '[$context]' : '';
      AppLogger.error('$prefix Error inesperado: $error');
    }

    if (error is DioException) {
      return handleDioError(error, context: context, logError: false);
    } else if (error is AppException) {
      return error;
    } else {
      return NetworkException(
        'Error inesperado: ${error.toString()}',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Verificar si un error es recuperable (se puede reintentar)
  static bool isRetryable(AppException error) {
    if (error is NetworkException) {
      // Errores de red son recuperables
      return true;
    } else if (error is ServerException) {
      // Errores 5xx del servidor son recuperables
      final statusCode = error.statusCode;
      return statusCode != null && statusCode >= 500 && statusCode < 600;
    }
    // Otros errores no son recuperables
    return false;
  }

  /// Obtener mensaje amigable para el usuario
  static String getUserFriendlyMessage(AppException error) {
    // Si el mensaje ya es amigable, usarlo directamente
    if (error.message.isNotEmpty) {
      return error.message;
    }

    // Mensajes por defecto según el tipo de error
    switch (error) {
      case NetworkException _:
        return 'Problema de conexión. Verifica tu internet.';
      case AuthException _:
        return 'Error de autenticación. Por favor, inicia sesión nuevamente.';
      case ValidationException _:
        return 'Datos inválidos. Por favor, verifica la información.';
      case NotFoundException _:
        return 'Recurso no encontrado.';
      case ServerException _:
        return 'Error del servidor. Por favor, intenta más tarde.';
      default:
        return 'Ha ocurrido un error. Por favor, intenta nuevamente.';
    }
  }
}

