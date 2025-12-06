import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/artist.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/widgets/follow_button.dart';
import '../../../core/widgets/verified_badge.dart';

String flagEmoji(String? code) {
  if (code == null || code.length != 2) return '🏳️';
  final cc = code.toUpperCase();
  final runes = cc.runes.map((c) => 0x1F1E6 - 65 + c).toList();
  return String.fromCharCodes(runes);
}

class ArtistCard extends ConsumerWidget {
  final ArtistLite artist;
  final VoidCallback? onTap;

  const ArtistCard({super.key, required this.artist, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.7,
            child: OptimizedImage(
              imageUrl: artist.coverPhotoUrl,
              fit: BoxFit.cover,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipOval(
                child: OptimizedImage(
                  imageUrl: artist.profilePhotoUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ArtistNameWithBadge(
                  artistName: artist.name,
                  isVerified: false, // ArtistLite no tiene isVerified, se puede extender si es necesario
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  badgeSize: 14.0,
                ),
              ),
              Text(flagEmoji(artist.nationalityCode)),
              const SizedBox(width: 4),
              // Botón de seguir en modo compacto
              FollowButton(
                artistId: artist.id,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


