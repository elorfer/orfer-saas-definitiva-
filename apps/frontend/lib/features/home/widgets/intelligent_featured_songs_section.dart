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
  @override
  void initState() {
    super.initState();
    // Inicializar una vez para evitar trabajo extra en cada rebuild
    Future.microtask(() {
      ref.read(intelligentFeaturedInitProvider);
      ref.read(unifiedAudioProviderFixed.notifier).ensureInitialized();
    });
  }

  @override
  bool get wantKeepAlive => true; // 🔥 OPTIMIZACIÓN: Mantener estado al hacer scroll

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // ✅ OPTIMIZACIÓN: Los providers ya usan select() internamente
    // Solo se reconstruye cuando cambian estos valores específicos
    final featuredSongs = ref.watch(intelligentFeaturedSongsProvider);
    final isLoading = ref.watch(intelligentFeaturedLoadingProvider);
    final error = ref.watch(intelligentFeaturedErrorProvider);

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
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
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
        ),
        
        const SizedBox(height: 16),
        
        // 🔥 OPTIMIZACIÓN: Column con items fijos (máximo 4) - más eficiente que ListView con shrinkWrap
        Column(
          children: [
            for (int index = 0; index < featuredSongs.take(4).length; index++)
              IntelligentFeaturedSongCard(
                key: ValueKey('intelligent_song_card_${featuredSongs[index].song.id}'),
                featuredSong: featuredSongs[index],
                onTap: () {
                  _onSongTap(context, ref, featuredSongs[index].song);
                },
              ),
          ],
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = featuredSong.song;
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    return Container(
      key: ValueKey('intelligent_song_${song.id}'),
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
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8, // Igual que en perfil de artista
            offset: const Offset(0, 3), // Igual que en perfil de artista
            spreadRadius: 0,
          ),
        ],
      ),
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
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
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
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
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: OptimizedImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          width: 64,
                          height: 64,
                          borderRadius: 16,
                          useThumbnail: true,
                          maxCacheWidth: 300, // 🔥 OPTIMIZACIÓN: Tamaño optimizado (300px suficiente)
                          maxCacheHeight: 300,
                          skipFade: true, // 🔥 Sin fade para mejor rendimiento
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
