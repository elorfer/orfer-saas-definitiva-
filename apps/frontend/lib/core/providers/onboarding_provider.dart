import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'auth_provider.dart';

/// Provider para manejar el estado del onboarding
/// ✅ FIX: Ahora el onboarding es por usuario - solo aparece una vez por usuario
final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(() {
  return OnboardingNotifier();
});

class OnboardingNotifier extends Notifier<bool> {
  static const String _onboardingKeyPrefix = 'onboarding_completed_';
  static const String _lastUserIdKey = 'onboarding_last_user_id';
  bool _isInitialized = false;
  
  @override
  bool build() {
    // 🔍 OPTIMIZACIÓN: Solo cargar si el usuario está autenticado
    // El valor por defecto es true para no bloquear la app innecesariamente,
    // pero se valida inmediatamente de forma asíncrona.
    final userId = ref.watch(currentUserProvider.select((u) => u?.id));
    
    if (userId != null) {
      if (!_isInitialized) {
        _isInitialized = true;
        Future.microtask(() => checkOnboardingStatusForUser(userId));
      }
    }

    // Por defecto devolvemos true (completado) para evitar que viejos usuarios
    // vean el onboarding un segundo mientras carga el ID de usuario.
    // El router se encargará de redirigir si el valor cambia a false.
    return true;
  }

  /// Verificar si el onboarding ya fue completado para el usuario actual
  Future<void> _checkOnboardingStatus() async {
    try {
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated && authState.user != null) {
        // ✅ OPTIMIZACIÓN: Verificar inmediatamente para evitar mostrar onboarding prematuramente
        await checkOnboardingStatusForUser(authState.user!.id);
      } else {
        // Si no hay usuario autenticado, no mostrar onboarding
        state = true; // Marcar como completado para no mostrar onboarding sin usuario
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [OnboardingProvider] Error en _checkOnboardingStatus: $e');
      }
      // ✅ OPTIMIZACIÓN: Si hay error, asumir que está completado para evitar mostrar onboarding
      // Es mejor errar del lado de no mostrar onboarding que mostrarlo innecesariamente
      state = true;
    }
  }

  /// Verificar si el onboarding ya fue completado para un usuario específico
  Future<void> checkOnboardingStatusForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUserId = prefs.getString(_lastUserIdKey);
      
      if (kDebugMode) {
        debugPrint('🔍 [OnboardingProvider] Verificando onboarding para usuario: $userId');
        debugPrint('🔍 [OnboardingProvider] Último usuario guardado: $lastUserId');
      }
      
      // Si el usuario cambió, verificar si el nuevo usuario ya completó el onboarding
      if (lastUserId != userId) {
        // Usuario nuevo o diferente - verificar si ya completó onboarding antes
        final key = '$_onboardingKeyPrefix$userId';
        final completed = prefs.getBool(key) ?? false;
        
        if (kDebugMode) {
          debugPrint('🔍 [OnboardingProvider] Usuario cambió. Estado de onboarding: $completed');
        }
        
        // Guardar el nuevo userId
        await prefs.setString(_lastUserIdKey, userId);
        
        // ✅ OPTIMIZACIÓN: Establecer el estado según si ya completó o no
        // Si completed es false (no completó), mostrar onboarding
        // Si completed es true (ya completó), no mostrar onboarding
        state = completed;
        return;
      }
      
      // Verificar si este usuario ya completó el onboarding
      final key = '$_onboardingKeyPrefix$userId';
      final completed = prefs.getBool(key) ?? false;
      
      if (kDebugMode) {
        debugPrint('🔍 [OnboardingProvider] Mismo usuario. Estado de onboarding: $completed');
      }
      
      // ✅ OPTIMIZACIÓN: Actualizar estado solo si cambió para evitar rebuilds innecesarios
      if (state != completed) {
        state = completed;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [OnboardingProvider] Error verificando estado: $e');
      }
      // ✅ OPTIMIZACIÓN: Si hay error, asumir que está completado para evitar mostrar onboarding
      // Es mejor errar del lado de no mostrar onboarding que mostrarlo innecesariamente
      state = true;
    }
  }

  /// Marcar el onboarding como completado para el usuario actual
  Future<void> completeOnboarding() async {
    try {
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated && authState.user != null) {
        final prefs = await SharedPreferences.getInstance();
        final userId = authState.user!.id;
        final key = '$_onboardingKeyPrefix$userId';
        
        if (kDebugMode) {
          debugPrint('✅ [OnboardingProvider] Completando onboarding para usuario: $userId');
        }
        
        // Guardar que este usuario completó el onboarding
        final saved = await prefs.setBool(key, true);
        await prefs.setString(_lastUserIdKey, userId);
        
        if (kDebugMode) {
          debugPrint('✅ [OnboardingProvider] Estado guardado en SharedPreferences: $saved');
          debugPrint('✅ [OnboardingProvider] Verificando guardado: ${prefs.getBool(key)}');
        }
        
        // Actualizar el estado del provider
        state = true;
        
        if (kDebugMode) {
          debugPrint('✅ [OnboardingProvider] Estado del provider actualizado: $state');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [OnboardingProvider] No hay usuario autenticado, marcando como completado en memoria');
        }
        // Si no hay usuario, igualmente marcar como completado en memoria
        state = true;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [OnboardingProvider] Error completando onboarding: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      // Si hay error, igualmente marcar como completado en memoria
      state = true;
    }
  }

  /// Resetear el onboarding para el usuario actual (útil cuando un usuario nuevo se registra)
  Future<void> resetForNewUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_onboardingKeyPrefix$userId';
      
      // Eliminar el estado de onboarding para este usuario
      await prefs.remove(key);
      await prefs.setString(_lastUserIdKey, userId);
      
      // 🚀 CRÍTICO: Actualizar estado inmediatamente para que el router reaccione
      state = false;
      
      debugPrint('🆕 Onboarding reseteado para nuevo usuario: $userId');
    } catch (e) {
      state = false;
    }
  }

  /// Verificar si el onboarding está completado
  bool get isCompleted => state;
}

