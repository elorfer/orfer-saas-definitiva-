
import 'package:flutter/material.dart';

class CustomProfileDrawerRoute extends PageRouteBuilder {
  final Widget child;

  CustomProfileDrawerRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          opaque: false,
          barrierColor: Colors.black54,
          barrierDismissible: true,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Curva fluida tipo iOS/Premium
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            );

            // ⚡ OPTIMIZACIÓN EXTREMA: Aislar la transición en una capa de composición (RepaintBoundary)
            // Esto evita que Flutter redibuje el contenido del Drawer en cada frame de la animación.
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: RepaintBoundary( // 🚀 CORE FIX: Cache de la textura animada
                 child: _SwipeToCloseWrapper(child: child),
              ),
            );
          },
        );
}

class _SwipeToCloseWrapper extends StatefulWidget {
  final Widget child;
  const _SwipeToCloseWrapper({required this.child});

  @override
  State<_SwipeToCloseWrapper> createState() => _SwipeToCloseWrapperState();
}

class _SwipeToCloseWrapperState extends State<_SwipeToCloseWrapper> {
  double _totalDrag = 0;
  bool _hasPopped = false; // 🚀 FIX: Flag para evitar múltiples pops

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (_) {
         _totalDrag = 0;
         _hasPopped = false;
      },
      onHorizontalDragUpdate: (details) {
        if (_hasPopped) return; // Ya se cerró, ignorar resto del gesto

        _totalDrag += details.delta.dx;
        // Si arrastró más de 50px a la izquierda acumulados, cerrar
        if (_totalDrag < -50) {
           _triggerPop();
        }
      },
      onHorizontalDragEnd: (details) {
        if (_hasPopped) return;

        // O si hizo un "flick" rápido a la izquierda
        if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
           _triggerPop();
        }
      },
      child: widget.child,
    );
  }

  void _triggerPop() {
    if (mounted && !_hasPopped) {
      _hasPopped = true;
      Navigator.of(context).pop();
    }
  }
}
