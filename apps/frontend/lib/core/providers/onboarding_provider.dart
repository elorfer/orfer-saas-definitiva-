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
    // ✅ FIX: Verificar estado inicial de forma asíncrona sin bloquear
    // No usar ref.listen() durante build() para evitar problemas de ciclo de vida
    if (!_isInitialized) {
      _isInitialized = true;
      Future.microtask(() async {
        try {
          // Escuchar cambios en el usuario autenticado para verificar onboarding
          ref.listen<AuthState>(
            authStateProvider,
            (previous, next) {
              // Si el usuario cambió, verificar el onboarding para el nuevo usuario
              if (next.isAuthenticated && next.user != null) {
                _checkOnboardingStatusForUser(next.user!.id);
              } else if (!next.isAuthenticated) {
                // Si se desautenticó, resetear estado
                state = false;
              }
            },
          );
          
          // Verificar estado inicial
          await _checkOnboardingStatus();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [OnboardingProvider] Error durante inicialización: $e');
          }
          // Si hay error durante la inicialización, asumir que no se completó
          state = false;
        }
      });
    }
    
    // Retornar false inicialmente hasta que se verifique el estado real
    return false;
  }

  /// Verificar si el onboarding ya fue completado para el usuario actual
  Future<void> _checkOnboardingStatus() async {
    try {
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated && authState.user != null) {
        await _checkOnboardingStatusForUser(authState.user!.id);
      } else {
        // Si no hay usuario autenticado, no mostrar onboarding
        state = true; // Marcar como completado para no mostrar onboarding sin usuario
      }
    } catch (e) {
      // Si hay error, asumir que no se completó para mostrar onboarding
      state = false;
    }
  }

  /// Verificar si el onboarding ya fue completado para un usuario específico
  Future<void> _checkOnboardingStatusForUser(String userId) async {
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
        
        // Establecer el estado según si ya completó o no
        state = completed;
        return;
      }
      
      // Verificar si este usuario ya completó el onboarding
      final key = '$_onboardingKeyPrefix$userId';
      final completed = prefs.getBool(key) ?? false;
      
      if (kDebugMode) {
        debugPrint('🔍 [OnboardingProvider] Mismo usuario. Estado de onboarding: $completed');
      }
      
      state = completed;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [OnboardingProvider] Error verificando estado: $e');
      }
      // Si hay error, asumir que no se completó para mostrar onboarding
      state = false;
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
      state = false;
    } catch (e) {
      state = false;
    }
  }

  /// Verificar si el onboarding está completado
  bool get isCompleted => state;
}

