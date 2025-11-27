/// Excepción personalizada para errores de autenticación
class AuthException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const AuthException(
    this.message, {
    this.code,
    this.statusCode,
  });

  @override
  String toString() => 'AuthException: $message${code != null ? ' (code: $code)' : ''}';

  /// Factory para crear desde DioException
  factory AuthException.fromDioError(dynamic error, {String? context}) {
    if (error.response?.statusCode == 401) {
      return const AuthException(
        'Credenciales inválidas',
        code: 'INVALID_CREDENTIALS',
        statusCode: 401,
      );
    }
    
    if (error.response?.statusCode == 403) {
      return const AuthException(
        'Acceso denegado',
        code: 'ACCESS_DENIED',
        statusCode: 403,
      );
    }

    final message = error.response?.data?['message'] ?? 
                   error.message ?? 
                   'Error de autenticación';
    
    return AuthException(
      message,
      code: 'AUTH_ERROR',
      statusCode: error.response?.statusCode,
    );
  }

  /// Factory para crear desde error genérico
  factory AuthException.fromGenericError(dynamic error, {String? context}) {
    return AuthException(
      error.toString(),
      code: 'GENERIC_ERROR',
    );
  }
}


