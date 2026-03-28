import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/library_coordinator.dart';
import '../../../../core/providers/offline_manager_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/neumorphism_theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/optimized_image.dart';
import '../../../../core/models/song_model.dart';
import '../../../../core/utils/url_normalizer.dart';

class WebLibraryScreen extends ConsumerStatefulWidget {
  const WebLibraryScreen({super.key});

  @override
  ConsumerState<WebLibraryScreen> createState() => _WebLibraryScreenState();
}

class _WebLibraryScreenState extends ConsumerState<WebLibraryScreen> {
  @override
  Widget build(BuildContext context) {
    // 🔥 Watch themeProvider to force rebuild on theme changes
    ref.watch(themeProvider);

    // Providers
    final stats = ref.watch(libraryStatsProvider);
    final recentlyPlayed = ref.watch(libraryRecentlyPlayedProvider);
    final isSyncing = ref.watch(libraryIsSyncingProvider);
    final downloadsCount = ref.watch(
      offlineManagerProvider.select((state) => state.downloadedSongs.length),
    );

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Espaciador superior
          const SliverToBoxAdapter(child: SizedBox(height: 40)),

          // HEADER: TÃ­tulo y Stats RÃ¡pidos
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    'Tu Biblioteca',
                    style: AppTextStyles.displayMedium.copyWith(
                      color: NeumorphismTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isSyncing) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NeumorphismTheme.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 30)),

          // GRID DE CATEGORÃAS (Highlights)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.8,
              ),
              delegate: SliverChildListDelegate([
                _WebLibraryCard(
                  title: 'Canciones Favoritas',
                  subtitle: '${stats.totalFavorites} canciones',
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFE91E63), // Pink
                  onTap: () => context.push('/favorites'),
                ),
                _WebLibraryCard(
                  title: 'Mis Playlists',
                  subtitle: '${stats.totalSavedPlaylists} playlists',
                  icon: Icons.playlist_play_rounded,
                  color: const Color(0xFF7C4DFF), // Deep Purple
                  onTap: () => context.push('/playlists'),
                ),
                _WebLibraryCard(
                  title: 'Artistas Seguidos',
                  subtitle: '${stats.totalFollowedArtists} artistas',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF00BFA5), // Teal
                  onTap: () => context.push('/followed-artists'),
                ),
                _WebLibraryCard(
                  title: 'Descargas',
                  subtitle: '$downloadsCount disponibles offline',
                  icon: Icons.download_done_rounded,
                  color: const Color(0xFFFF9100), // Orange
                  onTap: () => context.push('/downloads'),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 50)),

          // SECCIÃ“N: Actividad Reciente
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Escuchado Recientemente',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: NeumorphismTheme.textPrimary,
                    ),
                  ),
                  if (recentlyPlayed.isNotEmpty)
                    TextButton(
                      onPressed: () => context.push('/recently-played'),
                      child: Text(
                        'Ver todo',
                        style: TextStyle(
                          color: NeumorphismTheme.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          if (recentlyPlayed.isEmpty)
             const SliverToBoxAdapter(
               child: Center(
                 child: Text('AÃºn no has escuchado nada.'),
               ),
             )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 0.75, // Altas para mostrar portadas
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = recentlyPlayed[index];
                    return _WebRecentSongCard(song: song);
                  },
                  childCount: recentlyPlayed.take(12).length, // Mostrar mÃ¡s para web
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _WebLibraryCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WebLibraryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_WebLibraryCard> createState() => _WebLibraryCardState();
}

class _WebLibraryCardState extends State<_WebLibraryCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: NeumorphismTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovered ? widget.color.withValues(alpha: 0.5) : Colors.transparent,
              width: 2,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const Spacer(),
              Text(
                widget.title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: NeumorphismTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebRecentSongCard extends StatefulWidget {
  final Song song;
  const _WebRecentSongCard({required this.song});

  @override
  State<_WebRecentSongCard> createState() => _WebRecentSongCardState();
}

class _WebRecentSongCardState extends State<_WebRecentSongCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cover = widget.song.coverArtUrl != null && widget.song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(widget.song.coverArtUrl)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/song/${widget.song.id}', extra: widget.song),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered ? NeumorphismTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ]
                        : [],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: cover != null
                      ? OptimizedImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
                          child: Icon(Icons.music_note, color: NeumorphismTheme.textSecondary, size: 40),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.song.title ?? 'Sin TÃ­tulo',
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isHovered ? NeumorphismTheme.accent : NeumorphismTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.song.artist?.displayName ?? 'Artista',
                style: AppTextStyles.bodyMedium.copyWith(color: NeumorphismTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

