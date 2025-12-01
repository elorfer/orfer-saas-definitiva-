/// Funciones de validación reutilizables para formularios de autenticación
/// Centraliza la lógica de validación para mejorar mantenibilidad
class AuthValidators {
  /// Valida que un campo requerido no esté vacío
  static String? required(String? value, {String fieldName = 'Este campo'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  /// Valida formato de email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu correo electrónico';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  /// Valida contraseña (mínimo 8 caracteres)
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return null;
  }

  /// Valida que dos contraseñas coincidan
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (value != password) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  /// Valida nombre de usuario (mínimo 3 caracteres, solo letras, números y guiones bajos)
  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu nombre de usuario';
    }
    if (value.length < 3) {
      return 'El nombre de usuario debe tener al menos 3 caracteres';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Solo se permiten letras, números y guiones bajos';
    }
    return null;
  }

  /// Valida nombre (requerido)
  static String? name(String? value, {String fieldName = 'Nombre'}) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu $fieldName';
    }
    return null;
  }

  /// Valida nombre artístico (requerido para artistas)
  static String? stageName(String? value, {required bool isArtist}) {
    if (isArtist) {
      if (value == null || value.isEmpty) {
        return 'Ingresa tu nombre artístico';
      }
    }
    return null;
  }
}




