/// Excepción personalizada para errores de autenticación
class AuthException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final String? email; // Para el caso EMAIL_NOT_VERIFIED

  const AuthException(
    this.message, {
    this.code,
    this.statusCode,
    this.email,
  });

  @override
  String toString() => 'AuthException: $message${code != null ? ' (code: $code)' : ''}';

  /// Factory para crear desde DioException
  factory AuthException.fromDioError(dynamic error, {String? context}) {
    if (error.response?.statusCode == 401) {
      // Detectar el caso especial de EMAIL_NOT_VERIFIED
      final responseData = error.response?.data;
      final innerCode = responseData?['code'] ?? responseData?['response']?['code'];
      final innerEmail = responseData?['email'] ?? responseData?['response']?['email'];
      final innerMessage = responseData?['message'] ?? responseData?['response']?['message'];

      if (innerCode == 'EMAIL_NOT_VERIFIED') {
        return AuthException(
          innerMessage ?? 'Debes verificar tu email. Te enviamos un nuevo código.',
          code: 'EMAIL_NOT_VERIFIED',
          statusCode: 401,
          email: innerEmail,
        );
      }

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













