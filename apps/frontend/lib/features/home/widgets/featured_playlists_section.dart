import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import 'featured_playlist_card.dart';

class FeaturedPlaylistsSection extends ConsumerWidget {
  const FeaturedPlaylistsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    final isLoading = ref.watch(isLoadingProvider);

    if (isLoading) {
      return _buildLoadingSection();
    }

    if (featuredPlaylists.isEmpty) {
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
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navegar a vista de todas las playlists
                  context.push('/playlists');
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.8),
                ),
                child: Text(
                  'Ver todas',
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
        
        // Lista horizontal de playlists optimizada
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 24, right: 8),
            cacheExtent: 800, // Aumentado a 800px para scroll más rápido y fluido
            physics: const FastScrollPhysics(), // Scroll más rápido y fluido
            itemCount: featuredPlaylists.length,
            itemBuilder: (context, index) {
              final featuredPlaylist = featuredPlaylists[index];
              return RepaintBoundary(
                key: ValueKey('playlist_${featuredPlaylist.playlist.id}'), // Key estable para optimización
                child: FeaturedPlaylistCard(
                  key: ValueKey('playlist_card_${featuredPlaylist.playlist.id}'), // Key estable
                  featuredPlaylist: featuredPlaylist,
                  onTap: () {
                    _onPlaylistTap(context, featuredPlaylist.playlist);
                  },
                ),
              );
            },
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
          'Playlists Destacadas',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            cacheExtent: 800, // Aumentado para scroll más rápido
            physics: const FastScrollPhysics(), // Scroll más rápido y fluido
            itemCount: 3,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                key: ValueKey('loading_playlist_$index'),
                child: Container(
                width: 160,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
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
          'Playlists Destacadas',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
      ],
    );
  }

  void _onPlaylistTap(BuildContext context, Playlist playlist) {
    // Navegar a detalles de la playlist
    context.push('/playlist/${playlist.id}');
  }
}

