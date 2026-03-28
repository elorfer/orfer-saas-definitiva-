import 'dart:async'; // ✅ Para Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/config/performance_config.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/utils/intersection_observer.dart';

/// 🚀 PANTALLA OPTIMIZADA DE CANCIONES DESTACADAS
/// Implementa múltiples optimizaciones de rendimiento:
/// - Lazy loading con AutomaticKeepAliveClientMixin
/// - Precarga inteligente de imágenes
/// - Caché de widgets con RepaintBoundary
/// - Scroll optimizado con cacheExtent
class FeaturedSongsScreen extends ConsumerStatefulWidget {
  const FeaturedSongsScreen({super.key});

  @override
  ConsumerState<FeaturedSongsScreen> createState() =>
      _FeaturedSongsScreenState();
}

class _FeaturedSongsScreenState extends ConsumerState<FeaturedSongsScreen>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;

  // ✅ OPTIMIZACIÓN: Cache de URLs de imágenes para evitar recálculos en _onScroll
  List<String> _cachedImageUrls = [];
  int _cachedSongsCount = 0;

  // ✅ OPTIMIZACIÓN: Timer para debounce en _onScroll
  Timer? _scrollDebounceTimer;

  @override
  bool get wantKeepAlive => PerformanceConfig.enableKeepAlive;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // ✅ FIX: Usar microtask en lugar de postFrameCallback
    // Si la Home ya cargó datos, el provider los tiene y esto retorna al instante.
    // Si no hay datos, arranca la carga sin esperar un frame extra.
    Future.microtask(() {
      if (!mounted) return;
      final state = ref.read(intelligentFeaturedProvider);
      if (state.featuredSongs.isEmpty && !state.isLoading) {
        ref
            .read(intelligentFeaturedProvider.notifier)
            .loadIntelligentFeaturedSongs();
      }
    });
  }

  @override
  void dispose() {
    // ✅ OPTIMIZACIÓN: Cancelar timer de debounce
    _scrollDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// ✅ OPTIMIZACIÓN: Precachear imágenes visibles al hacer scroll
  /// ✅ CORRECCIÓN: Agregado debounce para evitar ejecuciones excesivas
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    // ✅ OPTIMIZACIÓN: Cancelar timer anterior si existe
    _scrollDebounceTimer?.cancel();

    // ✅ OPTIMIZACIÓN: Debounce de 300ms para evitar ejecuciones excesivas
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_scrollController.hasClients) return;

      try {
        // ✅ OPTIMIZACIÓN: Usar URLs cacheadas en lugar de leer del provider cada vez
        if (_cachedImageUrls.isEmpty) {
          // Si no hay cache, actualizar desde el provider (solo una vez)
          final featuredSongs =
              ref.read(intelligentFeaturedProvider).featuredSongs;
          if (featuredSongs.isEmpty) return;

          _cachedImageUrls = featuredSongs
              .map((fs) => UrlNormalizer.normalizeImageUrl(fs.song.coverArtUrl))
              .where((url) => url != null && url.isNotEmpty)
              .cast<String>()
              .toList();
          _cachedSongsCount = featuredSongs.length;
        }

        // Precachear imágenes visibles
        if (_cachedImageUrls.isNotEmpty) {
          LazyImageLoader.precacheVisibleVerticalImages(
            scrollController: _scrollController,
            itemExtent:
                80.0, // Altura aproximada de cada tarjeta (padding + contenido)
            itemCount: _cachedSongsCount,
            imageUrls: _cachedImageUrls,
            context: context,
            precacheCount:
                5, // Precachear 5 items antes y después de los visibles
          );
        }
      } catch (e) {
        // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente para no bloquear la app
        debugPrint('[FeaturedSongsScreen] Error en _onScroll: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin

    // 🔥 REQUERIDO: Observar el tema para reconstruir cuando cambie modoclara/oscuro
    ref.watch(themeProvider);

    final isLoading = ref
        .watch(intelligentFeaturedProvider.select((state) => state.isLoading));
    final error =
        ref.watch(intelligentFeaturedProvider.select((state) => state.error));
    final featuredSongs = ref.watch(
        intelligentFeaturedProvider.select((state) => state.featuredSongs));

    // ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambien los datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cachedImageUrls = featuredSongs
            .map((fs) => UrlNormalizer.normalizeImageUrl(fs.song.coverArtUrl))
            .where((url) => url != null && url.isNotEmpty)
            .cast<String>()
            .toList();
        _cachedSongsCount = featuredSongs.length;
      }
    });

    return RepaintBoundary(
      // ✅ OPTIMIZACIÓN: Evitar repintados innecesarios
      child: Scaffold(
        backgroundColor: NeumorphismTheme.background,
        appBar: AppBar(
          systemOverlayStyle: NeumorphismTheme.isDark 
              ? SystemUiOverlayStyle.light 
              : SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: NeumorphismTheme.textPrimary,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          title: const SizedBox.shrink(), // ✅ Sin título
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(intelligentFeaturedProvider.notifier)
                .loadIntelligentFeaturedSongs(forceRefresh: true);
          },
          child: (isLoading && featuredSongs.isEmpty)
              ? _buildLoadingSection()
              : error != null && featuredSongs.isEmpty
                  ? _buildErrorSection(error)
                  : featuredSongs.isEmpty
                      ? _buildEmptySection()
                      : _buildSongsList(context, featuredSongs),
        ),
      ),
    );
  }

  Widget _buildSongsList(
      BuildContext context, List<FeaturedSong> featuredSongs) {
    // ✅ OPTIMIZACIÓN: Precachear imágenes iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final imageUrls = featuredSongs
            .take(5) // Solo las primeras 5
            .map((fs) => UrlNormalizer.normalizeImageUrl(fs.song.coverArtUrl))
            .toList();

        LazyImageLoader.precacheInitialImages(
          imageUrls: imageUrls,
          context: context,
          count: 5,
        );
      }
    });

    return CustomScrollView(
      key:
          const PageStorageKey('featured_songs_scroll'), // ✅ Fix Scroll Flicker
      controller:
          _scrollController, // ✅ OPTIMIZACIÓN: Conectar ScrollController
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()), // ✅ Scroll estilo iPhone
      cacheExtent:
          PerformanceConfig.listCacheExtent, // ✅ Optimizado: cache centralizado
      clipBehavior: Clip.none, // Evitar clipping innecesario
      slivers: [
        // Título limpio
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              'Canciones Destacadas',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.textPrimary,
              ),
            ),
          ),
        ),

        // ✅ OPTIMIZACIÓN: Lista de canciones con itemExtent fijo para mejor rendimiento
        SliverFixedExtentList(
          itemExtent: 90.0, // ✅ Aumentado para acomodar la etiqueta de género
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final featuredSong = featuredSongs[index];
              final song = featuredSong.song;
              return RepaintBoundary(
                key: ValueKey('featured_song_${song.id}'),
                child: _BlurSongCard(
                  featuredSong: featuredSong,
                  onTap: () => _onSongTap(context, song),
                ),
              );
            },
            childCount: featuredSongs.length,
            addAutomaticKeepAlives:
                false, // Optimización: no mantener estado fuera de vista
            addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual
          ),
        ),
        // Espacio para el reproductor
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildLoadingSection() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorSection(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: NeumorphismTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar canciones',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: NeumorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No se pudieron cargar las canciones destacadas',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: NeumorphismTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(intelligentFeaturedProvider.notifier)
                  .loadIntelligentFeaturedSongs(forceRefresh: true);
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 64,
            color: NeumorphismTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay canciones destacadas',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: NeumorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vuelve más tarde para descubrir nueva música',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: NeumorphismTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _onSongTap(BuildContext context, Song song) {
    // Usar go_router a través de la función estática que previene duplicados
    // go_router maneja las transiciones automáticamente según la configuración en app_router.dart
    SongDetailScreen.navigateToSong(context, song);
  }
}

/// Widget de tarjeta con estilo igual al Home (IntelligentFeaturedSongCard) pero más pequeña
class _BlurSongCard extends ConsumerWidget {
  final FeaturedSong featuredSong;
  final VoidCallback onTap;

  const _BlurSongCard({
    required this.featuredSong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔥 REQUERIDO: Observar el tema para usar colores actualizados
    ref.watch(themeProvider);

    // Estilos reactivos (definidos dentro de build)
    final TextStyle titleStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: NeumorphismTheme.textPrimary,
      letterSpacing: -0.3,
      height: 1.2,
    );
    final TextStyle artistStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: NeumorphismTheme.textSecondary,
      height: 1.2,
    );

    final song = featuredSong.song;
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ Portada simple
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: OptimizedImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    borderRadius: 8,
                    useThumbnail: true,
                    lazyLoad: true,
                    visibilityThreshold: 0.1,
                    maxCacheWidth: 140,
                    maxCacheHeight: 140,
                    skipFade: true,
                    placeholderColor: NeumorphismTheme.accentLight,
                    errorWidget: Container(
                      color:
                          NeumorphismTheme.accentLight.withValues(alpha: 0.4),
                      child: Icon(Icons.music_note,
                          color: NeumorphismTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Información de la canción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title ?? 'Sin título',
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      song.artist != null
                          ? ArtistNameWithBadge(
                              artistName: song.artist!.stageName ??
                                  (song.artist!.displayName.isNotEmpty
                                      ? song.artist!.displayName
                                      : 'Artista Desconocido'),
                              isVerified: song.artist!.isVerifiedValue,
                              textStyle: artistStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              badgeSize: 12.0,
                            )
                          : Text(
                              'Artista Desconocido',
                              style: artistStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      if (song.genres != null && song.genres!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.accentLight
                                .withValues(alpha: 0.3),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(4)),
                          ),
                          child: Text(
                            song.genres!.first.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: NeumorphismTheme.accentDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
