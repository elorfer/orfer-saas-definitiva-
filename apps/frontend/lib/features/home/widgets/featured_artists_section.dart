import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/home_provider.dart';

import '../../../core/models/artist_model.dart';
import '../../../core/widgets/optimized_image.dart';

import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/verified_badge.dart';

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
          height: 300, // 🚀 Aumentado para asegurar visibilidad de nombres en 2da fila
          child: Consumer(
            builder: (context, ref, _) {
              final featuredArtists = ref.watch(featuredArtistsProvider);
              
              return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: false, // 🚀 Ya cada _ArtistTile tiene su propio RepaintBoundary
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4, // 🚀 Reducido de 12
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82, // 🚀 Ajustado para reducir espacio muerto vertical
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    if (index < featuredArtists.length) {
                      final artist = featuredArtists[index];
                      return _ArtistTile(key: ValueKey('artist_tile_${artist.artist.id}'), featuredArtist: artist);
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3EBE3), // 🚀 Sólido
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 60,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAE2D9), // 🚀 Sólido
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
        // Header skeleton simplificado
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 22,
            width: 140,
            decoration: const BoxDecoration(
              color: Color(0xFFE4D6C8), // 🚀 Sólido
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Lista skeleton estática - solo 3 círculos
        SizedBox(
          height: 200,
          child: Row(
            children: [
              const SizedBox(width: 24),
              for (int i = 0; i < 3; i++) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFDED1C4), // 🚀 Sólido
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 14,
                      width: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDED1C4), // 🚀 Sólido
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
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

/// Small widget for a single artist tile. Kept minimal so rebuilds are tiny.
class _ArtistTile extends StatelessWidget {
  final FeaturedArtist featuredArtist;

  const _ArtistTile({super.key, required this.featuredArtist});

  static const _artistNameStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: NeumorphismTheme.textPrimary,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    // ⚡ GAMA BAJA: Eliminamos la observación de reproducción aquí.
    // Solo mostramos un indicador estático o dejamos que la imagen sea el centro.
    // Esto evita que todos los tiles se rebuilden cuando cambia la canción.

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => GoRouter.of(context).push('/artist/${featuredArtist.artist.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            OptimizedImage(
              imageUrl: featuredArtist.artist.profilePhotoUrl ?? featuredArtist.imageUrl,
              fit: BoxFit.cover,
              width: 86,
              height: 86,
              maxCacheWidth: 150,
              maxCacheHeight: 150,
              borderRadius: 43, // 🚀 Circular directo en el widget
              placeholderColor: const Color(0xFFF3EBE3),
              lazyLoad: true,
            ),
            const SizedBox(height: 4), // 🚀 Reducido de 6
            ArtistNameWithBadge(
              artistName: featuredArtist.artist.stageName ?? 'Artista',
              isVerified: featuredArtist.artist.isVerifiedValue,
              textStyle: _artistNameStyle,
              badgeSize: 12.0,
              badgeColor: NeumorphismTheme.accentDark,
              alignment: MainAxisAlignment.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
