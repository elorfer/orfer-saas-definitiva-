import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import 'featured_playlist_card.dart';

class FeaturedPlaylistsSection extends ConsumerStatefulWidget {
  const FeaturedPlaylistsSection({super.key});

  @override
  ConsumerState<FeaturedPlaylistsSection> createState() => _FeaturedPlaylistsSectionState();
}

class _FeaturedPlaylistsSectionState extends ConsumerState<FeaturedPlaylistsSection> {
  List<FeaturedPlaylist> _featuredPlaylists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Leer estado de loading
    final isLoading = ref.read(isLoadingProvider);
    final featuredPlaylists = ref.read(featuredPlaylistsProvider);
    
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
        _featuredPlaylists = featuredPlaylists;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ OPTIMIZACIÓN: Usar select específico para evitar rebuilds innecesarios
    final isLoading = ref.watch(isLoadingProvider.select((state) => state));
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider.select((state) => state));
    
    // Actualizar estado solo si cambió (fuera de build)
    if (isLoading != _isLoading || featuredPlaylists != _featuredPlaylists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = isLoading;
            _featuredPlaylists = featuredPlaylists;
          });
          // Pre-cachear imágenes después de actualizar la lista
          if (!isLoading && featuredPlaylists.isNotEmpty) {
            _precacheImages();
          }
        }
      });
    }

    // CRÍTICO: Solo mostrar skeleton durante carga inicial (cuando no hay datos)
    // Si hay datos pero está cargando (refresh), mostrar contenido existente
    if (_isLoading && _featuredPlaylists.isEmpty) {
      return _buildLoadingSection();
    }

    if (_featuredPlaylists.isEmpty && !_isLoading) {
      return _buildEmptySection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Playlists Destacadas',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3D2E20),
                  decoration: TextDecoration.none,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navegar a vista de todas las playlists
                  context.push('/playlists');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8B7A6A),
                ),
                child: Text(
                  'Ver todas',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF8B7A6A),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista horizontal de playlists optimizada
        _buildPlaylistsList(),
      ],
    );
  }

  Widget _buildPlaylistsList() {
    return SizedBox(
      height: 260, // ✅ Aumentado para evitar overflow con badges
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true, // Necesario cuando está dentro de un Column dentro de SingleChildScrollView
        padding: const EdgeInsets.only(left: 24, right: 8),
        cacheExtent: 300, // ✅ OPTIMIZACIÓN: Reducido de 800 a 300px para mejor rendimiento
        physics: const ClampingScrollPhysics(), // Cambiar a ClampingScrollPhysics para evitar conflictos
        itemCount: _featuredPlaylists.length,
        itemBuilder: (context, index) {
          final featuredPlaylist = _featuredPlaylists[index];
          return RepaintBoundary(
            key: ValueKey('playlist_${featuredPlaylist.playlist.id}'),
            child: FeaturedPlaylistCard(
              key: ValueKey('playlist_card_${featuredPlaylist.playlist.id}'), // Key estable
              featuredPlaylist: featuredPlaylist,
              onTap: () {
                _onPlaylistTap(context, featuredPlaylist.playlist);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Playlists Destacadas',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260, // ✅ Misma altura que la lista real
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true, // Necesario cuando está dentro de un Column dentro de SingleChildScrollView
            padding: const EdgeInsets.only(left: 24, right: 8),
            cacheExtent: 300, // ✅ OPTIMIZACIÓN: Reducido de 800 a 300px
            physics: const ClampingScrollPhysics(), // Cambiar a ClampingScrollPhysics para evitar conflictos
            itemCount: 3,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                key: ValueKey('loading_playlist_$index'),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16), // Mismo margin que el real
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen skeleton - CRÍTICO: 160x160 con borderRadius 16 y sombra
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(16)), // Mismo borderRadius que el real (no 12)
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Shimmer.fromColors(
                            baseColor: NeumorphismTheme.shimmerBaseColor,
                            highlightColor: NeumorphismTheme.shimmerHighlightColor,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: const BoxDecoration(
                                color: NeumorphismTheme.shimmerContentColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12), // Mismo espacio que el real
                      // Nombre skeleton - CRÍTICO: fontSize 15
                      Shimmer.fromColors(
                        baseColor: NeumorphismTheme.shimmerBaseColor,
                        highlightColor: NeumorphismTheme.shimmerHighlightColor,
                        child: Container(
                          height: 15, // Mismo fontSize que el texto real
                          width: 120,
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.shimmerContentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4), // Mismo espacio que el real
                      // Info adicional skeleton - CRÍTICO: fontSize 13 con icono
                      SizedBox(
                        width: 160, // Mismo ancho fijo que el real
                        child: Row(
                          children: [
                            Expanded(
                              child: Shimmer.fromColors(
                                baseColor: NeumorphismTheme.shimmerBaseColor,
                                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                                child: Container(
                                  height: 13, // Mismo fontSize que el texto real
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: NeumorphismTheme.shimmerContentColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8), // Mismo espacio que el real
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14, // Mismo tamaño que el icono real
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: NeumorphismTheme.shimmerContentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4), // Mismo espacio que el real
                                Shimmer.fromColors(
                                  baseColor: NeumorphismTheme.shimmerBaseColor,
                                  highlightColor: NeumorphismTheme.shimmerHighlightColor,
                                  child: Container(
                                    height: 12, // Mismo fontSize que el texto real
                                    width: 20,
                                    decoration: BoxDecoration(
                                      color: NeumorphismTheme.shimmerContentColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Playlists Destacadas',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.playlist_play,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay playlists destacadas',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descubre nuevas playlists más tarde',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Pre-cachear imágenes de las primeras playlists para mejor UX
  void _precacheImages() {
    if (!mounted || _featuredPlaylists.isEmpty) return;
    
    // Pre-cachear primeras 3 imágenes (las más visibles)
    final imagesToPrecache = _featuredPlaylists.take(3).toList();
    
    for (final featuredPlaylist in imagesToPrecache) {
      final imageUrl = featuredPlaylist.playlist.coverArtUrl;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        ).catchError((_) {
          // Ignorar errores de pre-cache (imagen no disponible, etc.)
        });
      }
    }
  }

  void _onPlaylistTap(BuildContext context, Playlist playlist) {
    // Navegar a detalles de la playlist
    context.push('/playlist/${playlist.id}');
  }
}
