import 'package:flutter/material.dart';

/// Física de scroll ultra rápida y sensible
/// Scroll extremadamente rápido y responsivo con máxima sensibilidad
class FastScrollPhysics extends ClampingScrollPhysics {
  const FastScrollPhysics({super.parent});

  @override
  FastScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FastScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 🔥 MÁXIMA SENSIBILIDAD: Multiplicador alto para scroll muy rápido
    return super.applyPhysicsToUserOffset(position, offset * 1.8);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Sin rebote, solo clamp suave en los límites
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 🔥 FRICCIÓN MUY BAJA: Scroll más largo y rápido
    final tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity * 1.2, // 🔥 Aumentar velocidad de fling
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  double get minFlingVelocity => 25.0; // 🔥 Velocidad mínima muy baja para respuesta inmediata

  @override
  double get maxFlingVelocity => 15000.0; // 🔥 Velocidad máxima muy alta para scroll rápido
}

