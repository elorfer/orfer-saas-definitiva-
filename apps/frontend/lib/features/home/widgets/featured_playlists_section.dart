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
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 24, right: 8),
        cacheExtent: 1200, // 🔥 OPTIMIZACIÓN MÁXIMA: Precarga 4-6 items extra
        physics: const BouncingScrollPhysics(), // 🔥 Configuración perfecta
        addAutomaticKeepAlives: false, // Menos reconstrucciones
        addRepaintBoundaries: true, // 🔥 GPU trabaja menos
        addSemanticIndexes: false, // 🔥 Más rápido
        itemCount: _featuredPlaylists.length,
        itemBuilder: (context, index) {
          final featuredPlaylist = _featuredPlaylists[index];
          return RepaintBoundary(
            key: ValueKey('playlist_${featuredPlaylist.playlist.id}'),
            child: FeaturedPlaylistCard(
              key: ValueKey('playlist_card_${featuredPlaylist.playlist.id}'),
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

  /// ⚡ OPTIMIZADO: Skeleton ligero adaptado al contenido real
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
        // Lista skeleton - Tamaños exactos del contenido real
        SizedBox(
          height: 260, // Altura del contenido real
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            padding: const EdgeInsets.only(left: 24, right: 8), // Igual que el real
            cacheExtent: 300, // Reducido para ser más ligero
            physics: const ClampingScrollPhysics(), // Igual que el real
            itemCount: 2, // Solo 2 items para reducir carga
            itemBuilder: (context, index) {
              return Container(
                width: 160, // Igual que FeaturedPlaylistCard
                margin: const EdgeInsets.only(right: 16), // Igual que el real
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen skeleton - 160x160 (igual que el real)
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200), // Más lento = más ligero
                      child: Container(
                        width: 160, // Igual que el real
                        height: 160, // Igual que el real
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.shimmerContentColor,
                          borderRadius: BorderRadius.circular(16), // Igual que el real
                        ),
                      ),
                    ),
                    const SizedBox(height: 12), // Igual que el real
                    // Texto skeleton - Tamaño aproximado del título
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        height: 15, // Altura aproximada del texto
                        width: 120, // Ancho aproximado
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.shimmerContentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
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
