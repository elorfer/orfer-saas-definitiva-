import 'package:flutter/material.dart';
import '../../../../../../core/models/playlist_model.dart';
import '../../../../../../core/widgets/optimized_image.dart';

class WebPlaylistCard extends StatefulWidget {
  final FeaturedPlaylist featuredPlaylist;
  final VoidCallback? onTap;

  const WebPlaylistCard({
    super.key,
    required this.featuredPlaylist,
    this.onTap,
  });

  @override
  State<WebPlaylistCard> createState() => _WebPlaylistCardState();
}

class _WebPlaylistCardState extends State<WebPlaylistCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = _isHovering 
        ? const Color(0xFF282828) 
        : const Color(0xFF181818);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12), // Reduced from 16
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container
               AspectRatio(
                aspectRatio: 1,
                child: OptimizedImage(
                  imageUrl: widget.featuredPlaylist.playlist.coverArtUrl,
                  fit: BoxFit.cover,
                  borderRadius: 4,
                  placeholderColor: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12), // Reduced from 16
              
              // Title
              Text(
                widget.featuredPlaylist.playlist.name ?? 'Untitled Playlist',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              
              // Description / Owner
              Text(
                'By Struky', // Could be dynamic if owner info is available
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFB3B3B3),
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
