import 'dart:async'; // ✅ Para Timer
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../features/artists/models/artist.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/utils/intersection_observer.dart';
import 'featured_artist_card.dart';

class FeaturedArtistsSection extends ConsumerStatefulWidget {
  const FeaturedArtistsSection({super.key});

  @override
  ConsumerState<FeaturedArtistsSection> createState() => _FeaturedArtistsSectionState();
}

class _FeaturedArtistsSectionState extends ConsumerState<FeaturedArtistsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 🔥 OPTIMIZACIÓN: Mantener estado al hacer scroll
  
  // ScrollController para detectar visibilidad y precachear imágenes
  final ScrollController _scrollController = ScrollController();
  
  // ✅ OPTIMIZACIÓN: Cache de URLs de imágenes para evitar recálculos en _onScroll
  List<String> _cachedImageUrls = [];
  int _cachedArtistsCount = 0;
  
  // ✅ OPTIMIZACIÓN: Timer para debounce en _onScroll
  Timer? _scrollDebounceTimer;
  
  @override
  void initState() {
    super.initState();
    // Listener para precachear imágenes visibles al hacer scroll
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
  
  /// ✅ OPTIMIZACIÓN: Precargar imágenes visibles cuando el usuario hace scroll
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
          final featuredArtists = ref.read(featuredArtistsProvider);
          _cachedImageUrls = featuredArtists
              .map((fa) => fa.artist.profilePhotoUrl)
              .where((url) => url != null && url.isNotEmpty)
              .cast<String>()
              .toList();
          _cachedArtistsCount = featuredArtists.length;
        }
        
        // Precachear imágenes visibles basado en posición del scroll (IntersectionObserver)
        if (_cachedImageUrls.isNotEmpty) {
          LazyImageLoader.precacheVisibleImages(
            scrollController: _scrollController,
            itemExtent: 156.0, // Ancho fijo de cada item
            itemCount: _cachedArtistsCount,
            imageUrls: _cachedImageUrls,
            context: context,
            precacheCount: 3, // Precachear 3 items antes y después del viewport
          );
        }
      } catch (e) {
        // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente para no bloquear la app
        debugPrint('[FeaturedArtistsSection] Error en _onScroll: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // ✅ OPTIMIZACIÓN: Los providers ya usan select() internamente
    // Solo se reconstruye cuando cambian estos valores específicos
    final featuredArtists = ref.watch(featuredArtistsProvider);
    final isLoading = ref.watch(isLoadingProvider);
    
    // ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambien los datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cachedImageUrls = featuredArtists
            .map((fa) => fa.artist.profilePhotoUrl)
            .where((url) => url != null && url.isNotEmpty)
            .cast<String>()
            .toList();
        _cachedArtistsCount = featuredArtists.length;
      }
    });
    
    // Pre-cachear imágenes después del primer build cuando hay datos
    if (featuredArtists.isNotEmpty && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _cachedImageUrls.isNotEmpty) {
          try {
            LazyImageLoader.precacheInitialImages(
              imageUrls: _cachedImageUrls,
              context: context,
              count: 3,
            );
          } catch (e) {
            // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente
            debugPrint('[FeaturedArtistsSection] Error en precache inicial: $e');
          }
        }
      });
    }

    // CRÍTICO: Solo mostrar skeleton durante carga inicial (cuando no hay datos)
    // Si hay datos pero está cargando (refresh), mostrar contenido existente
    if (isLoading && featuredArtists.isEmpty) {
      return _buildLoadingSection();
    }

    if (featuredArtists.isEmpty && !isLoading) {
      return _buildEmptySection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header mejorado con icono
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15),
                  NeumorphismTheme.coffeeDark.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000), // 🔥 Const: alpha 0.08
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icono de artista destacado (sin círculo)
                const Icon(
                  Icons.star_rounded,
                  color: NeumorphismTheme.coffeeDark,
                  size: 24,
                ),
                const SizedBox(width: 12),
                // Título
                Expanded(
                  child: Text(
                    'Artistas Destacados',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                // Botón "Ver todos"
                TextButton(
                  onPressed: () {
                    context.push('/artists');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: NeumorphismTheme.accentDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Ver todos',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NeumorphismTheme.accentDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista horizontal de artistas optimizada con Pull to Refresh
        SizedBox(
          height: 215, // Reducido para ajustar al nuevo tamaño de imagen
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(homeStateProvider.notifier).loadFeaturedArtists();
            },
            child: ListView.builder(
              controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache basado en visibilidad
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 24, right: 8),
              cacheExtent: 1200, // 🔥 OPTIMIZACIÓN MÁXIMA: Precarga 4-6 items extra
              physics: const BouncingScrollPhysics(), // 🔥 Configuración perfecta
              itemExtent: 136.0, // 🔥 OPTIMIZACIÓN: Ancho fijo (120 + 16 margin) para mejor cálculo de scroll
              addAutomaticKeepAlives: false, // Menos reconstrucciones
              addRepaintBoundaries: true, // 🔥 GPU trabaja menos
              addSemanticIndexes: false, // 🔥 Más rápido
              itemCount: featuredArtists.length,
              itemBuilder: (context, index) {
                final featuredArtist = featuredArtists[index];
                return RepaintBoundary(
                  key: ValueKey('artist_${featuredArtist.artist.id}'),
                  child: FeaturedArtistCard(
                    key: ValueKey('artist_card_${featuredArtist.artist.id}'),
                    featuredArtist: featuredArtist,
                    onTap: () {
                      _onArtistTap(context, featuredArtist.artist);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// ⚡ OPTIMIZADO: Skeleton ligero adaptado al contenido real
  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton - Tamaños exactos del contenido real
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Shimmer.fromColors(
                baseColor: NeumorphismTheme.shimmerBaseColor,
                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                period: const Duration(milliseconds: 1200), // Más lento = más ligero
                child: Container(
                  width: 48, // Igual que el icono real
                  height: 48, // Igual que el icono real
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: NeumorphismTheme.shimmerContentColor,
                  ),
                ),
              ),
              const SizedBox(width: 12), // Igual que el real
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: NeumorphismTheme.shimmerBaseColor,
                  highlightColor: NeumorphismTheme.shimmerHighlightColor,
                  period: const Duration(milliseconds: 1200),
                  child: Container(
                    height: 20, // Igual que fontSize 20 del título real
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.shimmerContentColor,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12), // Igual que el real
              Shimmer.fromColors(
                baseColor: NeumorphismTheme.shimmerBaseColor,
                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                period: const Duration(milliseconds: 1200),
                child: Container(
                  height: 14, // Igual que fontSize 14 del botón "Ver todos"
                  width: 70, // Ancho aproximado del botón
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.shimmerContentColor,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16), // Igual que el real
        // Lista skeleton - Altura exacta 235px (igual que el contenido real)
        SizedBox(
          height: 235, // Igual que el contenido real
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 24, right: 8), // Igual que el real
            cacheExtent: 300, // Reducido para ser más ligero
            physics: const BouncingScrollPhysics(), // Igual que el real
            itemExtent: 156.0, // 🔥 OPTIMIZACIÓN: Ancho fijo (140 + 16 margin) para mejor cálculo de scroll
            itemCount: 2, // Solo 2 items para reducir carga
            itemBuilder: (context, index) {
              return Container(
                width: 120, // Igual que FeaturedArtistCard
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen skeleton - 120x120 circular (igual que el real)
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        width: 120, // Igual que el real
                        height: 120, // Igual que el real
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: NeumorphismTheme.shimmerContentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12), // Igual que el real
                    // Texto skeleton - Tamaño aproximado del nombre del artista
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        height: 14, // Altura aproximada del texto
                        width: 100, // Ancho aproximado
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.shimmerContentColor,
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Artistas Destacados',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_note,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay artistas destacados',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vuelve más tarde para descubrir nuevos talentos',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onArtistTap(BuildContext context, Artist artist) {
    final lite = ArtistLite(
      id: artist.id,
      name: artist.stageName ?? 'Artista',
      profilePhotoUrl: artist.profilePhotoUrl,
      coverPhotoUrl: artist.coverPhotoUrl,
      nationalityCode: null,
      featured: true,
    );
    context.push('/artist/${artist.id}', extra: lite);
  }
}
