/// Utilidad para formatear tiempo relativo ("hace X minutos")
class TimeAgoFormatter {
  /// Formatea un DateTime a texto relativo en español
  /// Por ejemplo: "hace 5 minutos", "hace 2 horas", "hace 1 día"
  static String format(DateTime? dateTime) {
    if (dateTime == null) return 'Nunca';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Justo ahora';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'Hace $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Hace $hours ${hours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return 'Hace $days ${days == 1 ? 'día' : 'días'}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Hace $months ${months == 1 ? 'mes' : 'meses'}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Hace $years ${years == 1 ? 'año' : 'años'}';
    }
  }
  
  /// Versión corta para espacios reducidos
  /// Por ejemplo: "5m", "2h", "1d"
  static String formatShort(DateTime? dateTime) {
    if (dateTime == null) return '-';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}sem';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}m';
    } else {
      return '${(difference.inDays / 365).floor()}a';
    }
  }
}
