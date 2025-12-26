import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/song_model.dart';

/// Dirección del swipe para animaciones
enum SwipeDirection { left, right }

/// Widget SIMPLIFICADO de portada - Solo muestra la portada actual (SIN SWIPE)
class AlbumSwiper extends StatelessWidget {
  final Song currentSong;
  final Function(SwipeDirection direction) onSwipe;

  const AlbumSwiper({
    super.key,
    required this.currentSong,
    required this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final coverSize = screenWidth * 0.95;

    return SizedBox(
      height: coverSize,
      child: Container(
        height: coverSize,
        width: coverSize,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 50,
              spreadRadius: -5,
              offset: const Offset(0, 25),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          child: _AlbumCoverImage(song: currentSong),
        ),
      ),
    );
  }
}

/// Widget simple para la imagen de la portada
class _AlbumCoverImage extends StatelessWidget {
  final Song song;

  const _AlbumCoverImage({required this.song});

  @override
  Widget build(BuildContext context) {
    if (song.coverArtUrl == null || song.coverArtUrl!.isEmpty) {
      return Container(
        key: ValueKey('placeholder_${song.id}'),
        color: Colors.grey[800],
        child: const Center(
          child: Icon(Icons.music_note, color: Colors.white70, size: 80),
        ),
      );
    }

    return CachedNetworkImage(
      // ✅ FIX: Usar key único por canción para forzar actualización cuando cambia la canción
      key: ValueKey('album_cover_${song.id}_${song.coverArtUrl}'),
      imageUrl: song.coverArtUrl!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: Duration.zero,
      // ✅ FIX: Usar useOldImageOnUrlChange para evitar mostrar imagen anterior durante la carga
      useOldImageOnUrlChange: false,
      placeholder: (context, url) => Container(
        key: ValueKey('placeholder_${song.id}'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[850] ?? Colors.grey[800]!,
              Colors.grey[900] ?? Colors.grey[800]!,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white.withValues(alpha: 0.3),
            size: 60,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        key: ValueKey('error_${song.id}'),
        color: Colors.grey[800],
        child: const Center(
          child: Icon(Icons.music_note, color: Colors.white70, size: 80),
        ),
      ),
    );
  }
}

/// Widget animado para el título de la canción
class SongTitleAnimated extends StatelessWidget {
  final String title;
  final SwipeDirection? direction;

  const SongTitleAnimated({
    super.key,
    required this.title,
    this.direction,
  });

  @override
  Widget build(BuildContext context) {
    if (direction == null) {
      return Text(
        title,
        key: ValueKey(title),
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final offsetX = direction == SwipeDirection.left ? 40.0 : -40.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: Offset(offsetX / 100, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text(
        title,
        key: ValueKey(title),
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Widget animado para el nombre del artista
class ArtistAnimated extends StatelessWidget {
  final String artist;
  final SwipeDirection? direction;

  const ArtistAnimated({
    super.key,
    required this.artist,
    this.direction,
  });

  @override
  Widget build(BuildContext context) {
    if (direction == null) {
      return Text(
        artist,
        key: ValueKey(artist),
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final offsetX = direction == SwipeDirection.left ? 30.0 : -30.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: Offset(offsetX / 100, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text(
        artist,
        key: ValueKey(artist),
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
