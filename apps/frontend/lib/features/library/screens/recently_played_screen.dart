import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/play_history_provider.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/models/song_model.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/widgets/optimized_image.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pantalla de canciones recientemente reproducidas
/// ✅ MEJORA: Precarga de imágenes optimizada
class RecentlyPlayedScreen extends ConsumerStatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  ConsumerState<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends ConsumerState<RecentlyPlayedScreen> {
  // Cache de URLs normalizadas para evitar recálculos
  final Map<String, String?> _cachedCoverUrls = {};
  
  @override
  void initState() {
    super.initState();
    // Precargar imágenes después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages();
    });
  }
  
  /// Precargar imágenes de las primeras canciones visibles
  /// ✅ MEJORA: Precarga más agresiva (15 imágenes iniciales)
  void _precacheImages() {
    if (!mounted) return;
    
    final recentSongs = ref.read(playHistoryProvider.notifier).getRecentHistory(limit: 50);
    
    // ✅ MEJORA: Precargar primeras 15 imágenes (aumentado de 10 a 15)
    // Esto asegura que las imágenes estén listas antes de que el usuario haga scroll
    for (var i = 0; i < recentSongs.length && i < 15; i++) {
      final song = recentSongs[i];
      final coverUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl);
      if (coverUrl != null && coverUrl.isNotEmpty && !_cachedCoverUrls.containsKey(song.id)) {
        _cachedCoverUrls[song.id] = coverUrl;
        // Precargar en background sin bloquear
        precacheImage(CachedNetworkImageProvider(coverUrl), context).catchError((_) {
          // Ignorar errores de precarga
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentSongs = ref.watch(playHistoryProvider.notifier).getRecentHistory(limit: 50);

    return Scaffold(
      backgroundColor: NeumorphismTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeumorphismTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Recientemente Reproducidas',
          style: GoogleFonts.inter(
            color: NeumorphismTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: recentSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay canciones recientes',
                    style: GoogleFonts.inter(
                      color: NeumorphismTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              // 🔥 OPTIMIZADO: cacheExtent reducido para mejor rendimiento con grandes listas
              cacheExtent: 400, // Reducido de 500 a 400 para mejor rendimiento
              physics: const BouncingScrollPhysics(), // Física más suave
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = recentSongs[index];
                        
                        // ✅ MEJORA: Precarga progresiva más agresiva mientras se hace scroll
                        // Precargar imágenes de las siguientes 8 canciones (aumentado de 5 a 8)
                        // Esto asegura que siempre haya imágenes listas cuando el usuario hace scroll rápido
                        if (index < recentSongs.length - 8 && mounted) {
                          for (var i = index + 1; i <= index + 8 && i < recentSongs.length; i++) {
                            final nextSong = recentSongs[i];
                            if (!_cachedCoverUrls.containsKey(nextSong.id)) {
                              final nextCoverUrl = UrlNormalizer.normalizeImageUrl(nextSong.coverArtUrl);
                              if (nextCoverUrl != null && nextCoverUrl.isNotEmpty) {
                                _cachedCoverUrls[nextSong.id] = nextCoverUrl;
                                // Precargar en background sin bloquear
                                precacheImage(CachedNetworkImageProvider(nextCoverUrl), context).catchError((_) {
                                  // Ignorar errores de precarga
                                });
                              }
                            }
                          }
                        }
                        
                        return RepaintBoundary(
                          key: ValueKey('recent_song_${song.id}'),
                          child: _SongHistoryItem(
                            song: song,
                            index: index,
                            onTap: () {
                              SongDetailScreen.navigateToSong(context, song);
                            },
                            onPlay: () {
                              // ✅ CRÍTICO: useAlgorithm = true desactiva fixed queue automáticamente
                              ref.read(unifiedAudioProviderFixed.notifier).playSong(song, useAlgorithm: true);
                            },
                          ),
                        );
                      },
                      childCount: recentSongs.length,
                      // 🔥 OPTIMIZACIONES PARA GRANDES VOLÚMENES:
                      addAutomaticKeepAlives: false, // No mantener vivos items fuera de vista (ahorra memoria)
                      addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual (evita duplicación)
                      addSemanticIndexes: false, // Desactivar índices semánticos (mejor rendimiento)
                      // ⚠️ findChildIndexCallback removido - puede causar problemas con el orden de widgets
                    ),
                  ),
                ),
                // ✅ Padding inferior para que el mini player no tape la última canción
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 120),
                ),
              ],
            ),
    );
  }
}

class _SongHistoryItem extends ConsumerWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _SongHistoryItem({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Verificar si la canción está disponible para reproducir
    final isAvailable = song.fileUrl != null && song.fileUrl!.isNotEmpty;
    
    // ✅ OPTIMIZACIÓN: Usar selectores separados para escuchar solo cambios relevantes
    final currentSongId = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong?.id),
    );
    final isPlaying = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlaying),
    );
    final isCurrentSong = currentSongId == song.id;
    final showPause = isCurrentSong && isPlaying && isAvailable;

    // ✅ OPTIMIZACIÓN: Usar URL normalizada (ya está en cache si se precargó)
    final coverUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl);

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5, // Reducir opacidad si no está disponible
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: NeumorphismTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: NeumorphismTheme.floatingCardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isAvailable ? onTap : null, // Deshabilitar tap si no está disponible
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Número de posición
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        color: isAvailable 
                            ? NeumorphismTheme.textSecondary 
                            : NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Portada optimizada con precarga
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: coverUrl != null
                        ? OptimizedImage(
                            imageUrl: coverUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            isLargeCover: false,
                            // 🔥 OPTIMIZADO: Tamaños de cache reducidos para mejor rendimiento con muchas imágenes
                            maxCacheWidth: 128, // 2x el tamaño de visualización (64 * 2)
                            maxCacheHeight: 128,
                            useThumbnail: true, // Usar thumbnails cuando estén disponibles
                            skipFade: true, // Sin fade para mejor rendimiento en scroll rápido
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                            child: const Icon(Icons.music_note, color: Colors.white30),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Información
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title ?? 'Sin título',
                          style: GoogleFonts.inter(
                            color: isAvailable 
                                ? NeumorphismTheme.textPrimary 
                                : NeumorphismTheme.textPrimary.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                song.artist?.displayName ?? 'Artista desconocido',
                                style: GoogleFonts.inter(
                                  color: isAvailable 
                                      ? NeumorphismTheme.textSecondary 
                                      : NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isAvailable) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Colors.orange.withValues(alpha: 0.7),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Botón play - deshabilitado si no está disponible
                  IconButton(
                    icon: Icon(
                      showPause ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: isAvailable 
                          ? NeumorphismTheme.coffeeMedium 
                          : NeumorphismTheme.textSecondary.withValues(alpha: 0.3),
                      size: 40,
                    ),
                    onPressed: isAvailable ? onPlay : null,
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

