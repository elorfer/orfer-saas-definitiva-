import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song_model.dart';

/// Widget de fondo persistente estilo Spotify
/// Mantiene la carátula anterior visible mientras aparece la nueva
/// Con blur global y transición suave
class PersistentArtworkBackground extends StatelessWidget {
  final Song? currentSong;

  const PersistentArtworkBackground({
    super.key,
    required this.currentSong,
  });

  @override
  Widget build(BuildContext context) {
    final song = currentSong;
    if (song == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: _ArtworkImage(
              key: ValueKey('artwork_${song.id}'),
              song: song,
            ),
          ),
        ),
        // Blur removido para máxima fluidez: solo overlay translúcido
        Positioned.fill(
          child: RepaintBoundary(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget optimizado para mostrar la imagen de la carátula
class _ArtworkImage extends StatelessWidget {
  final Song song;

  const _ArtworkImage({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    if (song.coverArtUrl == null || song.coverArtUrl!.isEmpty) {
      return Container(
        color: const Color(0xFF2B1E13),
        child: const Center(
          child: Icon(Icons.music_note, color: Colors.white30, size: 80),
        ),
      );
    }

    return CachedNetworkImage(
      key: ValueKey('cached_image_${song.id}_${song.coverArtUrl}'),
      imageUrl: song.coverArtUrl!,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero, // Sin fade, ya lo maneja el FadeTransition
      placeholder: (context, url) => Container(
        color: const Color(0xFF2B1E13),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF2B1E13),
        child: const Center(
          child: Icon(Icons.music_note, color: Colors.white30, size: 80),
        ),
      ),
    );
  }
}

