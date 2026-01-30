import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/home_provider.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/models/playlist_model.dart';
import 'cards/web_playlist_card.dart';

class WebFeaturedPlaylistsSection extends ConsumerStatefulWidget {
  const WebFeaturedPlaylistsSection({super.key});

  @override
  ConsumerState<WebFeaturedPlaylistsSection> createState() => _WebFeaturedPlaylistsSectionState();
}

class _WebFeaturedPlaylistsSectionState extends ConsumerState<WebFeaturedPlaylistsSection> {
  // Evitar múltiples requests desde el mismo widget
  bool _requestedLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Si la lista está vacía al montar el widget, solicitar carga lazy
      final homeState = ref.read(homeStateProvider);
      if (!homeState.hasLoadedPlaylists && homeState.featuredPlaylists.isEmpty && !_requestedLoad) {
        _requestedLoad = true;
        ref.read(homeStateProvider.notifier).loadFeaturedPlaylists();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);

    if (featuredPlaylists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Playlists',
        ),
        const SizedBox(height: 20),
        
        // Grid Layout for Playlists (Spotify Style)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220, // Standard card width
            childAspectRatio: 0.7, 
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: featuredPlaylists.length,
          itemBuilder: (context, index) {
            final featuredPlaylist = featuredPlaylists[index];
            return WebPlaylistCard(
              featuredPlaylist: featuredPlaylist,
              onTap: () => _onPlaylistTap(context, featuredPlaylist.playlist),
            );
          },
        ),
      ],
    );
  }

  void _onPlaylistTap(BuildContext context, Playlist playlist) {
    context.push('/playlist/${playlist.id}');
  }
}
