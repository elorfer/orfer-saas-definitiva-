import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';

/// Widget de fondo con color sólido profesional (marrón oscuro)
class PersistentArtworkBackground extends StatelessWidget {
  final Song? currentSong;

  const PersistentArtworkBackground({
    super.key,
    required this.currentSong,
  });

  @override
  Widget build(BuildContext context) {
    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    // Fondo con color sólido marrón más oscuro
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeumorphismTheme.coffeeDark.withValues(alpha: 0.95),
            NeumorphismTheme.coffeeDark.withValues(alpha: 1.0),
          ],
        ),
      ),
    );
  }
}
