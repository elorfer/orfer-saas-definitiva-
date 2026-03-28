import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'web/web_library_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/song_model.dart';
import '../../../core/providers/library_coordinator.dart';
import '../../../core/providers/offline_manager_provider.dart'; // ✅ Importar OfflineManager
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/optimized_image.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎯 LIBRARY SCREEN - UI DE ALTO RENDIMIENTO
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Características:
/// - NestedScrollView con SliverAppBar flotante
/// - SliverFixedExtentList para máximo rendimiento de scroll
/// - Integración con LibraryCoordinator (Event-Driven)
/// - Datos Offline-First desde Hive
/// - Indicador de sincronización en background
/// ═══════════════════════════════════════════════════════════════════════════

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Altura fija para SliverFixedExtentList (máximo rendimiento)
  static const double _recentCardHeight = 150.0;
  static const double _metricCardHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (kIsWeb) {
      return const WebLibraryScreen();
    }

    // 🔥 Watch themeProvider to force rebuild on theme changes
    ref.watch(themeProvider);
    // debugPrint('🎨 [LibraryScreen] Rebuilding due to theme change. isDark: ${NeumorphismTheme.isDark}');
    final stats = ref.watch(libraryStatsProvider);
    final recentlyPlayed = ref.watch(libraryRecentlyPlayedProvider);
    final isLoading = ref.watch(libraryIsLoadingProvider);
    final isSyncing = ref.watch(libraryIsSyncingProvider);
    // ✅ Offline Count
    final downloadsCount = ref.watch(
      offlineManagerProvider.select((state) => state.downloadedSongs.length),
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // 🎯 SliverAppBar flotante con efecto de elevación
            _buildSliverAppBar(stats, isSyncing, innerBoxIsScrolled),
          ],
          body: isLoading
              ? const _LibraryLoadingSkeleton()
              : RefreshIndicator(
                  onRefresh: () => ref.read(libraryCoordinatorProvider.notifier).refresh(),
                  color: NeumorphismTheme.coffeeDark,
                  child: CustomScrollView(
                    physics: const SmoothScrollPhysics(),
                    slivers: [
                      // Actividad reciente (horizontal)
                      _buildRecentActivitySection(recentlyPlayed),
                      
                      // Espaciador
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      
                      // Título Categorías
                      SliverToBoxAdapter(
                        child: _buildSectionTitle('Categorías'),
                      ),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      
                      // Categorías con SliverFixedExtentList
                      _buildCategoriesSection(stats),
                      
                      // Espaciador
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      
                      // Card destacada
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildFeaturedCard(downloadsCount), // ✅ Pasar downloadsCount
                        ),
                      ),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      
                      // Métricas con SliverFixedExtentList
                      _buildMetricsSection(stats),
                      
                      // Espaciador inferior para el mini player
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// SliverAppBar flotante con estadísticas
  Widget _buildSliverAppBar(LibraryStats stats, bool isSyncing, bool innerBoxIsScrolled) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      expandedHeight: 120,
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: NeumorphismTheme.isDark 
          ? SystemUiOverlayStyle.light 
          : SystemUiOverlayStyle.dark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: NeumorphismTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
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
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Título y estadísticas
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Tu Biblioteca',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: NeumorphismTheme.coffeeDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            // Indicador de sincronización
                            if (isSyncing) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: NeumorphismTheme.coffeeMedium,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.totalRecentlyPlayed} recientes · ${stats.totalFavorites} favoritas · ${stats.totalSavedPlaylists} playlists',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: NeumorphismTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sección de título
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: NeumorphismTheme.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  /// Sección de actividad reciente (horizontal con SliverToBoxAdapter)
  Widget _buildRecentActivitySection(List<Song> recentlyPlayed) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Actividad reciente',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: NeumorphismTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (recentlyPlayed.isNotEmpty)
                  GestureDetector(
                    onTap: () => context.push('/recently-played'),
                    child: Text(
                      'Ver todo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: NeumorphismTheme.coffeeMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: _recentCardHeight,
            child: recentlyPlayed.isEmpty
                ? _buildEmptyRecentActivity()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: recentlyPlayed.take(10).length,
                    itemExtent: 140, // 🚀 Fixed extent for max performance (width + spacing)
                    cacheExtent: 500, // 🚀 Pre-render offscreen items
                    itemBuilder: (context, index) {
                      final song = recentlyPlayed[index];
                      // Usar Container simple en lugar de Padding anidado para layout
                      return Container(
                        margin: EdgeInsets.only(
                          right: index < recentlyPlayed.length - 1 ? 14 : 0,
                        ),
                        child: _RecentSongCard(song: song), // remove RepaintBoundary (overhead for simple items)
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecentActivity() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface.withValues(alpha: 0.75),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: NeumorphismTheme.softShadow,
      ),
      child: Center(
        child: Text(
          'Cuando reproduzcas música, aparecerá aquí',
          style: TextStyle(
            color: NeumorphismTheme.textSecondary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  /// Sección de categorías con grid optimizado - Solo muestra 2 categorías
  Widget _buildCategoriesSection(LibraryStats stats) {
    final categories = [
      _CategoryData(
        icon: Icons.favorite_rounded,
        label: 'Favoritas',
        value: '${stats.totalFavorites}',
        route: '/favorites',
      ),
      _CategoryData(
        icon: Icons.playlist_play_rounded,
        label: 'Mis Playlists',
        value: '${stats.totalSavedPlaylists}', // ✅ AHORA REAL
        route: '/playlists',
      ),
      _CategoryData(
        icon: Icons.person_rounded,
        label: 'Artistas seguidos',
        value: '${stats.totalFollowedArtists}',
        route: '/followed-artists',
      ),
      _CategoryData(
        icon: Icons.history_rounded,
        label: 'Recientes',
        value: '${stats.totalRecentlyPlayed}',
        route: '/recently-played',
      ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.0, // Más ancho que alto
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = categories[index];
            return RepaintBoundary(
              child: _CategoryCard(
                icon: category.icon,
                label: category.label,
                value: category.value,
                onTap: () => context.push(category.route),
              ),
            );
          },
          childCount: categories.length,
        ),
      ),
    );
  }

  /// Card destacada (Reemplazada por Descargas)
  Widget _buildFeaturedCard(int downloadsCount) {
    return GestureDetector(
      onTap: () => context.push('/downloads'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NeumorphismTheme.accentDark.withValues(alpha: 0.9),
              NeumorphismTheme.accent.withValues(alpha: 0.85),
            ],
          ),
          boxShadow: NeumorphismTheme.floatingShadow,
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.download_done_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    'Música Descargada',
                    style: TextStyle(
                      fontSize: 19, // Ligeramente más grande
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    downloadsCount == 0
                        ? 'Toca para ver tu música offline'
                        : '$downloadsCount canciones listas para escuchar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Sección de métricas con SliverFixedExtentList
  Widget _buildMetricsSection(LibraryStats stats) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverFixedExtentList(
        itemExtent: _metricCardHeight,
        delegate: SliverChildListDelegate([
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: '${stats.totalRecentlyPlayed}',
                  label: 'Escuchadas',
                  icon: Icons.headphones_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: '${stats.totalFavorites}',
                  label: 'Favoritos',
                  icon: Icons.favorite_border_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: '${stats.totalFollowedArtists}',
                  label: 'Artistas',
                  icon: Icons.person_outline_rounded,
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎯 WIDGETS AUXILIARES OPTIMIZADOS
/// ═══════════════════════════════════════════════════════════════════════════

class _CategoryData {
  final IconData icon;
  final String label;
  final String value;
  final String route;

  const _CategoryData({
    required this.icon,
    required this.label,
    required this.value,
    required this.route,
  });
}

/// Card de canción reciente (optimizada con const)
class _RecentSongCard extends StatelessWidget {
  final Song song;

  const _RecentSongCard({required this.song});

  @override
  Widget build(BuildContext context) {
    final cover = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;

    return GestureDetector(
      onTap: () {
        context.push('/song/${song.id}', extra: song);
      },
      child: Container(
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
                    ? OptimizedImage(
                        imageUrl: cover,
                        width: 126,
                        height: 96,
                        fit: BoxFit.cover,
                        maxCacheWidth: 252,
                        maxCacheHeight: 192,
                        skipFade: true,
                        lazyLoad: false,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: NeumorphismTheme.imagePlaceholderGradient,
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
              ),
            ),
            Padding(
              // Reducir padding vertical ligeramente para evitar overflow por 1px
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title ?? 'Sin título',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NeumorphismTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist?.displayName ?? 'Artista desconocido',
                    style: TextStyle(
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
      ),
    );
  }
}

/// Card de categoría (optimizada)
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NeumorphismTheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: NeumorphismTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Icon(
                icon,
                color: NeumorphismTheme.coffeeDark,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NeumorphismTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
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

/// Card de métrica (optimizada)
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: NeumorphismTheme.softShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: NeumorphismTheme.coffeeDark,
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: NeumorphismTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: NeumorphismTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Skeleton de carga
class _LibraryLoadingSkeleton extends StatelessWidget {
  const _LibraryLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: NeumorphismTheme.coffeeMedium,
      ),
    );
  }
}
