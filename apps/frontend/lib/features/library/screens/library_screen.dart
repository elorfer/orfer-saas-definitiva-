import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/song_model.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../core/providers/follow_provider.dart';
import '../../../core/providers/play_history_provider.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/fast_scroll_physics.dart';

/// LibraryScreen optimizado con AutomaticKeepAliveClientMixin
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Mantener estado al cambiar de pestaña

  @override
  void initState() {
    super.initState();
    // Cargar artistas seguidos inmediatamente al montar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    // Optimización: usar select para escuchar solo cambios necesarios
    final favoritesCount = ref.watch(
      favoritesProvider.select((state) => state.favorites.length),
    );
    final recentHistory = ref.watch(
      playHistoryProvider.select(
        (state) => state.reversed.take(8).toList(),
      ),
    );
    final historyCount = recentHistory.length;
    final followedArtistsCount = ref.watch(
      followProvider.select((state) => state.followedArtistIds.length),
    );
    final isLoadingFollowed = ref.watch(
      followProvider.select(
        (state) => state.isLoading && state.followedArtistIds.isEmpty,
      ),
    );
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const SmoothScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildHeader(
                        favoritesCount: favoritesCount,
                        historyCount: historyCount,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Actividad reciente'),
                      const SizedBox(height: 12),
                      _buildRecentActivity(recentHistory),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Categorías'),
                      const SizedBox(height: 12),
                      _buildCategories(
                        context,
                        favoritesCount: favoritesCount,
                        followedArtistsCount: followedArtistsCount,
                        isLoadingFollowed: isLoadingFollowed,
                        historyCount: historyCount,
                      ),
                      const SizedBox(height: 24),
                      _buildFeaturedCard(favoritesCount),
                      const SizedBox(height: 24),
                      _buildMetrics(
                        historyCount: historyCount,
                        favoritesCount: favoritesCount,
                        followedArtistsCount: followedArtistsCount,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required int favoritesCount,
    required int historyCount,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NeumorphismTheme.coffeeMedium,
                NeumorphismTheme.coffeeDark,
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu Biblioteca',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: NeumorphismTheme.coffeeDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$historyCount canciones escuchadas · $favoritesCount favoritas',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: NeumorphismTheme.coffeeDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: NeumorphismTheme.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildRecentActivity(List<Song> recentHistory) {
    if (recentHistory.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: NeumorphismTheme.surface.withValues(alpha: 0.75),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          boxShadow: NeumorphismTheme.softShadow,
        ),
        child: Center(
          child: Text(
            'Cuando reproduzcas música, aparecerá aquí',
            style: GoogleFonts.inter(
              color: NeumorphismTheme.textSecondary,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: recentHistory.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = recentHistory[index];
          return _buildRecentCard(song);
        },
      ),
    );
  }

  Widget _buildRecentCard(Song song) {
    final cover = song.coverArtUrl;
    return Container(
      width: 126,
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        boxShadow: NeumorphismTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: cover != null && cover.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      placeholder: (context, _) => Container(
                        decoration: const BoxDecoration(
                          gradient: NeumorphismTheme.imagePlaceholderGradient,
                        ),
                      ),
                      errorWidget: (context, _, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: NeumorphismTheme.imagePlaceholderGradient,
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: NeumorphismTheme.imagePlaceholderGradient,
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title ?? 'Canción sin título',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NeumorphismTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist?.displayName ?? 'Artista desconocido',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: NeumorphismTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(
    BuildContext context, {
    required int favoritesCount,
    required int followedArtistsCount,
    required bool isLoadingFollowed,
    required int historyCount,
  }) {
    final cards = [
      {
        'icon': Icons.favorite_rounded,
        'label': 'Canciones favoritas',
        'value': '$favoritesCount',
        'onTap': () => context.push('/favorites'),
      },
      {
        'icon': Icons.playlist_play_rounded,
        'label': 'Mis playlists',
        'value': '0',
        'onTap': () => context.push('/playlists'),
      },
      {
        'icon': Icons.person_rounded,
        'label': 'Artistas seguidos',
        'value': isLoadingFollowed
            ? '...'
            : '$followedArtistsCount',
        'onTap': () => context.push('/followed-artists'),
      },
      {
        'icon': Icons.history_rounded,
        'label': 'Recientes',
        'value': '$historyCount',
        'onTap': () => context.push('/recently-played'),
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (item) => _CategoryCard(
              icon: item['icon'] as IconData,
              label: item['label'] as String,
              value: item['value'] as String,
              onTap: item['onTap'] as VoidCallback,
            ),
          )
          .toList(),
    );
  }

  Widget _buildFeaturedCard(int favoritesCount) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeumorphismTheme.coffeeDark.withValues(alpha: 0.9),
            NeumorphismTheme.coffeeMedium.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: NeumorphismTheme.floatingShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus favoritos del mes',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  favoritesCount == 0
                      ? 'Empieza a marcar canciones como favoritas'
                      : 'Tus mejores $favoritesCount canciones guardadas',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics({
    required int historyCount,
    required int favoritesCount,
    required int followedArtistsCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            value: '$historyCount',
            label: 'Canciones escuchadas recientemente',
            icon: Icons.headphones_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            value: '$favoritesCount',
            label: 'Favoritos totales',
            icon: Icons.favorite_border_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            value: '$followedArtistsCount',
            label: 'Artistas seguidos',
            icon: Icons.person_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 24 * 2 - 12) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: NeumorphismTheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          boxShadow: NeumorphismTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Icon(
                icon,
                color: NeumorphismTheme.coffeeDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: NeumorphismTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: NeumorphismTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        boxShadow: NeumorphismTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: NeumorphismTheme.coffeeDark,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: NeumorphismTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: NeumorphismTheme.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}



