import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/song_model.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import 'featured_song_card.dart';
import '../../../core/theme/neumorphism_theme.dart';

class FeaturedSongsSection extends ConsumerWidget {
  const FeaturedSongsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ OPTIMIZACIÓN: Los providers ya usan select() internamente
    // Solo se reconstruye cuando cambian estos valores específicos
    final featuredSongs = ref.watch(featuredSongsProvider);
    final isLoading = ref.watch(isLoadingProvider);

    if (isLoading && featuredSongs.isEmpty) {
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D2E20),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: NeumorphismTheme.accentDark, // ✅ Marrón oscuro del tema
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista vertical de canciones optimizada (máximo 4)
        // Usar Column con Expanded para evitar shrinkWrap (mejor rendimiento)
        ...featuredSongs.take(4).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final featuredSong = entry.value;
          return RepaintBoundary(
            key: ValueKey('song_${featuredSong.song.id}'), // Key estable para optimización
            child: FeaturedSongCard(
              key: ValueKey('song_card_${featuredSong.song.id}'), // Key estable
              featuredSong: featuredSong,
              precacheAudio: index < 2, // Solo precargar audio de los primeros visibles
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
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B7A6A),
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w500,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 24,
                width: 180,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4D6C8), // 🚀 Sólido
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              Container(
                height: 14,
                width: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4D6C8), // 🚀 Sólido
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Usar Column en lugar de ListView.builder con shrinkWrap (mejor rendimiento)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: List.generate(4, (index) { // Match 4 items (take(4))
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                   border: Border.all(
                    color: const Color(0xFFEEE4DA),
                    width: 1,
                  ),
                ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3EBE3), // 🚀 Sólido
                      borderRadius: BorderRadius.all(Radius.circular(12)), // Match card 10/12 radius mixing
                    ),
                  ),
                  const SizedBox(width: 16), // Match 16px
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 15,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3EBE3), // 🚀 Sólido
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6), // Match 4px + lineheight approx
                        Container(
                          height: 12,
                          width: 120, // Artist name
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEE4DA), // 🚀 Sólido
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6), // Match 4px
                        Container(
                          height: 10,
                          width: 80, // Meta info
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEE4DA), // 🚀 Sólido
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Play button placeholder (32px)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3EBE3), // 🚀 Sólido
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2E20),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFEEE4DA), // 🚀 Sólido
              borderRadius: BorderRadius.all(Radius.circular(12)),
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
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF3D2E20),
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descubre nueva música más tarde',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B7A6A),
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
    
    // Navegar a la pantalla de detalle de canción usando go_router
    // La función estática previene duplicados y maneja errores
    SongDetailScreen.navigateToSong(context, song);
  }

}




