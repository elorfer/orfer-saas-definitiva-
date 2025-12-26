import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/home_provider.dart';
import '../../../../core/models/artist_model.dart';
import '../../../../core/widgets/optimized_image.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../core/theme/neumorphism_theme.dart';

class SliverFeaturedArtistsSection extends ConsumerWidget {
  const SliverFeaturedArtistsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredArtists = ref.watch(featuredArtistsProvider);
    
    // Si está cargando y no hay datos, el Skeleton se maneja en un Sliver separado (opcional)
    // O podemos retornar un SliverToBoxAdapter vacío o con skeletons aquí.
    if (featuredArtists.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        // Header de Sección
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Compositores',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: NeumorphismTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/compositores'),
                  child: const Text('Ver todos', style: TextStyle(color: NeumorphismTheme.coffeeMedium)),
                ),
              ],
            ),
          ),
        ),
        
        // Grid Nativo (Sin scroll interno, sin shrinkWrap)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final artist = featuredArtists[index];
                return ScaleTap(
                  onTap: () => context.push('/artist/${artist.artist.id}'),
                  child: _SliverArtistTile(artist: artist),
                );
              },
              childCount: featuredArtists.length > 6 ? 6 : featuredArtists.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ... _SliverArtistTile remains the same ...

class _SliverArtistTile extends StatelessWidget {
  final FeaturedArtist artist;
  const _SliverArtistTile({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RepaintBoundary(
            child: OptimizedImage(
              imageUrl: artist.artist.profilePhotoUrl ?? artist.imageUrl,
              borderRadius: 60,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          artist.artist.stageName ?? 'Artista',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: NeumorphismTheme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Helper para agrupar múltiples slivers como una sola entidad (si se tuviera sliver_tools)
/// Si no, simplemente devolvemos una lista de slivers para ser integrados con ...
class MultiSliver extends StatelessWidget {
  final List<Widget> children;
  const MultiSliver({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    // En Flutter nativo, esto no existe como widget único que retorne Slyvers.
    // Usaremos un truco: devolver un fragmento y expandirlo en el CustomScrollView.
    return const SizedBox.shrink(); // No se usa así en este flujo.
  }
}
