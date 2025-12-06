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

    // Manejar errores de conexión con mensajes más informativos
    final errorType = error.type?.toString() ?? '';
    final isConnectionError = errorType.contains('connectionTimeout') ||
        errorType.contains('sendTimeout') ||
        errorType.contains('receiveTimeout') ||
        errorType.contains('connectionError') ||
        error.message?.toString().toLowerCase().contains('failed host lookup') == true ||
        error.message?.toString().toLowerCase().contains('network') == true ||
        error.message?.toString().toLowerCase().contains('socket') == true;

    if (isConnectionError) {
      return const AuthException(
        'No se pudo conectar al servidor. Verifica:\n'
        '1. Que el backend esté corriendo\n'
        '2. Que estés en la misma red (si usas dispositivo físico)\n'
        '3. Que la IP configurada sea correcta\n'
        '4. Usa: flutter run --dart-define=API_BASE_URL=http://TU_IP:3001/api/v1',
        code: 'CONNECTION_ERROR',
        statusCode: null,
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

















