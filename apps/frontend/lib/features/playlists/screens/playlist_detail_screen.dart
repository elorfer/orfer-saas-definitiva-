import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neumorphism_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/playlist_provider.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/utils/data_normalizer.dart';
import '../../../core/utils/retry_handler.dart';
import '../../../core/utils/number_formatter.dart';

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
  bool _hasMoreSongs = false;
  bool _loadingMore = false;
  bool _hasLoadedOnce = false; // Flag para saber si ya se cargó una vez
  String? _error;
  
  // Timer para debounce solo en "Reproducir todo" (mantuvo para evitar múltiples toques)
  Timer? _playAllDebounce;
  
  static const int _initialSongsLimit = 20;
  static const int _loadMoreSongsLimit = 20;
  static const Duration _debounceDuration = Duration(milliseconds: 300);
  
  // ✅ Cache estático para mantener datos entre navegaciones (evita parpadeo)
  // Estructura: { playlistId: { 'playlist': Playlist, 'displayedSongs': List<Song>, 'lastLoad': DateTime } }
  static final Map<String, Map<String, dynamic>> _playlistCache = {};
  static const Duration _cacheExpiration = Duration(minutes: 10); // Cache válido por 10 minutos

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // ✅ Cargar desde caché inmediatamente en el siguiente microtask (más rápido)
    scheduleMicrotask(() {
      if (mounted) {
        _loadFromCache();
      }
    });
    // Cargar datos en el siguiente frame para permitir que el primer frame se renderice
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPlaylist();
      }
    });
  }

  @override
  void dispose() {
    // Cancelar timers de debounce al destruir el widget
    _playAllDebounce?.cancel();
    super.dispose();
  }

  // ✅ Cargar datos desde caché si están disponibles
  void _loadFromCache() {
    final cachedData = _playlistCache[widget.playlistId];
    if (cachedData != null) {
      final lastLoad = cachedData['lastLoad'] as DateTime?;
      if (lastLoad != null && DateTime.now().difference(lastLoad) < _cacheExpiration) {
        // Cache válido, cargar datos inmediatamente
        final cachedPlaylist = cachedData['playlist'] as Playlist?;
        final cachedSongs = cachedData['displayedSongs'] as List<Song>?;
        final cachedHasMore = cachedData['hasMoreSongs'] as bool? ?? false;
        
        if (cachedPlaylist != null && cachedSongs != null) {
          setState(() {
            _playlist = cachedPlaylist;
            _displayedSongs = List<Song>.from(cachedSongs);
            _hasMoreSongs = cachedHasMore;
            _hasLoadedOnce = true; // NO mostrar loading si tenemos datos en caché
          });
        }
      } else {
        // Cache expirado, limpiar
        _playlistCache.remove(widget.playlistId);
      }
    }
  }

  Future<void> _loadPlaylist() async {
    if (!mounted) return;
    
    // Limpiar error al iniciar carga
    if (!_hasLoadedOnce && mounted) {
      setState(() {
        _error = null;
      });
    }

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
      });
    }
  }

  Future<void> _processPlaylistData(Map<String, dynamic> jsonData) async {
    // ✅ OPTIMIZACIÓN: Para JSON pequeños, procesar directamente (más rápido)
    // Solo usar isolate si el JSON es grande (más de ~100KB estimado)
    final jsonString = jsonData.toString();
    final isLargeJson = jsonString.length > 100000; // ~100KB
    
    final Playlist? playlist;
    if (isLargeJson) {
      // Para JSON grandes, usar isolate para evitar bloqueo
      playlist = await compute(_parsePlaylist, jsonData);
    } else {
      // Para JSON pequeños, procesar directamente (más rápido, sin overhead de isolate)
      playlist = _parsePlaylist(jsonData);
    }
    
    if (!mounted) return;
    
    if (playlist == null) {
      setState(() {
        _error = 'Error al procesar playlist: datos inválidos o incompletos';
      });
      return;
    }

    // Verificar que la playlist tenga datos básicos
    if (playlist.id.isEmpty) {
      setState(() {
        _error = 'Error: Playlist sin ID válido';
      });
      return;
    }

    // Extraer canciones y aplicar paginación inicial
    final allSongs = playlist.songs;
    final initialSongs = allSongs.take(_initialSongsLimit).toList();
    final hasMore = allSongs.length > _initialSongsLimit;

    final now = DateTime.now();
    setState(() {
      _playlist = playlist;
      _displayedSongs = initialSongs;
      _hasMoreSongs = hasMore;
      _hasLoadedOnce = true;
    });
    
    // ✅ Guardar en caché estático para futuras navegaciones
    _playlistCache[widget.playlistId] = {
      'playlist': playlist,
      'displayedSongs': List<Song>.from(initialSongs),
      'hasMoreSongs': hasMore,
      'lastLoad': now,
    };

    // Pre-cachear imagen de portada para mejor UX
    final coverUrl = playlist.coverArtUrl;
    if (mounted && coverUrl != null && coverUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          precacheImage(
            CachedNetworkImageProvider(coverUrl),
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

    // ✅ Permitir que el frame se renderice antes de procesar más datos
    await Future.microtask(() {});

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

    if (_error != null || (_playlist == null && _hasLoadedOnce)) {
      return _buildErrorState(context, _error ?? 'Playlist no encontrada');
    }

    // Si no ha cargado, mostrar skeleton
    if (!_hasLoadedOnce || _playlist == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: true,
          child: CustomScrollView(
            // 🔥 OPTIMIZADO: cacheExtent reducido para mejor rendimiento con grandes listas
            cacheExtent: 400, // Reducido de 800 a 400 para mejor rendimiento
            physics: const FastScrollPhysics(), // Física optimizada para scroll rápido
            slivers: [
              _buildAppBarSkeleton(),
              _buildContentSkeleton(),
              _buildSongsSkeleton(),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 120),
              ),
            ],
          ),
        ),
      );
    }

    final playlist = _playlist!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        child: CustomScrollView(
          // 🔥 OPTIMIZADO: cacheExtent reducido para mejor rendimiento con grandes listas
          // Mantiene solo ~10 items fuera de vista (800px / 80px por item)
          cacheExtent: 400, // Reducido de 800 a 400 para mejor rendimiento
          physics: const FastScrollPhysics(), // Física optimizada para scroll rápido
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

                    // Botón de reproducir todo - con verificación de contextId
                    Consumer(
                      builder: (context, ref, child) {
                        final audioState = ref.watch(unifiedAudioProviderFixed);
                        final isSameContext = audioState.contextId == widget.playlistId &&
                                             audioState.playbackMode == PlaybackMode.fixedQueue;
                        final isPlaying = isSameContext && audioState.isPlaying;
                        
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_displayedSongs.isNotEmpty) {
                                _onPlayAll(context, _displayedSongs);
                              }
                            },
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
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
                        );
                      },
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

            // Lista de canciones con paginación - OPTIMIZADO para grandes volúmenes
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
                itemExtent: 80.0, // Altura fija conocida (mejora rendimiento significativamente)
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
                  // 🔥 OPTIMIZACIONES PARA GRANDES VOLÚMENES:
                  addAutomaticKeepAlives: false, // No mantener estado de items fuera de vista (ahorra memoria)
                  addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual (evita duplicación)
                  addSemanticIndexes: false, // Desactivar índices semánticos (mejor rendimiento)
                  // ⚠️ findChildIndexCallback removido - puede causar problemas con el orden de widgets
                ),
              ),
            
            // ✅ Padding inferior para que el mini player no tape la última canción
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
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

  // ✅ Skeleton loader para el SliverAppBar - OPTIMIZADO: Más liviano
  Widget _buildAppBarSkeleton() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
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
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[200]!,
            child: Container(
              color: Colors.grey[300],
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 72, bottom: 16),
                  child: Container(
                    width: 200,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Skeleton loader para el contenido - OPTIMIZADO: Más liviano
  Widget _buildContentSkeleton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Descripción skeleton - solo 2 líneas
            Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Estadísticas skeleton - simplificado
            Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.grey[100]!,
              child: Row(
                children: [
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Botón reproducir todo skeleton
            Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Título canciones skeleton
            Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 120,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ✅ Skeleton loader para la lista de canciones - OPTIMIZADO: Más liviano
  Widget _buildSongsSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeumorphismTheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Número skeleton
                Shimmer.fromColors(
                  baseColor: Colors.grey[200]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 32,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Portada skeleton
                Shimmer.fromColors(
                  baseColor: Colors.grey[200]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Información skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[200]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: double.infinity,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[200]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Botón play skeleton
                Shimmer.fromColors(
                  baseColor: Colors.grey[200]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          childCount: 5, // Reducido de 6 a 5 skeletons
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

  void _onPlaySong(BuildContext context, Song song) {
    // ✅ Reproducir en modo PLAYLIST (fixedQueue) para mantener la cola
    final container = ProviderScope.containerOf(context);
    final audioNotifier = container.read(unifiedAudioProviderFixed.notifier);
    
    // Usar onPressPlayAll para reproducir en modo playlist, empezando desde la canción seleccionada
    // Esto activa el modo fixedQueue y permite navegar por la playlist
    unawaited(audioNotifier.onPressPlayAll(
      song,
      widget.playlistId,
      allSongs: _displayedSongs,
    ));
  }

  void _onPlayAll(BuildContext context, List<Song> songs) {
    // Debounce: cancelar acción anterior si existe
    _playAllDebounce?.cancel();
    
    // Crear nuevo timer con debounce
    _playAllDebounce = Timer(_debounceDuration, () async {
      if (!mounted) return;
      
      // Filtrar solo canciones con fileUrl válido
      final validSongs = songs.where((s) => s.fileUrl != null && s.fileUrl!.isNotEmpty).toList();
      
      if (validSongs.isEmpty) {
        // No mostrar SnackBar - el usuario puede ver que no hay canciones disponibles
        return;
      }

      final container = ProviderScope.containerOf(context);
      final audioNotifier = container.read(unifiedAudioProviderFixed.notifier);
      
      try {
        // ✅ Usar onPressPlayAll() con contextId de la playlist
        await audioNotifier.onPressPlayAll(
          validSongs.first,
          widget.playlistId,
          allSongs: validSongs,
        );
        
        // SnackBar eliminado para mejor UX
      } catch (error) {
        // SnackBar de error también eliminado
      }
    });
  }
}

class _SongListItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ OPTIMIZACIÓN: Usar selectores separados para escuchar solo cambios relevantes
    final currentSongId = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong?.id),
    );
    final isPlaying = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlaying),
    );
    final isCurrentSong = currentSongId == song.id;
    final showPause = isCurrentSong && isPlaying;
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // Reducido de 12 a 10
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
                  // 🔥 OPTIMIZADO: Tamaños de cache reducidos para mejor rendimiento con muchas imágenes
                  maxCacheWidth: 112, // 2x el tamaño de visualización (56 * 2)
                  maxCacheHeight: 112,
                  useThumbnail: true, // Usar thumbnails cuando estén disponibles
                  skipFade: true, // Sin fade para mejor rendimiento en scroll rápido
                ),
              ),
            ),

            const SizedBox(width: 16),

            // ✅ TÍTULO Y ARTISTA - Máxima prioridad con todo el espacio disponible
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

            // ✅ Espacio antes de controles
            const Spacer(),

            // ✅ Botón de play/pause con duración y reproducciones debajo - Legible sin overflow
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Botón de play/pause - toggle si es la canción actual, reproducir si es otra
                // ✅ CORREGIDO: Usar playFromCard para activar modo algoritmo (no playlist)
                IconButton(
                  onPressed: () {
                    if (isCurrentSong && isPlaying) {
                      // Si es la canción actual y está reproduciéndose, pausar
                      ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
                    } else {
                      // ✅ Si es otra canción o está pausada, usar playFromCard para modo algoritmo
                      // Esto cancela el modo playlist si está activo y activa el algoritmo
                      ref.read(unifiedAudioProviderFixed.notifier).playFromCard(song);
                    }
                  },
                  icon: Icon(
                    showPause ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: NeumorphismTheme.coffeeMedium,
                    size: 36, // Reducido ligeramente para evitar overflow
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  iconSize: 36,
                ),
                // ✅ Duración y reproducciones debajo del botón - Tamaños legibles sin overflow
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Duración - Tamaño legible
                    Text(
                      song.durationFormatted,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                        height: 0.95, // Reducido ligeramente
                      ),
                    ),
                    // ✅ Reproducciones - Tamaño legible sin padding extra
                    Text(
                      '▶ ${NumberFormatter.format(song.totalStreams)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                        height: 0.95, // Reducido ligeramente
                      ),
                    ),
                  ],
                ),
              ],
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
