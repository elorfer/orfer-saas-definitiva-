import 'package:flutter/foundation.dart';

/// Sistema de logging seguro para producción
/// Solo muestra logs en modo DEBUG, nunca en producción
class AppLogger {
  /// Log de información (solo en debug)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ $message');
    }
  }

  /// Log de éxito (solo en debug)
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ $message');
    }
  }

  /// Log de advertencia (solo en debug)
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ $message');
    }
  }

  /// Log de error (solo en debug)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n   ')}');
      }
    }
  }

  /// Log de debug detallado (solo en debug)
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 $message');
    }
  }

  /// Log de proceso/loading (solo en debug)
  static void loading(String message) {
    if (kDebugMode) {
      debugPrint('⏳ $message');
    }
  }

  /// Log de refresh/update (solo en debug)
  static void refresh(String message) {
    if (kDebugMode) {
      debugPrint('🔄 $message');
    }
  }

  /// Log de datos/parsing (solo en debug)
  static void data(String message) {
    if (kDebugMode) {
      debugPrint('📊 $message');
    }
  }

  /// Log de red/API (solo en debug)
  static void network(String message) {
    if (kDebugMode) {
      debugPrint('🌐 $message');
    }
  }

  /// Log de archivos/imágenes (solo en debug)
  static void media(String message) {
    if (kDebugMode) {
      debugPrint('🖼️ $message');
    }
  }

  /// Log de artista/usuario (solo en debug)
  static void artist(String message) {
    if (kDebugMode) {
      debugPrint('🎤 $message');
    }
  }

  /// Log de canción/música (solo en debug)
  static void song(String message) {
    if (kDebugMode) {
      debugPrint('🎵 $message');
    }
  }

  /// Log de playlist (solo en debug)
  static void playlist(String message) {
    if (kDebugMode) {
      debugPrint('📋 $message');
    }
  }

  /// Log de configuración (solo en debug)
  static void config(String message) {
    if (kDebugMode) {
      debugPrint('⚙️ $message');
    }
  }

  /// Log de autenticación (solo en debug)
  static void auth(String message) {
    if (kDebugMode) {
      debugPrint('🔐 $message');
    }
  }

  /// Log genérico (solo en debug)
  static void log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}


