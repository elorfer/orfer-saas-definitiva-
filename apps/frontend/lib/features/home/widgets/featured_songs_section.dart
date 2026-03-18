import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/models/song_model.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import 'featured_song_card.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/section_header.dart';

class FeaturedSongsSection extends ConsumerWidget {
  const FeaturedSongsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 Refresh on Theme Change
    ref.watch(themeProvider);

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
        // Header estandarizado
        SectionHeader(
          title: 'Canciones Destacadas',
          actionLabel: 'Ver todas',
          onTapMore: () => context.push('/featured-songs'),
        ),
        
        const SizedBox(height: 8),
        
        // Lista vertical de canciones optimizada (máximo 4)
        // Lista vertical de canciones optimizada (máximo 4)
        // Usar spread operator direactamente sobre el iterable
        ...Iterable.generate(featuredSongs.length.clamp(0, 4), (index) {
          final featuredSong = featuredSongs[index];
          return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24), 
              child: RepaintBoundary(
                key: ValueKey('song_${featuredSong.song.id}'), 
                child: FeaturedSongCard(
                  key: ValueKey('song_card_${featuredSong.song.id}'), 
                  featuredSong: featuredSong,
                  precacheAudio: index < 2, 
                  onTap: () {
                    _onSongTap(context, featuredSong.song);
                  },
                ),
              ),
            );
        }),
        
        // Botón para ver más canciones
        if (featuredSongs.length > 4) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                // Navegar a la pantalla de canciones destacadas para ver todas
                context.push('/featured-songs');
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
                decoration: BoxDecoration(
                  color: NeumorphismTheme.shimmerBaseColor,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
              Container(
                height: 14,
                width: 60,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.shimmerBaseColor,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8), // ✅ Sincronizado con real (8)
        // Usar Column en lugar de ListView.builder con shrinkWrap (mejor rendimiento)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: List.generate(4, (index) { // Match 4 items (take(4))
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  // No border
                ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.shimmerBaseColor,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 15,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.shimmerBaseColor,
                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.shimmerBaseColor,
                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 80,
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.shimmerBaseColor,
                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.shimmerBaseColor,
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




