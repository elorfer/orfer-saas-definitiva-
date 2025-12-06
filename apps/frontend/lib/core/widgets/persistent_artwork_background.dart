import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song_model.dart';

/// Widget de fondo persistente estilo Spotify
/// Mantiene la carátula anterior visible mientras aparece la nueva
/// Con blur global y transición suave
class PersistentArtworkBackground extends StatefulWidget {
  final Song? currentSong;
  final Song? previousSong;

  const PersistentArtworkBackground({
    super.key,
    required this.currentSong,
    this.previousSong,
  });

  @override
  State<PersistentArtworkBackground> createState() =>
      _PersistentArtworkBackgroundState();
}

class _PersistentArtworkBackgroundState
    extends State<PersistentArtworkBackground>
    with SingleTickerProviderStateMixin {
  Song? _currentArtwork;
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _currentArtwork = widget.currentSong;

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Más rápido para transiciones fluidas
    );
    _fadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic, // Curva más suave
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.2, 0), // Deslizar hacia la izquierda (salir)
    ).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(PersistentArtworkBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ Detectar cambio de canción
    if (oldWidget.currentSong?.id != widget.currentSong?.id &&
        widget.currentSong != null) {
      _handleArtworkChange();
    }
  }

  /// Manejar cambio de carátula sin mostrar la anterior
  void _handleArtworkChange() {
    if (_isTransitioning) return;

    setState(() {
      _isTransitioning = true;
      // ✅ NO guardar carátula anterior para evitar parpadeo
      // Solo actualizar la carátula actual directamente
      _currentArtwork = widget.currentSong;
      // ✅ Resetear animación para nueva transición
      _transitionController.reset();
      
      // ✅ Configurar animación de entrada desde la derecha
      _slideAnimation = Tween<Offset>(
        begin: const Offset(1.2, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _transitionController,
          curve: Curves.easeOutCubic,
        ),
      );
    });

    // ✅ Iniciar transición inmediatamente
    Future.microtask(() {
      if (mounted) {
        _transitionController.forward().then((_) {
          if (mounted) {
            setState(() {
              _isTransitioning = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ✅ Solo mostrar la carátula actual (sin mostrar la anterior)
        if (_currentArtwork != null)
          Positioned.fill(
            child: _isTransitioning
                ? SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: RepaintBoundary(
                        child: _ArtworkImage(song: _currentArtwork!),
                      ),
                    ),
                  )
                : RepaintBoundary(
                    child: _ArtworkImage(song: _currentArtwork!),
                  ),
          ),

        // ✅ Blur global (encima de la carátula)
        Positioned.fill(
          child: RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
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

  const _ArtworkImage({required this.song});

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

