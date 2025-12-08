import 'dart:async'; // ✅ Para Timer
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/utils/intersection_observer.dart';
import 'featured_playlist_card.dart';

/// ✅ OPTIMIZADO: ConsumerStatefulWidget con precache basado en visibilidad
/// Usa directamente los providers para evitar rebuilds innecesarios
class FeaturedPlaylistsSection extends ConsumerStatefulWidget {
  const FeaturedPlaylistsSection({super.key});

  @override
  ConsumerState<FeaturedPlaylistsSection> createState() => _FeaturedPlaylistsSectionState();
}

class _FeaturedPlaylistsSectionState extends ConsumerState<FeaturedPlaylistsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 🔥 OPTIMIZACIÓN: Mantener estado al hacer scroll
  
  // ScrollController para detectar visibilidad y precachear imágenes
  final ScrollController _scrollController = ScrollController();
  
  // ✅ OPTIMIZACIÓN: Cache de URLs de imágenes para evitar recálculos en _onScroll
  List<String> _cachedImageUrls = [];
  int _cachedPlaylistsCount = 0;
  
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
          final featuredPlaylists = ref.read(featuredPlaylistsProvider);
          _cachedImageUrls = featuredPlaylists
              .map((fp) => fp.playlist.coverArtUrl)
              .where((url) => url != null && url.isNotEmpty)
              .cast<String>()
              .toList();
          _cachedPlaylistsCount = featuredPlaylists.length;
        }
        
        // Precachear imágenes visibles basado en posición del scroll (IntersectionObserver)
        if (_cachedImageUrls.isNotEmpty) {
          LazyImageLoader.precacheVisibleImages(
            scrollController: _scrollController,
            itemExtent: 176.0, // Ancho fijo de cada item
            itemCount: _cachedPlaylistsCount,
            imageUrls: _cachedImageUrls,
            context: context,
            precacheCount: 3, // Precachear 3 items antes y después del viewport
          );
        }
      } catch (e) {
        // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente para no bloquear la app
        debugPrint('[FeaturedPlaylistsSection] Error en _onScroll: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // ✅ OPTIMIZACIÓN: Los providers ya usan select() internamente
    // Solo se reconstruye cuando cambian estos valores específicos
    final isLoading = ref.watch(isLoadingProvider);
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    
    // ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambien los datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cachedImageUrls = featuredPlaylists
            .map((fp) => fp.playlist.coverArtUrl)
            .where((url) => url != null && url.isNotEmpty)
            .cast<String>()
            .toList();
        _cachedPlaylistsCount = featuredPlaylists.length;
      }
    });
    
    // Pre-cachear imágenes después del primer build cuando hay datos (IntersectionObserver)
    if (featuredPlaylists.isNotEmpty && !isLoading) {
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
            debugPrint('[FeaturedPlaylistsSection] Error en precache inicial: $e');
          }
        }
      });
    }

    // CRÍTICO: Solo mostrar skeleton durante carga inicial (cuando no hay datos)
    // Si hay datos pero está cargando (refresh), mostrar contenido existente
    if (isLoading && featuredPlaylists.isEmpty) {
      return _buildLoadingSection();
    }

    if (featuredPlaylists.isEmpty && !isLoading) {
      return _buildEmptySection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Playlists Destacadas',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3D2E20),
                  decoration: TextDecoration.none,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navegar a vista de todas las playlists
                  context.push('/playlists');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8B7A6A),
                ),
                child: Text(
                  'Ver todas',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF8B7A6A),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista horizontal de playlists optimizada
        _buildPlaylistsList(featuredPlaylists),
      ],
    );
  }

  Widget _buildPlaylistsList(List<FeaturedPlaylist> featuredPlaylists) {
    return SizedBox(
      height: 260,
      child: ListView.builder(
        controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache basado en visibilidad
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 24, right: 8),
        cacheExtent: 1200, // 🔥 OPTIMIZACIÓN MÁXIMA: Precarga 4-6 items extra
        physics: const BouncingScrollPhysics(), // 🔥 Configuración perfecta
        itemExtent: 176.0, // 🔥 OPTIMIZACIÓN: Ancho fijo (160 + 16 margin) para mejor cálculo de scroll
        addAutomaticKeepAlives: false, // Menos reconstrucciones
        addRepaintBoundaries: true, // 🔥 GPU trabaja menos
        addSemanticIndexes: false, // 🔥 Más rápido
        itemCount: featuredPlaylists.length,
        itemBuilder: (context, index) {
          final featuredPlaylist = featuredPlaylists[index];
          return RepaintBoundary(
            key: ValueKey('playlist_${featuredPlaylist.playlist.id}'),
            child: FeaturedPlaylistCard(
              key: ValueKey('playlist_card_${featuredPlaylist.playlist.id}'),
              featuredPlaylist: featuredPlaylist,
              onTap: () {
                _onPlaylistTap(context, featuredPlaylist.playlist);
              },
            ),
          );
        },
      ),
    );
  }

  /// ⚡ OPTIMIZADO: Skeleton ligero adaptado al contenido real
  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Playlists Destacadas',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Lista skeleton - Tamaños exactos del contenido real
        SizedBox(
          height: 260, // Altura del contenido real
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            padding: const EdgeInsets.only(left: 24, right: 8), // Igual que el real
            cacheExtent: 300, // Reducido para ser más ligero
            physics: const ClampingScrollPhysics(), // Igual que el real
            itemExtent: 176.0, // 🔥 OPTIMIZACIÓN: Ancho fijo (160 + 16 margin) para mejor cálculo de scroll
            itemCount: 2, // Solo 2 items para reducir carga
            itemBuilder: (context, index) {
              return Container(
                width: 160, // Igual que FeaturedPlaylistCard
                margin: const EdgeInsets.only(right: 16), // Igual que el real
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen skeleton - 160x160 (igual que el real)
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200), // Más lento = más ligero
                      child: Container(
                        width: 160, // Igual que el real
                        height: 160, // Igual que el real
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.shimmerContentColor,
                          borderRadius: const BorderRadius.all(Radius.circular(16)), // Igual que el real
                        ),
                      ),
                    ),
                    const SizedBox(height: 12), // Igual que el real
                    // Texto skeleton - Tamaño aproximado del título
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        height: 15, // Altura aproximada del texto
                        width: 120, // Ancho aproximado
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Playlists Destacadas',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.playlist_play,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay playlists destacadas',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descubre nuevas playlists más tarde',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  void _onPlaylistTap(BuildContext context, Playlist playlist) {
    // Navegar a detalles de la playlist
    context.push('/playlist/${playlist.id}');
  }
}
