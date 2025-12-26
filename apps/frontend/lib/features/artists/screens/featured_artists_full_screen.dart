import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../home/widgets/featured_artist_card.dart';
import '../../../core/providers/home_provider.dart';

class FeaturedArtistsFullScreen extends ConsumerWidget {
  const FeaturedArtistsFullScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredArtists = ref.watch(featuredArtistsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compositores Destacados'),
        backgroundColor: NeumorphismTheme.coffeeMedium,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: NeumorphismTheme.background,
      body: featuredArtists.isEmpty
          ? Center(
              child: Text(
                'No hay compositores destacados',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: featuredArtists.length,
                itemBuilder: (context, index) {
                  final featuredArtist = featuredArtists[index];
                  return FeaturedArtistCard(
                    featuredArtist: featuredArtist,
                    onTap: () {
                      final artist = featuredArtist.artist;
                      context.push('/artist/${artist.id}', extra: artist);
                    },
                  );
                },
              ),
            ),
    );
  }
}
