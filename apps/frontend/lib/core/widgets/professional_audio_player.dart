import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../providers/playback_state.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'favorite_button.dart';
import 'album_swiper.dart';
import 'persistent_artwork_background.dart';
import 'verified_badge.dart';

/// Widget separado para el fondo premium (evita rebuilds)
/// ✅ INDEPENDIENTE: El fondo no depende de la portada de la canción actual
class _BackgroundImageWidget extends StatelessWidget {
  const _BackgroundImageWidget();

  @override
  Widget build(BuildContext context) {
    // ✅ Fondo independiente: color fijo que no cambia con la portada
    return Container(
      color: const Color(0xFF2B1E13), // Color fijo independiente de la portada
    );
  }
}

/// ✅ CACHE EN MEMORIA: URLs de imágenes precargadas (evita precargas duplicadas)
class _ImagePreloadCache {
  static final Set<String> _preloadedUrls = {};
  static final Map<String, DateTime> _preloadTimes = {};
  static const Duration _cacheExpiry = Duration(hours: 1); // Cache válido por 1 hora
  
  static bool isPreloaded(String url) {
    final time = _preloadTimes[url];
    if (time == null) return false;
    
    // Verificar si el cache expiró
    if (DateTime.now().difference(time) > _cacheExpiry) {
      _preloadedUrls.remove(url);
      _preloadTimes.remove(url);
      return false;
    }
    
    return _preloadedUrls.contains(url);
  }
  
  static void markPreloaded(String url) {
    _preloadedUrls.add(url);
    _preloadTimes[url] = DateTime.now();
  }
}

/// Widget separado para la carátula del álbum (evita rebuilds)
/// OPTIMIZADO: Cache en memoria + ImageCache de Flutter + tamaño reducido
class _AlbumCoverWidget extends StatefulWidget {
  final Song song;

  const _AlbumCoverWidget({
    required this.song,
  });

  @override
  State<_AlbumCoverWidget> createState() => _AlbumCoverWidgetState();
}

class _AlbumCoverWidgetState extends State<_AlbumCoverWidget> {
  // ✅ OPTIMIZACIÓN: Mostrar imagen inmediatamente, precarga en background
  // No bloquear el render inicial esperando precarga

  @override
  void initState() {
    super.initState();
    // ✅ DIFERIR PRECARGA: No bloquear el render inicial
    // La imagen se mostrará inmediatamente con CachedNetworkImage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _preloadImage();
      }
    });
  }

  @override
  void didUpdateWidget(_AlbumCoverWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.coverArtUrl != widget.song.coverArtUrl) {
      // Precarga en background sin bloquear
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _preloadImage();
        }
      });
    }
  }

  /// ✅ OPTIMIZACIÓN: Precarga en background sin bloquear UI
  /// La imagen se muestra inmediatamente con CachedNetworkImage
  Future<void> _preloadImage() async {
    if (widget.song.coverArtUrl == null || widget.song.coverArtUrl!.isEmpty) {
      return;
    }

    final normalizedUrl = UrlNormalizer.normalizeImageUrl(widget.song.coverArtUrl);
    if (normalizedUrl == null) {
      return;
    }

    // ✅ CACHE EN MEMORIA: Verificar si ya está precargada
    if (_ImagePreloadCache.isPreloaded(normalizedUrl)) {
      return;
    }

    // ✅ PRECARGA EN BACKGROUND: No bloquear UI, solo mejorar cache
    try {
      final mediaQuery = MediaQuery.of(context);
      final screenWidth = mediaQuery.size.width;
      final devicePixelRatio = mediaQuery.devicePixelRatio;
      final displaySize = screenWidth * 0.85;
      final preloadSize = (displaySize * 0.7 * devicePixelRatio).round();
      
      final imageProvider = CachedNetworkImageProvider(normalizedUrl);
      final resizedProvider = ResizeImage(
        imageProvider,
        width: preloadSize,
        height: preloadSize,
      );
      
      // Precargar en background sin await (no bloquea)
      precacheImage(resizedProvider, context).then((_) {
        if (mounted) {
          _ImagePreloadCache.markPreloaded(normalizedUrl);
        }
      }).catchError((_) {
        // Ignorar errores silenciosamente
      });
    } catch (e) {
      // Ignorar errores silenciosamente
    }
  }

  // ✅ CACHEAR MediaQuery: Evitar múltiples llamadas costosas
  MediaQueryData? _cachedMediaQuery;
  int? _cachedMemCacheSize;

  @override
  Widget build(BuildContext context) {
    // ✅ OPTIMIZACIÓN: Mostrar imagen inmediatamente, no esperar precarga
    if (widget.song.coverArtUrl == null || widget.song.coverArtUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    final normalizedUrl = UrlNormalizer.normalizeImageUrl(widget.song.coverArtUrl);
    if (normalizedUrl == null) {
      return _buildPlaceholder();
    }

    // ✅ CACHEAR MediaQuery: Solo calcular una vez por build
    _cachedMediaQuery ??= MediaQuery.of(context);
    final screenWidth = _cachedMediaQuery!.size.width;
    final devicePixelRatio = _cachedMediaQuery!.devicePixelRatio;
    final imageSize = screenWidth * 0.85;
    _cachedMemCacheSize ??= (imageSize * devicePixelRatio).round();

    // ✅ MOSTRAR INMEDIATAMENTE: CachedNetworkImage maneja el cache automáticamente
    return CachedNetworkImage(
      key: ValueKey(normalizedUrl),
      imageUrl: normalizedUrl,
      fit: BoxFit.cover,
      memCacheWidth: _cachedMemCacheSize,
      memCacheHeight: _cachedMemCacheSize,
      maxWidthDiskCache: _cachedMemCacheSize,
      maxHeightDiskCache: _cachedMemCacheSize,
      fadeInDuration: Duration.zero, // Sin animación de fade
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      cacheKey: normalizedUrl,
      httpHeaders: const {
        'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
        'Cache-Control': 'max-age=86400',
      },
      useOldImageOnUrlChange: true,
      filterQuality: FilterQuality.medium,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      key: const ValueKey('placeholder'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
            NeumorphismTheme.coffeeDark.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white30, size: 80),
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

      // ✅ Crear la UI estática con key única basada en el ID de la canción
      // Esto fuerza la reconstrucción cuando cambia la canción
      return _StaticPlayerUI(
        key: ValueKey('player_ui_${currentSong.id}'),
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
/// OPTIMIZADO: StatefulWidget para mejor control y lazy loading
class _StaticPlayerUI extends ConsumerStatefulWidget {
  final Song song;
  final bool isPlaying;

  const _StaticPlayerUI({
    super.key,
    required this.song,
    required this.isPlaying,
  });

  @override
  ConsumerState<_StaticPlayerUI> createState() => _StaticPlayerUIState();
}

class _StaticPlayerUIState extends ConsumerState<_StaticPlayerUI> {
  Song? _lastSongId; // ✅ Guardar ID de la última canción para detectar cambios
  Song? _previousSong; // ✅ Guardar canción anterior para transición
  SwipeDirection? _lastSwipeDirection; // ✅ Dirección del último swipe para animaciones
  bool _isInitialLoad = true; // ✅ Flag para detectar carga inicial

  @override
  void initState() {
    super.initState();
    _lastSongId = widget.song;
    // ✅ Marcar que es la carga inicial para mostrar todo sin animación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false; // Después del primer frame, ya no es carga inicial
        });
      }
    });
  }

  @override
  void didUpdateWidget(_StaticPlayerUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ DETECTAR CAMBIO DE CANCIÓN: Si cambió la canción, resetear estado
    if (oldWidget.song.id != widget.song.id || _lastSongId?.id != widget.song.id) {
      // ✅ Guardar canción anterior para transición suave
      _previousSong = _lastSongId;
      _lastSongId = widget.song;
      // Resetear dirección del swipe para nueva canción
      setState(() {
        _lastSwipeDirection = null; // Resetear dirección del swipe
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true, // ✅ Extender el body debajo del sistema
      extendBodyBehindAppBar: true, // ✅ Extender detrás de la app bar
      body: Stack(
        children: [
          // ✅ 1. Capa de carátulas persistentes (estilo Spotify)
          // Mantiene la carátula anterior visible mientras aparece la nueva
          // Incluye blur global encima de ambas carátulas
          SizedBox.expand(
            child: PersistentArtworkBackground(
              currentSong: widget.song,
              previousSong: _previousSong,
            ),
          ),

          // ✅ 2. Fondo independiente (no depende de la portada)
          // Color fijo que no cambia con la canción
          SizedBox.expand(
            child: RepaintBoundary(
              child: _BackgroundImageWidget(),
            ),
          ),

          // 2. Contenido seguro - OPTIMIZADO con CustomScrollView
          SafeArea(
            bottom: true, // ✅ Mantener padding inferior del SafeArea
            child: Builder(
              builder: (context) {
                // ✅ OPTIMIZACIÓN: CustomScrollView con Slivers para mejor rendimiento
                // Usa lazy loading y mejor gestión de memoria que SingleChildScrollView
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // ✅ Scroll estilo iPhone (consistente con Home)
                  cacheExtent: 400, // ✅ Optimizado: cache de scroll para mejor rendimiento
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                // Header - ESTÁTICO (con espacio para el botón de contraer)
                // ✅ OPTIMIZACIÓN: RepaintBoundary para widget estático
                RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48, bottom: 12), // Espacio superior para no interferir con botón de contraer
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
                ),
                
                const SizedBox(height: 8), // Espacio antes del cover
                
                // ✅ Carátula con swipe horizontal para cambiar canciones
                Center(
                  child: AlbumSwiper(
                    currentSong: widget.song,
                    onSwipe: (direction) {
                      // Cambiar canción según dirección del swipe
                      final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
                      if (direction == SwipeDirection.left) {
                        // Swipe izquierda = siguiente canción
                        audioNotifier.next();
                        setState(() {
                          _lastSwipeDirection = SwipeDirection.left;
                        });
                      } else {
                        // Swipe derecha = canción anterior
                        audioNotifier.previous();
                        setState(() {
                          _lastSwipeDirection = SwipeDirection.right;
                        });
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 20), // Espacio para alinear título con corazón
                
                // Info y Controles - ESTÁTICOS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Padding vertical para separar del cover
                  child: Column(
                    children: [
                      // Título y Artista - ESTÁTICO
                      // ✅ CORRECCIÓN: RepaintBoundary dentro del Expanded, no envolviendo el Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start, // Alineado arriba para que el corazón se alinee con el título
                        children: [
                          Expanded(
                            child: RepaintBoundary(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ Título animado con entrada lateral (sin animación en carga inicial)
                                  _isInitialLoad 
                                    ? Text(
                                        widget.song.title ?? 'Sin título',
                                        style: GoogleFonts.inter(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : (_lastSwipeDirection == SwipeDirection.left
                                        ? SlideInLeft(
                                            duration: const Duration(milliseconds: 300),
                                            child: Text(
                                              widget.song.title ?? 'Sin título',
                                              style: GoogleFonts.inter(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: -0.5,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )
                                        : SlideInRight(
                                            duration: const Duration(milliseconds: 300),
                                            child: Text(
                                              widget.song.title ?? 'Sin título',
                                              style: GoogleFonts.inter(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: -0.5,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                  const SizedBox(height: 4),
                                  // ✅ Artista animado con badge de verificación
                                  _isInitialLoad
                                    ? ArtistNameWithBadge(
                                        artistName: widget.song.artist?.displayName ?? 'Artista desconocido',
                                        isVerified: widget.song.artist?.isVerifiedValue ?? false,
                                        textStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          letterSpacing: -0.3,
                                        ),
                                        badgeSize: 16.0,
                                      )
                                    : (_lastSwipeDirection == SwipeDirection.left
                                        ? SlideInLeft(
                                            duration: const Duration(milliseconds: 300),
                                            child: ArtistNameWithBadge(
                                              artistName: widget.song.artist?.displayName ?? 'Artista desconocido',
                                              isVerified: widget.song.artist?.isVerifiedValue ?? false,
                                              textStyle: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white.withValues(alpha: 0.9),
                                                letterSpacing: -0.3,
                                              ),
                                              badgeSize: 16.0,
                                            ),
                                          )
                                        : SlideInRight(
                                            duration: const Duration(milliseconds: 300),
                                            child: ArtistNameWithBadge(
                                              artistName: widget.song.artist?.displayName ?? 'Artista desconocido',
                                              isVerified: widget.song.artist?.isVerifiedValue ?? false,
                                              textStyle: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white.withValues(alpha: 0.9),
                                                letterSpacing: -0.3,
                                              ),
                                              badgeSize: 16.0,
                                            ),
                                          )),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2), // Pequeño ajuste para alinear con el título
                            child: FavoriteButton(
                              songId: widget.song.id,
                              iconColor: Colors.white,
                              iconSize: 28,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12), // Reducido aún más
                      
                      // Progress Control - DINÁMICO usando provider unificado
                      const _ProgressControl(),
                      
                      const SizedBox(height: 20), // Reducido aún más
                      
                      // Controles Principales - ESTÁTICOS (excepto el botón play/pause)
                      // ✅ OPTIMIZACIÓN: RepaintBoundary para contenedor de controles
                      RepaintBoundary(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Botón Shuffle - con estado visual
                            Consumer(
                              builder: (context, ref, child) {
                                final isShuffled = ref.watch(
                                  unifiedAudioProviderFixed.select((state) => state.isShuffled),
                                );
                                return RepaintBoundary(
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.shuffle_rounded,
                                      color: isShuffled 
                                        ? NeumorphismTheme.coffeeMedium 
                                        : Colors.white.withValues(alpha: 0.7),
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      ref.read(unifiedAudioProviderFixed.notifier).toggleShuffle();
                                    },
                                  ),
                                );
                              },
                            ),
                            RepaintBoundary(
                              child: IconButton(
                                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 42),
                                onPressed: () async {
                                  await ref.read(unifiedAudioProviderFixed.notifier).previous();
                                },
                              ),
                            ),
                            // Solo el botón play/pause se actualiza - observa el estado directamente
                            _PlayPauseButton(ref: ref),
                            RepaintBoundary(
                              child: IconButton(
                                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 42),
                                onPressed: () async {
                                  await ref.read(unifiedAudioProviderFixed.notifier).next();
                                },
                              ),
                            ),
                            // Botón Repeat - con estado visual y diferentes iconos
                            Consumer(
                              builder: (context, ref, child) {
                                final repeatMode = ref.watch(
                                  unifiedAudioProviderFixed.select((state) => state.repeatMode),
                                );
                                
                                IconData icon;
                                Color color;
                                
                                switch (repeatMode) {
                                  case RepeatMode.off:
                                    icon = Icons.repeat_rounded;
                                    color = Colors.white.withValues(alpha: 0.7);
                                    break;
                                  case RepeatMode.all:
                                    icon = Icons.repeat_rounded;
                                    color = NeumorphismTheme.coffeeMedium;
                                    break;
                                  case RepeatMode.one:
                                    icon = Icons.repeat_one_rounded;
                                    color = NeumorphismTheme.coffeeMedium;
                                    break;
                                }
                                
                                return RepaintBoundary(
                                  child: IconButton(
                                    icon: Icon(icon, color: color, size: 24),
                                    onPressed: () {
                                      ref.read(unifiedAudioProviderFixed.notifier).toggleRepeat();
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8), // Reducido espacio inferior
                        ],
                      ),
                    ),
                    // ✅ Agregar padding inferior para evitar que el contenido quede pegado al borde
                    SliverPadding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                      ),
                    ),
                  ],
                );
              },
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

/// Datos optimizados para el control de progreso (reduce rebuilds)
@immutable
class _ProgressData {
  final Duration currentPosition;
  final Duration totalDuration;
  final double progress;

  const _ProgressData({
    required this.currentPosition,
    required this.totalDuration,
    required this.progress,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ProgressData &&
          runtimeType == other.runtimeType &&
          currentPosition.inMilliseconds == other.currentPosition.inMilliseconds &&
          totalDuration == other.totalDuration &&
          progress == other.progress;

  @override
  int get hashCode =>
      currentPosition.inMilliseconds.hashCode ^
      totalDuration.hashCode ^
      progress.hashCode;
}

/// Widget separado para el control de progreso usando provider unificado
/// OPTIMIZADO: Un solo watch + memoización para reducir rebuilds
class _ProgressControl extends ConsumerStatefulWidget {
  const _ProgressControl();

  @override
  ConsumerState<_ProgressControl> createState() => _ProgressControlState();
}

class _ProgressControlState extends ConsumerState<_ProgressControl> {
  bool _isDraggingSeek = false;
  Duration? _dragPosition;
  
  // ✅ MEMOIZACIÓN: Cache de strings formateados para evitar recálculos
  String? _cachedCurrentTime;
  String? _cachedTotalTime;
  int? _lastCachedPositionMs;
  int? _lastCachedDurationMs;

  /// ✅ MEMOIZACIÓN: Formatear duración con cache para evitar recálculos
  /// Compara por milisegundos para mejor precisión del cache
  String _formatDuration(Duration? duration, {bool isCurrent = true}) {
    if (duration == null) return '00:00';
    
    final durationMs = duration.inMilliseconds;
    
    // Cache para posición actual
    if (isCurrent) {
      if (durationMs == _lastCachedPositionMs && _cachedCurrentTime != null) {
        return _cachedCurrentTime!;
      }
    } else {
      // Cache para duración total
      if (durationMs == _lastCachedDurationMs && _cachedTotalTime != null) {
        return _cachedTotalTime!;
      }
    }
    
    // Calcular formato
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final formatted = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    // Actualizar cache
    if (isCurrent) {
      _lastCachedPositionMs = durationMs;
      _cachedCurrentTime = formatted;
    } else {
      _lastCachedDurationMs = durationMs;
      _cachedTotalTime = formatted;
    }
    
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ OPTIMIZACIÓN: UN SOLO WATCH que combina todos los valores necesarios
    // Esto reduce de 3 rebuilds potenciales a solo 1
    final progressData = ref.watch(
      unifiedAudioProviderFixed.select((state) => _ProgressData(
        currentPosition: state.currentPosition,
        totalDuration: state.totalDuration,
        progress: state.progress,
      )),
    );
    
    // ✅ MEMOIZACIÓN: Cache se actualiza automáticamente en _formatDuration
    
    // Usar posición de drag si está activa, sino usar la posición actual
    final currentPosition = _isDraggingSeek && _dragPosition != null
        ? _dragPosition!
        : progressData.currentPosition;

    final currentDuration = progressData.totalDuration;

    // ✅ MEMOIZACIÓN: Calcular progreso solo cuando es necesario
    final finalProgress = _isDraggingSeek && _dragPosition != null
        ? (currentDuration.inMilliseconds > 0
            ? (_dragPosition!.inMilliseconds / currentDuration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0)
        : progressData.progress;
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
            
            // Tiempos - OPTIMIZADO: Alineados visualmente con ancho fijo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ MEMOIZACIÓN: Usar cache para evitar recálculos
                  // Ancho fijo para alinear ambos textos perfectamente
                  SizedBox(
                    width: 50, // Ancho fijo para alineación perfecta
                    child: Text(
                      _formatDuration(currentPosition, isCurrent: true),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5, // Mejor legibilidad
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  SizedBox(
                    width: 50, // Mismo ancho para alineación perfecta
                    child: Text(
                      _formatDuration(currentDuration, isCurrent: false),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5, // Mejor legibilidad
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
  }
}

