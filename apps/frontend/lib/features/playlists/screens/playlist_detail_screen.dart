import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/playlist_provider.dart';
import '../../../core/providers/audio_player_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/widgets/fast_scroll_physics.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Validar que el ID no esté vacío
    if (playlistId.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildNotFoundState(context, 'ID de playlist inválido'),
      );
    }

    final playlistAsync = ref.watch(playlistProvider(playlistId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true, // Asegura que el contenido respete la barra de navegación del sistema
        child: playlistAsync.when(
        data: (playlist) {
          if (playlist == null) {
            return _buildNotFoundState(context, 'La playlist que buscas no existe o fue eliminada');
          }

          final songs = playlist.songs;

          return CustomScrollView(
            cacheExtent: 800, // Aumentado a 800px para scroll más rápido
            physics: const FastScrollPhysics(), // Scroll más rápido y fluido
            slivers: [
              // App Bar con imagen de fondo
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Imagen de portada optimizada (portada grande)
                      OptimizedImage(
                        imageUrl: playlist.coverArtUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        isLargeCover: true, // Marcar como portada grande para optimización
                      ),
                      
                      // Overlay oscuro
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    (playlist.name?.isNotEmpty == true) ? playlist.name! : 'Playlist',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
                ),
              ),

              // Contenido
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información de la playlist
                      if (playlist.description != null && playlist.description!.isNotEmpty) ...[
                        Text(
                          playlist.description!,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Estadísticas
                      Row(
                        children: [
                          if (playlist.user != null) ...[
                            Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              playlist.user?.firstName ?? 'Usuario',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Icon(Icons.queue_music, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${playlist.totalSongs} canciones',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            playlist.durationFormatted,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Botón de reproducir todo
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (songs.isNotEmpty) {
                              _onPlayAll(context, songs);
                            }
                          },
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          label: Text(
                            'Reproducir todo',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Título de canciones
                      Text(
                        'Canciones',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Lista de canciones
              if (songs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: 24, // Solo padding estándar, SafeArea maneja el resto
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.music_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Esta playlist no tiene canciones',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return RepaintBoundary(
                        key: ValueKey('song_item_${song.id}'), // Key estable para optimización
                        child: _SongListItem(
                          key: ValueKey(song.id), // Key estable para el widget
                          song: song,
                          index: index + 1,
                          onTap: () {
                            _onSongTap(context, song);
                          },
                          onPlay: () {
                            _onPlaySong(context, song);
                          },
                        ),
                      );
                    },
                    childCount: songs.length,
                    // Optimización: desactivar keepAlive y repaintBoundaries automáticos para mejor rendimiento
                    addAutomaticKeepAlives: false, // No mantener vivos items fuera de la vista (mejor rendimiento)
                    addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual
                  ),
                ),
              
              // Padding inferior para evitar superposición (SafeArea ya maneja el padding del sistema)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 16), // Solo padding extra, SafeArea maneja el resto
              ),
            ],
          );
        },
        loading: () => _buildLoadingState(context),
        error: (error, stack) => _buildErrorState(context, error),
        ),
      ),
    );
  }

  Widget _buildNotFoundState(BuildContext context, [String? message]) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_remove,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'Playlist no encontrada',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La playlist que buscas no existe o fue eliminada',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF667eea),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar playlist',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Volver',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSongTap(BuildContext context, Song song) {
    // Navegar a detalles de la canción o abrir reproductor
    // Por ahora, reproducir la canción directamente ya que no hay ruta de detalles
    // Nota: Se puede crear una ruta /song/:id en el futuro para mostrar detalles completos
    _onPlaySong(context, song);
  }

  void _onPlaySong(BuildContext context, Song song) {
    // Reproducir canción usando el reproductor existente
    final container = ProviderScope.containerOf(context);
    final audioService = container.read(audioPlayerServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    
    audioService.playSong(song).then((_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Reproduciendo ${song.title ?? "Canción"}'),
          backgroundColor: const Color(0xFF667eea),
          duration: const Duration(seconds: 2),
        ),
      );
    }).catchError((error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al reproducir: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _onPlayAll(BuildContext context, List<Song> songs) {
    // Reproducir toda la playlist usando el reproductor existente
    final messenger = ScaffoldMessenger.of(context);
    
    if (songs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No hay canciones para reproducir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final container = ProviderScope.containerOf(context);
    final audioService = container.read(audioPlayerServiceProvider);
    
    audioService.playQueue(songs).then((_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Reproduciendo playlist con ${songs.length} canciones'),
          backgroundColor: const Color(0xFF667eea),
          duration: const Duration(seconds: 2),
        ),
      );
    }).catchError((error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al reproducir playlist: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }
}

class _SongListItem extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _SongListItem({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            // Número de posición
            SizedBox(
              width: 32,
              child: Text(
                '$index',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(width: 16),

            // Portada de la canción
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: OptimizedImage(
                    imageUrl: song.coverArtUrl,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    borderRadius: 8,
                    placeholderColor: const Color(0xFF667eea).withValues(alpha: 0.3),
                  ),
                ),
            ),

            const SizedBox(width: 16),

            // Información de la canción
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title ?? 'Canción sin título',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getArtistName(song),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Duración
            Text(
              song.durationFormatted,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(width: 16),

            // Botón de play
            IconButton(
              onPressed: onPlay,
              icon: const Icon(
                Icons.play_arrow,
                color: Color(0xFF667eea),
                size: 28,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  String _getArtistName(Song song) {
    if (song.artist != null) {
      final stageName = song.artist!.stageName;
      if (stageName != null && stageName.isNotEmpty) {
        return stageName;
      }
      final displayName = song.artist!.displayName;
      if (displayName.isNotEmpty && displayName != 'Artista Desconocido') {
        return displayName;
      }
    }
    return 'Artista desconocido';
  }
}

