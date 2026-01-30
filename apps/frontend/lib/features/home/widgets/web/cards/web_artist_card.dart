import 'package:flutter/material.dart';
import '../../../../../../core/models/artist_model.dart';
import '../../../../../../core/widgets/optimized_image.dart';

class WebArtistCard extends StatefulWidget {
  final FeaturedArtist featuredArtist;
  final VoidCallback? onTap;

  const WebArtistCard({
    super.key,
    required this.featuredArtist,
    this.onTap,
  });

  @override
  State<WebArtistCard> createState() => _WebArtistCardState();
}

class _WebArtistCardState extends State<WebArtistCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = _isHovering 
        ? const Color(0xFF282828) 
        : Colors.transparent; // Transparent by default for Artists (Spotify style)

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Center everything
            children: [
              // Circular Image
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      // Fallback color if image is loading/transparent
                      color: Color(0xFF282828), 
                    ),
                    clipBehavior: Clip.antiAlias, // Enforce circle for child
                    child: OptimizedImage(
                      imageUrl: widget.featuredArtist.imageUrl,
                      fit: BoxFit.cover,
                      placeholderColor: const Color(0xFF282828),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Name
              Text(
                widget.featuredArtist.artist.stageName ?? 'Artist',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              
              // Label
              const Text(
                'Compositor',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFB3B3B3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
