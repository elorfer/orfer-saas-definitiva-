/// Ruta modal personalizada con Hero animation optimizada
library;

import 'package:flutter/material.dart';

class HeroModalRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  @override
  final bool barrierDismissible;
  final String? _barrierLabel;
  final Color _barrierColor;
  final Duration _transitionDuration;
  final Duration _reverseTransitionDuration;

  HeroModalRoute({
    required this.builder,
    this.barrierDismissible = true,
    String? barrierLabel,
    Color barrierColor = Colors.black54,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Duration reverseTransitionDuration = const Duration(milliseconds: 250),
    super.settings,
  }) : _barrierLabel = barrierLabel,
       _barrierColor = barrierColor,
       _transitionDuration = transitionDuration,
       _reverseTransitionDuration = reverseTransitionDuration;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => _barrierColor;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Curva suave para la animación
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: curvedAnimation,
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
    return builder(context);
  }
}

/// Extension para facilitar el uso
extension HeroModalRouteExtension on NavigatorState {
  Future<T?> pushHeroModal<T extends Object?>(
    WidgetBuilder builder, {
    bool barrierDismissible = true,
    Color barrierColor = Colors.black54,
    Duration? transitionDuration,
    String? routeName,
  }) {
    return push<T>(
      HeroModalRoute<T>(
        builder: builder,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        transitionDuration: transitionDuration ?? const Duration(milliseconds: 300),
        settings: RouteSettings(name: routeName),
      ),
    );
  }
}
