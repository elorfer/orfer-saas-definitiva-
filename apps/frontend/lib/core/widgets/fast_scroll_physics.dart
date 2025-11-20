import 'package:flutter/material.dart';

/// Física de scroll optimizada para velocidad y fluidez
/// Similar a ClampingScrollPhysics pero con mejor sensibilidad
class FastScrollPhysics extends ClampingScrollPhysics {
  const FastScrollPhysics({super.parent});

  @override
  FastScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FastScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Aumentar la sensibilidad del scroll (multiplicador 1.2 para mayor velocidad)
    return super.applyPhysicsToUserOffset(position, offset * 1.2);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Permitir scroll más rápido y fluido
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Reducir la fricción para scroll más rápido
    final tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity * 0.9, // Reducir fricción (de 1.0 a 0.9)
        tolerance: tolerance,
      );
    }
    return null;
  }
}

