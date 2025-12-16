import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
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
  
  // ScrollController simplificado - solo para el ListView horizontal
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // 🔥 FIX: Usar select() directamente para evitar rebuilds innecesarios durante scroll
    // Solo observar isLoading si realmente lo necesitamos para mostrar skeleton
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    
    // ✅ OPTIMIZACIÓN: Solo observar isLoading si la lista está vacía
    final isLoading = featuredPlaylists.isEmpty 
        ? ref.watch(homeStateProvider.select((state) => state.isLoading)) 
        : false;
    
    // OPTIMIZACIÓN: Logging removido del build para mejor rendimiento

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
        // Título simplificado
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Playlists',
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2E20),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Lista horizontal de playlists optimizada
        _buildPlaylistsList(featuredPlaylists),
      ],
    );
  }

  Widget _buildPlaylistsList(List<FeaturedPlaylist> featuredPlaylists) {
    return SizedBox(
      height: 252,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 24, right: 8),
        cacheExtent: 300,
        physics: const BouncingScrollPhysics(),
        itemExtent: 176.0,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        itemCount: featuredPlaylists.length,
        itemBuilder: (context, index) {
          final featuredPlaylist = featuredPlaylists[index];
          return RepaintBoundary(
            key: ValueKey('playlist_${featuredPlaylist.playlist.id}'),
            child: FeaturedPlaylistCard(
              key: ValueKey('playlist_card_${featuredPlaylist.playlist.id}'),
              featuredPlaylist: featuredPlaylist,
              onTap: () => _onPlaylistTap(context, featuredPlaylist.playlist),
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
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: const TextStyle(
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
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: const TextStyle(
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
                    // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descubre nuevas playlists más tarde',
                    // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                    style: TextStyle(
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
  
  // OPTIMIZACIÓN: Método de logging removido para mejor rendimiento
}
