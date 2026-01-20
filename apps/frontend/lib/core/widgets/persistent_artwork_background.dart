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
        // ✅ FIX: Usar el color de fondo exacto del tema (Casi Negro 0xFF1E1B19)
        color: NeumorphismTheme.background,
      ),
    );
  }
}
