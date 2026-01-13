import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/social_auth_service.dart'; // 🔐 Social Auth
import '../exceptions/auth_exception.dart';
import 'onboarding_provider.dart';
import '../services/revenuecat_service.dart';
import 'offline_manager_provider.dart'; // 🔒 Offline Manager
import 'play_history_provider.dart'; // PlayHistory
import 'playback_notifier.dart'; // 🎵 Playback
import '../services/audio_service.dart'; // 🔊 Audio Service
import '../utils/logger.dart'; // 📝 Logger

/// Provider para el servicio de autenticación
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider para el estado de autenticación
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

/// Estado de autenticación
class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final bool isInitialized;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.isInitialized = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    bool? isInitialized,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Notifier para manejar el estado de autenticación
class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;



  @override
  AuthState build() {
    _authService = ref.read(authServiceProvider);
    
    // Escuchar cambios de RevenueCat para actualización optimista instantánea
    // Esto elimina el delay entre la compra y la actualización de la UI
    RevenueCatService().premiumStatusStream.listen((isPremium) {
      if (state.user != null) {
        debugPrint('⚡ AuthNotifier: Recibido evento de RevenueCat. isPremium: $isPremium');
        
        final updatedUser = state.user!.copyWith(
          isPremiumField: isPremium,
          subscriptionStatus: isPremium ? SubscriptionStatus.premium : SubscriptionStatus.free, // Fallback a free si false
        );
        
        // Optimistic Update: Actualizamos el estado local inmediatamente
        state = state.copyWith(user: updatedUser);
      }
    });

    Future.microtask(() => _initialize());
    return const AuthState(isLoading: true);
  }

  /// Inicializar el servicio de autenticación
  Future<void> _initialize() async {
    try {
      // Timeout de 8 segundos para evitar falsos negativos en dispositivos lentos
      await _authService.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          // Si toma mucho tiempo, continuar sin inicializar
          return;
        },
      );
      
      if (_authService.isAuthenticated) {
        // Primero establecer el estado con el usuario guardado
        state = state.copyWith(
          user: _authService.currentUser,
          isAuthenticated: true,
          isLoading: false,
          isInitialized: true,
        );
        
        
        // CRITICO: Inicializar OfflineManager para el usuario restaurado
        if (_authService.currentUser != null) {
          try {
            final offlineManager = ref.read(offlineManagerProvider.notifier);
            await offlineManager.initializeForUser(_authService.currentUser!.id);
            AppLogger.info('[AuthProvider] OfflineManager inicializado para usuario restaurado');
          } catch (e) {
            AppLogger.error('[AuthProvider] Error inicializando OfflineManager al restaurar sesion: $e');
          }
          
          // CRITICO: Inicializar PlayHistory para el usuario restaurado
          try {
            final playHistory = ref.read(playHistoryProvider.notifier);
            await playHistory.initializeForUser(_authService.currentUser!.id);
            AppLogger.info('[AuthProvider] PlayHistory inicializado para usuario restaurado');
          } catch (e) {
            AppLogger.error('[AuthProvider] Error inicializando PlayHistory al restaurar sesion: $e');
          }
        }
        // Luego refrescar el perfil en segundo plano (sin bloquear)
        refreshProfile().catchError((e) {
          // Silenciar errores de refresh, el usuario ya está cargado
          // El error se ignora silenciosamente
        });
      } else {
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al inicializar: $e',
        isInitialized: true,
      );
    }
  }

  /// Login
  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final authResponse = await _authService.login(
        email: email,
        password: password,
      );
      
      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );
      
      // 🔒 Inicializar OfflineManager para este usuario
      try {
        final offlineManager = ref.read(offlineManagerProvider.notifier);
        await offlineManager.initializeForUser(authResponse.user.id);
        AppLogger.info('[AuthProvider] ✅ OfflineManager inicializado para usuario: ${authResponse.user.id}');
        final playHistory = ref.read(playHistoryProvider.notifier);
        await playHistory.initializeForUser(authResponse.user.id);
        AppLogger.info('[AuthProvider] PlayHistory inicializado para usuario: ${authResponse.user.id}');
      } catch (e) {
        AppLogger.error('[AuthProvider] ⚠️ Error inicializando OfflineManager: $e');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error inesperado: $e',
      );
      rethrow;
    }
  }

  /// Registro
  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    UserRole? role,
    String? stageName,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final authResponse = await _authService.register(
        email: email,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        stageName: stageName,
      );
      
      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );
      
      // 🔒 Inicializar OfflineManager para este usuario
      try {
        final offlineManager = ref.read(offlineManagerProvider.notifier);
        await offlineManager.initializeForUser(authResponse.user.id);
        AppLogger.info('[AuthProvider] ✅ OfflineManager inicializado para usuario: ${authResponse.user.id}');
        final playHistory = ref.read(playHistoryProvider.notifier);
        await playHistory.initializeForUser(authResponse.user.id);
        AppLogger.info('[AuthProvider] PlayHistory inicializado para usuario: ${authResponse.user.id}');
      } catch (e) {
        AppLogger.error('[AuthProvider] ⚠️ Error inicializando OfflineManager: $e');
      }
      
      // ✅ FIX: Resetear onboarding para el nuevo usuario registrado
      // Esto asegura que el onboarding aparezca solo para usuarios nuevos
      if (authResponse.user.id.isNotEmpty) {
        try {
          final onboardingNotifier = ref.read(onboardingProvider.notifier);
          await onboardingNotifier.resetForNewUser(authResponse.user.id);
        } catch (e) {
          // Si hay error reseteando onboarding, continuar de todas formas
          debugPrint('⚠️ Error reseteando onboarding para nuevo usuario: $e');
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error inesperado: $e',
      );
      rethrow;
    }
  }

  /// 🔵 LOGIN CON GOOGLE
  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // Obtener servicio social auth
      final socialAuth = ref.read(socialAuthServiceProvider);
      final authData = await socialAuth.signInWithGoogle();
      
      if (authData == null) {
        // Usuario canceló
        state = state.copyWith(isLoading: false);
        return;
      }

      // Enviar al backend
      final authResponse = await _authService.socialLogin(
        provider: authData['provider']!,
        accessToken: authData['accessToken']!,
        email: authData['email']!,
        displayName: authData['displayName']!,
        photoUrl: authData['photoUrl'],
      );

      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );
      
      // 🔒 Inicializar OfflineManager para este usuario
      try {
        final offlineManager = ref.read(offlineManagerProvider.notifier);
        await offlineManager.initializeForUser(authResponse.user.id);
        AppLogger.info('[AuthProvider] ✅ OfflineManager inicializado para usuario: ${authResponse.user.id}');
        final playHistory = ref.read(playHistoryProvider.notifier);
        await playHistory.initializeForUser(authResponse.user.id);
        AppLogger.info('[AuthProvider] PlayHistory inicializado para usuario: ${authResponse.user.id}');
      } catch (e) {
        AppLogger.error('[AuthProvider] ⚠️ Error inicializando OfflineManager: $e');
      }
      
      // Reset onboarding si es nuevo usuario
      if (authResponse.user.id.isNotEmpty) {
        try {
          final onboardingNotifier = ref.read(onboardingProvider.notifier);
          await onboardingNotifier.resetForNewUser(authResponse.user.id);
        } catch (e) {
          debugPrint('⚠️ Error reseteando onboarding: $e');
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error al iniciar sesión con Google: $e',
      );
      rethrow;
    }
  }

  /// 🔴 LOGIN CON FACEBOOK
  Future<void> signInWithFacebook() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // Obtener servicio social auth
      final socialAuth = ref.read(socialAuthServiceProvider);
      final authData = await socialAuth.signInWithFacebook();
      
      if (authData == null) {
        // Usuario canceló
        state = state.copyWith(isLoading: false);
        return;
      }

      // Enviar al backend
      final authResponse = await _authService.socialLogin(
        provider: authData['provider']!,
        accessToken: authData['accessToken']!,
        email: authData['email']!,
        displayName: authData['displayName']!,
        photoUrl: authData['photoUrl'],
      );

      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );
      
      // Reset onboarding si es nuevo usuario
      if (authResponse.user.id.isNotEmpty) {
        try {
          final onboardingNotifier = ref.read(onboardingProvider.notifier);
          await onboardingNotifier.resetForNewUser(authResponse.user.id);
        } catch (e) {
          debugPrint('⚠️ Error reseteando onboarding: $e');
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error al iniciar sesión con Facebook: $e',
      );
      rethrow;
    }
  }

  /// Cambiar contraseña
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      
      state = state.copyWith(
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error inesperado: $e',
      );
      rethrow;
    }
  }

  /// Actualizar usuario inmediatamente sin hacer HTTP
  /// Útil para actualizaciones en tiempo real vía WebSocket
  void updateUserImmediately(User updatedUser) {
    state = state.copyWith(
      user: updatedUser,
      isAuthenticated: true,
    );
  }

  /// Refrescar perfil
  Future<void> refreshProfile() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final user = await _authService.getProfile();
      
      // Debug: Verificar estado premium después del refresh
      debugPrint('🔄 AuthProvider.refreshProfile - subscriptionStatus: ${user.subscriptionStatus}, isPremium: ${user.isPremium}');
      
      state = state.copyWith(
        user: user,
        isLoading: false,
        error: null,
        isAuthenticated: true, // Asegurar que sigue autenticado
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error inesperado: $e',
      );
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // 🎵 CRÍTICO: Detener música y ocultar reproductor antes de cerrar sesión
      try {
        AppLogger.info('[AuthProvider] 🎵 Deteniendo música...');
        
        // Detener el audio directamente
        try {
          final audioService = ref.read(audioServiceProvider);
          await audioService.player.pause();
          AppLogger.info('[AuthProvider] ⏸️ Audio pausado');
        } catch (e) {
          AppLogger.warning('[AuthProvider] Error pausando audio: $e');
        }
        
        // Ocultar reproductor
        final playbackNotifier = ref.read(playbackNotifierProvider.notifier);
        playbackNotifier.state = playbackNotifier.state.copyWith(
          isMiniPlayerVisible: false,
          isSessionActive: false,
          isPlaying: false,
        );
        
        AppLogger.info('[AuthProvider] ✅ Música detenida y reproductor oculto');
      } catch (e) {
        AppLogger.error('[AuthProvider] ⚠️ Error deteniendo música: $e');
        // No bloquear el logout si falla
      }
      
      // 🔒 Cerrar sesión de OfflineManager (SIN eliminar datos)
      // Los datos del usuario se mantienen para cuando vuelva a iniciar sesión
      try {
        AppLogger.info('[AuthProvider] 🔄 Cerrando sesión de OfflineManager...');
        final offlineManager = ref.read(offlineManagerProvider.notifier);
        await offlineManager.closeCurrentUserSession();
        final playHistory = ref.read(playHistoryProvider.notifier);
        await playHistory.closeCurrentUserSession();
        AppLogger.info('[AuthProvider] ✅ OfflineManager cerrado correctamente');
      } catch (e) {
        AppLogger.error('[AuthProvider] ⚠️ Error cerrando OfflineManager (continuando con logout): $e');
        // No bloquear el logout si falla
      }
      
      await _authService.logout();
      
      state = state.copyWith(
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error inesperado: $e',
      );
    }
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Refrescar token
  Future<void> refreshToken() async {
    try {
      await _authService.refreshToken();
    } catch (e) {
      // Si falla el refresh, hacer logout
      await logout();
    }
  }

  /// Verificar disponibilidad de nombre de usuario
  Future<bool> checkUsernameAvailability(String username) async {
    return await _authService.checkUsernameAvailability(username);
  }

  /// Verificar disponibilidad de email
  Future<bool> checkEmailAvailability(String email) async {
    return await _authService.checkEmailAvailability(email);
  }

  /// Verificar si un usuario existe (para login)
  Future<bool> checkUserExists(String emailOrUsername) async {
    return await _authService.checkUserExists(emailOrUsername);
  }

  /// Solicitar recuperación de contraseña
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final result = await _authService.forgotPassword(email);
      state = state.copyWith(isLoading: false, error: null);
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error inesperado: $e',
      );
      rethrow;
    }
  }

  /// Restablecer contraseña con token
  Future<void> resetPassword(String token, String newPassword) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _authService.resetPassword(token, newPassword);
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error inesperado: $e',
      );
      rethrow;
    }
  }
}

/// Provider para verificar si el usuario está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isAuthenticated;
});

/// Provider para obtener el usuario actual
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.user;
});

/// Provider para verificar si está cargando
final isLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isLoading;
});

/// Provider para obtener el error actual
final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.error;
});
