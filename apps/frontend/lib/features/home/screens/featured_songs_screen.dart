import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/config/performance_config.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/utils/logger.dart';

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
      physics: const FastScrollPhysics(),
      cacheExtent: 1200.0,
      slivers: [
        // Header con información
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descubre música increíble',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: NeumorphismTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${featuredSongs.length} canciones seleccionadas especialmente para ti',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: NeumorphismTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Lista de canciones
        SliverList.builder(
          itemCount: featuredSongs.length,
          itemBuilder: (context, index) {
            final featuredSong = featuredSongs[index];
            return RepaintBoundary(
              child: _BlurSongCard(
                key: ValueKey('featured_song_${featuredSong.song.id}'),
                featuredSong: featuredSong,
                onTap: () => _onSongTap(context, featuredSong.song),
              ),
            );
          },
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

/// Widget de tarjeta con estilo del reproductor principal
class _BlurSongCard extends StatelessWidget {
  final FeaturedSong featuredSong;
  final VoidCallback onTap;

  const _BlurSongCard({
    super.key,
    required this.featuredSong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final song = featuredSong.song;
    
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // ✅ Fondo de imagen con blur (igual que el reproductor)
            Positioned.fill(
              child: song.coverArtUrl != null
                  ? CachedNetworkImage(
                      imageUrl: song.coverArtUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: NeumorphismTheme.background,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: NeumorphismTheme.background,
                      ),
                    )
                  : Container(color: NeumorphismTheme.background),
            ),
            // ✅ Blur overlay (igual que el reproductor)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
            // ✅ Contenido sobre el blur
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Imagen de la canción
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: OptimizedImage(
                            imageUrl: song.coverArtUrl,
                            fit: BoxFit.cover,
                            width: 68,
                            height: 68,
                            borderRadius: 16,
                            placeholderColor: NeumorphismTheme.accentLight,
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
                                color: Colors.white, // ✅ Texto blanco como el reproductor
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 4),
                            
                            // Artista
                            Text(
                              song.artist?.stageName ?? 'Artista Desconocido',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.7), // ✅ Texto blanco semi-transparente
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Duración y badge
                            Row(
                              children: [
                                if (song.duration != null) ...[
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.6), // ✅ Texto blanco más transparente
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(song.duration!),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                
                                // Badge destacado
                                if (featuredSong.featuredReason != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1), // ✅ Fondo blanco semi-transparente
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3), // ✅ Borde blanco semi-transparente
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      featuredSong.featuredReason!,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white, // ✅ Badge en blanco para contraste
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Botón de reproducción (igual que el reproductor)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white, // ✅ Botón blanco como el reproductor
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: onTap,
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black, // ✅ Icono negro como el reproductor
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}