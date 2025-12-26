import 'package:flutter/material.dart';
import '../theme/neumorphism_theme.dart';

/// Versión simplificada: pinta un fondo plano y mantiene la API para compatibilidad.
class DynamicBackgroundOverlay extends StatelessWidget {
  final String? coverArtUrl;
  final Widget child;

  const DynamicBackgroundOverlay({
    super.key,
    required this.coverArtUrl,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NeumorphismTheme.coffeeMedium,
      child: child,
    );
  }
}

