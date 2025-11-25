import 'package:flutter/material.dart';

/// Constante para el ángulo de rotación hacia arriba (-90 grados en radianes)
const double _playIconUpwardRotation = -1.5708; // -π/2

/// Widget optimizado para mostrar el icono de play
/// Se rota hacia arriba cuando la canción está reproduciéndose
class PlayButtonIcon extends StatelessWidget {
  final bool isPlaying;
  final Color color;
  final double size;
  final IconData icon;

  const PlayButtonIcon({
    super.key,
    required this.isPlaying,
    required this.color,
    required this.size,
    this.icon = Icons.play_arrow_rounded,
  });

  @override
  Widget build(BuildContext context) {
    // Optimización: solo aplicar Transform si es necesario
    if (isPlaying) {
      return Transform.rotate(
        angle: _playIconUpwardRotation,
        child: Icon(
          icon,
          color: color,
          size: size,
        ),
      );
    }
    
    return Icon(
      icon,
      color: color,
      size: size,
    );
  }
}

