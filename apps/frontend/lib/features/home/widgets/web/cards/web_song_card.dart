import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/models/song_model.dart';
import '../../../../../../core/widgets/optimized_image.dart';
import '../../../../../../core/theme/neumorphism_theme.dart';

class WebSongCard extends StatefulWidget {
  final FeaturedSong featuredSong;
  final VoidCallback? onTap;

  const WebSongCard({
    super.key,
    required this.featuredSong,
    this.onTap,
  });

  @override
  State<WebSongCard> createState() => _WebSongCardState();
}

class _WebSongCardState extends State<WebSongCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    // Spotify-style card: Dark background that gets lighter on hover
    final cardColor = _isHovering 
        ? const Color(0xFF282828) 
        : const Color(0xFF181818); // Darker base

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12), // Reduced from 16 to prevnet overflow
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(6), // Spotify uses slightly rounded corners
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container with Play Button overlay
              Expanded(
                child: Stack(
                  children: [
                     SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: OptimizedImage(
                        imageUrl: widget.featuredSong.song.coverArtUrl,
                        fit: BoxFit.cover,
                        borderRadius: 4,
                        placeholderColor: const Color(0xFF333333),
                      ),
                    ),
                    // Hover Play Button
                    if (_isHovering)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.accent, // Brand color (Green/Orange)
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12), // Reduced from 16
              
              // Title
              Text(
                widget.featuredSong.song.title ?? 'Untitled',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              
              // Artist Name
              Text(
                widget.featuredSong.song.artist?.displayName ?? 'Unknown Artist',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFB3B3B3), // Spotify-like grey
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
