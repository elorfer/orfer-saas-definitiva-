import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
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
  
  @override
  void initState() {
    super.initState();
    // ✅ OPTIMIZACIÓN: Carga diferida - solo cargar cuando el widget esté montado y visible
    if (!_hasInitialized) {
      _hasInitialized = true;
      // Cargar de forma diferida para no bloquear el build inicial
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          final state = ref.read(intelligentFeaturedProvider);
          // Solo cargar si no está inicializado
          if (!state.isInitialized && !state.isLoading) {
            ref.read(intelligentFeaturedProvider.notifier).loadIntelligentFeaturedSongs(limit: 10);
          }
        }
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // ✅ OPTIMIZACIÓN: Solo observar las canciones - evitar observar loading/error innecesariamente
    final featuredSongs = ref.watch(intelligentFeaturedSongsProvider);
    
    // Solo verificar loading/error una vez al inicio, no en cada build
    final state = ref.read(intelligentFeaturedProvider);
    final isLoading = featuredSongs.isEmpty && state.isLoading;
    final error = featuredSongs.isEmpty ? state.error : null;

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
        // Título de la sección simplificado
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Para Ti',
            // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2E20),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // ✅ OPTIMIZACIÓN: Column directo - mostrar solo 2 canciones para menos saturación
        Column(
          children: featuredSongs.take(2).map((featuredSong) {
            return RepaintBoundary(
              key: ValueKey('intelligent_song_card_${featuredSong.song.id}'),
              child: IntelligentFeaturedSongCard(
                key: ValueKey('intelligent_song_${featuredSong.song.id}'),
                featuredSong: featuredSong,
                onTap: () {
                  _onSongTap(context, ref, featuredSong.song);
                },
              ),
            );
          }).toList(),
        ),
        
        // Indicador de carga si está actualizando
        if (isLoading && featuredSongs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8B7A6A),
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
              child: Text(
                'Ver más',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NeumorphismTheme.accentDark,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// ⚡ OPTIMIZADO: Skeleton ligero adaptado al contenido real
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ⚡ Solo 2 items skeleton - Tamaños exactos del contenido real
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: List.generate(2, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Shimmer.fromColors(
                  baseColor: NeumorphismTheme.shimmerBaseColor,
                  highlightColor: NeumorphismTheme.shimmerHighlightColor,
                  period: const Duration(milliseconds: 1200), // Más lento = más ligero
                  child: Padding(
                    padding: const EdgeInsets.all(16.0), // Igual que el contenido real
                    child: Row(
                      children: [
                        // Portada skeleton - 64x64 exacto
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.shimmerContentColor,
                            borderRadius: const BorderRadius.all(Radius.circular(16)), // Igual que el real
                          ),
                        ),
                        const SizedBox(width: 16), // Igual que el real
                        // Información skeleton - Tamaños exactos del texto real
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Título skeleton - 17px (igual que fontSize del título real)
                              Container(
                                height: 17,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: NeumorphismTheme.shimmerContentColor,
                                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 6), // Igual que el real
                              // Artista skeleton - 14px (igual que fontSize del artista real) + espacio para badge
                              Row(
                                children: [
                                  Container(
                                    height: 14,
                                    width: 120, // Ancho aproximado para artista + badge
                                    decoration: BoxDecoration(
                                      color: NeumorphismTheme.shimmerContentColor,
                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
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
              borderRadius: const BorderRadius.all(Radius.circular(12)),
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
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: Color(0xFF8B7A6A),
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

  /// ✅ SOLUCIÓN: Las canciones destacadas NO tienen contextos de reproducción
  /// Solo navegan a song_detail_screen.dart sin reproducir automáticamente
  void _onSongTap(BuildContext context, WidgetRef ref, Song song) {
    if (!context.mounted) {
      debugPrint('[IntelligentFeaturedSongs] Contexto no montado');
      return;
    }
    
    debugPrint('[IntelligentFeaturedSongs] Navegando a canción destacada: ${song.title} (${song.id})');
    
    // ✅ SOLUCIÓN: Solo navegar a song_detail_screen.dart (NO reproducir automáticamente)
    // El usuario puede reproducir desde la pantalla de detalle si lo desea
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

  // ✅ Decoración ligera - sin gradientes pesados ni sombras excesivas
  static final BoxDecoration _cardDecoration = BoxDecoration(
    color: NeumorphismTheme.surface.withValues(alpha: 0.6),
    borderRadius: const BorderRadius.all(Radius.circular(16)),
    border: Border.all(
      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
      width: 1,
    ),
  );
  
  static final BoxDecoration _imageDecoration = BoxDecoration(
    color: Colors.transparent,
    borderRadius: const BorderRadius.all(Radius.circular(12)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = featuredSong.song;
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    return Container(
      key: ValueKey('intelligent_song_${song.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: _cardDecoration,
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            onTap: onTap,
            splashColor: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
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
                        maxCacheWidth: 200,
                        maxCacheHeight: 200,
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
                              child: song.artist != null
                                  ? ArtistNameWithBadge(
                                      artistName: song.artist!.stageName ?? 
                                          (song.artist!.displayName.isNotEmpty 
                                              ? song.artist!.displayName 
                                              : 'Artista Desconocido'),
                                      isVerified: song.artist!.isVerifiedValue,
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: NeumorphismTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      badgeSize: 12.0,
                                    )
                                  : Text(
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
      ),
    );
  }
}
