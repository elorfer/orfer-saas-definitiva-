import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/utils/logger.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// 🧠 SECCIÓN DE CANCIONES DESTACADAS INTELIGENTES
/// Usa tu algoritmo avanzado de recomendaciones para mostrar:
/// 1. Canciones destacadas estáticas (marcadas por admin)
/// 2. Recomendaciones dinámicas personalizadas
/// 3. Actualización automática basada en la canción actual
class IntelligentFeaturedSongsSection extends ConsumerWidget {
  const IntelligentFeaturedSongsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inicializar el sistema inteligente
    ref.watch(intelligentFeaturedInitProvider);
    
    final featuredSongs = ref.watch(intelligentFeaturedSongsProvider);
    final isLoading = ref.watch(intelligentFeaturedLoadingProvider);
    final error = ref.watch(intelligentFeaturedErrorProvider);

    if (isLoading && featuredSongs.isEmpty) {
      return _buildLoadingSection();
    }

    if (error != null && featuredSongs.isEmpty) {
      return _buildErrorSection(context, ref, error);
    }

    if (featuredSongs.isEmpty) {
      return _buildEmptySection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección con indicador de IA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Destacadas para Ti',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3D2E20),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Indicador de IA
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B7A6A).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: const Color(0xFF8B7A6A),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'IA',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8B7A6A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Botón de refresh
                  if (!isLoading)
                    IconButton(
                      onPressed: () {
                        ref.read(intelligentFeaturedProvider.notifier)
                            .refreshIntelligentRecommendations();
                      },
                      icon: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFF8B7A6A),
                      ),
                      tooltip: 'Actualizar recomendaciones',
                    ),
                  TextButton(
                    onPressed: () {
                      context.push('/search');
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
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista vertical de canciones optimizada (máximo 4)
        ...featuredSongs.take(4).map((featuredSong) {
          return RepaintBoundary(
            key: ValueKey('intelligent_song_${featuredSong.song.id}'),
            child: IntelligentFeaturedSongCard(
              key: ValueKey('intelligent_song_card_${featuredSong.song.id}'),
              featuredSong: featuredSong,
              onTap: () {
                _onSongTap(context, featuredSong.song);
              },
            ),
          );
        }),
        
        // Indicador de carga si está actualizando
        if (isLoading && featuredSongs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFF8B7A6A),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Actualizando recomendaciones...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF8B7A6A),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Botón para ver más canciones
        if (featuredSongs.length > 4) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                context.push('/featured-songs'); // ✅ Nueva ruta para todas las canciones
              },
              style: TextButton.styleFrom(
                foregroundColor: NeumorphismTheme.accentDark, // ✅ Marrón oscuro
              ),
              child: Text(
                'Ver ${featuredSongs.length - 4} recomendaciones más',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: NeumorphismTheme.accentDark, // ✅ Marrón oscuro
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'Destacadas para Ti',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3D2E20),
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF8B7A6A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: List.generate(3, (index) {
              return RepaintBoundary(
                key: ValueKey('loading_intelligent_song_$index'),
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
                          child: Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 24,
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
                              width: 150,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
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

  Widget _buildErrorSection(BuildContext context, WidgetRef ref, String error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Destacadas para Ti',
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
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar recomendaciones',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF3D2E20),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF8B7A6A),
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(intelligentFeaturedProvider.notifier)
                          .refreshIntelligentRecommendations();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7A6A),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Reintentar',
                      style: GoogleFonts.inter(fontSize: 14),
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

  Widget _buildEmptySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Destacadas para Ti',
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
                    Icons.auto_awesome,
                    size: 48,
                    color: const Color(0xFF8B7A6A),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Preparando recomendaciones',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF3D2E20),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reproduce una canción para obtener recomendaciones personalizadas',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF8B7A6A),
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
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
    if (!context.mounted) {
      debugPrint('[IntelligentFeaturedSongs] Contexto no montado');
      return;
    }
    
    debugPrint('[IntelligentFeaturedSongs] Navegando a canción inteligente: ${song.title} (${song.id})');
    
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SongDetailScreen(song: song),
          settings: RouteSettings(arguments: {
            'isFeatured': true,
            'isIntelligent': true,
            'source': 'intelligent_recommendations'
          }),
        ),
      );
      debugPrint('[IntelligentFeaturedSongs] Navegación exitosa');
    } catch (e, stackTrace) {
      AppLogger.error('[IntelligentFeaturedSongs] Error al navegar: $e', stackTrace);
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

/// 🎵 TARJETA DE CANCIÓN DESTACADA INTELIGENTE
/// Versión mejorada que muestra la razón de la recomendación
class IntelligentFeaturedSongCard extends StatelessWidget {
  final FeaturedSong featuredSong;
  final VoidCallback onTap;

  const IntelligentFeaturedSongCard({
    super.key,
    required this.featuredSong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE4D6C8).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Imagen de la canción con indicador de IA
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B7A6A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: featuredSong.song.coverArtUrl != null
                            ? Image.network(
                                featuredSong.song.coverArtUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                    size: 24,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                    // Indicador de IA para recomendaciones dinámicas
                    if (featuredSong.featuredReason?.contains('IA') == true ||
                        featuredSong.featuredReason?.contains('Recomendada') == true)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B7A6A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(width: 12),
                
                // Información de la canción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        featuredSong.song.title ?? 'Sin título',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3D2E20),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        featuredSong.song.artist?.displayName ?? 'Artista desconocido',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF8B7A6A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (featuredSong.featuredReason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          featuredSong.featuredReason!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF8B7A6A).withValues(alpha: 0.8),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Botón de reproducir
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B7A6A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
