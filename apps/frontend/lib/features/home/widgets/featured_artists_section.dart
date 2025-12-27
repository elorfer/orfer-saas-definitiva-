import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/home_provider.dart';

import '../../../core/models/artist_model.dart';
import '../../../core/widgets/optimized_image.dart';

import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/verified_badge.dart';
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
  
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
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
        // Header simplificado
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Compositores',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: NeumorphismTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.push('/compositores');
                },
                child: const Text(
                  'Ver Más',
                  style: TextStyle(
                    fontSize: 14,
                    color: NeumorphismTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20), // Padding interno para que los items no toquen los bordes
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final featuredArtists = ref.watch(featuredArtistsProvider);
                  
                  return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true, // Importante para que se ajuste al contenido
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: false,
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8, // Ajustado para items transparentes
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        if (index < featuredArtists.length) {
                          final artist = featuredArtists[index];
                          return FeaturedArtistCard(
                            key: ValueKey('artist_card_${artist.artist.id}'),
                            featuredArtist: artist,
                            onTap: () => GoRouter.of(context).push('/artist/${artist.artist.id}'),
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3EBE3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 60,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEAE2D9),
                                  borderRadius: BorderRadius.all(Radius.circular(4)),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    );
                },
              ),
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
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 24,
                width: 160,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4D6C8), // 🚀 Sólido
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              Container(
                height: 14,
                width: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4D6C8), // 🚀 Sólido
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Grid skeleton (simulado con Container + GridView static)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90, // Match 90px from FeaturedArtistCard
                      height: 90,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3EBE3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 14,
                      width: 70,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAE2D9),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compositores Destacados',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: NeumorphismTheme.textPrimary,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 160,
          decoration: const BoxDecoration(
            color: Color(0xFFEEE4DA), // 🚀 Sólido
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 40,
                  color: Color(0xFF8B7A6A),
                ),
                SizedBox(height: 12),
                Text(
                  'No hay compositores destacados',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF3D2E20),
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
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
