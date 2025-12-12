import 'dart:async'; // ✅ Para Timer
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
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
  ConsumerState<FeaturedSongsScreen> createState() => _FeaturedSongsScreenState();
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
    // ✅ OPTIMIZACIÓN: Listener para precachear imágenes visibles al hacer scroll
    _scrollController.addListener(_onScroll);
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
          final featuredSongs = ref.read(intelligentFeaturedProvider).featuredSongs;
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
            itemExtent: 80.0, // Altura aproximada de cada tarjeta (padding + contenido)
            itemCount: _cachedSongsCount,
            imageUrls: _cachedImageUrls,
            context: context,
            precacheCount: 5, // Precachear 5 items antes y después de los visibles
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
    
    // 🔥 OPTIMIZACIÓN: Usar select() específico para evitar rebuilds innecesarios
    // Solo se reconstruye cuando cambian estos valores específicos
    final isLoading = ref.watch(intelligentFeaturedProvider.select((state) => state.isLoading));
    final error = ref.watch(intelligentFeaturedProvider.select((state) => state.error));
    final featuredSongs = ref.watch(intelligentFeaturedProvider.select((state) => state.featuredSongs));
    
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

    return RepaintBoundary( // ✅ OPTIMIZACIÓN: Evitar repintados innecesarios
      child: Scaffold(
        backgroundColor: NeumorphismTheme.background,
        appBar: AppBar(
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
          await ref.read(intelligentFeaturedProvider.notifier).loadIntelligentFeaturedSongs(forceRefresh: true);
        },
        child: isLoading
            ? _buildLoadingSection()
            : error != null
                ? _buildErrorSection(error)
                : featuredSongs.isEmpty
                    ? _buildEmptySection()
                    : _buildSongsList(context, featuredSongs),
        ),
      ),
    );
  }

  Widget _buildSongsList(BuildContext context, List<FeaturedSong> featuredSongs) {
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
      controller: _scrollController, // ✅ OPTIMIZACIÓN: Conectar ScrollController
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // ✅ Scroll estilo iPhone
      cacheExtent: 400.0, // ✅ Optimizado: cache de scroll para mejor rendimiento
      clipBehavior: Clip.none, // Evitar clipping innecesario
      slivers: [
        // Header mejorado con gradiente (similar a favoritos)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                  NeumorphismTheme.coffeeDark.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icono de estrella grande (diferente al de favoritos)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        NeumorphismTheme.coffeeMedium,
                        NeumorphismTheme.coffeeDark,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Título y subtítulo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Canciones Destacadas',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: NeumorphismTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            size: 16,
                            color: NeumorphismTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${featuredSongs.length} canciones seleccionadas especialmente para ti',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: NeumorphismTheme.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // ✅ OPTIMIZACIÓN: Lista de canciones con itemExtent fijo para mejor rendimiento
        SliverFixedExtentList(
          itemExtent: 80.0, // ✅ Ajustado: margin vertical 4*2=8 + padding vertical 8*2=16 + imagen 56 = 80
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
            addAutomaticKeepAlives: false, // Optimización: no mantener estado fuera de vista
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
              await ref.read(intelligentFeaturedProvider.notifier).loadIntelligentFeaturedSongs(forceRefresh: true);
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

  // Estilos cacheados
  static final TextStyle _titleStyle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );
  static final TextStyle _artistStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
    height: 1.2,
  );

  const _BlurSongCard({
    required this.featuredSong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = featuredSong.song;
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // ✅ Reducir margin vertical para evitar overflow
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.25, 1.0],
          colors: [
            NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15), // ✅ Igual que Home
            NeumorphismTheme.surface.withValues(alpha: 0.8),
            NeumorphismTheme.beigeMedium.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8, // ✅ Igual que Home
            offset: const Offset(0, 3), // ✅ Igual que Home
            spreadRadius: 0,
          ),
        ],
      ),
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // ✅ Reducir padding vertical para evitar overflow
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // ✅ Centrar verticalmente
                children: [
                  // ✅ Portada igual que Home pero más pequeña (64 -> 56) - CUADRADA
                  SizedBox(
                    width: 56, // ✅ Más pequeño que Home (64 -> 56)
                    height: 56, // ✅ Más pequeño que Home (64 -> 56)
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: const BorderRadius.all(Radius.circular(12)), // ✅ Más pequeño que Home (16 -> 12)
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15), // ✅ Igual que Home
                            blurRadius: 6, // ✅ Igual que Home
                            offset: const Offset(0, 2), // ✅ Igual que Home
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(12)), // ✅ Más pequeño que Home (16 -> 12)
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 1.0, // ✅ FORZAR ASPECTO CUADRADO
                          child: OptimizedImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            width: 56, // ✅ Más pequeño que Home (64 -> 56)
                            height: 56, // ✅ Más pequeño que Home (64 -> 56)
                            borderRadius: 12, // ✅ Más pequeño que Home (16 -> 12)
                            useThumbnail: true,
                            lazyLoad: true, // ✅ Lazy loading con IntersectionObserver
                            visibilityThreshold: 0.1, // Cargar cuando 10% visible
                            maxCacheWidth: 140, // 2.5x para nitidez sin exceso
                            maxCacheHeight: 140,
                            skipFade: true, // Sin fade para mejor rendimiento en scroll rápido
                            placeholderColor: NeumorphismTheme.accentLight,
                            errorWidget: Container(
                              color: NeumorphismTheme.accentLight.withValues(alpha: 0.4),
                              child: const Icon(Icons.music_note, color: NeumorphismTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // ✅ Más pequeño que Home (16 -> 12)
                  // Información de la canción (igual estilo que Home pero más pequeña)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, // ✅ Evitar overflow
                      children: [
                        Text(
                          song.title ?? 'Sin título',
                          style: _titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3), // ✅ Reducir espaciado (4 -> 3)
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 13, // ✅ Más pequeño que Home (14 -> 13)
                              color: NeumorphismTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: song.artist != null
                                  ? ArtistNameWithBadge(
                                      artistName: song.artist!.stageName ?? 
                                          (song.artist!.displayName.isNotEmpty 
                                              ? song.artist!.displayName 
                                              : 'Artista Desconocido'),
                                      isVerified: song.artist!.isVerifiedValue,
                                      textStyle: _artistStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      badgeSize: 12.0, // ✅ Tamaño más pequeño para esta tarjeta
                                    )
                                  : Text(
                                      'Artista Desconocido',
                                      style: _artistStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
