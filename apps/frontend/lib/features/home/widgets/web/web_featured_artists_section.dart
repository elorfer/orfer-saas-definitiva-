import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/home_provider.dart';
import '../../../../core/widgets/section_header.dart';
import 'cards/web_artist_card.dart';

class WebFeaturedArtistsSection extends ConsumerWidget {
  const WebFeaturedArtistsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredArtists = ref.watch(featuredArtistsProvider);

    if (featuredArtists.isEmpty) {
      return const SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Compositores',
          onTapMore: () => context.push('/compositores'),
        ),
        const SizedBox(height: 20),
        
        // Grid Layout for Artists
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200, // Slightly larger for better spacing
            childAspectRatio: 0.7, // Adjusted to prevent overflow (v0.8 was too tight)
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: featuredArtists.length,
          itemBuilder: (context, index) {
            final artist = featuredArtists[index];
            return WebArtistCard(
              featuredArtist: artist,
              onTap: () => GoRouter.of(context).push('/artist/${artist.artist.id}'),
            );
          },
        ),
      ],
    );
  }
}
