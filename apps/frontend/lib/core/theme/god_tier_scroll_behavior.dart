import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class UnknownScrollBehavior extends ScrollBehavior {
  const UnknownScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class GodTierScrollBehavior extends MaterialScrollBehavior {
  const GodTierScrollBehavior();

  // 🚀 Override correcto del builder de velocity tracker
  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) {
    // Usamos el tracker por defecto que ya es excelente en Flutter 3+
    // SamplingGestureVelocityTracker no está expuesto públicamente o tiene otro nombre.
    // Retornamos el de sistema que es seguro.
    return (PointerEvent event) => VelocityTracker.withKind(event.kind);
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const GodTierScrollPhysics();
  }
}

class GodTierScrollPhysics extends BouncingScrollPhysics {
  const GodTierScrollPhysics({super.parent});

  @override
  GodTierScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return GodTierScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double frictionFactor(double overscrollFraction) => 0.01; // 🚀 LOW FRICTION: Desliza como sobre hielo
}
