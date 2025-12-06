import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/follow_provider.dart';
import '../../../core/widgets/follow_button.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../artists/models/artist.dart';

/// Pantalla de artistas seguidos
class FollowedArtistsScreen extends ConsumerStatefulWidget {
  const FollowedArtistsScreen({super.key});

  @override
  ConsumerState<FollowedArtistsScreen> createState() => _FollowedArtistsScreenState();
}

class _FollowedArtistsScreenState extends ConsumerState<FollowedArtistsScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar artistas seguidos al montar (solo si no hay datos)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followProvider.notifier).ensureLoaded();
    });
  }

  String flagEmoji(String? code) {
    if (code == null || code.length != 2) return '🏳️';
    final cc = code.toUpperCase();
    final runes = cc.runes.map((c) => 0x1F1E6 - 65 + c).toList();
    return String.fromCharCodes(runes);
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(followProvider);

    return Scaffold(
      backgroundColor: NeumorphismTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeumorphismTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Artistas Seguidos',
          style: GoogleFonts.inter(
            color: NeumorphismTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: followState.isLoading && followState.followedArtistIds.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : followState.followedArtistIds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 80,
                        color: NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No sigues a ningún artista',
                        style: GoogleFonts.inter(
                          color: NeumorphismTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Descubre artistas y sigue a tus favoritos',
                        style: GoogleFonts.inter(
                          color: NeumorphismTheme.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(followProvider.notifier).loadFollowedArtists(force: true);
                  },
                  child: _buildArtistsList(),
                ),
    );
  }

  Widget _buildArtistsList() {
    // Usar datos directamente del provider (sin llamada HTTP adicional)
    final followState = ref.watch(followProvider);
    final artists = followState.followedArtists;

    if (artists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No sigues a ningún artista',
              style: GoogleFonts.inter(
                color: NeumorphismTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return _buildArtistItem(artist);
      },
    );
  }

  Widget _buildArtistItem(ArtistLite artist) {
    final profileUrl = UrlNormalizer.normalizeImageUrl(artist.profilePhotoUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        boxShadow: NeumorphismTheme.neumorphismShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipOval(
          child: OptimizedImage(
            imageUrl: profileUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          artist.name,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: NeumorphismTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          '${artist.totalFollowers} ${artist.totalFollowers == 1 ? 'seguidor' : 'seguidores'}',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: NeumorphismTheme.textSecondary,
          ),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (artist.nationalityCode != null) ...[
                Flexible(
                  child: Text(
                    flagEmoji(artist.nationalityCode),
                    style: const TextStyle(fontSize: 20),
                    overflow: TextOverflow.visible,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              FollowButton(
                artistId: artist.id,
                compact: true,
              ),
            ],
          ),
        ),
        onTap: () {
          context.push('/artist/${artist.id}', extra: ArtistLite(
            id: artist.id,
            name: artist.name,
            profilePhotoUrl: artist.profilePhotoUrl,
            coverPhotoUrl: artist.coverPhotoUrl,
            nationalityCode: artist.nationalityCode,
            featured: artist.featured,
            totalFollowers: artist.totalFollowers,
            totalStreams: artist.totalStreams,
            monthlyListeners: artist.monthlyListeners,
          ));
        },
      ),
    );
  }
}

