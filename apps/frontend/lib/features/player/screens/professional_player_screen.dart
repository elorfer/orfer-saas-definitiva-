import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/optimized_cached_image.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/services/advanced_audio_engine.dart';
import '../../../core/services/player_navigation_service.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/professional_seekbar.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎵 PROFESSIONAL PLAYER SCREEN - PANTALLA DE REPRODUCTOR PROFESIONAL
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Características:
/// - Fondo con paleta dinámica (extraída de carátula)
/// - Animaciones suaves de transición
/// - Seekbar profesional con suavizado
/// - Controles con feedback háptico
/// - Blur de fondo elegante
/// - Soporte para gestos de swipe
/// ═══════════════════════════════════════════════════════════════════════════

class ProfessionalPlayerScreen extends ConsumerStatefulWidget {
  const ProfessionalPlayerScreen({super.key});

  @override
  ConsumerState<ProfessionalPlayerScreen> createState() => _ProfessionalPlayerScreenState();
}

class _ProfessionalPlayerScreenState extends ConsumerState<ProfessionalPlayerScreen>
    with SingleTickerProviderStateMixin {
  // Animación de entrada
  late AnimationController _entryController;


  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(audioEngineStateProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    // 🛡️ PROTECCIÓN CRÍTICA: Cerrar reproductor si hay un anuncio
    // El AdsMiniPlayer tomará el control de la UI durante los anuncios
    if (stateAsync.hasValue && stateAsync.value!.isPlayingAd) {
      // Cerrar el reproductor profesional para mostrar el AdsMiniPlayer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          PlayerNavigationService.closeFullPlayer(context: context, ref: ref);
        }
      });
      // Mientras se cierra, mostrar el estado actual sin parpadeos
      return _buildPlayer(context, stateAsync.value!, palette);
    }

    // ⚡ FIX: Evitar flash negro usando datos previos si existen (skipLoadingOnReload implícito)
    if (stateAsync.hasValue) {
      return _buildPlayer(context, stateAsync.value!, palette);
    }

    return stateAsync.when(
      data: (state) => _buildPlayer(context, state, palette),
      loading: () => _buildLoadingState(context, palette),
      error: (e, _) => _buildErrorState(context, e),
    );
  }

  Widget _buildPlayer(
    BuildContext context,
    AudioEngineState state,
    DynamicPalette palette,
  ) {
    // ✅ FIX: Usar lastConfirmedSong para evitar parpadeos durante transiciones o inserciones
    // lastConfirmedSong se actualiza de forma atómica y evita estados intermedios nulos
    final song = state.lastConfirmedSong ?? state.currentSong;
    if (song == null) return _buildEmptyState(context);

    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo con gradiente dinámico (no animado por opacidad heredada)
            _buildDynamicBackground(palette, coverUrl),

            // Contenido (sin animaciones temporales para evitar herencia de opacidad)
            SafeArea(
              child: Column(
                    children: [
                      // Header con botón de cerrar
                      _buildHeader(context),

                      const Spacer(flex: 1),

                      // Carátula
                      _buildCoverArt(coverUrl, palette),

                      const Spacer(flex: 1),

                      // Información de la canción
                      _buildSongInfo(song, palette),

                      const SizedBox(height: 32),

                      // Seekbar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: ProfessionalSeekbar(
                          height: 4,
                          thumbRadius: 6,
                          showTimes: true,
                          progressColor: palette.vibrant,
                          bufferColor: palette.muted.withValues(alpha: 0.3),
                          backgroundColor: palette.darkMuted.withValues(alpha: 0.2),
                          timeStyle: TextStyle(
                            color: palette.onBackground.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Controles principales
                      _buildMainControls(state, palette),

                      const SizedBox(height: 24),

                      // Controles secundarios
                      _buildSecondaryControls(state, palette),

                      const Spacer(flex: 1),
                    ],
                  ),
                ),
      ],
    ),
  ),
);
  }

  /// Fondo dinámico con blur y gradiente
  Widget _buildDynamicBackground(DynamicPalette palette, String? coverUrl) {
    // Reemplazado por un fondo plano para evitar problemas con ImageFiltered/blur
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: palette.background,
      ),
      child: const SizedBox.expand(),
    );
  }

  /// Header con botón de cerrar
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          // Botón cerrar (swipe down)
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            color: Colors.white,
            onPressed: () => PlayerNavigationService.closeFullPlayer(context: context, ref: ref),
          ),

          // Título
          const Text(
            'Reproduciendo',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Menú
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            color: Colors.white,
            onPressed: () {
              // TODO: Mostrar menú de opciones
            },
          ),
        ],
      ),
    );
  }

  /// Carátula del álbum
  Widget _buildCoverArt(String? coverUrl, DynamicPalette palette) {
    return Hero(
      tag: 'player_cover',
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: palette.dominant.withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: coverUrl != null
              ? OptimizedCachedImage(
                  imageUrl: coverUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: null, // ⚡ FIX: Quitar "tarjeta" de carga (skeleton). Dejar ver el fondo o imagen previa.
                  errorWidget: Container(
                    color: Colors.transparent, // Error transparente para no ensuciar
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 80,
                      color: palette.onBackground.withValues(alpha: 0.3),
                    ),
                  ),
                )
              : Container(
                  color: Colors.transparent, // No cover -> Transparente
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 80,
                    color: palette.onBackground.withValues(alpha: 0.3),
                  ),
                ),
        ),
      ),
    );
  }

  /// Información de la canción
  Widget _buildSongInfo(dynamic song, DynamicPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Título
          Text(
            song.title ?? 'Sin título',
            style: TextStyle(
              color: palette.onBackground,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Artista
          Text(
            song.artist?.displayName ?? song.artist?.name ?? 'Artista desconocido',
            style: TextStyle(
              color: palette.onBackground.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Controles principales (anterior, play/pause, siguiente)
  Widget _buildMainControls(AudioEngineState state, DynamicPalette palette) {
    final engine = ref.read(advancedAudioEngineProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Anterior
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          size: 40,
          color: palette.onBackground,
          enabled: state.hasPrevious || state.position.inSeconds > 3,
          onPressed: () {
            HapticFeedback.lightImpact();
            engine.previous();
          },
        ),

        const SizedBox(width: 24),

        // Play/Pause
        _PlayPauseButton(
          isPlaying: state.isPlaying,
          isBuffering: state.isBuffering,
          color: palette.vibrant,
          onPressed: () {
            HapticFeedback.mediumImpact();
            engine.togglePlayPause();
          },
        ),

        const SizedBox(width: 24),

        // Siguiente
        _ControlButton(
          icon: Icons.skip_next_rounded,
          size: 40,
          color: palette.onBackground,
          enabled: state.hasNext,
          onPressed: () {
            HapticFeedback.lightImpact();
            engine.next();
          },
        ),
      ],
    );
  }

  /// Controles secundarios (shuffle, repeat, etc.)
  Widget _buildSecondaryControls(AudioEngineState state, DynamicPalette palette) {
    final engine = ref.read(advancedAudioEngineProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Shuffle
          _ControlButton(
            icon: Icons.shuffle_rounded,
            size: 24,
            color: state.shuffleEnabled
                ? palette.vibrant
                : palette.onBackground.withValues(alpha: 0.5),
            onPressed: () {
              HapticFeedback.selectionClick();
              engine.toggleShuffle();
            },
          ),

          // Repeat
          _ControlButton(
            icon: _getRepeatIcon(state.loopMode),
            size: 24,
            color: state.loopMode != LoopMode.off
                ? palette.vibrant
                : palette.onBackground.withValues(alpha: 0.5),
            onPressed: () {
              HapticFeedback.selectionClick();
              _cycleLoopMode(engine, state.loopMode);
            },
          ),

          // Favorito (placeholder)
          _ControlButton(
            icon: Icons.favorite_border_rounded,
            size: 24,
            color: palette.onBackground.withValues(alpha: 0.5),
            onPressed: () {
              HapticFeedback.selectionClick();
              // TODO: Toggle favorito
            },
          ),

          // Cola
          _ControlButton(
            icon: Icons.queue_music_rounded,
            size: 24,
            color: palette.onBackground.withValues(alpha: 0.5),
            onPressed: () {
              HapticFeedback.selectionClick();
              // TODO: Mostrar cola
            },
          ),
        ],
      ),
    );
  }

  IconData _getRepeatIcon(LoopMode mode) {
    switch (mode) {
      case LoopMode.one:
        return Icons.repeat_one_rounded;
      case LoopMode.all:
        return Icons.repeat_rounded;
      case LoopMode.off:
        return Icons.repeat_rounded;
    }
  }

  void _cycleLoopMode(AdvancedAudioEngine engine, LoopMode current) {
    switch (current) {
      case LoopMode.off:
        engine.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        engine.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        engine.setLoopMode(LoopMode.off);
        break;
    }
  }

  Widget _buildLoadingState(BuildContext context, DynamicPalette palette) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparente para ver fondo si lo hubiera, o manejado por container
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: palette.background,
        child: Center(
          child: CircularProgressIndicator(
            color: palette.vibrant.withValues(alpha: 0.8),
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error de reproducción',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay canción en reproducción',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎛️ WIDGETS DE CONTROL
/// ═══════════════════════════════════════════════════════════════════════════

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onPressed;
  final bool enabled;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: enabled ? color : color.withValues(alpha: 0.3),
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final Color color;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_PlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: widget.isBuffering
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              )
            : AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: _controller,
                size: 40,
                color: Colors.white,
              ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎵 MINI PLAYER WIDGET - Para uso en bottom bar
/// ═══════════════════════════════════════════════════════════════════════════

class ProfessionalMiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;

  const ProfessionalMiniPlayer({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(audioEngineStateProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return stateAsync.when(
      data: (state) {
        // 🛡️ PROTECCIÓN: Ocultar si hay anuncio (el AdsMiniPlayer tomará el control)
        if (state.isPlayingAd) return const SizedBox.shrink();
        
        if (state.currentSong == null) return const SizedBox.shrink();
        return _buildMiniPlayer(context, ref, state, palette);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMiniPlayer(
    BuildContext context,
    WidgetRef ref,
    AudioEngineState state,
    DynamicPalette palette,
  ) {
    // ✅ FIX: Usar lastConfirmedSong para evitar parpadeos en mini player
    final song = state.lastConfirmedSong ?? state.currentSong!;
    final engine = ref.read(advancedAudioEngineProvider);
    
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: palette.background,
          border: Border(
            top: BorderSide(
              color: palette.muted.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            // Progress bar
            const MiniSeekbar(height: 2),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Cover
                    Hero(
                      tag: 'player_cover',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: coverUrl != null
                              ? OptimizedCachedImage(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                  placeholder: null,
                                  errorWidget: Container(color: Colors.transparent),
                                )
                              : Container(
                                  color: Colors.transparent,
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: palette.onBackground.withValues(alpha: 0.3),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Song info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title ?? 'Sin título',
                            style: TextStyle(
                              color: palette.onBackground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song.artist?.displayName ?? 'Artista',
                            style: TextStyle(
                              color: palette.onBackground.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Controls
                    IconButton(
                      icon: Icon(
                        state.isPlaying 
                            ? Icons.pause_rounded 
                            : Icons.play_arrow_rounded,
                        size: 32,
                      ),
                      color: palette.onBackground,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        engine.togglePlayPause();
                      },
                    ),

                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 28),
                      color: state.hasNext
                          ? palette.onBackground
                          : palette.onBackground.withValues(alpha: 0.3),
                      onPressed: state.hasNext
                          ? () {
                              HapticFeedback.lightImpact();
                              engine.next();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
