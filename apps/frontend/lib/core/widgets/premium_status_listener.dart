import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_activation_provider.dart';
import '../services/realtime_service.dart';
import '../navigation/app_router.dart';

/// Widget optimizado que detecta cambios en el estado premium usando WebSockets
/// 
/// Características:
/// - Usa WebSockets para notificaciones en tiempo real (latencia sub-segundo)
/// - Se desactiva automáticamente una vez detectado premium estable
/// - Refresca al volver al foreground como fallback
/// - Sin polling, eficiencia máxima de batería y recursos
class PremiumStatusListener extends ConsumerStatefulWidget {
  final Widget child;

  const PremiumStatusListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<PremiumStatusListener> createState() => _PremiumStatusListenerState();
}

class _PremiumStatusListenerState extends ConsumerState<PremiumStatusListener>
    with WidgetsBindingObserver {
  SubscriptionStatus? _previousSubscriptionStatus;
  bool _hasShownActivationScreen = false;
  bool _isPremiumStable = false;
  bool _isDisposed = false;
  bool _isRefreshing = false;
  bool _isNavigating = false; // Flag para evitar navegaciones duplicadas
  StreamSubscription<Map<String, dynamic>>? _premiumStatusSubscription;
  final RealtimeService _realtimeService = RealtimeService.instance;

  // Tiempo mínimo entre refrescos manuales (1 segundo)
  static const Duration _minRefreshInterval = Duration(seconds: 1);
  
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastRefreshTime = DateTime.now();
    // Inicializar el estado previo y conectar WebSocket solo si perfil/subscriptionStatus es válido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePreviousStatus();
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated && authState.user != null &&
          (authState.user!.subscriptionStatus == SubscriptionStatus.premium ||
           authState.user!.subscriptionStatus == SubscriptionStatus.vip ||
           authState.user!.subscriptionStatus == SubscriptionStatus.free ||
           authState.user!.subscriptionStatus == SubscriptionStatus.inactive)) {
        _connectWebSocket();
      }
    });
  }

  void _initializePreviousStatus() {
    try {
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated && authState.user != null) {
        final user = authState.user!;
        _previousSubscriptionStatus = user.subscriptionStatus;
        
        final isPremium = _previousSubscriptionStatus == SubscriptionStatus.premium || 
                          _previousSubscriptionStatus == SubscriptionStatus.vip;
        
        if (kDebugMode) {
          debugPrint('🔍 PremiumStatusListener - Estado inicial: $_previousSubscriptionStatus');
        }
        
        // Si el usuario ya es premium al inicializar, ASUMIMOS que ya vio la pantalla.
        // La pantalla de "Gracias" solo debe salir transicionalmente (cuando ocurre la compra).
        // Si entra a la app ya siendo premium, no debemos interrumpirlo.
        if (isPremium) {
          _hasShownActivationScreen = true;
          _isPremiumStable = true;
          
          if (kDebugMode) {
            debugPrint('ℹ️ Usuario ya es premium al inicio - Omitiendo pantalla de agradecimiento');
          }
          
          // Asegurar que esté marcado en persistencia para consistencia
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!_isDisposed && mounted) {
              await ref.read(premiumActivationShownProvider.notifier).markAsShown(user.id);
            }
          });
        } else {
          // Usuario free/inactive, mantener listener activo
          _isPremiumStable = false;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error al inicializar estado previo: $e');
      }
    }
  }

  /// Conectar al WebSocket y escuchar eventos de cambio premium
  void _connectWebSocket() {
    if (_isDisposed || !mounted) return;
    try {
      final authState = ref.read(authStateProvider);
      if (!authState.isAuthenticated || authState.user == null) {
        if (kDebugMode) {
          debugPrint('⚠️ Usuario no autenticado, no conectando WebSocket');
        }
        return;
      }
      // Solo conectar si el perfil tiene subscriptionStatus válido
      final status = authState.user!.subscriptionStatus;
      if (status != SubscriptionStatus.premium &&
          status != SubscriptionStatus.vip &&
          status != SubscriptionStatus.free &&
          status != SubscriptionStatus.inactive) {
        if (kDebugMode) {
          debugPrint('⚠️ Perfil sin subscriptionStatus válido, no conectando WebSocket');
        }
        return;
      }
      if (kDebugMode) {
        debugPrint('🔌 Intentando conectar WebSocket...');
        debugPrint('   - Estado actual: conectado=${_realtimeService.isConnected}');
      }
      _realtimeService.connect();
      Future.delayed(const Duration(seconds: 2), () {
        if (kDebugMode && mounted) {
          debugPrint('🔍 Estado WebSocket después de 2s: conectado=${_realtimeService.isConnected}');
        }
      });
      _premiumStatusSubscription?.cancel();
      _premiumStatusSubscription = _realtimeService.premiumStatusStream.listen(
        (data) async {
          if (_isDisposed || !mounted) return;

          if (kDebugMode) {
            debugPrint('🎉 Evento premium recibido vía WebSocket: $data');
          }

          // El evento contiene: userId, subscriptionStatus, timestamp
          final subscriptionStatus = data['subscriptionStatus'] as String?;
          final userId = data['userId'] as String?;
          
          if (kDebugMode) {
            debugPrint('📥 Datos del evento: userId=$userId, subscriptionStatus=$subscriptionStatus');
          }
          
          if (subscriptionStatus != null) {
            if (subscriptionStatus == 'active' || subscriptionStatus == 'PREMIUM' || subscriptionStatus == 'VIP') {
              // Cuando recibimos evento de activación premium, actualizar INMEDIATAMENTE
              if (kDebugMode) {
                debugPrint('🎯 Evento de activación premium recibido - Actualizando estado INMEDIATAMENTE');
              }
              
              // Mapear el estado del WebSocket al enum
              final newStatus = subscriptionStatus == 'VIP' 
                  ? SubscriptionStatus.vip 
                  : SubscriptionStatus.premium;
              
              // Actualizar estado local INMEDIATAMENTE sin esperar HTTP
              _updateSubscriptionStatusImmediately(newStatus);
              
              // Resetear flag para permitir mostrar pantalla
              _hasShownActivationScreen = false;
              
              // Verificar y mostrar pantalla INMEDIATAMENTE
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!_isDisposed && mounted) {
                  final authState = ref.read(authStateProvider);
                  final currentUser = authState.user;
                  
                  if (currentUser != null) {
                    await _checkAndShowActivationScreen(currentUser);
                  }
                }
              });
              
              // Refrescar perfil en background para sincronizar (sin bloquear)
              _refreshProfileAndCheckActivation().catchError((e) {
                if (kDebugMode) {
                  debugPrint('⚠️ Error al refrescar perfil en background: $e');
                }
              });
            } else if (subscriptionStatus == 'inactive' || subscriptionStatus == 'INACTIVE' || subscriptionStatus == 'FREE' || subscriptionStatus == 'free') {
              // Cuando se quita el premium, actualizar estado INMEDIATAMENTE
              if (kDebugMode) {
                debugPrint('🔄 Evento de desactivación premium recibido - Actualizando estado INMEDIATAMENTE');
              }
              
              // Mapear el estado del WebSocket al enum
              final newStatus = _mapWebSocketStatusToEnum(subscriptionStatus);
              
              // Actualizar estado local INMEDIATAMENTE sin esperar HTTP
              _updateSubscriptionStatusImmediately(newStatus);
              
              // Resetear flags para permitir detectar premium nuevamente en el futuro
              final activationProvider = ref.read(premiumActivationShownProvider.notifier);
              activationProvider.reset();
              
              _hasShownActivationScreen = false;
              _isPremiumStable = false;
              
              // Navegar INMEDIATAMENTE a la pantalla de premium desactivado
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_isDisposed && mounted) {
                  try {
                    final router = ref.read(goRouterProvider);
                    if (kDebugMode) {
                      debugPrint('✅ Navegando INMEDIATAMENTE a /premium (desactivado)');
                    }
                    router.go('/premium');
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint('❌ Error al navegar a /premium: $e');
                    }
                  }
                }
              });
              
              // Refrescar perfil en background para sincronizar (sin bloquear)
              _refreshProfileAndCheckActivation().catchError((e) {
                if (kDebugMode) {
                  debugPrint('⚠️ Error al refrescar perfil en background: $e');
                }
              });
            } else {
              if (kDebugMode) {
                debugPrint('⚠️ Evento premium con subscriptionStatus desconocido: $subscriptionStatus');
              }
            }
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ Evento premium sin subscriptionStatus válido');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ Error en stream de WebSocket: $error');
          }
        },
      );

      if (kDebugMode) {
        debugPrint('🔌 WebSocket conectado y escuchando eventos premium');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error al conectar WebSocket: $e');
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Cancelar suscripción de WebSocket
    _premiumStatusSubscription?.cancel();
    _premiumStatusSubscription = null;
    // Desconectar WebSocket al hacer logout o dispose
    _realtimeService.disconnect();
    // Limpiar referencias
    _lastRefreshTime = null;
    // Remover observer
    WidgetsBinding.instance.removeObserver(this);
    if (kDebugMode) {
      debugPrint('🧹 PremiumStatusListener - Recursos limpiados correctamente');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Cuando la app vuelve al foreground, refrescar como fallback
    // (por si el WebSocket no estaba conectado o perdió conexión)
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastRefreshTime == null || 
          now.difference(_lastRefreshTime!) >= _minRefreshInterval) {
        if (kDebugMode) {
          debugPrint('📱 App resumida - Refrescando perfil (fallback)...');
        }
        
        // Reconectar WebSocket si no está conectado
        if (!_realtimeService.isConnected) {
          _connectWebSocket();
        }
        
        // Refrescar perfil como fallback
        _refreshProfile();
      }
    }
  }

  /// Refrescar perfil y verificar activación premium en UNA SOLA LLAMADA
  Future<void> _refreshProfileAndCheckActivation() async {
    if (_isDisposed || !mounted || _isRefreshing) {
      return;
    }
    
    _isRefreshing = true;
    
    try {
      final authState = ref.read(authStateProvider);
      if (!authState.isAuthenticated) {
        _isRefreshing = false;
        return;
      }
      
      // Guardar estado previo antes de refrescar
      final statusBeforeRefresh = authState.user?.subscriptionStatus;
      
      if (kDebugMode) {
        debugPrint('🔄 Estado antes de refresh: $statusBeforeRefresh');
      }
      
      // Actualizar perfil
      await ref.read(authStateProvider.notifier).refreshProfile();
      
      if (_isDisposed || !mounted) {
        _isRefreshing = false;
        return;
      }
      
      _lastRefreshTime = DateTime.now();
      
      // Obtener el nuevo estado DESPUÉS del refresh
      final authStateAfter = ref.read(authStateProvider);
      final currentUser = authStateAfter.user;
      final statusAfterRefresh = currentUser?.subscriptionStatus;
      
      if (kDebugMode) {
        debugPrint('✅ Estado después de refresh: $statusAfterRefresh');
        debugPrint('🔄 Cambio detectado: $statusBeforeRefresh -> $statusAfterRefresh');
      }
      
      // Verificar estado premium después del refresh y actualizar UI
      if (currentUser != null) {
        final isPremium = statusAfterRefresh == SubscriptionStatus.premium || 
                         statusAfterRefresh == SubscriptionStatus.vip;
        
        if (isPremium) {
          // Verificar si ya se mostró la pantalla de activación para este usuario
          final userId = currentUser.id;
          final activationProvider = ref.read(premiumActivationShownProvider.notifier);
          final hasShown = await activationProvider.hasShownForUser(userId);
          
          if (kDebugMode) {
            debugPrint('🚀 Usuario es premium después de evento WebSocket');
            debugPrint('   - Ya se mostró pantalla: $hasShown');
            debugPrint('   - UserId: $userId');
          }
          
          // Solo mostrar si NO se ha mostrado antes
          if (!hasShown && !_isNavigating) {
            // Marcar como mostrada ANTES de navegar
            await activationProvider.markAsShown(userId);
            
            _hasShownActivationScreen = true;
            _isPremiumStable = true;
            _previousSubscriptionStatus = statusAfterRefresh;
            _isNavigating = true; // Prevenir navegaciones duplicadas
            
            // Navegar a la pantalla de activación premium UNA SOLA VEZ
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isDisposed && mounted) {
                try {
                  final router = ref.read(goRouterProvider);
                  final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
                  
                  // Solo navegar si no estamos ya en la ruta correcta
                  if (currentLocation != '/premium/activated') {
                    if (kDebugMode) {
                      debugPrint('✅ Navegando a /premium/activated desde evento WebSocket (UNA VEZ)');
                      debugPrint('   - Ruta actual: $currentLocation');
                    }
                    router.go('/premium/activated');
                  } else {
                    if (kDebugMode) {
                      debugPrint('ℹ️ Ya estamos en /premium/activated, no navegar');
                    }
                    _isNavigating = false;
                    return;
                  }
                  
                  // Resetear flag después de un breve delay
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _isNavigating = false;
                  });
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('❌ Error al navegar a /premium/activated: $e');
                  }
                  _isNavigating = false;
                }
              } else {
                _isNavigating = false;
              }
            });
          } else {
            // Ya se mostró antes, solo actualizar estado
            if (kDebugMode) {
              debugPrint('ℹ️ Pantalla de activación ya se mostró antes, no navegar');
            }
            _hasShownActivationScreen = true;
            _isPremiumStable = true;
            _previousSubscriptionStatus = statusAfterRefresh;
          }
        } else {
          // Usuario NO es premium - actualizar UI y flags
          if (kDebugMode) {
            debugPrint('🔄 Usuario ya NO es premium - Actualizando UI a estado no premium');
            debugPrint('   - Estado anterior: $statusBeforeRefresh');
            debugPrint('   - Estado actual: $statusAfterRefresh');
          }
          
          // Si estaba en premium y ahora no, asegurar que se actualice la UI
          final wasPremium = statusBeforeRefresh == SubscriptionStatus.premium || 
                            statusBeforeRefresh == SubscriptionStatus.vip;
          
          if (wasPremium) {
            // El usuario perdió premium - resetear todo y navegar a /premium (pantalla normal)
            // Resetear el flag persistente para que pueda ver la pantalla si vuelve a activar
            final activationProvider = ref.read(premiumActivationShownProvider.notifier);
            activationProvider.reset();
            
            _hasShownActivationScreen = false;
            _isPremiumStable = false;
            _previousSubscriptionStatus = statusAfterRefresh;
            
            if (kDebugMode) {
              debugPrint('🚪 Usuario perdió premium - Navegando a /premium');
              debugPrint('   - Estado anterior: $statusBeforeRefresh');
              debugPrint('   - Estado actual: $statusAfterRefresh');
            }
            
            // Navegar a /premium cuando se pierde premium (muestra PremiumScreen con barra de navegación)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isDisposed && mounted) {
                try {
                  final router = ref.read(goRouterProvider);
                  if (kDebugMode) {
                    debugPrint('✅ Ejecutando navegación a /premium (pantalla normal con barra)');
                  }
                  router.go('/premium');
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('❌ Error al navegar a /premium: $e');
                  }
                }
              }
            });
          } else {
            // Solo actualizar estado previo si no había cambio de premium
            _previousSubscriptionStatus = statusAfterRefresh;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error al refrescar perfil y verificar activación: $e');
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _refreshProfile() async {
    if (_isDisposed || !mounted || _isRefreshing) {
      return;
    }
    
    _isRefreshing = true;
    
    try {
      final authState = ref.read(authStateProvider);
      if (!authState.isAuthenticated) {
        _isRefreshing = false;
        return;
      }
      
      // Guardar estado previo antes de refrescar
      final statusBeforeRefresh = authState.user?.subscriptionStatus;
      
      // Actualizar perfil
      await ref.read(authStateProvider.notifier).refreshProfile();
      
      if (_isDisposed || !mounted) {
        _isRefreshing = false;
        return;
      }
      
      _lastRefreshTime = DateTime.now();
      
      // Verificar si el estado cambió después del refresh
      final authStateAfter = ref.read(authStateProvider);
      final statusAfterRefresh = authStateAfter.user?.subscriptionStatus;
      
      if (statusBeforeRefresh != statusAfterRefresh) {
        if (kDebugMode) {
          debugPrint('✅ Estado premium cambió: $statusBeforeRefresh -> $statusAfterRefresh');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error al refrescar perfil: $e');
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Mapea el estado del WebSocket (string) al enum SubscriptionStatus
  SubscriptionStatus _mapWebSocketStatusToEnum(String status) {
    switch (status.toUpperCase()) {
      case 'PREMIUM':
        return SubscriptionStatus.premium;
      case 'VIP':
        return SubscriptionStatus.vip;
      case 'FREE':
        return SubscriptionStatus.free;
      case 'INACTIVE':
        return SubscriptionStatus.inactive;
      default:
        // Por defecto, si se desactiva, usar free
        return SubscriptionStatus.free;
    }
  }

  /// Actualiza el estado de suscripción inmediatamente sin esperar HTTP
  void _updateSubscriptionStatusImmediately(SubscriptionStatus newStatus) {
    try {
      final authState = ref.read(authStateProvider);
      final currentUser = authState.user;
      
      if (currentUser != null) {
        // Crear nuevo usuario con el estado actualizado
        final updatedUser = currentUser.copyWith(
          subscriptionStatus: newStatus,
        );
        
        // Actualizar estado inmediatamente
        ref.read(authStateProvider.notifier).updateUserImmediately(updatedUser);
        
        // Actualizar estado previo
        _previousSubscriptionStatus = newStatus;
        
        if (kDebugMode) {
          debugPrint('⚡ Estado actualizado INMEDIATAMENTE: $newStatus');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error al actualizar estado inmediatamente: $e');
      }
    }
  }

  /// Verifica si debe mostrar la pantalla de activación y la muestra si es necesario
  Future<void> _checkAndShowActivationScreen(User currentUser) async {
    try {
      final userId = currentUser.id;
      final activationProvider = ref.read(premiumActivationShownProvider.notifier);
      final hasShown = await activationProvider.hasShownForUser(userId);
      
      if (kDebugMode) {
        debugPrint('🎉 Premium activado - Verificando si mostrar pantalla');
        debugPrint('   - Ya se mostró pantalla: $hasShown');
        debugPrint('   - UserId: $userId');
      }
      
      // Solo mostrar si NO se ha mostrado antes y no hay navegación en curso
      if (!hasShown && !_isNavigating) {
        // Marcar como mostrada ANTES de navegar
        await activationProvider.markAsShown(userId);
        
        _hasShownActivationScreen = true;
        _isPremiumStable = true;
        _isNavigating = true; // Prevenir navegaciones duplicadas
        
        if (kDebugMode) {
          debugPrint('🚀 Navegando a pantalla de activación premium (UNA VEZ)...');
        }
        
        // Navegar a la pantalla de activación premium UNA SOLA VEZ
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) {
            try {
              final router = ref.read(goRouterProvider);
              final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
              
              // Solo navegar si no estamos ya en la ruta correcta
              if (currentLocation != '/premium/activated') {
                if (kDebugMode) {
                  debugPrint('✅ Navegando a /premium/activated (UNA VEZ)');
                  debugPrint('   - Ruta actual: $currentLocation');
                }
                router.go('/premium/activated');
              } else {
                if (kDebugMode) {
                  debugPrint('ℹ️ Ya estamos en /premium/activated, no navegar');
                }
                _isNavigating = false;
                return;
              }
              
              // Resetear flag después de un breve delay
              Future.delayed(const Duration(milliseconds: 500), () {
                _isNavigating = false;
              });
            } catch (e) {
              if (kDebugMode) {
                debugPrint('❌ Error al navegar a /premium/activated: $e');
              }
              _isNavigating = false;
            }
          } else {
            _isNavigating = false;
          }
        });
      } else {
        // Ya se mostró antes, solo actualizar estado
        if (kDebugMode) {
          debugPrint('ℹ️ Pantalla de activación ya se mostró antes, no navegar');
        }
        _hasShownActivationScreen = true;
        _isPremiumStable = true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error al verificar estado de activación: $e');
      }
    }
  }

  void _checkPremiumActivation(User? currentUser) {
    if (currentUser == null || _isDisposed || !mounted) {
      return;
    }

    final currentStatus = currentUser.subscriptionStatus;
    final previousStatus = _previousSubscriptionStatus;

    final wasFreeOrInactive = previousStatus == null || 
        previousStatus == SubscriptionStatus.free || 
        previousStatus == SubscriptionStatus.inactive;
    
    final isNowPremium = currentStatus == SubscriptionStatus.premium ||
        currentStatus == SubscriptionStatus.vip;

    if (kDebugMode) {
      debugPrint('🔍 Verificando activación premium:');
      debugPrint('   - Estado anterior: $previousStatus');
      debugPrint('   - Estado actual: $currentStatus');
      debugPrint('   - Era free/inactive: $wasFreeOrInactive');
      debugPrint('   - Es premium ahora: $isNowPremium');
      debugPrint('   - Ya se mostró pantalla: $_hasShownActivationScreen');
    }

    // Mostrar pantalla si hay transición de free/inactive a premium
    if (isNowPremium && !_hasShownActivationScreen && !_isDisposed && mounted) {
      if (wasFreeOrInactive) {
        // Transición clásica: free -> premium
        // Verificar si ya se mostró la pantalla para este usuario
        _checkAndShowActivationScreen(currentUser);
      } else if (isNowPremium) {
        // Usuario ya era premium pero recibió evento (puede ser reconexión)
        if (kDebugMode) {
          debugPrint('ℹ️ Usuario ya era premium, no mostrar pantalla');
        }
      }
    }

    // Actualizar el estado previo y manejar transiciones
    if (_previousSubscriptionStatus != currentStatus) {
      final wasPremium = _previousSubscriptionStatus == SubscriptionStatus.premium || 
                         _previousSubscriptionStatus == SubscriptionStatus.vip;
      
      // Si el usuario se volvió premium estable
      if (isNowPremium && !_isPremiumStable && !_isDisposed) {
        _isPremiumStable = true;
        _previousSubscriptionStatus = currentStatus;
        if (kDebugMode) {
          debugPrint('✅ Premium estable detectado, listener optimizado');
        }
      } else if (!isNowPremium && wasPremium && !_isDisposed) {
        // Si el usuario DEJÓ de ser premium (tenía premium antes y ahora no)
        _isPremiumStable = false;
        _hasShownActivationScreen = false;
        _previousSubscriptionStatus = currentStatus;
        
        if (kDebugMode) {
          debugPrint('🔄 Usuario perdió premium - Actualizando UI a no premium');
          debugPrint('   - Estado anterior: $previousStatus');
          debugPrint('   - Estado actual: $currentStatus');
        }
        
            // Navegar a /premium cuando se pierde premium (muestra PremiumScreen con barra de navegación)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isDisposed && mounted) {
                try {
                  final router = ref.read(goRouterProvider);
                  if (kDebugMode) {
                    debugPrint('🚪 Usuario perdió premium - Navegando a /premium (pantalla normal con barra)');
                  }
                  router.go('/premium');
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('❌ Error al navegar a /premium: $e');
                  }
                }
              }
            });
        
        // Reconectar WebSocket para seguir escuchando cambios
        _connectWebSocket();
      } else {
        // Actualizar estado previo normalmente
        _previousSubscriptionStatus = currentStatus;
        if (!isNowPremium && !_isPremiumStable && !_isDisposed) {
          // Usuario sigue sin premium, mantener listener activo
          if (kDebugMode) {
            debugPrint('ℹ️ Usuario sigue sin premium, listener activo');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return widget.child;
    }
    
    // Escuchar cambios en el estado del usuario
    final authState = _isPremiumStable 
        ? ref.read(authStateProvider) // Leer una vez si es premium estable
        : ref.watch(authStateProvider); // Watch si está esperando activación
    final currentUser = authState.user;

    // Verificar si se activó premium cada vez que cambia el usuario
    final currentStatus = currentUser?.subscriptionStatus;
    final hasStatusChanged = currentStatus != _previousSubscriptionStatus;
    
    if (!_isPremiumStable || hasStatusChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted && currentUser != null) {
          _checkPremiumActivation(currentUser);
        }
      });
    }

    // Reconectar WebSocket si el usuario se autenticó y no está conectado
    if (authState.isAuthenticated && !_realtimeService.isConnected && !_isDisposed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) {
          _connectWebSocket();
        }
      });
    }

    return widget.child;
  }
}

