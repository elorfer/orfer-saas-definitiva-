import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/song_model.dart';

/// Widget que muestra una lista horizontal de canciones de un artista
class ArtistSongsHorizontalList extends ConsumerWidget {
  final String artistId;
  final String? currentSongId;
  final void Function(Song song)? onSongTap;

  const ArtistSongsHorizontalList({
    super.key,
    required this.artistId,
    this.currentSongId,
    this.onSongTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nota: La obtención de canciones del artista se implementará en una versión futura
    // Por ahora, retornamos un widget placeholder
    // En el futuro, esto debería usar un provider para obtener las canciones del artista
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 0, // Placeholder - se implementará cuando haya un provider
      itemBuilder: (context, index) {
        // Placeholder - se implementará cuando haya datos
        return const SizedBox.shrink();
      },
    );
  }
}
