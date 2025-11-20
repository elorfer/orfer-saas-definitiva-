import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/playlist_provider.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/widgets/fast_scroll_physics.dart';

/// PlaylistsScreen optimizado con paginación automática y mejor rendimiento
class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // Paginación automática al hacer scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;

    // Cargar más cuando esté cerca del final (80% del scroll)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      // Acumular playlists de todas las páginas
      final allPlaylistsAsync = ref.read(
        playlistsProvider((page: 1, limit: nextPage * _pageSize)),
      );
      
      await allPlaylistsAsync.when(
        data: (playlists) async {
          if (playlists.length < nextPage * _pageSize) {
            setState(() {
              _hasMore = false;
            });
          } else {
            setState(() {
              _currentPage = nextPage;
            });
          }
        },
        loading: () {},
        error: (_, __) {},
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Acumular todas las playlists de todas las páginas
    final allPlaylistsAsync = ref.watch(
      playlistsProvider((page: 1, limit: _currentPage * _pageSize)),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Playlists',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: true,
        child: allPlaylistsAsync.when(
          data: (playlists) {
            if (playlists.isEmpty) {
              return _buildEmptyState();
            }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _currentPage = 1;
                      _hasMore = true;
                    });
                    ref.invalidate(playlistsProvider((page: 1, limit: _pageSize)));
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    cacheExtent: 800, // Aumentado a 800px para scroll más rápido
                    physics: const FastScrollPhysics(), // Scroll más rápido y fluido
                    slivers: [
                  // Grid de playlists
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= playlists.length) {
                            return _isLoadingMore
                                ? RepaintBoundary(
                                    child: _buildShimmerCard(),
                                  )
                                : null;
                          }
                          final playlist = playlists[index];
                          return RepaintBoundary(
                            child: _PlaylistCard(
                              key: ValueKey('playlist_${playlist.id}'), // Key estable para optimización
                              playlist: playlist,
                              onTap: () {
                                context.push('/playlist/${playlist.id}');
                              },
                            ),
                          );
                        },
                        childCount: playlists.length + (_isLoadingMore ? 4 : 0),
                        // Optimización: desactivar keepAlive y repaintBoundaries automáticos para mejor rendimiento
                        addAutomaticKeepAlives: false, // No mantener vivos items fuera de la vista (mejor rendimiento)
                        addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual
                      ),
                    ),
                  ),

                  // Loading indicator al final
                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF667eea),
                          ),
                        ),
                      ),
                    ),

                  // Padding inferior
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: 16),
                  ),
                ],
              ),
            );
          },
          loading: () => _buildLoadingState(),
          error: (error, stack) => _buildErrorState(error),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay playlists disponibles',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las playlists aparecerán aquí cuando estén disponibles',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return CustomScrollView(
      cacheExtent: 800, // Aumentado para scroll más rápido
      physics: const FastScrollPhysics(), // Scroll más rápido y fluido
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => RepaintBoundary(
                child: _buildShimmerCard(),
              ),
              childCount: 6,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ),
        // Padding inferior (SafeArea ya maneja el padding del sistema)
        const SliverPadding(
          padding: EdgeInsets.only(bottom: 16), // Solo padding extra
        ),
      ],
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar playlists',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentPage = 1;
                _hasMore = true;
              });
              ref.invalidate(playlistsProvider((page: 1, limit: _pageSize)));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Reintentar',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portada de la playlist
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: OptimizedImage(
                  imageUrl: playlist.coverArtUrl,
                  fit: BoxFit.cover,
                  borderRadius: 12,
                  placeholderColor: const Color(0xFF667eea).withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Nombre de la playlist
          Text(
            (playlist.name?.isNotEmpty == true) ? playlist.name! : 'Playlist',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 4),
          
          // Información adicional
          Text(
            '${playlist.totalTracks ?? 0} canciones',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

