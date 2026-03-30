import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/home_provider.dart';

import '../../../core/providers/theme_provider.dart';


import '../../../core/theme/neumorphism_theme.dart';
import 'featured_artist_card.dart';
import '../../../core/widgets/section_header.dart';

class FeaturedArtistsSection extends ConsumerStatefulWidget {
  const FeaturedArtistsSection({super.key});

  @override
  ConsumerState<FeaturedArtistsSection> createState() => _FeaturedArtistsSectionState();
}



class _FeaturedArtistsSectionState extends ConsumerState<FeaturedArtistsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 🔥 OPTIMIZACIÓN: Mantener estado al hacer scroll
  
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    // 🚀 Refresh on Theme Change
    ref.watch(themeProvider);
    
    final featuredArtists = ref.watch(featuredArtistsProvider);
    final isLoading = featuredArtists.isEmpty && ref.watch(homeStateProvider.select((state) => state.isLoading));
    
    // OPTIMIZACIÓN: Logging removido del build para mejor rendimiento

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
        // Header estandarizado
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Compositores',
          onTapMore: () => context.push('/compositores'),
        ),
        const SizedBox(height: 12),
        // Listado horizontal de artistas (Estilo "Stories")
        RepaintBoundary(
          child: SizedBox(
            height: 140, // Altura suficiente para avatar + nombre
            child: ListView.builder(
              key: const PageStorageKey('featured_artists_list'), // ✅ Store Scroll Position
              scrollDirection: Axis.horizontal,
              itemExtent: 114.0, // ✅ ULTRA-OPTIMIZED: Fixed width (90 img + 8 pad + 16 margin)
              itemCount: featuredArtists.length,
              padding: const EdgeInsets.symmetric(horizontal: 24), // Padding alineado con header
              physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final artist = featuredArtists[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16), // Espacio entre items
                    child: RepaintBoundary(
                      key: ValueKey('artist_boundary_${artist.artist.id}'),
                      child: FeaturedArtistCard(
                        key: ValueKey('artist_card_${artist.artist.id}'),
                        featuredArtist: artist,
                        onTap: () => GoRouter.of(context).push('/artist/${artist.artist.id}'),
                      ),
                    ),
                  );
                },
              ),
            ),
        ),

      ],
    );
  }

  /// Construir imagen del artista con fallback apropiado
  // _buildArtistImage removed; use top-level helper `_artistImageWidget` instead.

  /// ⚡ OPTIMIZADO: Skeleton estático ultra-ligero sin animaciones
  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header simplificado skeleton
        const SizedBox(height: 24), // ✅ Sincronizado con real (24)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 24,
                width: 160,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.shimmerBaseColor,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
              Container(
                height: 14,
                width: 60,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.shimmerBaseColor,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12), // ✅ Sincronizado con real (12)
        // Horizontal Scroll Skeleton
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => const _ArtistSkeletonItem(),
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
          'Compositores Destacados',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: NeumorphismTheme.textPrimary,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        // Open Layout Empty State
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 40,
                  color: const Color(0xFF8B7A6A).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No hay compositores destacados',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF3D2E20),
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vuelve más tarde para descubrir nuevos talentos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B7A6A),
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
}
class _ArtistSkeletonItem extends StatelessWidget {
  const _ArtistSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: NeumorphismTheme.shimmerBaseColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 12,
          decoration: BoxDecoration(
            color: NeumorphismTheme.shimmerBaseColor,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ],
    );
  }
}