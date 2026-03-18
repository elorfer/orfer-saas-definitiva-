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

  /// Transición genérica de deslizamiento y fade para pantallas del menú lateral
  /// Animación en ambas direcciones (entrada y salida)
  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(1.0, 0.0); // Entra desde la derecha
    const end = Offset.zero;
    const curve = Curves.easeInOutCubic;

    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    final offsetAnimation = animation.drive(tween);

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: curve),
    );

    return RepaintBoundary(
      child: SlideTransition(
        position: offsetAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      ),
    );
  }

  /// Animación optimizada estilo Spotify: Slide + Scale + Opacity para máxima fluidez
  /// Aplicando principios de performance: RepaintBoundary, curvas optimizadas, transformaciones eficientes
  static Widget playerExpansionTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // ✅ MEJORADO: Curva más suave y visible para la expansión
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic, // Curva suave para apertura
      reverseCurve: Curves.easeInCubic, // Curva suave para cierre
    );
    
    // ✅ OPTIMIZACIÓN: AnimatedBuilder con transformaciones combinadas para mejor performance
    // Envuelto en RepaintBoundary para evitar repaints innecesarios
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: curvedAnimation,
        builder: (context, child) {
          final t = curvedAnimation.value;
          
          // ✅ MEJORADO: Slide desde abajo con efecto más pronunciado
          // Usar una curva de easing para que el movimiento sea más natural
          final easedT = Curves.easeOutCubic.transform(t);
          final translateY = (1 - easedT) * MediaQuery.of(context).size.height;
          
          // ✅ MEJORADO: Escala más visible para efecto premium (0.95 a 1.0)
          final scale = 0.95 + (0.05 * easedT);
          
          // ✅ MEJORADO: Opacity con fade más suave
          final opacity = Curves.easeOut.transform(t);
          
          return Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// Helper para crear CustomTransitionPage optimizado
/// go_router mantiene el estado automáticamente usando las keys
CustomTransitionPage<T> createCustomTransitionPage<T>({
  LocalKey? key,
  required Widget child,
  required Widget Function(BuildContext, Animation<double>, Animation<double>, Widget) transitionsBuilder,
  Duration transitionDuration = const Duration(milliseconds: 200),
  Duration reverseTransitionDuration = const Duration(milliseconds: 150),
}) {
  // NOTE: Avoid forcing manual page keys here to prevent duplicate key
  // reservations across multiple navigators. GoRouter provides stable
  // page identity; omitting explicit keys prevents the '!keyReservation.contains(key)'
  // assertion when multiple navigators are active.
  return CustomTransitionPage<T>(
    // Intentionally not setting the key to avoid duplicate reservations
    child: child,
    transitionsBuilder: transitionsBuilder,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
  );
}

/// Helper para crear NoTransitionPage optimizado
/// go_router mantiene el estado automáticamente usando las keys
NoTransitionPage<T> createNoTransitionPage<T>({
  LocalKey? key,
  required Widget child,
}) {
  // See note in createCustomTransitionPage: avoid setting explicit keys
  return NoTransitionPage<T>(
    child: child,
  );
}
