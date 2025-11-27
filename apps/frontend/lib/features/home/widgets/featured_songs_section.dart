import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/utils/logger.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import 'featured_song_card.dart';
import '../../../core/theme/neumorphism_theme.dart';

class FeaturedSongsSection extends ConsumerWidget {
  const FeaturedSongsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredSongs = ref.watch(featuredSongsProvider);
    final isLoading = ref.watch(isLoadingProvider);

    if (isLoading) {
      return _buildLoadingSection();
    }

    if (featuredSongs.isEmpty) {
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
                'Canciones Destacadas',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3D2E20),
                  decoration: TextDecoration.none,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navegar a búsqueda para ver todas las canciones destacadas
                  context.push('/search');
                },
                style: TextButton.styleFrom(
                  foregroundColor: NeumorphismTheme.accentDark, // ✅ Marrón oscuro del tema
                ),
                child: Text(
                  'Ver todas',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: NeumorphismTheme.accentDark, // ✅ Marrón oscuro del tema
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista vertical de canciones optimizada (máximo 4)
        // Usar Column con Expanded para evitar shrinkWrap (mejor rendimiento)
        ...featuredSongs.take(4).map((featuredSong) {
          return RepaintBoundary(
            key: ValueKey('song_${featuredSong.song.id}'), // Key estable para optimización
            child: FeaturedSongCard(
              key: ValueKey('song_card_${featuredSong.song.id}'), // Key estable
              featuredSong: featuredSong,
              onTap: () {
                _onSongTap(context, featuredSong.song);
              },
            ),
          );
        }),
        
        // Botón para ver más canciones
        if (featuredSongs.length > 4) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                // Navegar a búsqueda para ver todas las canciones destacadas
                context.push('/search');
              },
              child: Text(
                'Ver ${featuredSongs.length - 4} canciones más',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección con padding
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Canciones Destacadas',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3D2E20),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Usar Column en lugar de ListView.builder con shrinkWrap (mejor rendimiento)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: List.generate(3, (index) {
              return RepaintBoundary(
                key: ValueKey('loading_song_$index'),
                child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4D6C8).withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
            );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección con padding
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Canciones Destacadas',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3D2E20),
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
              color: const Color(0xFFE4D6C8).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 48,
                    color: const Color(0xFF8B7A6A),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay canciones destacadas',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF3D2E20),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descubre nueva música más tarde',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF8B7A6A),
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

  void _onSongTap(BuildContext context, Song song) {
    // Verificar que el contexto esté montado
    if (!context.mounted) {
      debugPrint('[FeaturedSongsSection] Contexto no montado');
      return;
    }
    
    debugPrint('[FeaturedSongsSection] Navegando a canción: ${song.title} (${song.id})');
    
    // Navegar a la pantalla de detalle de canción
    // Usar la función estática que verifica si ya existe la pantalla
    try {
      // Pasar parámetro indicando que es una canción destacada
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SongDetailScreen(song: song),
          settings: RouteSettings(arguments: {'isFeatured': true}),
        ),
      );
      debugPrint('[FeaturedSongsSection] Navegación exitosa');
    } catch (e, stackTrace) {
      // Si hay un error, intentar navegación directa como fallback
      AppLogger.error('[FeaturedSongsSection] Error al navegar: $e', stackTrace);
      debugPrint('[FeaturedSongsSection] Error: $e, usando fallback');
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SongDetailScreen(song: song),
          ),
        );
      }
    }
  }

}




