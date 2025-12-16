import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import 'premium_deactivated_screen.dart';
import 'premium_activated_screen.dart';

/// Router que determina qué pantalla premium mostrar según el estado del usuario.
///
/// - Si el usuario ES premium: muestra [PremiumActivatedScreen]
/// - Si el usuario NO es premium: muestra [PremiumDeactivatedScreen]
///
/// La pantalla de activación solo se muestra UNA VEZ cuando se activa premium
/// (gestionado por el listener y el provider de activación).
class PremiumRouterScreen extends ConsumerWidget {
  const PremiumRouterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    // Si el usuario es premium, mostrar la pantalla de activación
    if (_hasActivePremiumSubscription(user)) {
      return const PremiumActivatedScreen();
    }

    // Si no es premium, mostrar la pantalla de premium desactivado
    return const PremiumDeactivatedScreen();
  }

  /// Verifica si el usuario tiene una suscripción premium activa.
  bool _hasActivePremiumSubscription(User? user) {
    if (user == null) return false;

    return user.subscriptionStatus == SubscriptionStatus.premium ||
        user.subscriptionStatus == SubscriptionStatus.vip;
  }
}

