import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import 'package:go_router/go_router.dart';
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
import '../../../core/utils/url_normalizer.dart';
import '../../song_detail/screens/song_detail_screen.dart';

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
  bool _hasLoadedOnce = false; // Flag para saber si ya se cargó una vez
  
  // Cache estático para mantener datos entre navegaciones (evita parpadeo)
  // Estructura: { playlistId: { 'playlist': ..., 'songs': ..., 'lastLoad': ... } }
  static final Map<String, Map<String, dynamic>> _playlistCache = {};
  
  // Flags ligeros para evitar taps múltiples sin añadir retardos artificiales
  bool _isPlaySongInProgress = false;
  bool _isPlayAllInProgress = false;
  
  static const int _initialSongsLimit = 20;
  static const int _loadMoreSongsLimit = 20;
  static const Duration _cacheValidDuration = Duration(minutes: 5); // Cache válido por 5 minutos
  
  // Cachear dimensiones de pantalla para evitar recálculos
  double? _cachedScreenWidth;
  double? _cachedDevicePixelRatio;
  
  // URLs normalizadas cacheadas (optimización: calcular una vez, no en cada build)
  String? _cachedCoverUrl;
  
  // Constantes para skeleton loaders
  static const Color _shimmerBaseColor = Color(0xFFE0E0E0);
  static const Color _shimmerHighlightColor = Color(0xFFF5F5F5);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // CRÍTICO: Intentar cargar desde caché estático primero (evita parpadeo)
    // Esto debe hacerse ANTES de establecer cualquier estado de loading
    final cachedData = _playlistCache[widget.playlistId];
    if (cachedData != null) {
      final lastLoadTime = cachedData['lastLoadTime'] as DateTime;
      if (!_shouldReloadCache(lastLoadTime)) {
        // Restaurar datos desde caché inmediatamente SIN setState
        // Esto evita cualquier parpadeo porque el estado se establece antes del primer render
        _playlist = cachedData['playlist'] as Playlist?;
        _displayedSongs = List<Song>.from(
          cachedData['displayedSongs'] as List,
        );
        _hasMoreSongs = cachedData['hasMoreSongs'] as bool;
        _hasLoadedOnce = true;
        _loading = false; // Establecer directamente sin setState (estamos en initState)
        
        // Normalizar URL de portada desde cache
        _normalizeCoverUrl();
        
        // Pre-cachear imagen de portada inmediatamente (síncrono para evitar parpadeo)
        if (_cachedCoverUrl != null && _cachedCoverUrl!.isNotEmpty) {
          // Precargar inmediatamente sin esperar al siguiente frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              precacheImage(
                CachedNetworkImageProvider(_cachedCoverUrl!),
                context,
              ).catchError((_) {
                // Ignorar errores de pre-cache
              });
            }
          });
        }
        
        // CRÍTICO: Salir temprano si tenemos cache válido para evitar cualquier operación adicional
        // Esto evita el parpadeo al retroceder
        return;
      } else {
        // Caché expirado, limpiar
        _playlistCache.remove(widget.playlistId);
      }
    }
    
    // Solo llegar aquí si NO hay cache válido
    // CRÍTICO: Establecer loading en true SOLO si NO tenemos cache válido
    // Esto evita que se muestre skeleton loader cuando volvemos atrás con cache
    _loading = true;
    _hasLoadedOnce = false;
    
    // Cargar datos desde el backend
    _loadPlaylist();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cachear dimensiones de pantalla una sola vez (optimización: evitar MediaQuery en cada build)
    // Asegurar que siempre tengamos valores cacheados
    if (_cachedScreenWidth == null || _cachedDevicePixelRatio == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedScreenWidth ??= mediaQuery.size.width;
      _cachedDevicePixelRatio ??= mediaQuery.devicePixelRatio;
    }
  }
  
  /// Normaliza URL de portada una sola vez (optimización de rendimiento)
  void _normalizeCoverUrl() {
    if (_playlist?.coverArtUrl != null && _playlist!.coverArtUrl!.isNotEmpty) {
      _cachedCoverUrl = UrlNormalizer.normalizeImageUrl(_playlist!.coverArtUrl);
    } else {
      _cachedCoverUrl = null;
    }
  }
  
  /// Widget skeleton para la portada de la playlist
  Widget _buildCoverSkeleton() {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      child: Container(
        width: double.infinity,
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
      ),
    );
  }
  
  /// Widget skeleton para el título de la playlist
  Widget _buildTitleSkeleton() {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      child: Container(
        height: 24,
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
  
  /// Widget skeleton para metadata (estadísticas)
  Widget _buildMetadataSkeleton() {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      child: Container(
        height: 16,
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
  
  /// Widget skeleton para botón "Reproducir todo"
  Widget _buildPlayAllButtonSkeleton() {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  /// Widget skeleton para fila de canción
  Widget _buildSongRowSkeleton() {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
  
  /// Verifica si el caché estático expiró
  bool _shouldReloadCache(DateTime cacheTime) {
    final now = DateTime.now();
    return now.difference(cacheTime) > _cacheValidDuration;
  }
  
  /// Limpiar caché antiguo periódicamente
  static void _cleanOldCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _playlistCache.forEach((key, value) {
      final lastLoad = value['lastLoadTime'] as DateTime?;
      if (lastLoad != null && now.difference(lastLoad) > _cacheValidDuration) {
        expiredKeys.add(key);
      }
    });
    
    // Limpiar solo si hay más de 10 entradas
    if (_playlistCache.length > 10) {
      for (final key in expiredKeys) {
        _playlistCache.remove(key);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    if (!mounted) return;
    
    // CRÍTICO: NO mostrar loading si tenemos datos del cache (evita parpadeo al volver)
    // Solo mostrar loading si realmente NO tenemos datos previos
    if (!_hasLoadedOnce && _displayedSongs.isEmpty && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    
    // Pequeño delay para permitir que el primer frame se renderice sin bloqueo
    if (!_hasLoadedOnce) {
      await Future.delayed(const Duration(milliseconds: 16)); // ~1 frame a 60fps
    }
    
    if (!mounted) return;

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

    // Normalizar URL de portada ANTES del setState (optimización)
    _playlist = playlist;
    _normalizeCoverUrl();
    
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _displayedSongs = initialSongs;
        _hasMoreSongs = hasMore;
        _loading = false;
        _hasLoadedOnce = true;
      });
    }

    // Guardar en caché estático para futuras navegaciones
    _playlistCache[widget.playlistId] = {
      'playlist': playlist,
      'displayedSongs': initialSongs,
      'hasMoreSongs': hasMore,
      'lastLoadTime': now,
      'coverUrl': _cachedCoverUrl, // Guardar URL normalizada en cache
    };
    
    // Limpiar caché antiguo periódicamente (solo si hay muchas entradas)
    if (_playlistCache.length > 10) {
      _cleanOldCache();
    }

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

    // CRÍTICO: Si tenemos cache válido, mostrar contenido inmediatamente sin verificaciones
    // Esto evita cualquier parpadeo al retroceder
    final hasValidCache = _hasLoadedOnce && 
                         _displayedSongs.isNotEmpty && 
                         _cachedCoverUrl != null &&
                         _playlist != null;
    
    if (hasValidCache) {
      // Tenemos cache válido - renderizar contenido inmediatamente SIN skeleton loaders
      return _buildContentFromCache(context);
    }
    
    // Solo llegar aquí si NO hay cache válido
    if (_error != null || (_playlist == null && !_loading)) {
      return _buildErrorState(context, _error ?? 'Playlist no encontrada');
    }

    final playlist = _playlist;
    
    // Usar dimensiones cacheadas (ya calculadas en didChangeDependencies) - NO recalcular en build
    final screenWidth = _cachedScreenWidth!;
    final devicePixelRatio = _cachedDevicePixelRatio!;

    return Scaffold(
      key: ValueKey('playlist_detail_scaffold_${widget.playlistId}'), // Key estable para evitar rebuilds
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        child: CustomScrollView(
          cacheExtent: 300, // Optimizado: reducir cache de scroll para mejor rendimiento
          physics: const FastScrollPhysics(),
          clipBehavior: Clip.none,
          slivers: [
            // App Bar con imagen de fondo - con skeleton loader
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: (_loading && _cachedCoverUrl == null)
                    ? _buildCoverSkeleton()
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          OptimizedImage(
                            key: ValueKey('playlist_cover_${playlist?.id ?? widget.playlistId}_${_cachedCoverUrl ?? 'null'}'),
                            imageUrl: _cachedCoverUrl ?? playlist?.coverArtUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            isLargeCover: true,
                            maxCacheWidth: (screenWidth * devicePixelRatio * 2).toInt(),
                            maxCacheHeight: (300 * devicePixelRatio).toInt(),
                            skipFade: _cachedCoverUrl != null, // Sin fade cuando hay cache (evita parpadeo)
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
                title: (_loading && _playlist == null)
                    ? _buildTitleSkeleton()
                    : Text(
                        (playlist?.name?.isNotEmpty == true) ? playlist!.name! : 'Playlist',
                        style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                      ),
                titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
              ),
            ),

            // Contenido - con skeleton loaders
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información de la playlist - con skeleton
                    if (_loading && _playlist == null)
                      _buildMetadataSkeleton()
                    else if (playlist != null && playlist.description != null && playlist.description!.isNotEmpty) ...[
                      Text(
                        playlist.description!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Estadísticas - con skeleton
                    if (_loading && _playlist == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildMetadataSkeleton(),
                      )
                    else if (playlist != null)
                      Row(
                        children: [
                          if (playlist.user != null) ...[
                            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              playlist.user?.firstName ?? 'Usuario',
                              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 16),
                          ],
                          const Icon(Icons.queue_music, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${playlist.totalSongs} canciones',
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            playlist.durationFormatted,
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Botón de reproducir todo - con skeleton
                    if (_loading && _playlist == null)
                      _buildPlayAllButtonSkeleton()
                    else if (playlist != null && playlist.songs.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                NeumorphismTheme.coffeeMedium,
                                NeumorphismTheme.coffeeDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (_playlist != null && _playlist!.songs.isNotEmpty) {
                                  _onPlayAll(context, _playlist!.songs);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Reproducir todo',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Título de canciones
                    Text(
                      'Canciones',
                      style: AppTextStyles.sectionTitle,
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Lista de canciones con paginación - con skeleton loaders
            if (_loading && _displayedSongs.isEmpty)
              // Mostrar skeleton loaders mientras carga (solo si NO hay cache)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildSongRowSkeleton(),
                  childCount: 5, // Mostrar 5 skeletons
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                ),
              )
            else if (_displayedSongs.isEmpty)
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
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[600]),
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
                    if (index >= _displayedSongs.length) {
                      // Botón "Ver más" al final
                      if (_hasMoreSongs) {
                        return _buildLoadMoreButton();
                      }
                      return null;
                    }
                    
                    // Variables locales para evitar accesos repetidos
                    final song = _displayedSongs[index];
                    final songIndex = index + 1;
                    
                    return RepaintBoundary(
                      key: ValueKey('song_item_${song.id}'),
                      child: _SongListItem(
                        key: ValueKey(song.id),
                        song: song,
                        index: songIndex,
                        onTap: () => _onSongTap(context, song),
                        onPlay: () => _onPlaySong(context, song),
                      ),
                    );
                  },
                  childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false, // Ya agregamos RepaintBoundary manualmente
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
                  style: AppTextStyles.bodyMedium.copyWith(
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
              style: AppTextStyles.titleMedium.copyWith(color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              'La playlist que buscas no existe o fue eliminada',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
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
              style: AppTextStyles.titleMedium.copyWith(color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[600]),
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
                style: AppTextStyles.bodyMedium.copyWith(
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
    // Navegar a la pantalla de detalles de la canción
    SongDetailScreen.navigateToSong(context, song);
  }

  void _onPlaySong(BuildContext context, Song song) async {
    if (!mounted || _isPlaySongInProgress) return;

    _isPlaySongInProgress = true;

    final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
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
    } finally {
      _isPlaySongInProgress = false;
    }
  }

  void _onPlayAll(BuildContext context, List<Song> songs) async {
    if (!mounted || _isPlayAllInProgress) return;

    _isPlayAllInProgress = true;

    final messenger = ScaffoldMessenger.of(context);

    if (songs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No hay canciones para reproducir'),
          backgroundColor: Colors.orange,
        ),
      );
      _isPlayAllInProgress = false;
      return;
    }

    final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
    
    try {
      // Usar provider unificado corregido - reproducir primera canción de la playlist
      AppLogger.info('[PlaylistDetailScreen] 🎵 Reproduciendo playlist completa desde el inicio');
      await audioNotifier.playSong(songs.first);
      
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
    } finally {
      _isPlayAllInProgress = false;
    }
  }

  /// Construir contenido desde cache (sin skeleton loaders)
  Widget _buildContentFromCache(BuildContext context) {
    final playlist = _playlist!;
    final screenWidth = _cachedScreenWidth!;
    final devicePixelRatio = _cachedDevicePixelRatio!;

    return Scaffold(
      key: ValueKey('playlist_detail_scaffold_${widget.playlistId}'),
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        child: CustomScrollView(
          cacheExtent: 300,
          physics: const FastScrollPhysics(),
          clipBehavior: Clip.none,
          slivers: [
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
                      key: ValueKey('playlist_cover_${playlist.id}_${_cachedCoverUrl ?? 'null'}'),
                      imageUrl: _cachedCoverUrl ?? playlist.coverArtUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      isLargeCover: true,
                      maxCacheWidth: (screenWidth * devicePixelRatio * 2).toInt(),
                      maxCacheHeight: (300 * devicePixelRatio).toInt(),
                      skipFade: true, // Sin fade cuando hay cache (evita parpadeo al retroceder)
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
                  style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                ),
                titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (playlist.description != null && playlist.description!.isNotEmpty) ...[
                      Text(
                        playlist.description!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        if (playlist.user != null) ...[
                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            playlist.user?.firstName ?? 'Usuario',
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                        ],
                        const Icon(Icons.queue_music, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${playlist.totalSongs} canciones',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          playlist.durationFormatted,
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (playlist.songs.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                NeumorphismTheme.coffeeMedium,
                                NeumorphismTheme.coffeeDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (_playlist != null && _playlist!.songs.isNotEmpty) {
                                  _onPlayAll(context, _playlist!.songs);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      'Reproducir todo',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text('Canciones', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _displayedSongs.length) {
                    if (_hasMoreSongs) {
                      return _buildLoadMoreButton();
                    }
                    return null;
                  }
                  final song = _displayedSongs[index];
                  final songIndex = index + 1;
                  return RepaintBoundary(
                    key: ValueKey('song_item_${song.id}'),
                    child: _SongListItem(
                      key: ValueKey(song.id),
                      song: song,
                      index: songIndex,
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
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeumorphismTheme.surface.withValues(alpha: 0.8),
            NeumorphismTheme.beigeMedium.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(-2, -2),
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
                // Número de posición
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Portada con efecto de elevación - Hero removido para mejor rendimiento
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
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            width: 64,
                            height: 64,
                            memCacheWidth: 128,
                            memCacheHeight: 128,
                            fadeInDuration: const Duration(milliseconds: 200),
                            fadeOutDuration: const Duration(milliseconds: 100),
                            placeholder: (context, url) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    NeumorphismTheme.coffeeMedium,
                                    NeumorphismTheme.coffeeDark,
                                  ],
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    NeumorphismTheme.coffeeMedium,
                                    NeumorphismTheme.coffeeDark,
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  NeumorphismTheme.coffeeMedium,
                                  NeumorphismTheme.coffeeDark,
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Información de la canción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title ?? 'Canción sin título',
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
                              _getArtistName(song),
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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Duración
                Text(
                  song.durationFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NeumorphismTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                // Botón de play/pause optimizado profesionalmente (estilo Spotify)
                Consumer(
                  builder: (context, ref, child) {
                    // Usar select para escuchar solo los cambios relevantes
                    final currentSong = ref.watch(
                      unifiedAudioProviderFixed.select((state) => state.currentSong),
                    );
                    final isPlaying = ref.watch(
                      unifiedAudioProviderFixed.select((state) => state.isPlaying),
                    );
                    final isCurrentSong = currentSong?.id == song.id;
                    final showPause = isCurrentSong && isPlaying;
                    
                    return RepaintBoundary(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              NeumorphismTheme.coffeeMedium,
                              NeumorphismTheme.coffeeDark,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onPlay,
                            borderRadius: BorderRadius.circular(22),
                            child: Center(
                              child: Icon(
                                showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
