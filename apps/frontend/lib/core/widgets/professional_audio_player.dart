import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../providers/unified_audio_provider_fixed.dart';
import '../providers/playback_state.dart';
import '../models/song_model.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';
import '../services/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'favorite_button.dart';
import 'album_swiper.dart';
import 'persistent_artwork_background.dart';
import 'verified_badge.dart';
import 'smooth_seekbar.dart'; // 🎚️ NUEVO: Seekbar suavizado sin parpadeo
// import 'vibe_selector_widget.dart'; // 🎛️ VIBE SELECTOR (no usado actualmente)
import '../../features/ads/models/audio_ad_model.dart';
import '../../features/ads/widgets/ads_skip_button.dart';
import '../../features/ads/widgets/ad_duration_counter.dart';

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
      // ⚡ FIX: Fondo transparente para evitar "black card"
      color: Colors.transparent, 
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
    // 🛡️ MIRROR PATTERN: Escuchar directamente al motor de audio
    // Esto garantiza actualizaciones instantáneas en auto-advance
    final audioService = ref.watch(audioServiceProvider);
    
    return StreamBuilder<SequenceState?>(
      stream: audioService.player.sequenceStateStream,
      builder: (context, snapshot) {
        // 1. Obtener datos del Stream (Fuente de Verdad Instantánea)
        final sequenceState = snapshot.data;
        final currentSource = sequenceState?.currentSource;
        Song? streamSong;
        AudioAd? streamAd;
        
        if (currentSource != null) {
          if (currentSource.tag is Song) {
            streamSong = currentSource.tag as Song;
          } else if (currentSource.tag is AudioAd) {
            streamAd = currentSource.tag as AudioAd;
          }
        }
        
        try {
          // 2. Obtener datos de Riverpod (Gestión de Estado)
          final playbackState = ref.watch(unifiedAudioProviderFixed);
          final isPlaying = playbackState.isPlaying;
          
          // 3. Fusión de Inteligencia:
          // Priorizar el Stream para el contenido (qué se muestra)
          // Usar Riverpod para el estado de control (play/pause, shuffle, etc)
          final finalSong = streamSong ?? playbackState.currentSong;
          final finalAd = streamAd ?? playbackState.currentAd;
          
          // Lógica de visualización (prioridad a anuncios)
          final showAd = finalAd != null; // Si el stream dice ad, es ad.
          
          if (showAd) {
             return _StaticPlayerUI(
                song: null,
                ad: finalAd,
                isPlaying: isPlaying,
             );
          }
          
          if (finalSong != null) {
             return _StaticPlayerUI(
                song: finalSong,
                ad: null,
                isPlaying: isPlaying,
             );
          }
          
          return const SizedBox.shrink();

        } catch (e, stackTrace) {
          AppLogger.error('[ProfessionalAudioPlayer] Error en build: $e', stackTrace);
          return const SizedBox.shrink();
        }
      }
    );
  }
}

/// Widget estático que no se reconstruye con cada actualización de progreso
/// OPTIMIZADO: StatefulWidget para mejor control y lazy loading
/// ✅ FASE 5: Maneja tanto canciones como anuncios usando lógica condicional
class _StaticPlayerUI extends ConsumerStatefulWidget {
  final Song? song;
  final AudioAd? ad;
  final bool isPlaying;

  const _StaticPlayerUI({
    this.song,
    this.ad,
    required this.isPlaying,
  });

  @override
  ConsumerState<_StaticPlayerUI> createState() => _StaticPlayerUIState();
}

class _StaticPlayerUIState extends ConsumerState<_StaticPlayerUI> {
  Song? _lastSongId; // ✅ Guardar ID de la última canción para detectar cambios
  String? _lastAdId; // ✅ Guardar ID del último anuncio para detectar cambios

  // Estilos cacheados para evitar recreación
  static final TextStyle _titleStyle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  static final TextStyle _artistStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white.withValues(alpha: 0.5), // ✅ Opacidad aumentada
    letterSpacing: -0.3,
  );
  // Estilos para anuncios
  static final TextStyle _adTitleStyle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  static final TextStyle _advertiserStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white.withValues(alpha: 0.9),
    letterSpacing: -0.3,
  );

  @override
  void initState() {
    super.initState();
    _lastSongId = widget.song;
    _lastAdId = widget.ad?.id;
  }

  @override
  void didUpdateWidget(_StaticPlayerUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ✅ OPTIMIZACIÓN: Log solo cuando cambia el contenido (no en cada rebuild)
    final songChanged = oldWidget.song?.id != widget.song?.id;
    final adChanged = oldWidget.ad?.id != widget.ad?.id;
    
    if (songChanged && widget.song != null) {
      AppLogger.info('[ProfessionalAudioPlayer] 🎵 Widget recibió CANCIÓN: ${widget.song!.title}');
    }
    if (adChanged && widget.ad != null) {
      AppLogger.info('[ProfessionalAudioPlayer] 📢 Widget recibió ANUNCIO: ${widget.ad!.title}');
    }
    
    // ✅ FIX CRÍTICO: Detectar cambio de anuncio a canción
    // Si había anuncio y ahora hay canción, limpiar estado del anuncio inmediatamente
    if (oldWidget.ad != null && widget.ad == null && widget.song != null) {
      AppLogger.info('[ProfessionalAudioPlayer] ✅ Cambio detectado: anuncio → canción, limpiando estado del anuncio');
      _lastAdId = null;
      _lastSongId = widget.song;
      return; // No continuar con otras verificaciones
    }
    // ✅ FIX CRÍTICO: Detectar cambio de canción a anuncio
    // Si había canción y ahora hay anuncio, limpiar estado de la canción inmediatamente
    if (oldWidget.song != null && widget.song == null && widget.ad != null) {
      AppLogger.info('[ProfessionalAudioPlayer] ✅ Cambio detectado: canción → anuncio, limpiando estado de la canción');
      _lastSongId = null;
      _lastAdId = widget.ad?.id;
      return; // No continuar con otras verificaciones
    }
    // ✅ DETECTAR CAMBIO DE CANCIÓN: Si cambió la canción, resetear estado
    if (widget.song != null && (oldWidget.song?.id != widget.song?.id || _lastSongId?.id != widget.song?.id)) {
      _lastSongId = widget.song;
    }
    // ✅ DETECTAR CAMBIO DE ANUNCIO: Si cambió el anuncio, resetear estado
    if (widget.ad != null && (oldWidget.ad?.id != widget.ad?.id || _lastAdId != widget.ad?.id)) {
      _lastAdId = widget.ad?.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FASE 5: Determinar si estamos reproduciendo un anuncio o una canción
    final isPlayingAd = widget.ad != null;
    final currentSong = widget.song;
    final currentAd = widget.ad;
    
    // ✅ FIX CRÍTICO: Log removido del build - ya está en didUpdateWidget
    // El build se ejecuta muchas veces, solo loguear cuando realmente cambia el contenido
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true, // ✅ Extender el body debajo del sistema
      extendBodyBehindAppBar: true, // ✅ Extender detrás de la app bar
      body: Stack(
        children: [
          // ✅ 1. Capa de carátulas persistentes (estilo Spotify)
          // ✅ FASE 5: Mostrar carátula del anuncio o de la canción según corresponda
          SizedBox.expand(
            child: isPlayingAd && currentAd != null
                ? _AdArtworkBackground(ad: currentAd)
                : currentSong != null
                    ? PersistentArtworkBackground(
                        key: ValueKey('background_${currentSong.id}'),
                        currentSong: currentSong,
                      )
                    : const SizedBox.shrink(),
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
                  cacheExtent: 300, // ✅ Ajustado: menos trabajo fuera de viewport
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                // Header - ESTÁTICO (con espacio para el botón de contraer)
                // ✅ FASE 5: Mostrar "ANUNCIO" o "REPRODUCIENDO AHORA" según corresponda
                RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48, bottom: 12), // Espacio superior para no interferir con botón de contraer
                    child: Center(
                          child: isPlayingAd && currentAd != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                              ),
                              child: Text(
                                "ANUNCIO",
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            )
                          : Text(
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
                
                // ✅ FASE 5: Carátula del anuncio o de la canción según corresponda
                // ✅ FIX: Usar AnimatedSwitcher para transición suave y evitar parpadeo
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: isPlayingAd && currentAd != null
                        ? _AdCoverWidget(
                            key: ValueKey('ad_cover_${currentAd.id}'),
                            ad: currentAd,
                          )
                        : currentSong != null
                            ? AlbumSwiper(
                                key: ValueKey('album_swiper_${currentSong.id}'),
                                currentSong: currentSong,
                                onSwipe: (direction) {
                                  final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
                                  if (direction == SwipeDirection.left) {
                                    audioNotifier.next();
                                  } else {
                                    audioNotifier.previous();
                                  }
                                },
                              )
                            : Container(key: const ValueKey('empty_cover')),
                  ),
                ),
                
                const SizedBox(height: 20), // Espacio para alinear título con corazón
                
                // Info y Controles - ESTÁTICOS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Padding vertical para separar del cover
                  child: Column(
                    children: [
                      // ✅ FASE 5: Título y Artista/Anunciante - ESTÁTICO
                      // Mostrar información del anuncio o de la canción según corresponda
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start, // Alineado arriba para que el corazón se alinee con el título
                        children: [
                          Expanded(
                            child: RepaintBoundary(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ FASE 5: Mostrar título del anuncio o de la canción
                                  // ✅ NUEVO: Agregar etiqueta "AD" al lado del título del anuncio
                                  isPlayingAd && currentAd != null
                                      ? Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                currentAd.title,
                                                style: _adTitleStyle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.8),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'AD',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          currentSong?.title ?? 'Sin título',
                                          style: _titleStyle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  const SizedBox(height: 4),
                                  // ✅ FASE 5: Mostrar anunciante o artista según corresponda
                                  isPlayingAd && currentAd != null
                                      ? Text(
                                          currentAd.advertiserName,
                                          style: _advertiserStyle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : currentSong != null
                                          ? ArtistNameWithBadge(
                                              artistName: currentSong.artist?.displayName ?? 'Artista desconocido',
                                              isVerified: currentSong.artist?.isVerifiedValue ?? false,
                                              textStyle: _artistStyle,
                                              badgeSize: 16.0,
                                            )
                                          : const SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ),
                          // ✅ FASE 5: Mostrar botón de skip o botón de favorito según corresponda
                          // El contador de duración se muestra en la posición del progreso para anuncios no saltables
                          Padding(
                            padding: const EdgeInsets.only(top: 2), // Pequeño ajuste para alinear con el título
                            child: isPlayingAd && currentAd != null
                                ? (currentAd.isSkippable
                                    ? AdsSkipButton(ad: currentAd)
                                    : const SizedBox.shrink()) // Para anuncios no saltables, el contador va en la posición del progreso
                                : currentSong != null
                                    ? FavoriteButton(
                                        songId: currentSong.id,
                                        song: currentSong, // ✅ CRÍTICO: Pasar objeto completo para actualizar lista inmediatamente
                                        iconColor: Colors.white,
                                        iconSize: 28,
                                      )
                                    : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12), // Reducido aún más
                      
                      // ✅ FASE 5: Progress Control - Mostrar AdDurationCounter para anuncios o _ProgressControl para canciones
                      isPlayingAd && currentAd != null
                          ? AdDurationCounter(ad: currentAd)
                          : const _ProgressControl(),
                      
                      const SizedBox(height: 20), // Reducido aún más
                      
                      // Controles Principales - ESTÁTICOS (excepto el botón play/pause)
                      // ✅ OPTIMIZACIÓN: RepaintBoundary para contenedor de controles
                      // 🛑 BLOQUEO: Deshabilitar controles durante anuncios
                      Consumer(
                        builder: (context, ref, child) {
                          final isPlayingAd = ref.watch(
                            unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
                          );
                          
                          return RepaintBoundary(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: RepaintBoundary(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final isShuffled = ref.watch(
                                              unifiedAudioProviderFixed.select((state) => state.isShuffled),
                                            );
                                            return IconButton(
                                              icon: Icon(
                                                Icons.shuffle_rounded,
                                                color: isShuffled 
                                                  ? NeumorphismTheme.coffeeMedium 
                                                  : Colors.white.withValues(alpha: isPlayingAd ? 0.3 : 0.7),
                                                size: 24,
                                              ),
                                              onPressed: isPlayingAd ? null : () {
                                                ref.read(unifiedAudioProviderFixed.notifier).toggleShuffle();
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: _AsyncIconButton(
                                        icon: Icons.skip_previous_rounded,
                                        size: 42,
                                        isLocked: isPlayingAd,
                                        onTap: () async {
                                          await ref.read(unifiedAudioProviderFixed.notifier).previous();
                                        },
                                      ),
                                    ),
                                    Flexible(
                                      flex: 0,
                                      child: _PlayPauseButton(ref: ref, isLocked: isPlayingAd),
                                    ),
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: _AsyncIconButton(
                                        icon: Icons.skip_next_rounded,
                                        size: 42,
                                        isLocked: isPlayingAd,
                                        onTap: () async {
                                          await ref.read(unifiedAudioProviderFixed.notifier).next();
                                        },
                                      ),
                                    ),
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: RepaintBoundary(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final repeatMode = ref.watch(
                                              unifiedAudioProviderFixed.select((state) => state.repeatMode),
                                            );
                                            IconData icon;
                                            Color color;
                                            switch (repeatMode) {
                                              case RepeatMode.off:
                                                icon = Icons.repeat_rounded;
                                                color = Colors.white.withValues(alpha: isPlayingAd ? 0.3 : 0.7);
                                                break;
                                              case RepeatMode.all:
                                                icon = Icons.repeat_rounded;
                                                color = isPlayingAd 
                                                  ? Colors.white.withValues(alpha: 0.3)
                                                  : NeumorphismTheme.coffeeMedium;
                                                break;
                                              case RepeatMode.one:
                                                icon = Icons.repeat_one_rounded;
                                                color = isPlayingAd 
                                                  ? Colors.white.withValues(alpha: 0.3)
                                                  : NeumorphismTheme.coffeeMedium;
                                                break;
                                            }
                                            return IconButton(
                                              icon: Icon(icon, color: color, size: 24),
                                              onPressed: isPlayingAd ? null : () {
                                                ref.read(unifiedAudioProviderFixed.notifier).toggleRepeat();
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
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
/// ✅ SIMPLIFICADO: Usa solo el estado del provider (ya sincronizado con el stream)
class _PlayPauseButton extends ConsumerWidget {
  final WidgetRef ref;
  final bool isLocked;

  const _PlayPauseButton({
    required this.ref,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🛡️ FUENTE ÚNICA DE VERDAD: StreamBuilder con isPlayingStream directamente
    // Esto elimina toda dependencia del estado de PlaybackNotifier
    final audioService = ref.watch(audioServiceProvider);
    final isPlayingStream = audioService.isPlayingStream;
    // ✅ CORRECCIÓN: Obtener el valor actual del reproductor como initialData
    // Esto asegura que el botón muestre el estado correcto desde el inicio
    final currentPlayingState = audioService.player.playing;
    return StreamBuilder<bool>(
      stream: isPlayingStream,
      initialData: currentPlayingState, // ✅ Usar estado actual como valor inicial
      builder: (context, isPlayingSnapshot) {
        final bool isPlaying = isPlayingSnapshot.data ?? currentPlayingState;

        return GestureDetector(
          onTap: isLocked ? null : () {
            ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
          },
          child: RepaintBoundary(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isLocked 
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isLocked 
                  ? Colors.black.withValues(alpha: 0.5)
                  : Colors.black,
                size: 36,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Botón async con estado de "procesando" para next/prev (feedback inmediato)
class _AsyncIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Future<void> Function() onTap;
  final bool isLocked;

  const _AsyncIconButton({
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.isLocked = false,
  });

  @override
  State<_AsyncIconButton> createState() => _AsyncIconButtonState();
}

class _AsyncIconButtonState extends State<_AsyncIconButton> {
  bool _pending = false;
  DateTime _unlockAt = DateTime.fromMillisecondsSinceEpoch(0);
  
  // 🛡️ Timeout de seguridad para evitar bloqueo permanente
  static const Duration _maxPendingDuration = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isUnlocked = now.isAfter(_unlockAt);
    
    // 🛡️ Auto-desbloqueo si _pending lleva demasiado tiempo
    // Esto evita que el botón se quede bloqueado permanentemente
    final isDisabled = widget.isLocked || (_pending && isUnlocked == false);

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(
              widget.icon, 
              color: isDisabled 
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white, 
              size: widget.size,
            ),
            onPressed: isDisabled
                ? null
                : () async {
                    setState(() {
                      _pending = true;
                      // 🛡️ Desbloqueo automático después de timeout de seguridad
                      _unlockAt = DateTime.now().add(_maxPendingDuration);
                    });
                    try {
                      // 🛡️ Timeout en la operación para evitar bloqueo infinito
                      await widget.onTap().timeout(
                        _maxPendingDuration,
                        onTimeout: () {
                          AppLogger.warning('[AsyncIconButton] Timeout en operación, desbloqueando');
                        },
                      );
                    } catch (e) {
                      AppLogger.error('[AsyncIconButton] Error: $e');
                    } finally {
                      if (mounted) setState(() => _pending = false);
                    }
                  },
          ),
        ],
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
  DateTime? _lastSeekTime;
  
  // ✅ MEMOIZACIÓN: Cache de strings formateados para evitar recálculos
  String? _cachedCurrentTime;
  String? _cachedTotalTime;
  int? _lastCachedPositionMs;
  int? _lastCachedDurationMs;
  
  // ✅ PROTECCIÓN: Guardar última posición válida para evitar saltos a 0
  Duration? _lastValidPosition;
  // ✅ PROTECCIÓN: Guardar ID de la última canción para detectar cambios
  String? _lastSongId;

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
    final currentSong = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong?.id),
    );
    final isPlayingAd = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
    );
    final progressData = ref.watch(
      unifiedAudioProviderFixed.select((state) => _ProgressData(
        currentPosition: state.currentPosition,
        totalDuration: state.totalDuration,
        progress: state.progress,
      )),
    );
    
    // ✅ PROTECCIÓN: Si cambió la canción, resetear la posición guardada
    if (currentSong != null && currentSong != _lastSongId) {
      _lastSongId = currentSong;
      _lastValidPosition = null; // Resetear posición guardada cuando cambia la canción
    }
    
    // ✅ MEMOIZACIÓN: Cache se actualiza automáticamente en _formatDuration
    
    // ✅ PROTECCIÓN: Evitar saltos a 0 cuando la posición se resetea temporalmente
    // Solo usar la posición del estado si es válida (mayor que 0) o si no tenemos una posición guardada
    Duration effectivePosition = progressData.currentPosition;
    if (effectivePosition.inMilliseconds == 0 && _lastValidPosition != null && currentSong == _lastSongId) {
      // Si la posición es 0 pero tenemos una posición válida guardada Y es la misma canción, mantenerla
      // Esto evita que la barra parpadee cuando se sincroniza el estado
      effectivePosition = _lastValidPosition!;
    } else if (effectivePosition.inMilliseconds > 0) {
      // Guardar la última posición válida
      _lastValidPosition = effectivePosition;
    }
    
    // Usar posición de drag si está activa, sino usar la posición efectiva
    final currentPosition = _isDraggingSeek && _dragPosition != null
        ? _dragPosition!
        : effectivePosition;

    final currentDuration = progressData.totalDuration;

    return Column(
      children: [
            // 🎚️ NUEVO: SmoothSeekbar profesional sin parpadeo
                    // 🆕 FIX PARPADEO: Key por canción para forzar estado nuevo al cambiar canción
                    SmoothSeekbar(
                      key: ValueKey('smooth_seekbar_${currentSong ?? 'none'}'),
              enabled: !isPlayingAd, // 🛑 Deshabilitar durante anuncios
              height: 40,
              trackHeight: 4.0,
              thumbRadius: 6.0,
              activeColor: Colors.white.withValues(alpha: 0.9),
              inactiveColor: Colors.white.withValues(alpha: 0.2),
              bufferedColor: Colors.white.withValues(alpha: 0.4),
              thumbColor: Colors.white,
              showTooltip: true,
              tooltipStyle: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              onSeekStart: () {
                // Si la canción cambió recientemente, limpiar estado local antes de arrastrar
                if (currentSong != null && currentSong != _lastSongId) {
                  _lastSongId = currentSong;
                  _lastValidPosition = null;
                  _dragPosition = null;
                }
                _lastSeekTime = DateTime.now();
                setState(() => _isDraggingSeek = true);
              },
              onSeekEnd: (position) {
                // Debounce breve para evitar mezclar eventos muy rápidos
                final now = DateTime.now();
                if (_lastSeekTime != null && now.difference(_lastSeekTime!) < const Duration(milliseconds: 120)) {
                  // Considerar como tap accidental, ignorar
                  setState(() {
                    _isDraggingSeek = false;
                    _dragPosition = null;
                  });
                  return;
                }

                setState(() {
                  _isDraggingSeek = false;
                  _dragPosition = null;
                });
              },
              onSeekChange: (position) {
                // Ignorar cambios de seek si la canción ya cambió
                if (currentSong != null && currentSong != _lastSongId) return;
                setState(() => _dragPosition = position);
              },
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

  @override
  void dispose() {
    // Limpiar estado local para evitar que valores persistentes influyan en nuevas instancias
    _isDraggingSeek = false;
    _dragPosition = null;
    _lastValidPosition = null;
    _lastSongId = null;
    _lastSeekTime = null;
    super.dispose();
  }
}

/// Widget para mostrar el fondo con color sólido profesional del anuncio (marrón oscuro)
class _AdArtworkBackground extends StatelessWidget {
  final AudioAd ad;

  const _AdArtworkBackground({
    required this.ad,
  });

  @override
  Widget build(BuildContext context) {
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

/// ✅ FASE 5: Widget para mostrar la carátula del anuncio
class _AdCoverWidget extends StatelessWidget {
  final AudioAd ad;

  const _AdCoverWidget({
    super.key,
    required this.ad,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final coverSize = screenWidth * 0.85;

    return Container(
      width: coverSize,
      height: coverSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ad.coverImageUrl != null && ad.coverImageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: UrlNormalizer.normalizeImageUrl(ad.coverImageUrl) ?? ad.coverImageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                  child: Icon(
                    Icons.volume_up,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 64,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                  child: Icon(
                    Icons.volume_up,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 64,
                  ),
                ),
              )
            : Container(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                child: Icon(
                  Icons.volume_up,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 64,
                ),
              ),
      ),
    );
  }
}

