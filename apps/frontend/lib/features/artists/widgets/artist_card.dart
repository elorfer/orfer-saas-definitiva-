import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../../../core/widgets/network_image_with_fallback.dart';

String flagEmoji(String? code) {
  if (code == null || code.length != 2) return '🏳️';
  final cc = code.toUpperCase();
  final runes = cc.runes.map((c) => 0x1F1E6 - 65 + c).toList();
  return String.fromCharCodes(runes);
}

class ArtistCard extends StatelessWidget {
  final ArtistLite artist;
  final VoidCallback? onTap;

  const ArtistCard({super.key, required this.artist, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.7,
            child: NetworkImageWithFallback.medium(
              imageUrl: artist.coverPhotoUrl,
              fit: BoxFit.cover,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipOval(
                child: NetworkImageWithFallback.small(
                  imageUrl: artist.profilePhotoUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(flagEmoji(artist.nationalityCode)),
            ],
          ),
        ],
      ),
    );
  }
}


