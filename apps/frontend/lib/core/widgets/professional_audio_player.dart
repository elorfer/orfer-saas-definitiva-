import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import 'stable_image_widget.dart';
import '../utils/url_normalizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'favorite_button.dart';

/// Widget separado para el fondo de imagen (evita rebuilds)
class _BackgroundImageWidget extends StatelessWidget {
  final Song song;

  const _BackgroundImageWidget({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    return StableImageWidget(
      imageUrl: song.coverArtUrl,
      fit: BoxFit.cover,
      errorWidget: Container(color: NeumorphismTheme.background),
      placeholder: Container(color: NeumorphismTheme.background),
    );
  }
}

/// Widget separado para la carátula del álbum (evita rebuilds)
class _AlbumCoverWidget extends StatelessWidget {
  final Song song;

  const _AlbumCoverWidget({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    // Sin logs para mejor rendimiento
    
    if (song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty) {
      final normalizedUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl);
      
      // Calcular memCache basado en tamaño de pantalla y devicePixelRatio
      final mediaQuery = MediaQuery.of(context);
      final screenWidth = mediaQuery.size.width;
      final devicePixelRatio = mediaQuery.devicePixelRatio;
      // Tamaño de la imagen: 85% del ancho de pantalla
      final imageSize = screenWidth * 0.85;
      final memCacheSize = (imageSize * devicePixelRatio).round();
      
      return CachedNetworkImage(
        imageUrl: normalizedUrl!,
        fit: BoxFit.cover,
        // Optimización: límite de memoria para imágenes grandes
        memCacheWidth: memCacheSize,
        memCacheHeight: memCacheSize,
        maxWidthDiskCache: memCacheSize,
        maxHeightDiskCache: memCacheSize,
        // 🎭 OPTIMIZADO PARA HERO ANIMATION - Sin transiciones que interfieran
        fadeInDuration: Duration.zero, // Sin fade para Hero suave
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        // Cache optimizado
        cacheKey: normalizedUrl,
        httpHeaders: const {
          'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
          'Cache-Control': 'max-age=86400', // 24 horas
        },
        // Configuración para Hero animation perfecta
        useOldImageOnUrlChange: true,
        filterQuality: FilterQuality.medium,
        placeholder: (context, url) => Container(
          color: Colors.white10,
          child: const Center(
            child: Icon(Icons.music_note, color: Colors.white30, size: 80),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.white10,
          child: const Center(
            child: Icon(Icons.music_note, color: Colors.white, size: 80),
          ),
        ),
      );
    }
    
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white, size: 80),
      ),
    );
  }
}

/// Widget profesional de reproductor de audio con diseño inmersivo
class ProfessionalAudioPlayer extends ConsumerStatefulWidget {
  const ProfessionalAudioPlayer({super.key});

  @override
  ConsumerState<ProfessionalAudioPlayer> createState() => _ProfessionalAudioPlayerState();
}

class _ProfessionalAudioPlayerState
    extends ConsumerState<ProfessionalAudioPlayer>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      // 🚀 USAR EL PROVIDER UNIFICADO CORREGIDO - ÚNICA FUENTE DE VERDAD
      // Optimización: usar select para escuchar solo los campos necesarios
      final currentSong = ref.watch(
        unifiedAudioProviderFixed.select((state) => state.currentSong),
      );
      final isPlaying = ref.watch(
        unifiedAudioProviderFixed.select((state) => state.isPlaying),
      );
      
      if (currentSong == null) {
        return const SizedBox.shrink();
      }

      // Crear la UI estática una sola vez
      return _StaticPlayerUI(
        song: currentSong,
        isPlaying: isPlaying,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ProfessionalAudioPlayer] Error en build: $e', stackTrace);
      return const SizedBox.shrink();
    }
  }
}

/// Widget estático que no se reconstruye con cada actualización de progreso
class _StaticPlayerUI extends ConsumerWidget {
  final Song song;
  final bool isPlaying;

  const _StaticPlayerUI({
    required this.song,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Fondo dinámico con blur - ESTÁTICO
          Positioned.fill(
            child: _BackgroundImageWidget(
              key: ValueKey('background_${song.id}'), // 🔑 KEY ESTABLE PARA FONDO
              song: song,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),

          // 2. Contenido seguro - ESTÁTICO
          SafeArea(
            child: Column(
              children: [
                // Header - ESTÁTICO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: Text(
                      "REPRODUCIENDO AHORA",
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Carátula - ESTÁTICA
                Hero(
                  tag: 'album_cover_hero', // 🎭 ÚNICO Hero tag para transición suave
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: MediaQuery.of(context).size.width * 0.85,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _AlbumCoverWidget(
                        key: ValueKey('album_cover_${song.id}'), // 🔑 KEY ESTABLE PARA EL WIDGET COMPLETO
                        song: song,
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Info y Controles - ESTÁTICOS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      // Título y Artista - ESTÁTICO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title ?? 'Sin título',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  song.artist?.displayName ?? 'Artista desconocido',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          FavoriteButton(
                            songId: song.id,
                            iconColor: Colors.white,
                            iconSize: 28,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Progress Control - DINÁMICO usando provider unificado
                      const _ProgressControl(),
                      
                      const SizedBox(height: 32),
                      
                      // Controles Principales - ESTÁTICOS (excepto el botón play/pause)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 24),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 42),
                            onPressed: () async {
                              await ref.read(unifiedAudioProviderFixed.notifier).previous();
                            },
                          ),
                          // Solo el botón play/pause se actualiza - observa el estado directamente
                          _PlayPauseButton(ref: ref),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 42),
                            onPressed: () async {
                              await ref.read(unifiedAudioProviderFixed.notifier).next();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.repeat_rounded, color: Colors.white, size: 24),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget separado para el botón play/pause que se actualiza independientemente
/// Observa el estado directamente del provider para sincronización perfecta
class _PlayPauseButton extends ConsumerWidget {
  final WidgetRef ref;

  const _PlayPauseButton({
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observar isPlaying directamente del provider para actualización inmediata
    final isPlaying = ref.watch(isPlayingProviderFixed);
    
    return GestureDetector(
      onTap: () async {
        try {
          await ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
        } catch (e) {
          AppLogger.error('[PlayPauseButton] Error: $e');
        }
      },
      child: RepaintBoundary(
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.black,
            size: 36,
          ),
        ),
      ),
    );
  }
}

/// Widget separado para el control de progreso usando provider unificado
class _ProgressControl extends ConsumerStatefulWidget {
  const _ProgressControl();

  @override
  ConsumerState<_ProgressControl> createState() => _ProgressControlState();
}

class _ProgressControlState extends ConsumerState<_ProgressControl> {
  bool _isDraggingSeek = false;
  Duration? _dragPosition;

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 USAR DIRECTAMENTE EL PROVIDER UNIFICADO CORREGIDO - ÚNICA FUENTE DE VERDAD
    // Optimización: usar select para escuchar solo los campos necesarios
    final currentPositionRaw = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentPosition),
    );
    final totalDuration = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.totalDuration),
    );
    final progress = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.progress),
    );
    
    // Usar posición de drag si está activa, sino usar la posición actual
    final currentPosition = _isDraggingSeek && _dragPosition != null
        ? _dragPosition!
        : currentPositionRaw;

    final currentDuration = totalDuration;

    // 🚀 PROGRESO ULTRA FLUIDO - Usar el progreso calculado del provider
    final finalProgress = _isDraggingSeek && _dragPosition != null
        ? (currentDuration.inMilliseconds > 0
            ? (_dragPosition!.inMilliseconds / currentDuration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0)
        : progress;
    final clampedProgress = finalProgress.clamp(0.0, 1.0);

    return Column(
      children: [
            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3), // Reducido de 6 a 3
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8), // Reducido de 12 a 8
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.1),
                // 🚀 FLUIDEZ ULTRA PROFESIONAL
                trackShape: const RoundedRectSliderTrackShape(), // Bordes redondeados
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(), // Indicador suave
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50), // 🎯 Transición ultra rápida
                curve: Curves.easeOutCubic,
                child: Slider(
                  value: clampedProgress,
                onChanged: (value) {
                  if (currentDuration.inSeconds > 0) {
                    setState(() {
                      _isDraggingSeek = true;
                      _dragPosition = Duration(
                        seconds: (value * currentDuration.inSeconds).toInt(),
                      );
                    });
                  }
                },
                onChangeEnd: (value) async {
                  try {
                    if (currentDuration.inSeconds > 0) {
                      final seekPosition = Duration(
                        seconds: (value * currentDuration.inSeconds).toInt(),
                      );
                      await ref.read(unifiedAudioProviderFixed.notifier).seek(seekPosition);
                      if (!mounted) return;
                      setState(() {
                        _isDraggingSeek = false;
                        _dragPosition = null;
                      });
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _isDraggingSeek = false;
                      _dragPosition = null;
                    });
                  }
                },
                ),
              ),
            ),
            
            // Tiempos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(currentPosition),
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _formatDuration(currentDuration),
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
  }
}

