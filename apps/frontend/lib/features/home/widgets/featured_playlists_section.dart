import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/models/playlist_model.dart';

import 'featured_playlist_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/theme/neumorphism_theme.dart';

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

  // Evitar múltiples requests desde el mismo widget
  bool _requestedLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Si la lista está vacía al montar el widget, solicitar carga lazy
      final homeState = ref.read(homeStateProvider);
      if (!homeState.hasLoadedPlaylists && homeState.featuredPlaylists.isEmpty && !_requestedLoad) {
        _requestedLoad = true;
        ref.read(homeStateProvider.notifier).loadFeaturedPlaylists();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    // 🚀 Refresh on Theme Change
    ref.watch(themeProvider);
    
    // 🔥 FIX: Usar select() directamente para evitar rebuilds innecesarios durante scroll
    // Solo observar isLoading si realmente lo necesitamos para mostrar skeleton
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    
    // ✅ OPTIMIZACIÓN: Solo observar isLoading si la lista está vacía
      // Guardar: si ya hay datos, no disparar request extra ni mostrar skeleton
      if (featuredPlaylists.isNotEmpty) {
        // ...existing code...
      }
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
        // Header estandarizado
        SectionHeader(
          title: 'Playlists',
          // No "Ver más" needed for playlists yet, or could link to library
        ),
        
        const SizedBox(height: 16),
        
        // Lista horizontal de playlists optimizada
        _buildPlaylistsList(featuredPlaylists),
        
      ],
    );
  }

  Widget _buildPlaylistsList(List<FeaturedPlaylist> featuredPlaylists) {
    return RepaintBoundary(
      child: SizedBox(
        height: 252,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 24, right: 8),
          cacheExtent: 300, // 🚀 OPTIMIZACIÓN: Reducido para evitar trabajo excesivo de GPU
          physics: const BouncingScrollPhysics(), // 🚀 Bouncing para consistencia con el Home
          itemExtent: 176.0,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false, // 🚀 OPTIMIZATION: Manual control below with keys
          addSemanticIndexes: false,
          itemCount: featuredPlaylists.length,
          itemBuilder: (context, index) {
            final featuredPlaylist = featuredPlaylists[index];
            return RepaintBoundary(
              key: ValueKey('playlist_boundary_${featuredPlaylist.playlist.id}'),
              child: FeaturedPlaylistCard(
                key: ValueKey('playlist_card_${featuredPlaylist.playlist.id}'),
                featuredPlaylist: featuredPlaylist,
                onTap: () => _onPlaylistTap(context, featuredPlaylist.playlist),
              ),
            );
          },
        ),
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
            'Playlists',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: NeumorphismTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 16), // ✅ Sincronizado con real (16)
        // ⚡ Lista skeleton estática - sin animaciones Shimmer
        SizedBox(
          height: 252, // ✅ Sincronizado con real (252)
          child: Row(
            children: [
              const SizedBox(width: 24),
              for (int i = 0; i < 2; i++) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.shimmerBaseColor,
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.shimmerBaseColor,
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 6),
                     Container(
                      height: 18,
                      width: 100,
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.shimmerBaseColor,
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
              ],
            ],
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.playlist_play,
                  size: 48,
                  color: const Color(0xFFBCAAA4).withValues(alpha: 0.5), // 🚀 Sólido
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay playlists destacadas',
                  // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B7A6A), // 🚀 Sólido
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Descubre nuevas playlists más tarde',
                  // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF8B7A6A).withValues(alpha: 0.5),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
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
