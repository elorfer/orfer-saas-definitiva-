import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/home_provider.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/models/song_model.dart';
import '../../../song_detail/screens/song_detail_screen.dart';
import 'cards/web_song_card.dart';

class WebFeaturedSongsSection extends ConsumerWidget {
  const WebFeaturedSongsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredSongs = ref.watch(featuredSongsProvider);

    if (featuredSongs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to 12 songs for the home screen grid to avoid overcrowding
    final displaySongs = featuredSongs.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Canciones Destacadas',
          actionLabel: 'Ver todas',
          onTapMore: () => context.push('/featured-songs'),
        ),
        const SizedBox(height: 20),
        
        // Grid Layout for Songs (Spotify Style)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220, // Standard card width
            childAspectRatio: 0.7, // Taller for image + text to avoid overflow
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: displaySongs.length,
          itemBuilder: (context, index) {
            final featuredSong = displaySongs[index];
            return WebSongCard(
              featuredSong: featuredSong,
              onTap: () => _onSongTap(context, featuredSong.song),
            );
          },
        ),
      ],
    );
  }

  void _onSongTap(BuildContext context, Song song) {
    if (!context.mounted) return;
    SongDetailScreen.navigateToSong(context, song);
  }
}
