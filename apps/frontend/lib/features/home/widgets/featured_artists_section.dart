import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../features/artists/models/artist.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import 'featured_artist_card.dart';

class FeaturedArtistsSection extends ConsumerWidget {
  const FeaturedArtistsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredArtists = ref.watch(featuredArtistsProvider);
    final isLoading = ref.watch(isLoadingProvider);

    if (isLoading) {
      return _buildLoadingSection();
    }

    if (featuredArtists.isEmpty) {
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
                'Artistas Destacados',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.push('/artists');
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.8),
                ),
                child: Text(
                  'Ver todos',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista horizontal de artistas optimizada con Pull to Refresh
        SizedBox(
          height: 220,
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(homeStateProvider.notifier).loadFeaturedArtists();
            },
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 24, right: 8),
              cacheExtent: 800, // Aumentado a 800px para scroll más rápido y fluido
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
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            cacheExtent: 800, // Aumentado para scroll más rápido
            physics: const FastScrollPhysics(), // Scroll más rápido y fluido
            itemCount: 3,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                key: ValueKey('loading_artist_$index'),
                child: Shimmer.fromColors(
                  baseColor: Colors.white.withValues(alpha: 0.1),
                  highlightColor: Colors.white.withValues(alpha: 0.3),
                  period: const Duration(milliseconds: 1200),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 16,
                          width: 100,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                        ),
                      ],
                    ),
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
