import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../features/artists/models/artist.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/artist_model.dart';
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
                // Icono de artista destacado
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
              cacheExtent: 1200, // 🔥 OPTIMIZACIÓN MÁXIMA: Precarga 4-6 items extra
              physics: const BouncingScrollPhysics(), // 🔥 Configuración perfecta
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
                      borderRadius: BorderRadius.circular(4),
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
                    borderRadius: BorderRadius.circular(4),
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
            itemCount: 2, // Solo 2 items para reducir carga
            itemBuilder: (context, index) {
              return Container(
                width: 140, // Igual que FeaturedArtistCard
                margin: EdgeInsets.only(right: 16, left: index == 0 ? 0 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen skeleton - 140x140 circular (igual que el real)
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        width: 140, // Igual que el real
                        height: 140, // Igual que el real
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
                          borderRadius: BorderRadius.circular(4),
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
