import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neumorphism_theme.dart';
import 'package:go_router/go_router.dart';
// OPTIMIZACIÓN: GoogleFonts removido, usando estilos constantes
import '../../../core/providers/playlist_provider.dart';
import '../../../core/providers/saved_playlists_provider.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/widgets/fast_scroll_physics.dart';

/// PlaylistsScreen optimizado con paginación automática y mejor rendimiento
class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
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
      // ✅ OPTIMIZACIÓN: Cargar solo la página siguiente, no todas desde el inicio
      final nextPageAsync = ref.read(
        playlistsProvider((page: nextPage, limit: _pageSize)),
      );
      
      await nextPageAsync.when(
        data: (newPlaylists) async {
          if (newPlaylists.isEmpty || newPlaylists.length < _pageSize) {
            setState(() {
              _hasMore = false;
            });
          } else {
            setState(() {
              _currentPage = nextPage;
            });
            // No necesitamos invalidar - el build() ya combina todas las páginas
          }
        },
        loading: () {},
        error: (_, __) {
          setState(() {
            _hasMore = false;
          });
        },
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
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // ✅ OPTIMIZACIÓN: Cargar solo la primera página inicialmente
    // Las páginas adicionales se cargan mediante _loadMore() y se combinan localmente
    final firstPageAsync = ref.watch(
      playlistsProvider((page: 1, limit: _pageSize)),
    );
    
    // ✅ OPTIMIZACIÓN: Combinar todas las páginas cargadas eficientemente
    List<Playlist> allPlaylists = [];
    
    // Leer la primera página (ya está siendo watched)
    if (firstPageAsync.hasValue) {
      allPlaylists.addAll(firstPageAsync.value ?? []);
    }
    
    // Si hay más páginas cargadas, leerlas también (sin watch para evitar rebuilds innecesarios)
    if (_currentPage > 1) {
      for (int page = 2; page <= _currentPage; page++) {
        final pageAsync = ref.read(playlistsProvider((page: page, limit: _pageSize)));
        if (pageAsync.hasValue && pageAsync.value != null && pageAsync.value!.isNotEmpty) {
          allPlaylists.addAll(pageAsync.value!);
        }
      }
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: const ValueKey('playlists_scaffold'),
        backgroundColor: NeumorphismTheme.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: NeumorphismTheme.background,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: NeumorphismTheme.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Playlists',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NeumorphismTheme.textPrimary,
            ),
          ),
          centerTitle: false,
          bottom: TabBar(
            labelColor: NeumorphismTheme.coffeeMedium,
            unselectedLabelColor: Colors.grey,
            indicatorColor: NeumorphismTheme.coffeeMedium,
            tabs: [
              Tab(text: 'Mis Playlists'),
              Tab(text: 'Explorar'),
            ],
          ),
        ),
        body: SafeArea(
          bottom: true,
          child: TabBarView(
            children: [
              // -----------------------------------------------------------------
              // TAB 1: MIS PLAYLISTS (GUARDADAS)
              // -----------------------------------------------------------------
              Consumer(
                builder: (context, ref, _) {
                  final savedState = ref.watch(savedPlaylistsProvider);
                  
                  if (savedState.isLoading) {
                     return Center(child: CircularProgressIndicator(color: NeumorphismTheme.coffeeMedium));
                  }
                  
                  if (savedState.playlists.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            'Aún no tienes playlists guardadas',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explora y dale "Like" a las playlists que te gusten',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return CustomScrollView(
                     physics: const SmoothScrollPhysics(),
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
                             (context, index) {
                               final playlist = savedState.playlists[index];
                               return RepaintBoundary(
                                 child: _PlaylistCard(
                                   key: ValueKey('saved_playlist_${playlist.id}'),
                                   playlist: playlist,
                                   onTap: () => context.push('/playlist/${playlist.id}'),
                                 ),
                               );
                             },
                             childCount: savedState.playlists.length,
                           ),
                         ),
                       ),
                     ],
                   );
                },
              ),
              
              // -----------------------------------------------------------------
              // TAB 2: EXPLORAR (BACKEND)
              // -----------------------------------------------------------------
              firstPageAsync.when(
                data: (_) {
                  if (allPlaylists.isEmpty) {
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
                          cacheExtent: 500,
                          physics: const SmoothScrollPhysics(),
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
                              (context, index) {
                                if (index >= allPlaylists.length) {
                                  return _isLoadingMore
                                      ? RepaintBoundary(
                                          child: _buildShimmerCard(),
                                        )
                                      : null;
                                }
                                final playlist = allPlaylists[index];
                                return RepaintBoundary(
                                  child: _PlaylistCard(
                                    key: ValueKey('playlist_${playlist.id}'),
                                    playlist: playlist,
                                    onTap: () {
                                      context.push('/playlist/${playlist.id}');
                                    },
                                  ),
                                );
                              },
                              childCount: allPlaylists.length + (_isLoadingMore ? 4 : 0),
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: false,
                              addSemanticIndexes: false,
                            ),
                          ),
                        ),

                        if (_isLoadingMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: NeumorphismTheme.coffeeMedium,
                                ),
                              ),
                            ),
                          ),

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
            ],
          ),
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
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: NeumorphismTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las playlists aparecerán aquí cuando estén disponibles',
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: TextStyle(
              fontSize: 14,
              color: NeumorphismTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return CustomScrollView(
      cacheExtent: 500, // Optimizado: reducir de 800 a 500 para consistencia
      physics: const SmoothScrollPhysics(), // Scroll más rápido y fluido
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
              // 🔥 OPTIMIZACIONES PARA GRANDES VOLÚMENES:
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              addSemanticIndexes: false, // Desactivar índices semánticos (mejor rendimiento)
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
    return Container(
      decoration: BoxDecoration(
        color: NeumorphismTheme.shimmerBaseColor,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
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
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
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
              backgroundColor: NeumorphismTheme.coffeeMedium,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
            ),
            child: const Text(
              'Reintentar',
              // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
              style: TextStyle(
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
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: OptimizedImage(
                  imageUrl: playlist.coverArtUrl,
                  fit: BoxFit.cover,
                  borderRadius: 12,
                  placeholderColor: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                  // 🔥 OPTIMIZADO: Tamaños de cache reducidos para mejor rendimiento con muchas imágenes
                  // Calcular tamaño basado en el ancho de la pantalla (2 columnas)
                  maxCacheWidth: 300, // Tamaño suficiente para grid de 2 columnas
                  maxCacheHeight: 300,
                  useThumbnail: true, // Usar thumbnails cuando estén disponibles
                  skipFade: true, // Sin fade para mejor rendimiento en scroll rápido
                  lazyLoad: true, // ✅ Lazy loading con IntersectionObserver
                  visibilityThreshold: 0.1, // Cargar cuando 10% visible
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Nombre de la playlist
          Text(
            (playlist.name?.isNotEmpty == true) ? playlist.name! : 'Playlist',
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: NeumorphismTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 4),
          
          // Información adicional
          Text(
            '${playlist.totalTracks ?? 0} canciones',
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: TextStyle(
              fontSize: 12,
              color: NeumorphismTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

