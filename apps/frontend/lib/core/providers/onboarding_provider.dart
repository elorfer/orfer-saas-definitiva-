import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para manejar el estado del onboarding
final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(() {
  return OnboardingNotifier();
});

class OnboardingNotifier extends Notifier<bool> {
  static const String _onboardingKey = 'onboarding_completed';

  @override
  bool build() {
    // Inicializar como no completado por defecto (mostrar onboarding)
    // Verificar estado de forma asíncrona sin bloquear
    _checkOnboardingStatus();
    return false;
  }

  /// Verificar si el onboarding ya fue completado
  Future<void> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_onboardingKey) ?? false;
      // Actualizar state de forma segura
      state = completed;
    } catch (e) {
      // Si hay error, asumir que no se completó para mostrar onboarding
      // No actualizar state si hay error para evitar problemas
      state = false;
    }
  }

  /// Marcar el onboarding como completado
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
      state = true;
    } catch (e) {
      // Si hay error, igualmente marcar como completado en memoria
      state = true;
    }
  }

  /// Verificar si el onboarding está completado
  bool get isCompleted => state;
}

