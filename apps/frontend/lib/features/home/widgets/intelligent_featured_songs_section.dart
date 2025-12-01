import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/models/song_model.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/url_normalizer.dart';

/// 🧠 SECCIÓN DE CANCIONES DESTACADAS INTELIGENTES
/// Usa tu algoritmo avanzado de recomendaciones para mostrar:
/// 1. Canciones destacadas estáticas (marcadas por admin)
/// 2. Recomendaciones dinámicas personalizadas
/// 3. Actualización automática basada en la canción actual
class IntelligentFeaturedSongsSection extends ConsumerWidget {
  const IntelligentFeaturedSongsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inicializar el sistema inteligente (usar read para evitar rebuilds innecesarios)
    ref.read(intelligentFeaturedInitProvider);
    // Pre-inicializar el reproductor unificado para que el primer play sea más rápido
    ref.read(unifiedAudioProviderFixed.notifier).ensureInitialized();
    
    // Optimización: usar select para escuchar solo cambios específicos
    final featuredSongs = ref.watch(intelligentFeaturedSongsProvider.select((state) => state));
    final isLoading = ref.watch(intelligentFeaturedLoadingProvider.select((state) => state));
    final error = ref.watch(intelligentFeaturedErrorProvider.select((state) => state));

    // CRÍTICO: Solo mostrar skeleton durante carga inicial (cuando no hay datos)
    // Si hay datos pero está cargando (refresh), mostrar contenido existente
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
                        const Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Color(0xFF8B7A6A),
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
        
        // Botón para ver todas las canciones destacadas
        if (featuredSongs.isNotEmpty) ...[
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
                featuredSongs.length > 4
                    ? 'Ver ${featuredSongs.length - 4} recomendaciones más'
                    : 'Ver todas las canciones destacadas',
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
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Mismo margin que el real
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0.0, 0.25, 1.0],
                      colors: [
                        NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15),
                        NeumorphismTheme.surface.withValues(alpha: 0.8),
                        NeumorphismTheme.beigeMedium.withValues(alpha: 0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20), // Mismo borderRadius que el real
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Shimmer.fromColors(
                    baseColor: NeumorphismTheme.shimmerBaseColor,
                    highlightColor: NeumorphismTheme.shimmerHighlightColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // Mismo padding que el real (no 12)
                      child: Row(
                        children: [
                          // Portada skeleton - CRÍTICO: 64x64 con borderRadius 16 y sombra
                          Container(
                            width: 64,
                            height: 64,
                            constraints: const BoxConstraints(
                              minWidth: 64,
                              maxWidth: 64,
                              minHeight: 64,
                              maxHeight: 64,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16), // Mismo borderRadius que el real
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: NeumorphismTheme.shimmerContentColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16), // Mismo espacio que el real
                          // Información skeleton - CRÍTICO: Mismas alturas que los textos reales
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Título skeleton - fontSize: 17
                                Container(
                                  height: 17, // Mismo fontSize que el texto real
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: NeumorphismTheme.shimmerContentColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6), // Mismo espacio que el real
                                // Artista skeleton - fontSize: 14 con icono
                                Row(
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
                                    Container(
                                      height: 14, // Mismo fontSize que el texto real
                                      width: 150,
                                      decoration: BoxDecoration(
                                        color: NeumorphismTheme.shimmerContentColor,
                                        borderRadius: BorderRadius.circular(4),
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
                    onPressed: () async {
                      // Refrescar recomendaciones inteligentes
                      await ref.read(intelligentFeaturedProvider.notifier)
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
    
    // Usar go_router a través de la función estática que previene duplicados
    SongDetailScreen.navigateToSong(context, song);
  }
}

/// 🎵 TARJETA DE CANCIÓN DESTACADA INTELIGENTE
/// Estilo igual al perfil del artista (sin número, corazón ni play)
class IntelligentFeaturedSongCard extends ConsumerWidget {
  final FeaturedSong featuredSong;
  final VoidCallback onTap;

  const IntelligentFeaturedSongCard({
    super.key,
    required this.featuredSong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = featuredSong.song;
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.25, 1.0],
          colors: [
            NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15), // Toque de marrón en la izquierda
            NeumorphismTheme.surface.withValues(alpha: 0.8),
            NeumorphismTheme.beigeMedium.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8, // Igual que en perfil de artista
            offset: const Offset(0, 3), // Igual que en perfil de artista
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Portada con efecto de elevación (igual que perfil de artista)
                Container(
                    width: 64,
                    height: 64,
                    constraints: const BoxConstraints(
                      minWidth: 64,
                      maxWidth: 64,
                      minHeight: 64,
                      maxHeight: 64,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15), // Igual que perfil de artista
                          blurRadius: 6, // Igual que perfil de artista
                          offset: const Offset(0, 2), // Igual que perfil de artista
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: OptimizedImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        width: 64,
                        height: 64,
                        borderRadius: 16,
                        useThumbnail: true, // Usar thumbnail para carga más rápida
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                // Información de la canción (igual estilo que perfil de artista)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title ?? 'Sin título',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: NeumorphismTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: NeumorphismTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              song.artist?.stageName ?? 
                              song.artist?.displayName ?? 
                              'Artista Desconocido',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: NeumorphismTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Mostrar razón de destacado si existe
                      if (featuredSong.featuredReason != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          featuredSong.featuredReason!,
                          style: TextStyle(
                            fontSize: 11,
                            color: NeumorphismTheme.textSecondary.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
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
