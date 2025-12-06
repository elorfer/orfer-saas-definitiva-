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
      return 'El email tiene formato incorrecto';
    }
    return null;
  }

  /// Valida contraseña (mínimo 8 caracteres, con verificación de fortaleza)
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    
    // Verificar fortaleza de contraseña
    bool hasUpperCase = value.contains(RegExp(r'[A-Z]'));
    bool hasLowerCase = value.contains(RegExp(r'[a-z]'));
    bool hasNumbers = value.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    int strength = 0;
    if (hasUpperCase) strength++;
    if (hasLowerCase) strength++;
    if (hasNumbers) strength++;
    if (hasSpecialChar) strength++;
    
    if (strength < 2) {
      return 'La contraseña es muy débil';
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
  /// El parámetro isAvailable se usa para validación en tiempo real
  static String? username(String? value, {bool? isAvailable}) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu nombre de usuario';
    }
    if (value.length < 3) {
      return 'El nombre de usuario debe tener al menos 3 caracteres';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Solo se permiten letras, números y guiones bajos';
    }
    // Solo verificar disponibilidad si el campo está completo y válido
    // y si se ha verificado la disponibilidad (isAvailable no es null)
    if (isAvailable != null && !isAvailable) {
      return 'Este nombre de usuario no está disponible';
    }
    return null;
  }

  /// Valida nombre (requerido)
  static String? name(String? value, {String fieldName = 'Nombre'}) {
    if (value == null || value.isEmpty) {
      if (fieldName.toLowerCase() == 'nombre') {
        return 'Tu perfil necesita mínimo un nombre';
      }
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












