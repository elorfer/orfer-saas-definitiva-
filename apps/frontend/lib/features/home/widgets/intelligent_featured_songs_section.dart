import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/models/song_model.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/verified_badge.dart';

/// 🧠 SECCIÓN DE CANCIONES DESTACADAS INTELIGENTES
/// Usa tu algoritmo avanzado de recomendaciones para mostrar:
/// 1. Canciones destacadas estáticas (marcadas por admin)
/// 2. Recomendaciones dinámicas personalizadas
/// 3. Actualización automática basada en la canción actual
class IntelligentFeaturedSongsSection extends ConsumerStatefulWidget {
  const IntelligentFeaturedSongsSection({super.key});

  @override
  ConsumerState<IntelligentFeaturedSongsSection> createState() => _IntelligentFeaturedSongsSectionState();
}

class _IntelligentFeaturedSongsSectionState extends ConsumerState<IntelligentFeaturedSongsSection>
    with AutomaticKeepAliveClientMixin {
  bool _hasInitialized = false;

  static const _titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Color(0xFF3D2E20),
    decoration: TextDecoration.none,
  );

  static const _seeMoreStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: NeumorphismTheme.accentDark,
    decoration: TextDecoration.none,
  );
  
  @override
  void initState() {
    super.initState();
    // ✅ OPTIMIZACIÓN: Carga diferida - solo cargar cuando el widget esté montado y visible
    if (!_hasInitialized) {
      _hasInitialized = true;
      // 🚀 FIX: Eliminada la lógica de carga automática aquí para evitar bucles infinitos.
      // El HomeScreen ya se encarga de llamar a refreshIntelligentRecommendations()
      // Este widget debe ser puramente visual (Consumer).
      
      /* LÓGICA ANTERIOR (CAUSANTE DEL LOOP SI SE RECONSTRUYE)
      final featuredSongs = ref.read(intelligentFeaturedSongsProvider);
      if (featuredSongs.isNotEmpty) return;
      
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          final state = ref.read(intelligentFeaturedProvider);
          if (!state.isInitialized && !state.isLoading) {
            ref.read(intelligentFeaturedProvider.notifier).loadIntelligentFeaturedSongs(limit: 10);
          }
        }
      });
      */
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // ✅ OPTIMIZACIÓN: Solo observar si hay canciones para decidir qué widget base mostrar.
    // Los estados de carga y error se verifican internamente solo si no hay canciones.
    final hasSongs = ref.watch(intelligentFeaturedSongsProvider.select((s) => s.isNotEmpty));
    
    if (!hasSongs) {
      final isLoading = ref.watch(intelligentFeaturedLoadingProvider);
      if (isLoading) return _buildLoadingSection();
      
      final error = ref.watch(intelligentFeaturedErrorProvider);
      if (error != null) return _buildErrorSection(context, ref, error);
      
      return _buildEmptySection();
    }



    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Para Ti',
            style: _titleStyle,
          ),
        ),
        const SizedBox(height: 4),
        Consumer(
          builder: (context, ref, _) {
            final featuredSongs = ref.watch(intelligentFeaturedSongsProvider);
            final displayCount = featuredSongs.length < 3 ? featuredSongs.length : 3;
            final isRefreshing = ref.watch(intelligentFeaturedLoadingProvider);
            
            return Column(
              children: [
                Column(
                  children: List.generate(displayCount, (idx) {
                    final featuredSong = featuredSongs[idx];
                    return IntelligentFeaturedSongCard(
                      key: ValueKey('intelligent_song_${featuredSong.song.id}'),
                      featuredSong: featuredSong,
                      onTap: () {
                        _onSongTap(context, ref, featuredSong.song);
                      },
                    );
                  }),
                ),
                
                // Indicador de carga si está actualizando
                if (isRefreshing && featuredSongs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF8B7A6A),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Actualizando recomendaciones...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B7A6A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                // Botón simplificado para ver más
                if (featuredSongs.length > 2) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        context.push('/featured-songs');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: NeumorphismTheme.accentDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Ver más',
                        style: _seeMoreStyle,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// ⚡ OPTIMIZADO: Skeleton estático ultra-ligero sin animaciones
  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 22,
            width: 120,
            decoration: BoxDecoration(
              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ⚡ Solo 2 items skeleton estáticos - sin Shimmer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: List.generate(2, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3EBE3), // 🚀 Sólido para evitar blending
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    // Portada skeleton
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDED1C4), // 🚀 Sólido para evitar blending
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info skeleton
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 14,
                            width: 120,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAE2D9), // 🚀 Sólido
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ],
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

  Widget _buildErrorSection(BuildContext context, WidgetRef ref, String error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const Text(
            'Destacadas para Ti',
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
                    Icons.error_outline,
                    size: 48,
                    color: Color(0x99FF0000), // Usamos alpha aquí porque es un Icono dinámico, pero intentamos limitarlo
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar recomendaciones',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF3D2E20),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B7A6A),
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(intelligentFeaturedProvider.notifier)
                          .refreshIntelligentRecommendations();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7A6A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(fontSize: 14),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Destacadas para Ti',
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
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: Color(0xFF8B7A6A),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Preparando recomendaciones',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF3D2E20),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Reproduce una canción para obtener recomendaciones personalizadas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B7A6A),
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

  /// ✅ SOLUCIÓN: Las canciones destacadas NO tienen contextos de reproducción
  /// Solo navegan a song_detail_screen.dart sin reproducir automáticamente
  void _onSongTap(BuildContext context, WidgetRef ref, Song song) {
    if (!context.mounted) return;
    // ✅ SOLUCIÓN: Solo navegar a song_detail_screen.dart (NO reproducir automáticamente)
    // El usuario puede reproducir desde la pantalla de detalle si lo desea
    SongDetailScreen.navigateToSong(context, song);
  }
}

/// 🎵 TARJETA DE CANCIÓN DESTACADA INTELIGENTE
/// Estilo igual al perfil del artista (sin número, corazón ni play)
class IntelligentFeaturedSongCard extends StatelessWidget {
  final FeaturedSong featuredSong;
  final VoidCallback onTap;

  const IntelligentFeaturedSongCard({
    super.key,
    required this.featuredSong,
    required this.onTap,
  });

  // ✅ Decoración ligera - sin gradientes pesados ni sombras excesivas
  // ✅ Decoración ultra-ligera: Fondo blanco sólido y borde mínimo
  static final BoxDecoration _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: const BorderRadius.all(Radius.circular(16)),
    border: Border.all(
      color: const Color(0x148B7A6A),
      width: 1,
    ),
  );
  
  static const BoxDecoration _imageDecoration = BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  static const _songTitleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: NeumorphismTheme.textPrimary,
    letterSpacing: -0.3,
    decoration: TextDecoration.none,
  );

  static const _artistNameStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: NeumorphismTheme.textSecondary,
    decoration: TextDecoration.none,
  );

  static const _reasonStyle = TextStyle(
    fontSize: 11,
    color: Color(0x99756860),
    fontStyle: FontStyle.italic,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    final song = featuredSong.song;
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    return Container(
      key: ValueKey('intelligent_song_${song.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: _cardDecoration,
      child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            onTap: onTap,
            splashColor: const Color(0x1A8B7A6A),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  // Portada simplificada - sin sombras pesadas
                  Container(
                    width: 60,
                    height: 60,
                    decoration: _imageDecoration,
                      child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: OptimizedImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        borderRadius: 12,
                        useThumbnail: true,
                        maxCacheWidth: 150,
                        maxCacheHeight: 150,
                        lazyLoad: true, // ⚡ Optimización: Distribuir carga de frames
                        skipFade: true,
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
                          style: _songTitleStyle,
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
                              child: song.artist != null
                                  ? ArtistNameWithBadge(
                                      artistName: song.artist!.stageName ??
                                          (song.artist!.displayName.isNotEmpty
                                              ? song.artist!.displayName
                                              : 'Artista Desconocido'),
                                      isVerified: song.artist!.isVerifiedValue,
                                      textStyle: _artistNameStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      badgeSize: 12.0,
                                    )
                                  : const Text(
                                      'Artista Desconocido',
                                      style: _artistNameStyle,
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
                          style: _reasonStyle,
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
