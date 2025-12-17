import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song_model.dart';

/// Widget de fondo persistente estilo Spotify
/// Mantiene la carátula anterior visible mientras aparece la nueva
/// Con blur global y transición suave
/// ✅ FIX: Oculta inmediatamente la carátula anterior cuando cambia la canción
class PersistentArtworkBackground extends StatefulWidget {
  final Song? currentSong;

  const PersistentArtworkBackground({
    super.key,
    required this.currentSong,
  });

  @override
  State<PersistentArtworkBackground> createState() => _PersistentArtworkBackgroundState();
}

class _PersistentArtworkBackgroundState extends State<PersistentArtworkBackground> {
  Song? _previousSong;
  bool _showPrevious = false;

  @override
  void initState() {
    super.initState();
    _previousSong = widget.currentSong;
  }

  @override
  void didUpdateWidget(PersistentArtworkBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ✅ FIX CRÍTICO: Si cambió la canción, ocultar inmediatamente la carátula anterior
    // Esto evita que se vea la carátula de la canción siguiente durante un seek
    if (oldWidget.currentSong?.id != widget.currentSong?.id) {
      if (oldWidget.currentSong != null && widget.currentSong != null) {
        // Hay un cambio de canción - guardar la anterior pero ocultarla inmediatamente
        setState(() {
          _previousSong = oldWidget.currentSong;
          _showPrevious = false; // ✅ FIX: No mostrar anterior durante cambios de canción
        });
      } else if (widget.currentSong != null) {
        // Nueva canción sin anterior - no mostrar anterior
        setState(() {
          _previousSong = null;
          _showPrevious = false;
        });
      } else {
        // Se removió la canción
        setState(() {
          _previousSong = null;
          _showPrevious = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.currentSong;
    if (song == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // ✅ FIX: Solo mostrar carátula anterior si está activada y es diferente a la actual
        if (_showPrevious && _previousSong != null && _previousSong!.id != song.id)
          Positioned.fill(
            child: RepaintBoundary(
              child: Opacity(
                opacity: 0.3, // Carátula anterior más transparente
                child: _ArtworkImage(
                  key: ValueKey('artwork_prev_${_previousSong!.id}'),
                  song: _previousSong!,
                ),
              ),
            ),
          ),
        // Carátula actual
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

    // ✅ OPTIMIZACIÓN: Calcular tamaño de cache basado en el tamaño de pantalla
    // Esto evita decodificar imágenes grandes cuando solo se muestran a tamaño pequeño
    final screenSize = MediaQuery.of(context).size;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    // Usar el tamaño máximo de pantalla para el fondo (puede ser grande pero limitado)
    final maxScreenDimension = screenSize.width > screenSize.height 
        ? screenSize.width 
        : screenSize.height;
    // Limitar a un máximo razonable (ej: 800px) para evitar uso excesivo de memoria
    final maxCacheSize = (maxScreenDimension * devicePixelRatio * 1.2).round().clamp(0, 1200);

    return CachedNetworkImage(
      key: ValueKey('cached_image_${song.id}_${song.coverArtUrl}'),
      imageUrl: song.coverArtUrl!,
      fit: BoxFit.cover,
      // ✅ FIX CRÍTICO: Agregar parámetros de cache para optimizar memoria
      memCacheWidth: maxCacheSize,
      memCacheHeight: maxCacheSize,
      maxWidthDiskCache: maxCacheSize,
      maxHeightDiskCache: maxCacheSize,
      fadeInDuration: Duration.zero, // Sin fade, ya lo maneja el FadeTransition
      filterQuality: FilterQuality.medium, // Balance entre calidad y rendimiento
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

