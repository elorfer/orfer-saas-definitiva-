/// Helper para rastrear si el reproductor completo está abierto
/// Evita que se abran múltiples instancias del reproductor
class FullPlayerTracker {
  static bool _isOpen = false;
  
  static bool get isOpen => _isOpen;
  
  static void setOpen(bool value) {
    _isOpen = value;
  }
}






