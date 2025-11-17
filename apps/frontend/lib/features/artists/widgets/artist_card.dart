import 'package:flutter/material.dart';
import '../models/artist.dart';

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: artist.coverPhotoUrl != null
                  ? Image.network(artist.coverPhotoUrl!, fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: artist.profilePhotoUrl != null ? NetworkImage(artist.profilePhotoUrl!) : null,
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


