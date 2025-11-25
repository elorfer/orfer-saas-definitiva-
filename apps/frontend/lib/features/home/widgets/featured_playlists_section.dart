import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/playlist_model.dart';
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
    
    // Escuchar cambios en el provider para actualizar estado
    final isLoading = ref.watch(isLoadingProvider);
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    
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

    if (_isLoading) {
      return _buildLoadingSection();
    }

    if (_featuredPlaylists.isEmpty) {
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
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true, // Necesario cuando está dentro de un Column dentro de SingleChildScrollView
        padding: const EdgeInsets.only(left: 24, right: 8),
        cacheExtent: 800, // Aumentado a 800px para scroll más rápido y fluido
        physics: const ClampingScrollPhysics(), // Cambiar a ClampingScrollPhysics para evitar conflictos
        itemCount: _featuredPlaylists.length,
        itemBuilder: (context, index) {
          final featuredPlaylist = _featuredPlaylists[index];
          return FeaturedPlaylistCard(
            key: ValueKey('playlist_card_${featuredPlaylist.playlist.id}'), // Key estable
            featuredPlaylist: featuredPlaylist,
            onTap: () {
              _onPlaylistTap(context, featuredPlaylist.playlist);
            },
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
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true, // Necesario cuando está dentro de un Column dentro de SingleChildScrollView
            padding: const EdgeInsets.only(left: 24, right: 8),
            cacheExtent: 800, // Aumentado para scroll más rápido
            physics: const ClampingScrollPhysics(), // Cambiar a ClampingScrollPhysics para evitar conflictos
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                key: ValueKey('loading_playlist_$index'),
                width: 160,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
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
