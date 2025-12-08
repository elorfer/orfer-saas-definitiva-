import 'package:flutter/material.dart';

/// Física de scroll premium y suave
/// Desaceleración estilo iOS con movimientos más naturales
/// Ideal para apps profesionales - ZERO lags
class SmoothScrollPhysics extends ClampingScrollPhysics {
  const SmoothScrollPhysics({super.parent});

  @override
  SmoothScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // ✅ TOLERANCIA ESTRICTA: Para detenerse suavemente sin rebotes
    final tolerance = Tolerance(
      velocity: 0.0001, // ✅ Muy estricto para detenerse rápido y evitar rebotes
      distance: 0.0001, // ✅ Muy estricto para detenerse rápido y evitar rebotes
    );
    
    // Si la velocidad es muy baja, no crear simulación (evita rebotes)
    if (velocity.abs() < 50) return null;
    
    // ✅ Simulación con tolerancia estricta para detenerse sin rebotes
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
      friction: 0.15, // ✅ Fricción aumentada para detenerse más rápido y suave
    );
  }
}

/// Alias para compatibilidad con código existente
@Deprecated('Usar SmoothScrollPhysics en su lugar')
class FastScrollPhysics extends SmoothScrollPhysics {
  const FastScrollPhysics({super.parent});
}

