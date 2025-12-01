import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'dart:async';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/play_button_icon.dart';
import '../providers/song_detail_provider.dart';

// Set estático para evitar múltiples reproducciones simultáneas en artist songs list
final Set<String> _artistSongsListPlayingSongIds = {};

// Map estático para almacenar timers cancelables por songId
final Map<String, Timer> _artistSongsListRemoveTimers = {};

/// Widget que muestra una lista HORIZONTAL de canciones del mismo artista (estilo Spotify)
class ArtistSongsHorizontalList extends ConsumerWidget {
  final String artistId;
  final String? currentSongId;
  final Function(Song) onSongTap;

  const ArtistSongsHorizontalList({
    super.key,
    required this.artistId,
    this.currentSongId,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsByArtistProvider(artistId));
    
    // Escuchar cambios en la ruta actual para que el widget se reconstruya cuando cambia
    // Esto asegura que el filtro se actualice cuando navegas a otra canción
    final router = GoRouter.of(context);
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
    
    // Extraer el ID de la canción de la ruta actual si es una ruta de canción
    String? currentOpenSongId;
    if (currentLocation.startsWith('/song/')) {
      currentOpenSongId = currentLocation.replaceFirst('/song/', '');
    }
    
    // Obtener todas las rutas abiertas en el stack para excluir canciones ya abiertas
    final openSongRoutes = <String>{};
    if (currentOpenSongId != null && currentOpenSongId.isNotEmpty) {
      openSongRoutes.add(currentOpenSongId);
    }
    
    try {
      final matches = router.routerDelegate.currentConfiguration.matches;
      for (final match in matches) {
        final location = match.matchedLocation;
        if (location.startsWith('/song/')) {
          // Extraer el ID de la canción de la ruta
          final songId = location.replaceFirst('/song/', '');
          if (songId.isNotEmpty) {
            openSongRoutes.add(songId);
          }
        }
      }
    } catch (e) {
      // Si hay error obteniendo las rutas, continuar sin filtrar por stack
      debugPrint('[ArtistSongsHorizontalList] Error obteniendo rutas abiertas: $e');
    }

    return songsAsync.when(
      data: (songs) {
        // OPTIMIZACIÓN: Función helper para verificar si una canción debe incluirse
        bool _shouldIncludeSong(Song song) {
          // Excluir la canción actual pasada como parámetro
          if (currentSongId != null && currentSongId!.isNotEmpty && song.id == currentSongId) {
            return false;
          }
          
          // Excluir la canción que está siendo mostrada actualmente en la ruta
          if (currentOpenSongId != null && currentOpenSongId.isNotEmpty && song.id == currentOpenSongId) {
            return false;
          }
          
          // Excluir canciones que ya están abiertas en el stack
          if (openSongRoutes.contains(song.id)) {
            return false;
          }
          
          return true;
        }
        
        // OPTIMIZACIÓN: Crear lista de índices válidos en lugar de lista completa de objetos
        // Esto es mucho más eficiente en memoria (solo ints vs objetos completos)
        // y evita crear múltiples listas intermedias
        final validIndices = <int>[];
        for (int i = 0; i < songs.length && validIndices.length < 10; i++) {
          if (_shouldIncludeSong(songs[i])) {
            validIndices.add(i);
          }
        }
        
        if (validIndices.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: validIndices.length,
          itemBuilder: (context, index) {
            // Acceso O(1) usando el índice válido almacenado
            final song = songs[validIndices[index]];
            final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
                ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
                : null;

            return RepaintBoundary(
              key: ValueKey('artist_song_horizontal_${song.id}'),
              child: _SongHorizontalCard(
                key: ValueKey('artist_song_card_${song.id}'),
                song: song,
                coverUrl: coverUrl,
                onTap: () => onSongTap(song),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Error al cargar canciones: ${error.toString()}',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

/// Widget individual de canción en lista horizontal (estilo Spotify)
/// SIN botón de play flotante - solo navegación al tocar
class _SongHorizontalCard extends StatelessWidget {
  final Song song;
  final String? coverUrl;
  final VoidCallback onTap;

  const _SongHorizontalCard({
    super.key,
    required this.song,
    this.coverUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Asegurar que capture todos los taps
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portada cuadrada - SIN botón de play flotante
            // Sin Hero para evitar conflictos con navegación
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 64, // Optimización: límite de memoria para imágenes pequeñas
                        memCacheHeight: 64,
                        placeholder: (context, url) => Container(
                          color: NeumorphismTheme.coffeeMedium,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: NeumorphismTheme.coffeeMedium,
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        color: NeumorphismTheme.coffeeMedium,
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Título de la canción
            Text(
              song.title ?? 'Sin título',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NeumorphismTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            // Artista
            Text(
              song.artist?.displayName ?? 'Artista desconocido',
              style: const TextStyle(
                fontSize: 13,
                color: NeumorphismTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget que muestra una lista VERTICAL de canciones del mismo artista (versión anterior)
class ArtistSongsList extends ConsumerWidget {
  final String artistId;
  final String? currentSongId;
  final Function(Song) onSongTap;

  const ArtistSongsList({
    super.key,
    required this.artistId,
    this.currentSongId,
    required this.onSongTap,
  });

  /// Maneja el botón de play/expand
  /// Si NO hay canción reproduciéndose → reproduce normalmente
  /// Si HAY canción reproduciéndose → expande el full player
  Future<void> _handlePlayPause(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) async {
    // Protección: evitar múltiples taps rápidos
    if (_artistSongsListPlayingSongIds.contains(song.id)) return;
    
    try {
      _artistSongsListPlayingSongIds.add(song.id);
      final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
      final audioState = ref.read(unifiedAudioProviderFixed);
      
      // Verificar si hay una canción reproduciéndose
      final currentSong = audioState.currentSong;
      final isPlaying = audioState.isPlaying;
      final isCurrentSong = currentSong?.id == song.id;
      
      // Si es la canción actual y está reproduciéndose → toggle pause/play
      if (isCurrentSong && isPlaying) {
        await audioNotifier.togglePlayPause();
        return;
      }
      
      // Si hay otra canción reproduciéndose o no hay canción → reproducir nueva canción
      AppLogger.info('[ArtistSongsList] 🎵 Reproduciendo: ${song.title}');
      await audioNotifier.playSong(song);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // OPTIMIZACIÓN: Usar Timer cancelable en lugar de Future.delayed
      // Cancelar timer anterior si existe para esta canción
      _artistSongsListRemoveTimers[song.id]?.cancel();
      
      // Crear nuevo timer cancelable
      _artistSongsListRemoveTimers[song.id] = Timer(
        const Duration(milliseconds: 500),
        () {
          _artistSongsListPlayingSongIds.remove(song.id);
          _artistSongsListRemoveTimers.remove(song.id); // Limpiar el timer del map
        },
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsByArtistProvider(artistId));

    return songsAsync.when(
      data: (songs) {
        final filteredSongs = songs.where((song) => song.id != currentSongId).toList();
        
        if (filteredSongs.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          cacheExtent: 400, // Optimización: límite de cache para lista pequeña embebida
          itemCount: filteredSongs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final song = filteredSongs[index];
            final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
                ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
                : null;
            
            // Usar el provider unificado en lugar de streams
            return RepaintBoundary(
              key: ValueKey('artist_song_vertical_${song.id}'),
              child: Consumer(
                builder: (context, ref, child) {
                  // Optimización: usar select para escuchar solo los campos necesarios
                  final currentSong = ref.watch(
                    unifiedAudioProviderFixed.select((state) => state.currentSong),
                  );
                  final isPlaying = ref.watch(
                    unifiedAudioProviderFixed.select((state) => state.isPlaying),
                  );
                  final isCurrentSong = currentSong?.id == song.id;
                  
                  // Obtener el estado de reproducción del provider unificado
                  final isPlayingForThisSong = isCurrentSong && isPlaying;

                  return _SongListItem(
                    key: ValueKey('artist_song_item_${song.id}'),
                    song: song,
                    coverUrl: coverUrl,
                    isPlaying: isPlayingForThisSong,
                    onTap: () => onSongTap(song),
                    onPlayPause: () => _handlePlayPause(context, ref, song),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Error al cargar canciones: ${error.toString()}',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

/// Widget individual de canción en la lista vertical
class _SongListItem extends StatelessWidget {
  final Song song;
  final String? coverUrl;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const _SongListItem({
    super.key,
    required this.song,
    this.coverUrl,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: NeumorphismTheme.floatingCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: NeumorphismTheme.glassDecoration().copyWith(
              color: Colors.white.withValues(alpha: 0.3),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    // Mini portada
                    Hero(
                      tag: 'album_cover_${song.id}',
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: coverUrl != null
                              ? Builder(
                                  builder: (context) {
                                    // OPTIMIZACIÓN: Usar valor constante razonable (128) para mayoría de dispositivos
                                    // Esto evita llamar MediaQuery en cada build
                                    // 128 = 64 * 2.0 (devicePixelRatio típico) redondeado
                                    const memCacheSize = 128;
                                    return CachedNetworkImage(
                                      imageUrl: coverUrl!,
                                      fit: BoxFit.cover,
                                      memCacheWidth: memCacheSize, // Optimización: límite de memoria
                                      memCacheHeight: memCacheSize,
                                      placeholder: (context, url) => Container(
                                        color: NeumorphismTheme.coffeeMedium,
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: NeumorphismTheme.coffeeMedium,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: NeumorphismTheme.coffeeMedium,
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Información de la canción
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title ?? 'Sin título',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: NeumorphismTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.artist?.displayName ?? 'Artista desconocido',
                            style: const TextStyle(
                              fontSize: 13,
                              color: NeumorphismTheme.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Botón Play/Pause
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isPlaying 
                            ? NeumorphismTheme.coffeeMedium
                            : Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        boxShadow: NeumorphismTheme.floatingCardShadow,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onPlayPause,
                          borderRadius: BorderRadius.circular(22),
                          child: Center(
                            child: PlayButtonIcon(
                              isPlaying: isPlaying,
                              color: isPlaying 
                                  ? Colors.white
                                  : NeumorphismTheme.textPrimary,
                              size: 24,
                              icon: Icons.play_arrow,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
