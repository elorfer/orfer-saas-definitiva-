import 'package:flutter/material.dart';

/// Transiciones de página personalizadas estilo Spotify
/// Animaciones suaves y profesionales para cambios entre pantallas
class SpotifyPageTransitions {
  // Curva suave estilo Spotify
  static const Curve _curve = Curves.easeOutCubic;

  /// Transición por defecto: Fade + Slide (usada en la mayoría de pantallas)
  static Widget fadeSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Animación de fade (opacidad)
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: _curve,
      ),
    );

    // Animación de slide (deslizamiento suave)
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.02), // Pequeño desplazamiento hacia abajo (estilo Spotify)
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: _curve,
      ),
    );

    // Combinar fade + slide
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }

  /// Transición horizontal (para navegación lateral, tipo drawer)
  static Widget horizontalTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(1.0, 0.0); // Entra desde la derecha
    const end = Offset.zero;
    const curve = _curve;

    var tween = Tween(begin: begin, end: end).chain(
      CurveTween(curve: curve),
    );

    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  /// Transición vertical (para modales y pantallas que se abren desde abajo)
  static Widget verticalTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, 1.0); // Entra desde abajo
    const end = Offset.zero;
    const curve = _curve;

    var tween = Tween(begin: begin, end: end).chain(
      CurveTween(curve: curve),
    );

    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  /// Transición de escala (para detalles que se expanden)
  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Animación de escala suave
    final scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: _curve,
      ),
    );

    // Animación de fade
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: _curve,
      ),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: child,
      ),
    );
  }

  /// Transición ultra simple estilo Spotify para tabs (solo fade rápido)
  /// Sin slide, solo fade muy rápido para cambios instantáneos entre tabs
  static Widget tabTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Solo fade rápido, sin slide - estilo Spotify
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut, // Curva más rápida
      ),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: child,
    );
  }

  /// Transición personalizada estilo Spotify (Fade + Slide sutil)
  /// Solo para navegación hacia adelante, no para tabs
  static Widget spotifyTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return fadeSlideTransition(context, animation, secondaryAnimation, child);
  }
}

/// Builder de transiciones personalizado para GoRouter
class SpotifyPageTransitionsBuilder extends PageTransitionsBuilder {
  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) transitionBuilder;

  const SpotifyPageTransitionsBuilder({
    required this.transitionBuilder,
  });

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return transitionBuilder(context, animation, secondaryAnimation, child);
  }
}

