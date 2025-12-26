import 'package:flutter/material.dart';

/// 🔥 Física de scroll personalizada para scroll suave y profesional
/// - Desaceleración lenta y natural cuando se suelta el dedo
/// - Mejor sensibilidad al toque
/// - Fricción ajustada para movimiento más fluido
/// - Respeta límites estrictamente
class SmoothScrollPhysics extends ClampingScrollPhysics {
  const SmoothScrollPhysics({super.parent});

  @override
  SmoothScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0; // 🔥 Reducido para mejor sensibilidad

  // 🔥 Fricción personalizada para desaceleración más lenta y más velocidad
  // Balance entre fluidez y responsividad en tiempo real
  static const double _customFriction = 0.008; // 🔥 Aumentada ligeramente para mejor responsividad en tiempo real

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Si la velocidad es muy baja, no crear simulación (detener inmediatamente)
    final tolerance = toleranceFor(position);
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }

    // 🔥 FIX: Usar ClampingScrollSimulation que automáticamente respeta los límites
    // pero con nuestra fricción personalizada
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: _customFriction, // 🔥 Fricción muy baja = desaceleración más lenta
      tolerance: tolerance,
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 🔥 FIX: Aplicar offset inmediatamente sin retrasos para scroll en tiempo real
    // Usar la implementación base de ClampingScrollPhysics que es más responsiva
    return super.applyPhysicsToUserOffset(position, offset);
  }
}






