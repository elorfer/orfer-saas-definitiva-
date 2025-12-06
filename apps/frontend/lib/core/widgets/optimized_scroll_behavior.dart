import 'package:flutter/material.dart';

/// 🔥 ScrollBehavior optimizado para máximo rendimiento
/// Elimina efectos pesados y mejora la fluidez del scroll
class OptimizedScrollBehavior extends ScrollBehavior {
  const OptimizedScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // 🔥 Scroll suave y estable
    return const BouncingScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
  }
}

