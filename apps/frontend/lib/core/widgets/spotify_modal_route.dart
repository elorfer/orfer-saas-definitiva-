import 'package:flutter/material.dart';

/// Ruta personalizada para transición fluida estilo Spotify/Apple Music
/// El modal aparece DESDE el MiniPlayer con animación suave y optimizada para GPU
class SpotifyModalRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final bool _barrierDismissible;
  final Color? _barrierColor;
  final String? _barrierLabel;
  final bool _maintainState;

  SpotifyModalRoute({
    required this.builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool maintainState = true,
    super.settings,
  }) : _barrierDismissible = barrierDismissible,
       _barrierColor = barrierColor,
       _barrierLabel = barrierLabel,
       _maintainState = maintainState;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  Color? get barrierColor => _barrierColor ?? Colors.black54;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  bool get maintainState => _maintainState;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280); // Rápida pero suave (250-320ms)

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Transición optimizada para GPU: SlideTransition + FadeTransition
    // Estas animaciones se ejecutan en el GPU thread para fluidez sin lag
    // El modal aparece desde abajo (donde está el MiniPlayer) hacia arriba
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0), // Empieza desde abajo (posición del MiniPlayer)
        end: Offset.zero, // Termina en la parte superior
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic, // Curva suave estilo Spotify/Apple Music
        reverseCurve: Curves.easeInCubic,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Remover padding superior para que el modal ocupe toda la pantalla
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Builder(
        builder: builder,
      ),
    );
  }
}



