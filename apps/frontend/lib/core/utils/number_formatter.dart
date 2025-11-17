/// Utilidad centralizada para formatear números grandes
/// Convierte números a formato legible (1K, 1.5M, etc.)
class NumberFormatter {
  /// Formatea un número grande a formato legible
  /// 
  /// Ejemplos:
  /// - 1000 -> "1.0K"
  /// - 1500000 -> "1.5M"
  /// - 500 -> "500"
  static String format(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
}

