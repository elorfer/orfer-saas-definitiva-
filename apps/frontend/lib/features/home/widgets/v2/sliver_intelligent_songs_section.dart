import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/intelligent_featured_provider.dart';
import '../../../../core/models/song_model.dart';
import '../../../../core/widgets/optimized_image.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../core/theme/neumorphism_theme.dart';

class SliverIntelligentSongsSection extends ConsumerWidget {
  const SliverIntelligentSongsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(intelligentFeaturedSongsProvider);
    
    if (songs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Para Ti',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: NeumorphismTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/intelligent-recommendations'),
                  child: const Text('Ver más', style: TextStyle(color: NeumorphismTheme.coffeeMedium)),
                ),
              ],
            ),
          ),
        ),
        
        // Lista Nativa (SliverList)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final featuredSong = songs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScaleTap(
                    onTap: () {
                      // Lógica de reproducción o navegación
                    },
                    child: _SliverSongCard(featuredSong: featuredSong),
                  ),
                );
              },
              childCount: songs.length > 5 ? 5 : songs.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _SliverSongCard extends StatelessWidget {
  final FeaturedSong featuredSong;
  const _SliverSongCard({required this.featuredSong});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          RepaintBoundary(
            child: OptimizedImage(
              imageUrl: featuredSong.song.coverArtUrl ?? '',
              width: 56,
              height: 56,
              borderRadius: 12,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featuredSong.song.title ?? 'Sin título',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  featuredSong.song.artist?.stageName ?? 'Artista',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert, color: Colors.grey),
        ],
      ),
    );
  }
}
