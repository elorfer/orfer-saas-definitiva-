import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neumorphism_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/playlist_provider.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/utils/logger.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/utils/data_normalizer.dart';
import '../../../core/utils/retry_handler.dart';

// Función top-level para procesar playlist en isolate
Playlist? _parsePlaylist(Map<String, dynamic> jsonData) {
  try {
    // Validar que jsonData tenga al menos un campo básico
    if (jsonData.isEmpty) {
      return null;
    }
    
    final normalizedData = DataNormalizer.normalizePlaylist(jsonData);
    
    // Validar que la normalización produjo datos válidos
    if (normalizedData.isEmpty || !normalizedData.containsKey('id')) {
      return null;
    }
    
    final playlist = Playlist.fromJson(normalizedData);
    
    // Validar que la playlist tenga un ID válido
    if (playlist.id.isEmpty) {
      return null;
    }
    
    return playlist;
  } catch (e) {
    // Error al procesar playlist
    return null;
  }
}

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
  });

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> 
    with AutomaticKeepAliveClientMixin {
  Playlist? _playlist;
  List<Song> _displayedSongs = [];
  bool _loading = true;
  bool _hasMoreSongs = false;
  bool _loadingMore = false;
  String? _error;
  
  // Timer para debounce en botones de play
  Timer? _playSongDebounce;
  Timer? _playAllDebounce;
  
  static const int _initialSongsLimit = 20;
  static const int _loadMoreSongsLimit = 20;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  @override
  void dispose() {
    // Cancelar timers de debounce al destruir el widget
    _playSongDebounce?.cancel();
    _playAllDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(playlistServiceProvider);
      final playlistId = widget.playlistId.trim();
      
      if (playlistId.isEmpty) {
        throw Exception('ID de playlist vacío');
      }
      
      // Obtener respuesta HTTP con retry
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => service.dio.get('/public/playlists/$playlistId'),
      );
      
      if (response.statusCode == 200) {
        // Manejar diferentes formatos de respuesta
        Map<String, dynamic>? playlistData;
        
        if (response.data is Map<String, dynamic>) {
          final rawData = response.data as Map<String, dynamic>;
          
          // Verificar que sea realmente una playlist
          final hasPlaylistFields = rawData.containsKey('id') && 
                                   (rawData.containsKey('userId') || 
                                    rawData.containsKey('name') || 
                                    rawData.containsKey('totalTracks') ||
                                    rawData.containsKey('playlist_songs'));
          
          if (hasPlaylistFields) {
            playlistData = rawData;
          } else if (rawData.containsKey('playlist') && rawData['playlist'] is Map<String, dynamic>) {
            playlistData = rawData['playlist'] as Map<String, dynamic>;
          } else if (rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>) {
            playlistData = rawData['data'] as Map<String, dynamic>;
          }
        }
        
        if (playlistData != null) {
          await _processPlaylistData(playlistData);
        } else {
          throw Exception('Formato de respuesta inválido: no se encontró información de playlist');
        }
      } else {
        throw Exception('Error al cargar playlist: código ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _processPlaylistData(Map<String, dynamic> jsonData) async {
    // Procesar JSON en isolate para evitar bloqueo del UI thread
    final playlist = await compute(_parsePlaylist, jsonData);
    
    if (!mounted) return;
    
    if (playlist == null) {
      setState(() {
        _error = 'Error al procesar playlist: datos inválidos o incompletos';
        _loading = false;
      });
      return;
    }

    // Verificar que la playlist tenga datos básicos
    if (playlist.id.isEmpty) {
      setState(() {
        _error = 'Error: Playlist sin ID válido';
        _loading = false;
      });
      return;
    }

    // Extraer canciones y aplicar paginación inicial
    final allSongs = playlist.songs;
    final initialSongs = allSongs.take(_initialSongsLimit).toList();
    final hasMore = allSongs.length > _initialSongsLimit;

    setState(() {
      _playlist = playlist;
      _displayedSongs = initialSongs;
      _hasMoreSongs = hasMore;
      _loading = false;
    });

    // Pre-cachear imagen de portada para mejor UX
    if (mounted && playlist.coverArtUrl != null && playlist.coverArtUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          precacheImage(
            CachedNetworkImageProvider(playlist.coverArtUrl!),
            context,
          ).catchError((_) {
            // Ignorar errores de pre-cache (imagen no disponible, etc.)
          });
        }
      });
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_loadingMore || !_hasMoreSongs || _playlist == null) return;

    setState(() => _loadingMore = true);

    // Simular delay mínimo para mejor UX
    await Future.delayed(const Duration(milliseconds: 100));

    final allSongs = _playlist!.songs;
    final currentCount = _displayedSongs.length;
    final nextBatch = allSongs.skip(currentCount).take(_loadMoreSongsLimit).toList();
    final hasMore = currentCount + nextBatch.length < allSongs.length;

    if (!mounted) return;

    setState(() {
      _displayedSongs = [..._displayedSongs, ...nextBatch];
      _hasMoreSongs = hasMore;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido para AutomaticKeepAliveClientMixin
    
    // Validar que el ID no esté vacío
    if (widget.playlistId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildNotFoundState(context, 'ID de playlist inválido'),
      );
    }

    if (_loading) {
      return _buildLoadingState(context);
    }

    if (_error != null || _playlist == null) {
      return _buildErrorState(context, _error ?? 'Playlist no encontrada');
    }

    final playlist = _playlist!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        child: CustomScrollView(
          cacheExtent: 800,
          physics: const FastScrollPhysics(),
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
                    OptimizedImage(
                      imageUrl: playlist.coverArtUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      isLargeCover: true,
                    ),
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
                          if (_playlist != null && _playlist!.songs.isNotEmpty) {
                            _onPlayAll(context, _playlist!.songs);
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
                          backgroundColor: NeumorphismTheme.coffeeMedium,
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

            // Lista de canciones con paginación
            if (_displayedSongs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: 24,
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
              SliverFixedExtentList(
                itemExtent: 80.0, // Altura fija conocida (mejora rendimiento)
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= _displayedSongs.length) {
                      // Botón "Ver más" al final
                      if (_hasMoreSongs) {
                        return _buildLoadMoreButton();
                      }
                      return null;
                    }
                    
                    final song = _displayedSongs[index];
                    return RepaintBoundary(
                      key: ValueKey('song_item_${song.id}'),
                      child: _SongListItem(
                        key: ValueKey(song.id),
                        song: song,
                        index: index + 1,
                        onTap: () => _onSongTap(context, song),
                        onPlay: () => _onPlaySong(context, song),
                      ),
                    );
                  },
                  childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                ),
              ),
            
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                height: 40,
                child: Center(
                  child: CircularProgressIndicator(
                    color: NeumorphismTheme.coffeeMedium,
                    strokeWidth: 2,
                  ),
                ),
              )
            : TextButton(
                onPressed: _loadMoreSongs,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Ver más canciones',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NeumorphismTheme.coffeeMedium,
                  ),
                ),
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
      body: Center(
        child: CircularProgressIndicator(
          color: NeumorphismTheme.coffeeMedium,
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
                backgroundColor: NeumorphismTheme.coffeeMedium,
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
    _onPlaySong(context, song);
  }

  void _onPlaySong(BuildContext context, Song song) async {
    // Debounce: cancelar acción anterior si existe
    _playSongDebounce?.cancel();
    
    // Crear nuevo timer con debounce
    _playSongDebounce = Timer(_debounceDuration, () async {
      if (!mounted) return;
      
      final container = ProviderScope.containerOf(context);
      final audioNotifier = container.read(unifiedAudioProviderFixed.notifier);
      final messenger = ScaffoldMessenger.of(context);
      
      try {
        // Validar que la canción tenga URL de archivo
        if (song.fileUrl == null || song.fileUrl!.isEmpty) {
          throw Exception('La canción "${song.title}" no tiene archivo de audio disponible');
        }
        
        // Validar que tengamos la playlist completa
        if (_playlist == null || _playlist!.songs.isEmpty) {
          throw Exception('No se puede reproducir: playlist no disponible');
        }
        
        // Usar provider unificado corregido - reproducir canción específica
        AppLogger.info('[PlaylistDetailScreen] 🎵 Reproduciendo desde playlist: ${song.title}');
        await audioNotifier.playSong(song);
        
        // TODO: Implementar contexto de playlist completa en el provider unificado
        
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Reproduciendo playlist desde "${song.title ?? "Canción"}"'),
            backgroundColor: NeumorphismTheme.coffeeMedium,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al reproducir: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _onPlayAll(BuildContext context, List<Song> songs) async {
    // Debounce: cancelar acción anterior si existe
    _playAllDebounce?.cancel();
    
    // Crear nuevo timer con debounce
    _playAllDebounce = Timer(_debounceDuration, () async {
      if (!mounted) return;
      
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
      final audioNotifier = container.read(unifiedAudioProviderFixed.notifier);
      
      try {
        // Usar provider unificado corregido - reproducir primera canción de la playlist
        if (songs.isNotEmpty) {
          AppLogger.info('[PlaylistDetailScreen] 🎵 Reproduciendo playlist completa desde el inicio');
          await audioNotifier.playSong(songs.first);
          
          // TODO: Implementar contexto de playlist completa en el provider unificado
        }
        
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Reproduciendo playlist con ${songs.length} canciones'),
            backgroundColor: NeumorphismTheme.coffeeMedium,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al reproducir playlist: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
                  placeholderColor: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
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
                color: NeumorphismTheme.coffeeMedium,
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
