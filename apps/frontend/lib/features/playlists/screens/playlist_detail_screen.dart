import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neumorphism_theme.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/theme_provider.dart';
// OPTIMIZACIÓN: GoogleFonts removido, usando estilos constantes
import '../../../core/providers/playlist_provider.dart';
import '../../../core/providers/saved_playlists_provider.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/providers/playback_state.dart';
import '../../../core/providers/secondary_screens_scroll_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/data_normalizer.dart';
import '../../../core/utils/retry_handler.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/intersection_observer.dart';

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
  
  // 🔥 OPTIMIZACIÓN: ScrollController para precache dinámico de imágenes (como en Home)
  late final ScrollController _scrollController;
  
  // ✅ OPTIMIZACIÓN: Timer para debounce en _onScroll
  Timer? _scrollDebounceTimer;
  
  // 🔥 PERSISTENCIA: Guardar posición inicial para restaurar después de cargar datos
  double? _savedInitialScrollPosition;
  bool _hasRestoredInitialScroll = false;
  
  static const int _initialSongsLimit = 20;
  static const int _loadMoreSongsLimit = 10;
  static const Duration _debounceDuration = Duration(milliseconds: 180);
  
  // ✅ OPTIMIZACIÓN: Cache estático con límite de memoria para mantener datos entre navegaciones
  // Estructura: { playlistId: { 'playlist': Playlist, 'displayedSongs': List<Song>, 'lastLoad': DateTime } }
  static final Map<String, Map<String, dynamic>> _playlistCache = {};
  static const Duration _cacheExpiration = Duration(hours: 1); // Cache válido por 1 hora (aumentado para evitar refrescos)
  static const int _maxCacheSize = 5; // Máximo de 5 playlists en cache para evitar uso excesivo de memoria

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // ✅ OPTIMIZACIÓN: Cargar posición de scroll una sola vez
    final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
    final savedPosition = scrollNotifier.getScrollPosition('playlist_detail_${widget.playlistId}');
    final pageStoragePosition = PageStorage.of(context).readState(
      context, 
      identifier: PageStorageKey<String>('playlist_detail_scroll_${widget.playlistId}'),
    ) as double?;
    final initialPosition = savedPosition ?? pageStoragePosition ?? 0.0;
    
    // ✅ OPTIMIZACIÓN: Cargar desde cache SÍNCRONAMENTE una sola vez
    final cachedData = _playlistCache[widget.playlistId];
    bool hasValidCache = false;
    if (cachedData != null) {
      final lastLoad = cachedData['lastLoad'] as DateTime?;
      if (lastLoad != null && DateTime.now().difference(lastLoad) < _cacheExpiration) {
        final cachedPlaylist = cachedData['playlist'] as Playlist?;
        final cachedSongs = cachedData['displayedSongs'] as List<Song>?;
        final cachedHasMore = cachedData['hasMoreSongs'] as bool? ?? false;
        
        if (cachedPlaylist != null && cachedSongs != null) {
          hasValidCache = true;
          // Establecer datos ANTES de crear el ScrollController
          _playlist = cachedPlaylist;
          _displayedSongs = List<Song>.from(cachedSongs);
          _hasMoreSongs = cachedHasMore;
          _hasLoadedOnce = true;
        }
      }
    }
    
    // Inicializar ScrollController
    _scrollController = ScrollController(initialScrollOffset: 0.0);
    _savedInitialScrollPosition = initialPosition;
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_saveScrollPosition);
    
    // ✅ OPTIMIZACIÓN: Restaurar scroll solo una vez si hay cache y posición guardada
    if (hasValidCache && _playlist != null) {
      if (_savedInitialScrollPosition != null && _savedInitialScrollPosition! > 0) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _restoreScrollPosition();
        });
      }
      // ✅ OPTIMIZACIÓN: No recargar datos si hay cache válido - solo actualizar en background
      // Actualizar datos en background sin mostrar loading
      Future.microtask(() {
        if (mounted) {
          _loadPlaylist(); // Carga silenciosa para actualizar cache
        }
      });
    } else {
      // Si no hay cache, cargar datos después del frame inicial
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasLoadedOnce) {
          _loadPlaylist();
        }
        // Restaurar scroll después de cargar si hay posición guardada
        if (_savedInitialScrollPosition != null && _savedInitialScrollPosition! > 0) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _restoreScrollPosition();
          });
        }
      });
    }
  }
  
  /// 🔥 CRÍTICO: Restaurar posición del scroll después de que el contenido esté medido
  /// Este método verifica que el ScrollController tenga un maxScrollExtent válido
  /// antes de hacer jumpTo, evitando que la restauración falle silenciosamente
  /// OPTIMIZACIÓN: Agregado límite de reintentos para evitar loops infinitos
  int _restoreScrollAttempts = 0;
  static const int _maxRestoreAttempts = 5; // Máximo 5 intentos de restauración
  
  void _restoreScrollPosition() {
    if (!mounted || _hasRestoredInitialScroll) {
      _restoreScrollAttempts = 0; // Reset contador si ya se restauró
      return;
    }
    
    // 🔥 OPTIMIZACIÓN: Limitar intentos de restauración para evitar loops
    if (_restoreScrollAttempts >= _maxRestoreAttempts) {
      _restoreScrollAttempts = 0;
      return; // Abandonar restauración después de máximo intentos
    }
    
    _restoreScrollAttempts++;
    
    if (!_scrollController.hasClients) {
      // Si aún no tiene clients, esperar un frame más
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _restoreScrollPosition();
      });
      return;
    }
    
    // 🔥 CRÍTICO: Verificar que el contenido esté medido
    // Si maxScrollExtent es 0, el contenido aún no se ha medido
    if (_scrollController.position.maxScrollExtent <= 0) {
      // Esperar otro frame para que el contenido se mida
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _restoreScrollPosition();
      });
      return;
    }
    
    final savedPosition = _savedInitialScrollPosition;
    if (savedPosition != null && savedPosition > 0) {
      final currentOffset = _scrollController.offset;
      final maxExtent = _scrollController.position.maxScrollExtent;
      
      // Solo restaurar si:
      // 1. La posición guardada es válida (menor o igual al máximo)
      // 2. El scroll está cerca de 0 (no se ha movido manualmente)
      if (savedPosition <= maxExtent && currentOffset < 10) {
        // 🔥 OPTIMIZACIÓN: Usar animateTo en lugar de jumpTo para transición suave
        _scrollController.jumpTo(savedPosition);
        _hasRestoredInitialScroll = true;
        _restoreScrollAttempts = 0; // Reset contador al restaurar exitosamente
      } else {
        // Si la posición no es válida, resetear contador
        _restoreScrollAttempts = 0;
      }
    } else {
      // Si no hay posición guardada, resetear contador
      _restoreScrollAttempts = 0;
    }
  }

  /// 🔥 PERSISTENCIA: Guardar posición del scroll en Provider (persistente) y PageStorage (backup)
  void _saveScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final position = _scrollController.offset;
    if (position < 0) return;
    
    final screenKey = 'playlist_detail_${widget.playlistId}';
    
    // 🔥 PERSISTENCIA: Guardar en Provider (persistente incluso si el widget se destruye)
    final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
    scrollNotifier.saveScrollPosition(screenKey, position);
    
    // También guardar en PageStorage como backup
    try {
      PageStorage.of(context).writeState(
        context,
        position,
        identifier: PageStorageKey<String>('playlist_detail_scroll_${widget.playlistId}'),
      );
    } catch (e) {
      // Ignorar errores de PageStorage
    }
  }

  @override
  void dispose() {
    // Cancelar timers de debounce al destruir el widget
    _playAllDebounce?.cancel();
    _scrollDebounceTimer?.cancel();
    
    // 🔥 CRÍTICO: Guardar posición final antes de destruir (sin debounce)
    if (_scrollController.hasClients) {
      final finalPosition = _scrollController.offset;
      if (finalPosition >= 0) {
        final screenKey = 'playlist_detail_${widget.playlistId}';
        final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
        scrollNotifier.saveScrollPosition(screenKey, finalPosition);
      }
    }
    
    // 🔥 OPTIMIZACIÓN: Limpiar ScrollController
    _scrollController.removeListener(_onScroll);
    _scrollController.removeListener(_saveScrollPosition);
    _scrollController.dispose();
    
    // Reset contador de restauración
    _restoreScrollAttempts = 0;
    
    super.dispose();
  }
  
  
  /// 🔥 OPTIMIZACIÓN: Precargar imágenes visibles y detectar fin de scroll para paginación automática
  /// ✅ CORRECCIÓN: Agregado debounce para evitar ejecuciones excesivas
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients || _displayedSongs.isEmpty) return;
    
    // ⚡ PAGINACIÓN AUTOMÁTICA: Detectar si el usuario está cerca del final del scroll
    final position = _scrollController.position;
    final maxScrollExtent = position.maxScrollExtent;
    final currentOffset = position.pixels;
    
    // Cargar más cuando el usuario está a 200px del final
    if (maxScrollExtent > 0 && 
        currentOffset >= maxScrollExtent - 200 && 
        _hasMoreSongs && 
        !_loadingMore) {
      _loadMoreSongs();
    }
    
    // ✅ OPTIMIZACIÓN: Cancelar timer anterior si existe
    _scrollDebounceTimer?.cancel();
    
    // ✅ OPTIMIZACIÓN: Debounce de 300ms para evitar ejecuciones excesivas
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_scrollController.hasClients || _displayedSongs.isEmpty) return;
      
      try {
        // ⚡️ Rendimiento: para scroll fluido en listas grandes, omitimos precache intensivo aquí.
        // (Las imágenes ya se cachean vía OptimizedImage / cached_network_image.)
      } catch (e) {
        // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente para no bloquear la app
        debugPrint('[PlaylistDetailScreen] Error en _onScroll: $e');
      }
    });
  }

  // ✅ OPTIMIZACIÓN: Método removido - la carga de cache ahora se hace directamente en initState
  // Esto evita llamadas duplicadas y mejora el rendimiento

  Future<void> _loadPlaylist() async {
    if (!mounted) return;
    
    // ✅ OPTIMIZACIÓN: Solo limpiar error si realmente no hay datos cargados
    final isSilentUpdate = _hasLoadedOnce && _playlist != null;
    if (!isSilentUpdate && mounted) {
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
      
      // ✅ OPTIMIZACIÓN: Obtener respuesta HTTP con retry
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
          await _processPlaylistData(playlistData, isSilentUpdate: isSilentUpdate);
        } else {
          throw Exception('Formato de respuesta inválido: no se encontró información de playlist');
        }
      } else {
        throw Exception('Error al cargar playlist: código ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      // ✅ OPTIMIZACIÓN: Solo mostrar error si no hay datos cargados (no en actualizaciones silenciosas)
      if (!isSilentUpdate) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _processPlaylistData(Map<String, dynamic> jsonData, {bool isSilentUpdate = false}) async {
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
      if (!isSilentUpdate) {
        setState(() {
          _error = 'Error al procesar playlist: datos inválidos o incompletos';
        });
      }
      return;
    }

    // Verificar que la playlist tenga datos básicos
    if (playlist.id.isEmpty) {
      if (!isSilentUpdate) {
        setState(() {
          _error = 'Error: Playlist sin ID válido';
        });
      }
      return;
    }

    // ✅ OPTIMIZACIÓN: Si es actualización silenciosa y la playlist es la misma, solo actualizar cache sin setState
    if (isSilentUpdate && _playlist?.id == playlist.id) {
      // Solo actualizar cache sin rebuild de UI
      final now = DateTime.now();
      final allSongs = playlist.songs;
      final currentDisplayedCount = _displayedSongs.length;
      final initialSongs = allSongs.take(currentDisplayedCount > 0 ? currentDisplayedCount : _initialSongsLimit).toList();
      final hasMore = allSongs.length > initialSongs.length;
      
      // Actualizar cache sin setState
      _playlistCache[widget.playlistId] = {
        'playlist': playlist,
        'displayedSongs': List<Song>.from(initialSongs),
        'hasMoreSongs': hasMore,
        'lastLoad': now,
      };
      return;
    }

    // Extraer canciones y aplicar paginación inicial
    final allSongs = playlist.songs;
    final initialSongs = allSongs.take(_initialSongsLimit).toList();
    final hasMore = allSongs.length > _initialSongsLimit;

    final now = DateTime.now();
    
    // ✅ OPTIMIZACIÓN: Solo hacer setState si realmente hay cambios o es la primera carga
    if (!_hasLoadedOnce || _playlist?.id != playlist.id) {
      setState(() {
        _playlist = playlist;
        _displayedSongs = initialSongs;
        _hasMoreSongs = hasMore;
        _hasLoadedOnce = true;
      });
      
      // ✅ OPTIMIZACIÓN: Restaurar scroll solo en la primera carga
      if (!_hasRestoredInitialScroll && _savedInitialScrollPosition != null && _savedInitialScrollPosition! > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients && _displayedSongs.isNotEmpty) {
            final currentOffset = _scrollController.offset;
            if (currentOffset < 10) {
              _scrollController.jumpTo(_savedInitialScrollPosition!);
              _hasRestoredInitialScroll = true;
            }
          }
        });
      }
    }
    
    // ✅ OPTIMIZACIÓN: Guardar en caché estático con gestión de memoria
    _playlistCache.removeWhere((key, value) {
      final lastLoad = value['lastLoad'] as DateTime?;
      return lastLoad == null || DateTime.now().difference(lastLoad) >= _cacheExpiration;
    });
    
    if (_playlistCache.length >= _maxCacheSize && !_playlistCache.containsKey(widget.playlistId)) {
      final oldestKey = _playlistCache.keys.first;
      _playlistCache.remove(oldestKey);
    }
    
    _playlistCache[widget.playlistId] = {
      'playlist': playlist,
      'displayedSongs': List<Song>.from(initialSongs),
      'hasMoreSongs': hasMore,
      'lastLoad': now,
    };

    // ✅ OPTIMIZACIÓN: Pre-cachear imágenes solo si es la primera carga
    if (!isSilentUpdate && mounted) {
      final coverUrl = playlist.coverArtUrl;
      final initialImageUrls = <String?>[
        coverUrl,
        ...initialSongs.take(5).map((song) => song.coverArtUrl),
      ].where((url) => url != null && url.isNotEmpty).toList();
      
      if (initialImageUrls.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            LazyImageLoader.precacheInitialImages(
              imageUrls: initialImageUrls,
              context: context,
              count: initialImageUrls.length,
            );
          }
        });
      }
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_loadingMore || !_hasMoreSongs || _playlist == null) return;

    setState(() => _loadingMore = true);

    // ✅ OPTIMIZACIÓN: Procesar datos directamente sin microtask innecesario
    final allSongs = _playlist!.songs;
    final currentCount = _displayedSongs.length;
    final nextBatch = allSongs.skip(currentCount).take(_loadMoreSongsLimit).toList();
    final hasMore = currentCount + nextBatch.length < allSongs.length;

    if (!mounted) {
      setState(() => _loadingMore = false);
      return;
    }

    setState(() {
      _displayedSongs = [..._displayedSongs, ...nextBatch];
      _hasMoreSongs = hasMore;
      _loadingMore = false;
    });
    
    // ✅ OPTIMIZACIÓN: Actualizar cache con nuevas canciones mostradas
    if (_playlistCache.containsKey(widget.playlistId)) {
      _playlistCache[widget.playlistId] = {
        ..._playlistCache[widget.playlistId]!,
        'displayedSongs': List<Song>.from(_displayedSongs),
        'hasMoreSongs': hasMore,
      };
    }
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
        backgroundColor: NeumorphismTheme.background,
        body: SafeArea(
          bottom: true,
          child: CustomScrollView(
            key: PageStorageKey<String>('playlist_detail_scroll_${widget.playlistId}'),
            controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache dinámico
            // 🔥 OPTIMIZADO: cacheExtent reducido para mejor rendimiento con grandes listas
            cacheExtent: 400, // Reducido de 800 a 400 para mejor rendimiento
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ), // ✅ Scroll estilo iPhone (igual que Home)
            slivers: [
              _buildAppBarSkeleton(),
              _buildContentSkeleton(),
              _buildSongsSkeleton(),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 120),
              ),
            ],
          ), // Cierra CustomScrollView
        ),
      );
    }

    final playlist = _playlist!;

    // 🚀 Refresh on Theme Change
    ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: NeumorphismTheme.background, // 🚀 FIX: Dynamic Background
      body: SafeArea(
        bottom: true,
        child: CustomScrollView(
          key: PageStorageKey<String>('playlist_detail_scroll_${widget.playlistId}'),
          controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache dinámico
          // 🔥 OPTIMIZADO: cacheExtent ajustado para fluidez en gama media/baja
          // Mantiene ~4-5 ítems fuera de vista
          cacheExtent: 250,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ), // ✅ Scroll estilo iPhone (igual que Home)
          slivers: [
            // App Bar con imagen de fondo
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: NeumorphismTheme.isDark ? NeumorphismTheme.background : NeumorphismTheme.coffeeDark, // ✅ Fondo adaptativo: Background en Dark, Brown en Light
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back, 
                  color: NeumorphismTheme.isDark ? NeumorphismTheme.textPrimary : Colors.white
                ),
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
                      // Limitar decodificación para evitar imágenes enormes en SliverAppBar
                      maxCacheWidth: 1000,
                      maxCacheHeight: 750,
                      skipFade: true,
                      placeholderColor: NeumorphismTheme.beigeMedium.withValues(alpha: 0.2),
                      errorWidget: Container(
                        color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.25),
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.white70, size: 48),
                        ),
                      ),
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
                  // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: NeumorphismTheme.isDark ? NeumorphismTheme.textPrimary : Colors.white,
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
                        style: TextStyle(
                          fontSize: 16,
                          color: NeumorphismTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Estadísticas
                    Row(
                      children: [
                        if (playlist.user != null) ...[
                          Icon(Icons.person_outline, size: 16, color: NeumorphismTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            playlist.user?.firstName ?? 'Usuario',
                            style: TextStyle(
                              fontSize: 14,
                              color: NeumorphismTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Icon(Icons.queue_music, size: 16, color: NeumorphismTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${playlist.totalSongs} canciones',
                          style: TextStyle(
                            fontSize: 14,
                            color: NeumorphismTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.access_time, size: 16, color: NeumorphismTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          playlist.durationFormatted,
                          style: TextStyle(
                            fontSize: 14,
                            color: NeumorphismTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Botón de reproducir todo - con verificación de contextId
                    // ✅ OPTIMIZACIÓN: Usar select() para evitar rebuilds innecesarios
                      Consumer(
                        builder: (context, ref, child) {
                          final contextId = ref.watch(
                            unifiedAudioProviderFixed.select((state) => state.contextId),
                          );
                          final playbackMode = ref.watch(
                            unifiedAudioProviderFixed.select((state) => state.playbackMode),
                          );
                          final isPlaying = ref.watch(
                            unifiedAudioProviderFixed.select((state) => state.isPlaying),
                          );
                          final isSameContext = contextId == widget.playlistId &&
                                               playbackMode == PlaybackMode.fixedQueue;
                          final showPause = isSameContext && isPlaying;
                          
                          // Watch saved state
                          final savedState = ref.watch(savedPlaylistsProvider);
                          final isSaved = savedState.savedIds.contains(widget.playlistId);

                          return Row(
                            children: [
                              // Like Button
                              Container(
                                decoration: BoxDecoration(
                                  color: NeumorphismTheme.surface,
                                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                                  boxShadow: NeumorphismTheme.softShadow,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isSaved ? Colors.red : Colors.grey,
                                  ),
                                  onPressed: () {
                                    ref.read(savedPlaylistsProvider.notifier).toggleSave(playlist);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Play Button
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (_displayedSongs.isNotEmpty) {
                                        _onPlayAll(context, _displayedSongs);
                                      }
                                    },
                                    icon: Icon(
                                      showPause ? Icons.pause : Icons.play_arrow,
                                      color: NeumorphismTheme.isDark ? NeumorphismTheme.coffeeDark : Colors.white,
                                    ), 
                                    label: Text(
                                      'Reproducir todo',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: NeumorphismTheme.isDark ? NeumorphismTheme.coffeeDark : Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: NeumorphismTheme.isDark ? NeumorphismTheme.accent : NeumorphismTheme.coffeeMedium,
                                      foregroundColor: NeumorphismTheme.isDark ? NeumorphismTheme.coffeeDark : Colors.white, // Text/Icon color adaptation
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(12)),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    // Título de canciones
                    Text(
                      'Canciones',
                      // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: NeumorphismTheme.textPrimary,
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
                          // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverFixedExtentList(
                itemExtent: 80.0, // ✅ Altura fija conocida (mejora rendimiento significativamente)
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
                        onPlay: () => _playFromCardAlgorithm(context, song),
                      ),
                    );
                  },
                  childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
                  // 🔥 OPTIMIZACIONES PARA GRANDES VOLÚMENES:
                  addAutomaticKeepAlives: false, // No mantener estado de items fuera de vista (ahorra memoria)
                  addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual (evita duplicación)
                  addSemanticIndexes: false, // Desactivar índices semánticos (mejor rendimiento)
                ),
              ),
            
            // ✅ Padding inferior para que el mini player no tape la última canción
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
            ),
          ],
        ), // Cierra CustomScrollView
      ), // Cierra SafeArea
    ); // Cierra Scaffold
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: _loadingMore
            ? SizedBox(
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
                  // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                  style: TextStyle(
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
              // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La playlist que buscas no existe o fue eliminada',
              // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
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
        // ⚡ GAMA BAJA: Skeleton estático sin Shimmer
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                NeumorphismTheme.coffeeMedium.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 72, bottom: 16),
              child: Container(
                width: 200,
                height: 24,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ⚡ GAMA BAJA: Skeleton estático sin Shimmer
  Widget _buildContentSkeleton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Descripción skeleton
            Container(
              width: double.infinity,
              height: 16,
              decoration: BoxDecoration(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 150,
              height: 16,
              decoration: BoxDecoration(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            // Estadísticas skeleton
            Row(
              children: [
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Botón reproducir todo skeleton
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            // Título canciones skeleton
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ⚡ GAMA BAJA: Skeleton estático sin Shimmer ni boxShadow
  Widget _buildSongsSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Row(
              children: [
                // Número skeleton
                Container(
                  width: 28,
                  height: 16,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
                const SizedBox(width: 12),
                // Portada skeleton
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                // Información skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Botón play skeleton
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          childCount: 4, // ⚡ Reducido a 4 skeletons
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
              // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
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
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ),
              child: const Text(
                'Volver',
                // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                style: TextStyle(
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
    _playFromCardAlgorithm(context, song);
  }

  /// ⚡ OPTIMIZADO: Reproduce una canción individual en modo algoritmo (igual que tocar la tarjeta).
  /// Validación rápida y reproducción sin bloquear la UI
  Future<void> _playFromCardAlgorithm(BuildContext context, Song song) async {
    // ⚡ OPTIMIZACIÓN: Validación rápida usando isValidForPlayback (ya valida fileUrl)
    if (!song.isValidForPlayback) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: La canción "${song.title ?? 'Sin título'}" no tiene URL de archivo válida'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2), // Reducido de 3 a 2 segundos
          ),
        );
      }
      return;
    }

    try {
      // ⚡ OPTIMIZACIÓN: Iniciar reproducción de forma asíncrona sin bloquear la UI
      // El provider maneja la reproducción y los errores se capturan en el catchError
      ref.read(unifiedAudioProviderFixed.notifier).playFromCard(
        song,
        useAlgorithm: true,
      ).catchError((e, stackTrace) {
        debugPrint('❌ [PlaylistDetailScreen] Error al reproducir canción: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al reproducir "${song.title ?? 'la canción'}": ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3), // Reducido de 4 a 3 segundos
            ),
          );
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ [PlaylistDetailScreen] Error al reproducir canción: $e');
      debugPrint('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir "${song.title ?? 'la canción'}": ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onPlayAll(BuildContext context, List<Song> songs) {
    // Debounce: cancelar acción anterior si existe
    _playAllDebounce?.cancel();
    
    // Crear nuevo timer con debounce
    _playAllDebounce = Timer(_debounceDuration, () async {
      if (!mounted) return;
      
      // Filtrar canciones reproducibles (URL válida, duración mínima, no placeholders)
      final validSongs = songs
          .where((s) => s.isValidForPlayback)
          .toList();
      
      if (validSongs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No hay canciones reproducibles en esta playlist'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
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
  final Future<void> Function()? onPlay;

  // OPTIMIZACIÓN: Estilos constantes para evitar recreación por ítem
  // NOTA: Colores dinámicos se manejan en el build() para soportar Dark Mode
  static const TextStyle _indexStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    // color se asigna dinámicamente
  );
  
  static const TextStyle _baseTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    // color se asigna dinámicamente
  );
  
  static const TextStyle _baseSubtitleStyle = TextStyle(
    fontSize: 14,
    // color se asigna dinámicamente
  );
  
  static const TextStyle _durationStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 0.95,
     // color se asigna dinámicamente
  );
  
  static const TextStyle _streamsStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 0.95,
     // color se asigna dinámicamente
  );

  const _SongListItem({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔥 Reducir rebuilds: solo observar cambios relevantes
    final isCurrent = ref.watch(
      unifiedAudioProviderFixed.select((s) => s.currentSong?.id == song.id),
    );
    final isPlaying = ref.watch(
      unifiedAudioProviderFixed.select((s) => s.isPlaying),
    );
    final playIcon = Icon(
      isCurrent && isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
      color: NeumorphismTheme.coffeeMedium,
      size: 36,
    );
    
    // Colores dinámicos
    final indexColor = NeumorphismTheme.textSecondary;
    final titleColor = NeumorphismTheme.textPrimary;
    final subtitleColor = NeumorphismTheme.textSecondary;
    final metaColor = NeumorphismTheme.textLight;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            // Número de posición
            SizedBox(
              width: 32,
              child: Text(
                '$index',
                style: _indexStyle.copyWith(color: indexColor),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(width: 16),

            // Portada de la canción
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                // ⚡ GAMA BAJA: Sin boxShadow
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
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
                  lazyLoad: true, // ✅ Lazy loading con IntersectionObserver
                  visibilityThreshold: 0.25, // Cargar más cerca del viewport para menos descargas anticipadas
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
                    style: _baseTitleStyle.copyWith(color: titleColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getArtistName(song),
                    style: _baseSubtitleStyle.copyWith(color: subtitleColor),
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
                // ✅ Botón de play - SIEMPRE se comporta como tocar la tarjeta (usa onPressPlayAll para modo playlist)
                IconButton(
                  onPressed: onPlay,
                  icon: playIcon,
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
                      style: _durationStyle.copyWith(color: metaColor),
                    ),
                    // ✅ Reproducciones - Tamaño legible sin padding extra
                    Text(
                      '▶ ${NumberFormatter.format(song.totalStreams)}',
                      style: _streamsStyle.copyWith(color: metaColor),
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

/// Mini ecualizador ligero (3 barras) para indicar canción en reproducción.
class MiniEqualizer extends StatefulWidget {
  final bool active;
  final double size;
  final Color color;

  const MiniEqualizer({
    super.key,
    required this.active,
    this.size = 16,
    this.color = Colors.greenAccent,
  });

  @override
  State<MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<MiniEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant MiniEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bars = List.generate(3, (i) => i * 0.25); // desfases
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.map((phase) {
          return Expanded(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = (_c.value + phase) % 1;
                final h = lerpDouble(
                  widget.size * 0.25,
                  widget.size,
                  Curves.easeInOut.transform(t),
                )!;
                final height = widget.active ? h : widget.size * 0.35;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: height,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
