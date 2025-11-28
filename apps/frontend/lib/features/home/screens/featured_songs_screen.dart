import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/config/performance_config.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/url_normalizer.dart';

/// 🚀 PANTALLA OPTIMIZADA DE CANCIONES DESTACADAS
/// Implementa múltiples optimizaciones de rendimiento:
/// - Lazy loading con AutomaticKeepAliveClientMixin
/// - Precarga inteligente de imágenes
/// - Caché de widgets con RepaintBoundary
/// - Scroll optimizado con cacheExtent
class FeaturedSongsScreen extends ConsumerStatefulWidget {
  const FeaturedSongsScreen({super.key});

  @override
  ConsumerState<FeaturedSongsScreen> createState() => _FeaturedSongsScreenState();
}

class _FeaturedSongsScreenState extends ConsumerState<FeaturedSongsScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => PerformanceConfig.enableKeepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    final intelligentFeaturedState = ref.watch(intelligentFeaturedProvider);

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: NeumorphismTheme.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Canciones Destacadas',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: NeumorphismTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(intelligentFeaturedProvider.notifier).loadIntelligentFeaturedSongs(forceRefresh: true);
        },
        child: intelligentFeaturedState.isLoading
            ? _buildLoadingSection()
            : intelligentFeaturedState.error != null
                ? _buildErrorSection(intelligentFeaturedState.error!)
                : intelligentFeaturedState.featuredSongs.isEmpty
                    ? _buildEmptySection()
                    : _buildSongsList(context, intelligentFeaturedState.featuredSongs),
      ),
    );
  }

  Widget _buildSongsList(BuildContext context, List<FeaturedSong> featuredSongs) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(), // Más fluido que FastScrollPhysics
      cacheExtent: 500.0, // Optimizado: menos caché = scroll más fluido
      clipBehavior: Clip.none, // Evitar clipping innecesario
      slivers: [
        // Header mejorado con gradiente (similar a favoritos)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                  NeumorphismTheme.coffeeDark.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icono de estrella grande (diferente al de favoritos)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        NeumorphismTheme.coffeeMedium,
                        NeumorphismTheme.coffeeDark,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Título y subtítulo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Canciones Destacadas',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: NeumorphismTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            size: 16,
                            color: NeumorphismTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${featuredSongs.length} canciones seleccionadas especialmente para ti',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: NeumorphismTheme.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Lista de canciones optimizada para scroll fluido
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final featuredSong = featuredSongs[index];
              final song = featuredSong.song;
              return RepaintBoundary(
                key: ValueKey('featured_song_${song.id}'),
                child: _BlurSongCard(
                  featuredSong: featuredSong,
                  onTap: () => _onSongTap(context, song),
                ),
              );
            },
            childCount: featuredSongs.length,
            addAutomaticKeepAlives: false, // Optimización: no mantener estado fuera de vista
            addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual
          ),
        ),
        // Espacio para el reproductor
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildLoadingSection() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorSection(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: NeumorphismTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar canciones',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: NeumorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No se pudieron cargar las canciones destacadas',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: NeumorphismTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await ref.read(intelligentFeaturedProvider.notifier).loadIntelligentFeaturedSongs(forceRefresh: true);
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 64,
            color: NeumorphismTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay canciones destacadas',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: NeumorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vuelve más tarde para descubrir nueva música',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: NeumorphismTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _onSongTap(BuildContext context, Song song) {
    try {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) {
            return SongDetailScreen(song: song);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
      debugPrint('[FeaturedSongsScreen] Navegación exitosa');
    } catch (e, stackTrace) {
      AppLogger.error('[FeaturedSongsScreen] Error navegación: $e', stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir detalles de la canción'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Widget de tarjeta con estilo de favoritos (sin blur)
class _BlurSongCard extends ConsumerWidget {
  final FeaturedSong featuredSong;
  final VoidCallback onTap;

  const _BlurSongCard({
    required this.featuredSong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = featuredSong.song;
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeumorphismTheme.surface.withValues(alpha: 0.8),
            NeumorphismTheme.beigeMedium.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Portada con efecto de elevación
                Hero(
                  tag: 'featured_cover_${song.id}',
                  child: Container(
                    width: 64,
                    height: 64,
                    constraints: const BoxConstraints(
                      minWidth: 64,
                      maxWidth: 64,
                      minHeight: 64,
                      maxHeight: 64,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: coverUrl != null
                          ? SizedBox(
                              width: 64,
                              height: 64,
                              child: Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                repeat: ImageRepeat.noRepeat,
                              // Optimización: cargar imagen de forma asíncrona sin bloquear scroll
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) return child;
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 200),
                                  child: child,
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                // Placeholder simple sin CircularProgressIndicator para mejor rendimiento
                                return Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        NeumorphismTheme.coffeeMedium,
                                        NeumorphismTheme.coffeeDark,
                                      ],
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        NeumorphismTheme.coffeeMedium,
                                        NeumorphismTheme.coffeeDark,
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                );
                              },
                            ),
                          )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    NeumorphismTheme.coffeeMedium,
                                    NeumorphismTheme.coffeeDark,
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Información de la canción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Título
                      Text(
                        song.title ?? 'Canción Desconocida',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: NeumorphismTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Artista
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: NeumorphismTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              song.artist?.stageName ?? 'Artista Desconocido',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: NeumorphismTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Iconos: Corazón y Menú
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono de corazón
                    FavoriteButton(
                      songId: song.id,
                      iconSize: 24,
                    ),
                    const SizedBox(width: 8),
                    // Icono de tres rayitas (menú)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          // TODO: Implementar menú de opciones
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.more_vert,
                            color: NeumorphismTheme.textSecondary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
