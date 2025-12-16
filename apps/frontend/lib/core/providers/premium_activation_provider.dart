import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para manejar si ya se mostró la pantalla de activación premium
/// al usuario. Esto evita que se muestre múltiples veces.
final premiumActivationShownProvider = NotifierProvider<PremiumActivationShownNotifier, bool>(() {
  return PremiumActivationShownNotifier();
});

class PremiumActivationShownNotifier extends Notifier<bool> {
  static const String _activationShownKey = 'premium_activation_screen_shown';
  static const String _userIdKey = 'premium_activation_user_id';

  @override
  bool build() {
    // Inicializar como no mostrado por defecto
    _checkActivationShownStatus();
    return false;
  }

  /// Verificar si la pantalla de activación ya fue mostrada para el usuario actual
  Future<void> _checkActivationShownStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);
      final shown = prefs.getBool(_activationShownKey) ?? false;
      
      // Si hay un userId guardado y la pantalla ya se mostró, actualizar estado
      if (userId != null && shown) {
        state = true;
      } else {
        state = false;
      }
    } catch (e) {
      // Si hay error, asumir que no se mostró
      state = false;
    }
  }

  /// Verificar si la pantalla ya se mostró para un usuario específico
  Future<bool> hasShownForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_userIdKey);
      final shown = prefs.getBool(_activationShownKey) ?? false;
      
      // Si el userId coincide y ya se mostró, retornar true
      if (savedUserId == userId && shown) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Marcar la pantalla de activación como mostrada para un usuario específico
  Future<void> markAsShown(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setBool(_activationShownKey, true);
      state = true;
    } catch (e) {
      // Si hay error, igualmente marcar como mostrado en memoria
      state = true;
    }
  }

  /// Resetear el flag cuando el usuario pierde premium o cambia de usuario
  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_activationShownKey);
      state = false;
    } catch (e) {
      state = false;
    }
  }

  /// Verificar si la pantalla está marcada como mostrada
  bool get isShown => state;
}

