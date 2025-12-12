import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../features/artists/models/artist.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import 'featured_artist_card.dart';

class FeaturedArtistsSection extends ConsumerStatefulWidget {
  const FeaturedArtistsSection({super.key});

  @override
  ConsumerState<FeaturedArtistsSection> createState() => _FeaturedArtistsSectionState();
}

class _FeaturedArtistsSectionState extends ConsumerState<FeaturedArtistsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 🔥 OPTIMIZACIÓN: Mantener estado al hacer scroll
  
  // ScrollController simplificado - solo para el ListView horizontal
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // #region agent log
    final buildStartTime = DateTime.now().millisecondsSinceEpoch;
    // #endregion
    
    // 🔥 FIX: Usar select() directamente para evitar rebuilds innecesarios durante scroll
    // Solo observar isLoading si realmente lo necesitamos para mostrar skeleton
    final featuredArtists = ref.watch(featuredArtistsProvider);
    
    // ✅ OPTIMIZACIÓN: Solo observar isLoading si la lista está vacía
    final isLoading = featuredArtists.isEmpty 
        ? ref.watch(homeStateProvider.select((state) => state.isLoading)) 
        : false;
    
    // #region agent log
    final buildEndTime = DateTime.now().millisecondsSinceEpoch;
    final buildDuration = buildEndTime - buildStartTime;
    _writeDebugLog('featured_artists_section.dart:159', 'FeaturedArtistsSection build completed', {'duration': buildDuration}, 'A');
    // #endregion

    // CRÍTICO: Solo mostrar skeleton durante carga inicial (cuando no hay datos)
    // Si hay datos pero está cargando (refresh), mostrar contenido existente
    if (isLoading && featuredArtists.isEmpty) {
      return _buildLoadingSection();
    }

    if (featuredArtists.isEmpty && !isLoading) {
      return _buildEmptySection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header simplificado
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Artistas',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: NeumorphismTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Lista horizontal simplificada - menos items visibles
        SizedBox(
          height: 200,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 24, right: 8),
            cacheExtent: 300,
            physics: const BouncingScrollPhysics(),
            itemExtent: 136.0,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            addSemanticIndexes: false,
            itemCount: featuredArtists.length,
            itemBuilder: (context, index) {
              final featuredArtist = featuredArtists[index];
              return RepaintBoundary(
                key: ValueKey('artist_${featuredArtist.artist.id}'),
                child: FeaturedArtistCard(
                  key: ValueKey('artist_card_${featuredArtist.artist.id}'),
                  featuredArtist: featuredArtist,
                  onTap: () => _onArtistTap(context, featuredArtist.artist),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// ⚡ OPTIMIZADO: Skeleton ligero adaptado al contenido real
  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton - Tamaños exactos del contenido real
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Shimmer.fromColors(
                baseColor: NeumorphismTheme.shimmerBaseColor,
                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                period: const Duration(milliseconds: 1200), // Más lento = más ligero
                child: Container(
                  width: 48, // Igual que el icono real
                  height: 48, // Igual que el icono real
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: NeumorphismTheme.shimmerContentColor,
                  ),
                ),
              ),
              const SizedBox(width: 12), // Igual que el real
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: NeumorphismTheme.shimmerBaseColor,
                  highlightColor: NeumorphismTheme.shimmerHighlightColor,
                  period: const Duration(milliseconds: 1200),
                  child: Container(
                    height: 20, // Igual que fontSize 20 del título real
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.shimmerContentColor,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12), // Igual que el real
              Shimmer.fromColors(
                baseColor: NeumorphismTheme.shimmerBaseColor,
                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                period: const Duration(milliseconds: 1200),
                child: Container(
                  height: 14, // Igual que fontSize 14 del botón "Ver todos"
                  width: 70, // Ancho aproximado del botón
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.shimmerContentColor,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16), // Igual que el real
        // Lista skeleton - Altura exacta 235px (igual que el contenido real)
        SizedBox(
          height: 235, // Igual que el contenido real
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 24, right: 8), // Igual que el real
            cacheExtent: 300, // Reducido para ser más ligero
            physics: const BouncingScrollPhysics(), // Igual que el real
            itemExtent: 156.0, // 🔥 OPTIMIZACIÓN: Ancho fijo (140 + 16 margin) para mejor cálculo de scroll
            itemCount: 2, // Solo 2 items para reducir carga
            itemBuilder: (context, index) {
              return Container(
                width: 120, // Igual que FeaturedArtistCard
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen skeleton - 120x120 circular (igual que el real)
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        width: 120, // Igual que el real
                        height: 120, // Igual que el real
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: NeumorphismTheme.shimmerContentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12), // Igual que el real
                    // Texto skeleton - Tamaño aproximado del nombre del artista
                    Shimmer.fromColors(
                      baseColor: NeumorphismTheme.shimmerBaseColor,
                      highlightColor: NeumorphismTheme.shimmerHighlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        height: 14, // Altura aproximada del texto
                        width: 100, // Ancho aproximado
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.shimmerContentColor,
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
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
        Text(
          'Artistas Destacados',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_note,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay artistas destacados',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vuelve más tarde para descubrir nuevos talentos',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onArtistTap(BuildContext context, Artist artist) {
    final lite = ArtistLite(
      id: artist.id,
      name: artist.stageName ?? 'Artista',
      profilePhotoUrl: artist.profilePhotoUrl,
      coverPhotoUrl: artist.coverPhotoUrl,
      nationalityCode: null,
      featured: true,
    );
    context.push('/artist/${artist.id}', extra: lite);
  }
  
  // #region agent log
  void _writeDebugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
    final logEntry = {
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
      'runId': 'run1',
      'hypothesisId': hypothesisId,
    };
    debugPrint('[DEBUG] ${jsonEncode(logEntry)}');
    try {
      final logPath = r'c:\app definitiva\.cursor\debug.log';
      final logFile = File(logPath);
      final logDir = logFile.parent;
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      logFile.writeAsStringSync('${jsonEncode(logEntry)}\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[DEBUG LOG FILE ERROR] $e');
    }
  }
  // #endregion
}
