import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

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
    // Inicializar de forma asíncrona sin bloquear
    Future.microtask(() => _initialize());
    return const AuthState(isLoading: true);
  }

  /// Inicializar el servicio de autenticación
  Future<void> _initialize() async {
    try {
      // Timeout de 3 segundos para evitar bloqueos
      await _authService.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          // Si toma mucho tiempo, continuar sin inicializar
          return;
        },
      );
      
      if (_authService.isAuthenticated) {
        state = state.copyWith(
          user: _authService.currentUser,
          isAuthenticated: true,
          isLoading: false,
          isInitialized: true,
        );
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
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AuthException ? e.message : 'Error inesperado: $e',
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

  /// Refrescar perfil
  Future<void> refreshProfile() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final user = await _authService.getProfile();
      
      state = state.copyWith(
        user: user,
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

  /// Logout
  Future<void> logout() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
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
