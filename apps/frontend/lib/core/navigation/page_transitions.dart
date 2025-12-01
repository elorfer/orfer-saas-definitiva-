import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transiciones de página personalizadas estilo Spotify
/// Animaciones suaves y profesionales para cambios entre pantallas
class SpotifyPageTransitions {
  /// Transición optimizada para SongDetail: Sin transición al volver atrás
  /// CRÍTICO: Evita cualquier reconstrucción durante retroceso para prevenir parpadeo
  static Widget songDetailTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // CRÍTICO: Si estamos volviendo atrás, mostrar inmediatamente sin transición NI reconstrucción
    // Usar RepaintBoundary para evitar repintados innecesarios durante retroceso
    if (animation.status == AnimationStatus.reverse || 
        animation.value == 0.0) {
      // Sin transición = sin parpadeo, sin reconstrucción innecesaria
      return RepaintBoundary(
        child: child,
      );
    }
    
    // Solo animar al avanzar (cuando animation.value > 0)
    // Usar una curva más rápida para reducir tiempo de transición
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut, // Curva rápida
      ),
    );

    // Usar RepaintBoundary para evitar repintados durante la transición
    return RepaintBoundary(
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }

  /// Transición recomendada (alias de songDetailTransition para compatibilidad)
  static Widget recommendedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return songDetailTransition(context, animation, secondaryAnimation, child);
  }

  /// Transición para tabs (alias de songDetailTransition para compatibilidad)
  static Widget tabTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return songDetailTransition(context, animation, secondaryAnimation, child);
  }
}

/// Helper para crear CustomTransitionPage optimizado
/// go_router mantiene el estado automáticamente usando las keys
CustomTransitionPage<T> createCustomTransitionPage<T>({
  required LocalKey key,
  required Widget child,
  required Widget Function(BuildContext, Animation<double>, Animation<double>, Widget) transitionsBuilder,
  Duration transitionDuration = const Duration(milliseconds: 200),
  Duration reverseTransitionDuration = const Duration(milliseconds: 150),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionsBuilder: transitionsBuilder,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
  );
}

/// Helper para crear NoTransitionPage optimizado
/// go_router mantiene el estado automáticamente usando las keys
NoTransitionPage<T> createNoTransitionPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return NoTransitionPage<T>(
    key: key,
    child: child,
  );
}
