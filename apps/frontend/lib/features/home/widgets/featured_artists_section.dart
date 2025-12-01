import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../features/artists/models/artist.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/theme/neumorphism_theme.dart';
import 'featured_artist_card.dart';

class FeaturedArtistsSection extends ConsumerWidget {
  const FeaturedArtistsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Optimización: usar select para escuchar solo cambios específicos
    final featuredArtists = ref.watch(featuredArtistsProvider.select((state) => state));
    final isLoading = ref.watch(isLoadingProvider.select((state) => state));

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
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icono de artista destacado
                Container(
                  width: 48,
                  height: 48,
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
                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
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
          height: 235, // Aumentado para evitar overflow cuando hay razón destacada
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(homeStateProvider.notifier).loadFeaturedArtists();
            },
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 24, right: 8),
              cacheExtent: 300, // ✅ OPTIMIZACIÓN: Reducido de 800 a 300px para mejor rendimiento
              physics: const FastScrollPhysics(), // Scroll más rápido y fluido
              itemCount: featuredArtists.length,
              itemBuilder: (context, index) {
                final featuredArtist = featuredArtists[index];
                return RepaintBoundary(
                  key: ValueKey('artist_${featuredArtist.artist.id}'), // Key estable para optimización
                  child: FeaturedArtistCard(
                    key: ValueKey('artist_card_${featuredArtist.artist.id}'), // Key estable
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

  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton - CRÍTICO: Misma estructura que el header real
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24), // Mismo padding que el real
          child: Container(
            padding: const EdgeInsets.all(16.0), // Mismo padding que el real
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15),
                  NeumorphismTheme.coffeeDark.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20), // Mismo borderRadius que el real
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icono skeleton - CRÍTICO: 48x48 circular con gradiente y sombra
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                        NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Shimmer.fromColors(
                    baseColor: NeumorphismTheme.shimmerBaseColor,
                    highlightColor: NeumorphismTheme.shimmerHighlightColor,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: NeumorphismTheme.shimmerContentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12), // Mismo espacio que el real
                // Título skeleton - CRÍTICO: fontSize 20
                Expanded(
                  child: Shimmer.fromColors(
                    baseColor: NeumorphismTheme.shimmerBaseColor,
                    highlightColor: NeumorphismTheme.shimmerHighlightColor,
                    child: Container(
                      height: 20, // Mismo fontSize que el texto real
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.shimmerContentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                // Botón "Ver todos" skeleton - CRÍTICO: Mismo tamaño que el botón real
                Shimmer.fromColors(
                  baseColor: NeumorphismTheme.shimmerBaseColor,
                  highlightColor: NeumorphismTheme.shimmerHighlightColor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Mismo padding que el botón real
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.shimmerContentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Container(
                      height: 14, // Mismo fontSize que el texto del botón
                      width: 70, // Ancho aproximado del texto "Ver todos"
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16), // Mismo espacio que el real
        SizedBox(
          height: 235, // Aumentado para consistencia
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            cacheExtent: 300, // ✅ OPTIMIZACIÓN: Reducido de 800 a 300px
            physics: const FastScrollPhysics(), // Scroll más rápido y fluido
            itemCount: 3,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                key: ValueKey('loading_artist_$index'),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 16), // Mismo margin que el real
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen skeleton - CRÍTICO: 140x140 circular con sombra
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, // Mismo shape que el real (circular)
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Shimmer.fromColors(
                            baseColor: NeumorphismTheme.shimmerBaseColor,
                            highlightColor: NeumorphismTheme.shimmerHighlightColor,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: const BoxDecoration(
                                color: NeumorphismTheme.shimmerContentColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12), // Mismo espacio que el real
                      // Nombre skeleton - CRÍTICO: fontSize 15
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Shimmer.fromColors(
                              baseColor: NeumorphismTheme.shimmerBaseColor,
                              highlightColor: NeumorphismTheme.shimmerHighlightColor,
                              child: Container(
                                height: 15, // Mismo fontSize que el texto real
                                width: 100,
                                decoration: BoxDecoration(
                                  color: NeumorphismTheme.shimmerContentColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6), // Mismo espacio que el real
                            // Seguidores skeleton - CRÍTICO: fontSize 12 con icono
                            Row(
                              children: [
                                Container(
                                  width: 12, // Mismo tamaño que el icono real
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: NeumorphismTheme.shimmerContentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4), // Mismo espacio que el real
                                Shimmer.fromColors(
                                  baseColor: NeumorphismTheme.shimmerBaseColor,
                                  highlightColor: NeumorphismTheme.shimmerHighlightColor,
                                  child: Container(
                                    height: 12, // Mismo fontSize que el texto real
                                    width: 80,
                                    decoration: BoxDecoration(
                                      color: NeumorphismTheme.shimmerContentColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8), // Mismo espacio que el real
                            // Badge skeleton - CRÍTICO: Mismo padding y altura
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Mismo padding que el real
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                    NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12), // Mismo borderRadius que el real
                              ),
                              child: Shimmer.fromColors(
                                baseColor: NeumorphismTheme.shimmerBaseColor,
                                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                                child: Container(
                                  height: 11, // Mismo fontSize que el texto del badge
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
