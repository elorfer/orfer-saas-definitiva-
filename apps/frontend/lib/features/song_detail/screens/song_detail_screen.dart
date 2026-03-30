import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/providers/secondary_screens_scroll_provider.dart';
import '../../../core/providers/theme_provider.dart'; // 🚀 Importar themeProvider
import '../widgets/artist_songs_list.dart';
import '../providers/song_detail_provider.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/favorite_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../artists/models/artist.dart';
import '../../../core/services/http_cache_service.dart' as cache_service;
import '../../artists/services/artists_api.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/data_normalizer.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/providers/offline_manager_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart'; // For User/SubscriptionStatus

/// Pantalla de detalle de canción estilo Spotify con diseño moderno
class SongDetailScreen extends ConsumerStatefulWidget {
  final Song song;

  const SongDetailScreen({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
  
  // Variables estáticas para prevenir múltiples llamadas simultáneas (sin debounce para respuesta instantánea)
  static String? _lastNavigatedSongId;
  static DateTime? _lastNavigationTime;
  static const Duration _minNavigationInterval = Duration(milliseconds: 100); // Solo prevenir taps muy rápidos (<100ms)
  
  /// Función estática helper para navegar a una canción desde cualquier contexto
  /// Usa go_router para navegación consistente y previene múltiples instancias
  /// 
  /// Optimizado para navegación INSTANTÁNEA - sin debounce, solo previene taps accidentales muy rápidos
  /// Precarga imágenes para evitar flashes al regresar
  /// 
  /// Ejemplo de uso:
  /// ```dart
  /// SongDetailScreen.navigateToSong(context, song);
  /// ```
  static void navigateToSong(BuildContext context, Song song) {
    if (!context.mounted) return;
    
    final now = DateTime.now();
    
    // Solo prevenir taps accidentales muy rápidos (<100ms) de la misma canción
    if (_lastNavigatedSongId == song.id && 
        _lastNavigationTime != null &&
        now.difference(_lastNavigationTime!).inMilliseconds < _minNavigationInterval.inMilliseconds) {
      return; // Ignorar tap accidental muy rápido
    }
    
    _lastNavigatedSongId = song.id;
    _lastNavigationTime = now;
    
    // ✅ Pre-cargar imagen de portada para evitar flash al regresar
    // OPTIMIZADO: Usar addPostFrameCallback para precargar inmediatamente después del primer frame
    if (song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty) {
      final coverUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl);
      if (coverUrl != null && coverUrl.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            precacheImage(
              CachedNetworkImageProvider(coverUrl),
              context,
            ).catchError((_) {
              // Ignorar errores de pre-cache
            });
          }
        });
      }
    }
    
    // Navegación INSTANTÁNEA - sin debounce, sin esperas
    try {
      final router = GoRouter.of(context);
      final targetLocation = '/song/${song.id}';
      final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
      
      // Si ya estamos en esa pantalla, no hacer nada
      if (currentLocation == targetLocation) {
        return; // Ya estamos ahí, no hacer nada
      }
      
      // Navegación directa e instantánea - usar push directamente para mejor rendimiento
      // go_router maneja automáticamente el stack y las transiciones están optimizadas en app_router.dart
      context.push(targetLocation, extra: song);
    } catch (e) {
      // Error silencioso - go_router maneja los errores internamente
      // Fallback: intentar navegación simple
      try {
        if (context.mounted) {
          context.push('/song/${song.id}', extra: song);
        }
      } catch (fallbackError) {
        // Error silencioso - no bloquear la UI
      }
    }
  }
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> 
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  Song? _loadedSong; // Canción cargada desde el backend
  bool _isLoadingSong = false; // Indicador de carga
  
  // 🔥 PERSISTENCIA: Guardar posición inicial para restaurar después del primer frame
  double? _savedInitialScrollPosition;
  bool _hasRestoredInitialScroll = false;
  
  @override
  bool get wantKeepAlive => true; // Mantener estado al navegar (evita parpadeo)
  
  // URLs normalizadas cacheadas (optimización: calcular una vez, no en cada build)
  String? _cachedCoverUrl;
  String? _cachedArtistAvatarUrl;
  double? _cachedImageSize; // Cachear tamaño de imagen para evitar MediaQuery en cada build
  double? _cachedDevicePixelRatio; // Cachear devicePixelRatio para evitar MediaQuery en cada build
  
  // Estados para controlar la carga de imágenes (evita parpadeo)
  bool _coverImageReady = false;
  bool _artistAvatarReady = false;
  bool _isLoadingArtistAvatar = false; // 🆕 Estado para skeleton loader del avatar
  
  // Cache estático para mantener datos entre navegaciones (evita recargas innecesarias)
  // Estructura: { songId: { 'song': Song, 'lastLoad': DateTime } }
  static final Map<String, Map<String, dynamic>> _songCache = {};
  
  // Constantes de configuración del cache
  static const Duration _cacheValidDuration = Duration(minutes: 10); // Cache válido por 10 minutos
  static const int _maxCacheSize = 20; // Máximo de 20 canciones en cache

  @override
  void initState() {
    super.initState();
    
    // 🔥 PERSISTENCIA: Restaurar scroll position desde Provider (más robusto que PageStorage)
    final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
    final savedPosition = scrollNotifier.getScrollPosition('song_detail_${widget.song.id}');
    
    // También intentar desde PageStorage como backup
    final pageStorage = PageStorage.maybeOf(context);
    final pageStoragePosition = pageStorage?.readState(
      context, 
      identifier: PageStorageKey<String>('song_detail_scroll_${widget.song.id}')
    ) as double?;
    
    // Usar la posición del provider si existe, sino la de PageStorage
    final initialPosition = savedPosition ?? pageStoragePosition ?? 0.0;
    // 🔥 CRÍTICO: Inicializar en 0 y restaurar DESPUÉS de que el contenido esté medido
    _scrollController = ScrollController(initialScrollOffset: 0.0);
    
    // Guardar la posición para restaurarla después
    _savedInitialScrollPosition = initialPosition;
    
    // 🔥 CRÍTICO: Restaurar posición después del primer frame usando SchedulerBinding
    // Esto garantiza que el contenido ya esté medido y pintado
    if (initialPosition > 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _restoreScrollPosition();
      });
    }
    
    // 🔥 PERSISTENCIA: Guardar scroll position cuando cambie
    _scrollController.addListener(_saveScrollPosition);
    
    // CRÍTICO: Intentar cargar desde cache PRIMERO antes de normalizar URLs
    // Esto evita que _normalizeUrls() sobrescriba el _cachedCoverUrl del cache
    _loadFromCache();
    
    // Solo normalizar URLs desde widget.song si NO tenemos cache válido
    // Si tenemos cache válido, _loadFromCache() ya estableció _cachedCoverUrl correctamente
    if (_loadedSong == null) {
      // Normalizar URLs una sola vez al inicio (optimización)
      _normalizeUrls();
    }
    
    // Solo cargar desde backend si NO tenemos datos del cache
    // Si tenemos cache válido, _loadFromCache() ya estableció _isLoadingSong = false
    if (_loadedSong == null) {
      // Cargar la canción completa desde el backend si no está en cache o expiró
      // Usar Future.microtask para no bloquear el primer render y permitir navegación instantánea
      Future.microtask(() {
        if (mounted && _loadedSong == null) {
          // Usar un pequeño delay para permitir que la transición de navegación se complete primero
          // Esto hace que la navegación se sienta instantánea mientras los datos se cargan en segundo plano
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _loadedSong == null) {
              _loadSongFromBackend();
            }
          });
        }
      });
    }
  }
  
  /// Carga la canción desde el cache si está disponible y no ha expirado
  /// CRÍTICO: Este método debe ejecutarse en initState() ANTES de cualquier render
  /// para evitar parpadeo al volver atrás
  void _loadFromCache() {
    final cachedData = _songCache[widget.song.id];
    if (cachedData != null) {
      final lastLoadTime = cachedData['lastLoad'] as DateTime;
      final cachedSong = cachedData['song'] as Song;
      
      // Verificar si el cache es válido (no expirado)
      if (DateTime.now().difference(lastLoadTime) < _cacheValidDuration) {
        // Cache válido, usar datos cacheados inmediatamente SIN setState
        // Esto evita cualquier parpadeo porque el estado se establece antes del primer render
        _loadedSong = cachedSong;
        _updateNormalizedUrls(cachedSong);
        _isLoadingSong = false; // CRÍTICO: Establecer loading en false ANTES del primer render
        
        // CRÍTICO: Verificar si las imágenes están realmente en cache ANTES de marcarlas como listas
        // Esto evita parpadeo al retroceder
        _checkAndPrecacheImages();
        
        // CRÍTICO: Salir temprano si tenemos cache válido para evitar cualquier operación adicional
        // Esto evita el parpadeo al retroceder
        return;
      } else {
        // Cache expirado, limpiar
        _songCache.remove(widget.song.id);
      }
    }
    
    // Solo llegar aquí si NO hay cache válido
    // CRÍTICO: Establecer loading en true SOLO si NO tenemos cache válido
    // Esto evita que se muestre skeleton loader cuando volvemos atrás con cache
    _isLoadingSong = true;
    
    // Resetear estados de imágenes cuando no hay cache
    _coverImageReady = false;
    _artistAvatarReady = false;
  }
  
  /// Helper para precargar una imagen individual - ELIMINA CÓDIGO DUPLICADO
  /// Marca como lista INMEDIATAMENTE si está en cache de disco
  void _precacheSingleImage(String? imageUrl, void Function(bool) onReady) {
    if (imageUrl == null || imageUrl.isEmpty) {
      onReady(true);
      return;
    }
    
    // Verificar si está en cache de disco
    cache_service.AlbumArtCacheManager.instance.getFileFromCache(imageUrl).then((fileInfo) {
      // CRÍTICO: Si está en cache, marcar como lista INMEDIATAMENTE (no esperar precacheImage)
      if (mounted) {
        onReady(true);
      }
      
      // Precargar en memoria en segundo plano (no bloquea)
      if (mounted) {
        precacheImage(CachedNetworkImageProvider(imageUrl), context).catchError((_) {
          // Ignorar errores - ya marcamos como lista
        });
      }
    }).catchError((_) {
      // Si no está en cache o falla, marcar como lista igual y precargar desde red
      if (mounted) {
        onReady(true);
      }
      
      // Precargar desde red en segundo plano
      if (mounted) {
        precacheImage(CachedNetworkImageProvider(imageUrl), context).catchError((_) {
          // Ignorar errores
        });
      }
    });
  }
  
  /// Verifica si las imágenes están en cache y las precarga correctamente
  /// IMPLEMENTACIÓN OPTIMIZADA: Usa helper para eliminar código duplicado
  void _checkAndPrecacheImages() {
    // Precargar portada usando helper
    _precacheSingleImage(_cachedCoverUrl, (ready) {
      if (mounted) {
        setState(() {
          _coverImageReady = ready;
        });
      }
    });
    
    // Precargar avatar usando helper
    _precacheSingleImage(_cachedArtistAvatarUrl, (ready) {
      if (mounted) {
        setState(() {
          _artistAvatarReady = ready;
        });
      }
    });
  }
  
  /// Limpia el cache si excede el tamaño máximo (LRU - elimina el más antiguo)
  void _cleanupCacheIfNeeded() {
    if (_songCache.length >= _maxCacheSize) {
      // Encontrar la entrada más antigua
      String? oldestSongId;
      DateTime? oldestTime;
      
      _songCache.forEach((songId, data) {
        final lastLoad = data['lastLoad'] as DateTime;
        if (oldestTime == null || lastLoad.isBefore(oldestTime!)) {
          oldestTime = lastLoad;
          oldestSongId = songId;
        }
      });
      
      // Eliminar la entrada más antigua
      if (oldestSongId != null) {
        _songCache.remove(oldestSongId);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cachear dimensiones de pantalla una sola vez (optimización: evitar MediaQuery en cada build)
    // Asegurar que siempre tengamos valores cacheados
    // Reducido a 0.75 para diseño más compacto
    if (_cachedImageSize == null || _cachedDevicePixelRatio == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedImageSize ??= mediaQuery.size.width * 0.75;
      _cachedDevicePixelRatio ??= mediaQuery.devicePixelRatio;
    }
  }

  /// 🔥 CRÍTICO: Restaurar posición del scroll después de que el contenido esté medido
  /// Este método verifica que el ScrollController tenga un maxScrollExtent válido
  /// antes de hacer jumpTo, evitando que la restauración falle silenciosamente
  void _restoreScrollPosition() {
    if (!mounted || _hasRestoredInitialScroll) return;
    
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
        _scrollController.jumpTo(savedPosition);
        _hasRestoredInitialScroll = true;
      }
    }
  }

  /// Guarda la posición del scroll en Provider (persistente) y PageStorage (backup)
  void _saveScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final position = _scrollController.offset;
    if (position < 0) return;
    
    final screenKey = 'song_detail_${widget.song.id}';
    
    // 🔥 PERSISTENCIA: Guardar en Provider (persistente incluso si el widget se destruye)
    final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
    scrollNotifier.saveScrollPosition(screenKey, position);
    
    // También guardar en PageStorage como backup
    try {
      final pageStorage = PageStorage.maybeOf(context);
      if (pageStorage != null) {
        pageStorage.writeState(
          context,
          position,
          identifier: PageStorageKey<String>('song_detail_scroll_${widget.song.id}'),
        );
      }
    } catch (e) {
      // Ignorar errores de PageStorage
    }
  }

  @override
  void didUpdateWidget(SongDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ CRÍTICO: Detectar cambio de canción (ej. auto-advance) para actualizar la UI
    if (widget.song.id != oldWidget.song.id) {
       // Resetear estados de carga
       _loadedSong = null;
       _isLoadingSong = false;
       _coverImageReady = false;
       _artistAvatarReady = false;
       
       // Intentar cargar del cache primero
       _loadFromCache();
       
       // Actualizar URLs normalizadas
       _normalizeUrls();
       
       // Si no estaba en cache, cargar del backend
       if (_loadedSong == null) {
          _loadSongFromBackend();
       }
       
       // Restaurar scroll position si existe
       final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
       final savedPosition = scrollNotifier.getScrollPosition('song_detail_${widget.song.id}');
       if (savedPosition != null) {
          _scrollController.jumpTo(savedPosition);
       } else {
          _scrollController.jumpTo(0);
       }
    }
  }

  @override
  void dispose() {
    // 🔥 CRÍTICO: Guardar posición final antes de destruir (sin debounce)
    if (_scrollController.hasClients) {
      final finalPosition = _scrollController.offset;
      if (finalPosition >= 0) {
        final screenKey = 'song_detail_${widget.song.id}';
        final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
        scrollNotifier.saveScrollPosition(screenKey, finalPosition);
      }
    }
    
    _scrollController.removeListener(_saveScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }
  
  /// Normaliza URLs una sola vez
  void _normalizeUrls() {
    _cachedCoverUrl = UrlNormalizer.normalizeImageUrl(widget.song.coverArtUrl);
    _cachedArtistAvatarUrl = UrlNormalizer.normalizeImageUrl(widget.song.artist?.profilePhotoUrl);
    
    // Si no hay avatar pero hay artista con ID, intentar cargarlo
    if (_cachedArtistAvatarUrl == null && widget.song.artist?.id.isNotEmpty == true) {
      Future.microtask(() {
        if (mounted) _loadArtistAvatarAsync(widget.song.artist!.id);
      });
    }
  }
  
  /// Actualiza URLs normalizadas cuando se carga la canción desde el backend
  void _updateNormalizedUrls(Song song) {
    _cachedCoverUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl);
    _cachedArtistAvatarUrl = UrlNormalizer.normalizeImageUrl(song.artist?.profilePhotoUrl);
    
    // Si no hay avatar pero hay artista con ID, intentar cargarlo
    if (_cachedArtistAvatarUrl == null && song.artist?.id.isNotEmpty == true) {
      Future.microtask(() {
        if (mounted) _loadArtistAvatarAsync(song.artist!.id);
      });
    }
  }
  
  /// Cargar avatar del artista de forma asíncrona
  Future<void> _loadArtistAvatarAsync(String artistId) async {
    if (_isLoadingArtistAvatar || !mounted) return;
    
    _isLoadingArtistAvatar = true;
    setState(() {});
    
    try {
      final artistsApi = ArtistsApi(AppConfig.baseUrl);
      final artistData = await artistsApi.getById(artistId);
      final normalizedArtist = DataNormalizer.normalizeArtist(artistData);
      final profilePhotoUrl = normalizedArtist['profile_photo_url'] as String?;
      
      if (!mounted) return;
      
      final normalizedUrl = UrlNormalizer.normalizeImageUrl(profilePhotoUrl);
      if (normalizedUrl != null) {
        setState(() {
          _cachedArtistAvatarUrl = normalizedUrl;
          _isLoadingArtistAvatar = false;
        });
        _precacheSingleImage(normalizedUrl, (ready) {
          if (mounted) setState(() => _artistAvatarReady = ready);
        });
      } else {
        setState(() => _isLoadingArtistAvatar = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingArtistAvatar = false);
    }
  }

  /// Carga la canción completa desde el backend para asegurar datos actualizados
  /// Usa cache para evitar recargas innecesarias si la canción ya fue cargada recientemente
  Future<void> _loadSongFromBackend() async {
    // Verificar si ya tenemos datos del cache válidos
    final cachedData = _songCache[widget.song.id];
    if (cachedData != null) {
      final lastLoadTime = cachedData['lastLoad'] as DateTime;
      final cachedSong = cachedData['song'] as Song;
      
      // Si el cache es válido (no expirado), no recargar desde el backend
      if (DateTime.now().difference(lastLoadTime) < _cacheValidDuration) {
        // Ya tenemos datos del cache válidos, no necesitamos recargar
        if (mounted && _loadedSong == null) {
          // Solo actualizar si aún no tenemos datos cargados
          setState(() {
            _loadedSong = cachedSong;
            _isLoadingSong = false;
          });
        }
        return; // No recargar desde el backend
      }
    }
    
    // Solo mostrar loading si no tenemos datos del cache
    if (!mounted) return;
    
    // Solo mostrar loading si realmente vamos a cargar (no tenemos cache válido)
    if (_loadedSong == null) {
      setState(() {
        _isLoadingSong = true;
      });
    }
    
    try {
      final songDetailService = ref.read(songDetailServiceProvider);
      final loadedSong = await songDetailService.getSongById(widget.song.id);
      
      // Verificar mounted una sola vez después del await
      if (!mounted) return;
      
      // Actualizar URLs normalizadas cuando se carga la canción completa
      if (loadedSong != null) {
        _updateNormalizedUrls(loadedSong);
        
        // Guardar en cache
        _cleanupCacheIfNeeded(); // Limpiar cache si es necesario antes de agregar
        _songCache[widget.song.id] = {
          'song': loadedSong,
          'lastLoad': DateTime.now(),
        };
        
        // Precargar imágenes cuando se cargan nuevos datos
        _checkAndPrecacheImages();
        
        // Cargar avatar del artista si no está disponible
        if (loadedSong.artist != null && _cachedArtistAvatarUrl == null) {
          if (loadedSong.artist!.profilePhotoUrl == null || loadedSong.artist!.profilePhotoUrl!.isEmpty) {
            _loadArtistAvatarAsync(loadedSong.artist!.id);
          }
        }
      }
      
      setState(() {
        _loadedSong = loadedSong;
        _isLoadingSong = false;
      });
    } catch (e) {
      // Verificar mounted una sola vez en el catch
      if (!mounted) return;
      
      setState(() {
        _isLoadingSong = false;
      });
    }
  }



  /// Navega a la pantalla de detalle de una canción
  /// Si la pantalla de esa canción ya está abierta, vuelve a ella en lugar de abrir otra
  void _navigateToSong(Song song) {
    // Usar la función estática para evitar duplicación de código
    SongDetailScreen.navigateToSong(context, song);
  }

  void _navigateToArtist() {
    if (widget.song.artist != null) {
      final artist = widget.song.artist!;
      final artistLite = ArtistLite(
        id: artist.id,
        name: artist.displayName,
        profilePhotoUrl: artist.profilePhotoUrl,
        coverPhotoUrl: artist.coverPhotoUrl,
        featured: false,
      );
      // Usar go_router para navegación consistente
      context.push('/artist/${artist.id}', extra: artistLite);
    }
  }
  
  /// Reproducir canción con lógica inteligente
  /// - Si es la misma canción: pause/resume sin reiniciar
  /// - Si es diferente: reproducir desde el inicio
  /// ✅ IGUAL A artist_page.dart y playlist_detail_screen.dart
  void _onPlaySong(Song song) async {
    if (!mounted) return;
    
    try {
      final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
      final audioState = ref.read(unifiedAudioProviderFixed);
      
      final currentSong = audioState.currentSong;
      final isPlaying = audioState.isPlaying;
      final isCurrentSong = currentSong?.id == song.id;
      
      if (isCurrentSong) {
        // ✅ MISMA CANCIÓN: Solo hacer pause/resume sin reiniciar
        // No cambia el AudioSource, no reinicia la posición
        if (isPlaying) {
          await audioNotifier.togglePlayPause();
        } else {
          await audioNotifier.togglePlayPause();
        }
      } else {
        // ✅ CANCIÓN DIFERENTE: Reproducir desde el inicio
        // Esto cambia el AudioSource y reinicia la posición a 0
        // ✅ CRÍTICO: useAlgorithm = true desactiva fixed queue automáticamente
        await audioNotifier.playFromCard(song, useAlgorithm: true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  // Constantes para skeleton loaders - Colores del tema claro de la app
  static Color get _shimmerBaseColor => NeumorphismTheme.surface.withValues(alpha: 0.6);
  static Color get _shimmerHighlightColor => NeumorphismTheme.beigeMedium.withValues(alpha: 0.8);
  static const Duration _shimmerDuration = Duration(milliseconds: 1200); // Animación más lenta y suave
  
  /// Widget skeleton para la portada - Colores del tema claro
  Widget _buildCoverSkeleton(double imageSize) {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      period: _shimmerDuration,
      direction: ShimmerDirection.ltr,
      child: Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: _shimmerBaseColor, // Color del tema claro
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          // boxShadow removido
        ),
      ),
    );
  }
  
  /// Widget skeleton para el título - Colores del tema claro
  Widget _buildTitleSkeleton() {
    // ✅ Calcular altura exacta del texto real: fontSize * height * maxLines
    // fontSize: 28, height: 0.75, maxLines: 2
    final titleHeight = 28 * 0.75 * 2; // = 42
    return SizedBox(
      height: titleHeight, // ✅ Mismo tamaño que el texto real máximo (2 líneas)
      child: Shimmer.fromColors(
        baseColor: _shimmerBaseColor,
        highlightColor: _shimmerHighlightColor,
        period: _shimmerDuration,
        direction: ShimmerDirection.ltr,
        child: Container(
          height: titleHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: NeumorphismTheme.textPrimary.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
    );
  }
  
  /// Widget skeleton para el nombre del artista - Colores del tema claro
  /// CRÍTICO: Debe tener exactamente las mismas dimensiones que el elemento real
  Widget _buildArtistSkeleton() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Misma alineación que el real
      children: [
        // Avatar skeleton - 24x24 con sombra
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            // boxShadow removido
          ),
          child: Shimmer.fromColors(
            baseColor: _shimmerBaseColor,
            highlightColor: _shimmerHighlightColor,
            period: _shimmerDuration,
            direction: ShimmerDirection.ltr,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3), // Mismo color que el skeleton del avatar
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8), // Mismo espacio que el real
        // Texto skeleton - fontSize: 15, fontWeight.w500
        Shimmer.fromColors(
          baseColor: _shimmerBaseColor,
          highlightColor: _shimmerHighlightColor,
          period: _shimmerDuration,
          direction: ShimmerDirection.ltr,
          child: Container(
            height: 15, // Mismo fontSize que el texto real
            width: 120,
            decoration: BoxDecoration(
              color: NeumorphismTheme.textSecondary.withValues(alpha: 0.15), // Color del tema claro
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        const SizedBox(width: 8), // Mismo espacio que el real
        // Contador de streams skeleton - Icono + texto (igual que el real)
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Icono skeleton - 14x14 (igual que el icono real)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: NeumorphismTheme.textSecondary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4), // Mismo espacio que el real
            // Texto del contador skeleton - fontSize: 14
            Shimmer.fromColors(
              baseColor: _shimmerBaseColor,
              highlightColor: _shimmerHighlightColor,
              period: _shimmerDuration,
              direction: ShimmerDirection.ltr,
              child: Container(
                height: 14, // Mismo fontSize que el texto del contador
                width: 40, // Ancho aproximado del número
                decoration: BoxDecoration(
                  color: NeumorphismTheme.textSecondary.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8), // Mismo espacio que el real
        // "Sencillo" skeleton - fontSize: 14
        Shimmer.fromColors(
          baseColor: _shimmerBaseColor,
          highlightColor: _shimmerHighlightColor,
          period: _shimmerDuration,
          direction: ShimmerDirection.ltr,
          child: Container(
            height: 14, // Mismo fontSize que el texto "Sencillo"
            width: 60, // Ancho aproximado del texto "Sencillo"
            decoration: BoxDecoration(
              color: NeumorphismTheme.textLight.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Construir imagen de portada SIN parpadeo
  Widget _buildCoverImage(double imageSize, double devicePixelRatio, bool hasCacheData, String? coverUrl) {
    // Si tenemos cache y la imagen está lista, mostrar directamente sin skeleton
    if (hasCacheData && _coverImageReady && coverUrl != null && coverUrl.isNotEmpty) {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(32)),
          // boxShadow removido
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          child: CachedNetworkImage(
            imageUrl: coverUrl,
            cacheManager: cache_service.AlbumArtCacheManager.instance,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // memCacheWidth: (imageSize * devicePixelRatio).round(), // Desactivado por compatibilidad 90 días
            // memCacheHeight: (imageSize * devicePixelRatio).round(),
            // CRÍTICO: Sin fade ni placeholder cuando hay cache (evita parpadeo)
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            // Usar imagen anterior si la URL cambia
            useOldImageOnUrlChange: true,
            // Placeholder transparente cuando hay cache (no visible)
            placeholder: (context, url) => Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
            errorWidget: (context, url, error) => Container(
              color: NeumorphismTheme.coffeeMedium,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, color: Colors.white, size: 64),
                  SizedBox(height: 8),
                  Text('Error cargando imagen', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Si NO tenemos cache o la imagen no está lista, usar CachedNetworkImage con skeleton
    if (!hasCacheData || !_coverImageReady || coverUrl == null || coverUrl.isEmpty) {
      if (!hasCacheData && coverUrl == null) {
        return _buildCoverSkeleton(imageSize);
      }
      
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(32)),
          // boxShadow removido
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          child: CachedNetworkImage(
            imageUrl: coverUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: (imageSize * devicePixelRatio).round(),
            memCacheHeight: (imageSize * devicePixelRatio).round(),
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) => _buildCoverSkeleton(imageSize),
            errorWidget: (context, url, error) => Container(
              color: NeumorphismTheme.coffeeMedium,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, color: Colors.white, size: 64),
                  SizedBox(height: 8),
                  Text('Error cargando imagen', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Fallback: skeleton
    return _buildCoverSkeleton(imageSize);
  }
  
  /// 🆕 Widget skeleton para el avatar del artista
  Widget _buildArtistAvatarSkeleton() {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      period: _shimmerDuration,
      direction: ShimmerDirection.ltr,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          // boxShadow removido
        ),
      ),
    );
  }
  
  /// Construir avatar del artista
  Widget _buildArtistAvatar(bool hasCacheData, String? artistAvatarUrl) {
    final avatarUrl = artistAvatarUrl ?? _cachedArtistAvatarUrl;
    
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildArtistAvatarSkeleton();
    }
    
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // boxShadow removido
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          width: 24,
          height: 24,
          memCacheWidth: 48,
          memCacheHeight: 48,
          fadeInDuration: hasCacheData && _artistAvatarReady ? Duration.zero : const Duration(milliseconds: 200),
          placeholder: (context, url) => _buildArtistAvatarSkeleton(),
          errorWidget: (context, url, error) => _buildArtistAvatarSkeleton(),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider); // 🚀 Forzar rebuild cuando el tema cambia
    super.build(context); // Requerido para AutomaticKeepAliveClientMixin
    
    // CRÍTICO: Si tenemos cache válido, mostrar contenido inmediatamente sin verificaciones
    // Esto evita cualquier parpadeo al retroceder
    // Verificar cache válido: debe tener canción cargada Y no estar en estado de loading
    // No requerir _cachedCoverUrl porque algunas canciones pueden no tener portada
    final hasValidCache = _loadedSong != null && !_isLoadingSong;
    
    if (hasValidCache) {
      // Tenemos cache válido - renderizar contenido inmediatamente SIN skeleton loaders
      return _buildContentFromCache(context);
    }
    
    // Solo llegar aquí si NO hay cache válido completo
    // Usar valores cacheados (ya calculados en didChangeDependencies)
    final imageSize = _cachedImageSize!;
    final devicePixelRatio = _cachedDevicePixelRatio!;
    
    // Verificar si tenemos datos parciales del cache (imágenes ya cargadas)
    // CRÍTICO: Solo considerar cache válido si NO estamos en estado de loading
    // Esto evita mostrar skeleton loaders cuando hay cache pero aún se está cargando
    final hasCacheData = (_cachedCoverUrl != null || _loadedSong != null) && !_isLoadingSong;
    
    // Usar la canción cargada desde el backend si está disponible, sino usar la que viene como parámetro
    final song = _loadedSong ?? widget.song;
    final artist = song.artist ?? widget.song.artist;
    
    // Usar URLs cacheadas (ya normalizadas en initState o _updateNormalizedUrls)
    final coverUrl = _cachedCoverUrl;
    final artistAvatarUrl = _cachedArtistAvatarUrl;
    

    return RepaintBoundary( // ✅ OPTIMIZACIÓN: Evitar repintados innecesarios
      child: Scaffold(
        key: ValueKey('song_detail_scaffold_${song.id}'), // Key estable para evitar rebuilds
        extendBody: false, // No extender el cuerpo detrás del NavigationBar
        // ✅ AppBar ELIMINADO para diseño inmersivo full screen
        extendBodyBehindAppBar: true, 
        // appBar: removed
        body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          top: false, // ✅ Contenido detrás del status bar
          bottom: false, // No agregar padding inferior, MainNavigation ya lo maneja
          child: CustomScrollView(
            key: PageStorageKey<String>('song_detail_scroll_${widget.song.id}'),
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // ✅ Scroll estilo iPhone
            cacheExtent: 400, // ✅ Optimizado: cache de scroll para mejor rendimiento
            slivers: [
              // Contenido principal
              SliverToBoxAdapter(
                child: SelectionArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: MediaQuery.of(context).padding.top + 32),
                            // ✅ Header con botón de retroceso y título CENTRADO
                            SizedBox(
                              height: 48,
                              child: Stack(
                                children: [
                                  // Botón alineado a la izquierda
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: RepaintBoundary(
                                      child: _BackButton(
                                        onPressed: () => context.pop(),
                                      ),
                                    ),
                                  ),
                                  // Título centrado
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 48),
                                      child: RepaintBoundary(
                                        child: (!hasCacheData && song.title == null)
                                            ? Container(
                                                width: 120,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: NeumorphismTheme.accentLight.withValues(alpha: 0.3),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              )
                                            : Text(
                                                song.title ?? 'Sin título',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: NeumorphismTheme.textPrimary,
                                                  letterSpacing: -0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            const SizedBox(height: 24),
                            
                            // Portada centrada - Diseño compacto
                            RepaintBoundary(
                              child: Center(
                                child: _buildCoverImage(imageSize, devicePixelRatio, hasCacheData, coverUrl),
                              ),
                            ),
                            
                            const SizedBox(height: 24),

                            // Acciones y Metadata abajo de la portada
                            RepaintBoundary(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // "Sencillo" y género
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              'Sencillo',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: NeumorphismTheme.textLight,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            if (song.genres != null && song.genres!.isNotEmpty) ...[
                                              Text(
                                                ' • ',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: NeumorphismTheme.textLight,
                                                ),
                                              ),
                                              Text(
                                                song.genres!.first.toLowerCase(),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: NeumorphismTheme.textLight,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // Contador de streams
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.play_arrow_rounded,
                                              size: 14,
                                              color: NeumorphismTheme.textSecondary.withValues(alpha: 0.7),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              NumberFormatter.format(song.totalStreams),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: NeumorphismTheme.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Botones de acción
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FavoriteButton(
                                        songId: song.id,
                                        song: song, // ✅ CRÍTICO: Pasar objeto completo para actualizar lista inmediatamente
                                        iconColor: NeumorphismTheme.textPrimary,
                                        iconSize: 28,
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.more_vert_rounded, color: NeumorphismTheme.textPrimary, size: 22),
                                        onPressed: () {
                                          // Menú de opciones
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      _PlayPauseButtonLarge(
                                        song: song,
                                        onTap: () => _onPlaySong(song),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            RepaintBoundary(
                              // Artista con avatar redondo y tipo - Alineado con el título
                              child: (!hasCacheData && artist == null)
                                  ? _buildArtistSkeleton()
                                  : Row(
                                    crossAxisAlignment: CrossAxisAlignment.start, // ✅ Alineación consistente
                                    children: [
                                      // Artista con avatar redondo pequeño - clickeable
                                      GestureDetector(
                                        onTap: _navigateToArtist,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Siempre mostrar avatar (con placeholder si no hay URL)
                                            Builder(
                                              builder: (context) {
                                                // Removed verbose build logs to avoid jank during scrolling.
                                                // Avoid printing large objects like artist.toJson() here.
                                                return _buildArtistAvatar(hasCacheData, artistAvatarUrl);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              artist?.displayName ?? 'Artista desconocido',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: NeumorphismTheme.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Información de la canción actual que está sonando - DESHABILITADO
                            // if (currentSong?.id == widget.song.id)
                            //   Container(
                            //     ... código comentado ...
                            //   ),
                            
                            const SizedBox(height: 16),
                            
                            // Sección "Más de este artista" - Optimizada con lazy loading
                            if (artist != null)
                              RepaintBoundary(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: _navigateToArtist,
                                            child: Text(
                                              'Más de ${artist.displayName}',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: NeumorphismTheme.coffeeMedium,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _navigateToArtist,
                                          child: Text(
                                            'Mostrar todo',
                                            style: TextStyle(
                                              color: NeumorphismTheme.textSecondary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 200,
                                      child: ArtistSongsHorizontalList(
                                        artistId: artist.id,
                                        currentSongId: song.id, // Usar el ID de la canción actual (puede ser _loadedSong o widget.song)
                                        onSongTap: _navigateToSong,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 180), // Espacio para el reproductor inferior y NavigationBar
                          ],
                        ),
                      ),
                    ),
              ), // Cierra SliverToBoxAdapter
            ], // Cierra slivers
          ), // Cierra CustomScrollView
        ), // Cierra SafeArea
      ), // Cierra Container
      // El reproductor ya está en MainNavigation, no duplicar aquí
      // bottomNavigationBar: const ProfessionalAudioPlayer(),
      ), // Cierra Scaffold
    ); // Cierra RepaintBoundary
  }

  /// Construir contenido desde cache (sin skeleton loaders)
  Widget _buildContentFromCache(BuildContext context) {
    final imageSize = _cachedImageSize!;
    final devicePixelRatio = _cachedDevicePixelRatio!;
    final song = _loadedSong!;
    final artist = song.artist ?? widget.song.artist;
    final coverUrl = _cachedCoverUrl;
    final artistAvatarUrl = _cachedArtistAvatarUrl;

    return RepaintBoundary( // ✅ OPTIMIZACIÓN: Evitar repintados innecesarios
      child: Scaffold(
        key: ValueKey('song_detail_scaffold_${song.id}'),
        extendBody: false, // No extender el cuerpo detrás del NavigationBar
        // ✅ AppBar ELIMINADO para diseño inmersivo full screen
        extendBodyBehindAppBar: true, 
        // appBar: removed
        body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          top: false, // ✅ Contenido detrás del status bar
          bottom: false, // No agregar padding inferior, MainNavigation ya lo maneja
          child: CustomScrollView(
            key: PageStorageKey<String>('song_detail_scroll_${widget.song.id}'),
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // ✅ Scroll estilo iPhone
            cacheExtent: 400, // ✅ Optimizado: cache de scroll para mejor rendimiento
            slivers: [
              SliverToBoxAdapter(
                child: SelectionArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: MediaQuery.of(context).padding.top + 32),
                            // ✅ Header con botón de retroceso y título CENTRADO
                            SizedBox(
                              height: 48,
                              child: Stack(
                                children: [
                                  // Botón alineado a la izquierda
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: RepaintBoundary(
                                      child: _BackButton(
                                        onPressed: () => context.pop(),
                                      ),
                                    ),
                                  ),
                                  // Título centrado
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 48),
                                      child: RepaintBoundary(
                                        child: Text(
                                          song.title ?? 'Sin título',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: NeumorphismTheme.textPrimary,
                                            letterSpacing: -0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                        
                        const SizedBox(height: 24),

                      RepaintBoundary(
                        child: Center(
                          child: Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(Radius.circular(32)),
                              // boxShadow removido
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(32)),
                              child: coverUrl != null
                                  ? CachedNetworkImage(
                                      // ⚡ MIRROR PATTERN: ValueKey obliga a reconstruir si cambia la URL
                                      key: ValueKey(coverUrl),
                                      imageUrl: coverUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      memCacheWidth: (imageSize * devicePixelRatio).round(),
                                      memCacheHeight: (imageSize * devicePixelRatio).round(),
                                      // CRÍTICO: Sin fade ni placeholder cuando viene de cache (evita parpadeo)
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      placeholderFadeInDuration: Duration.zero,
                                      // Usar imagen anterior si la URL cambia (mejor UX durante transiciones)
                                      useOldImageOnUrlChange: true,
                                      // Sin placeholder para evitar parpadeo cuando hay cache
                                      placeholder: (context, url) => Container(
                                        color: NeumorphismTheme.coffeeMedium,
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: NeumorphismTheme.coffeeMedium,
                                        child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.music_note, color: Colors.white, size: 64),
                                            SizedBox(height: 8),
                                            Text('Sin portada', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: NeumorphismTheme.coffeeMedium,
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.music_note, color: Colors.white, size: 64),
                                          SizedBox(height: 8),
                                          Text('Sin portada', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                        // Acciones y Metadata abajo de la portada
                        RepaintBoundary(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // "Sencillo" y género
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          'Sencillo',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: NeumorphismTheme.textLight,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        if (song.genres != null && song.genres!.isNotEmpty) ...[
                                          Text(
                                            ' • ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: NeumorphismTheme.textLight,
                                            ),
                                          ),
                                          Text(
                                            song.genres!.first.toLowerCase(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: NeumorphismTheme.textLight,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Contador de streams
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          size: 14,
                                          color: NeumorphismTheme.textSecondary.withValues(alpha: 0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          NumberFormatter.format(song.totalStreams),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: NeumorphismTheme.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Botones de acción
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Botón Descargar (Offline)
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final offlineState = ref.watch(offlineManagerProvider);
                                      final isDownloaded = offlineState.downloadedSongs.containsKey(song.id);
                                      final isDownloading = offlineState.downloadingIds.contains(song.id);
                                      final progress = offlineState.downloadProgress[song.id] ?? 0.0;

                                      if (isDownloading) {
                                         return Container(
                                           margin: const EdgeInsets.symmetric(horizontal: 8),
                                           width: 24,
                                           height: 24,
                                            child: CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 2,
                                              color: NeumorphismTheme.coffeeMedium,
                                            ),
                                         );
                                      }

                                      return IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                                          color: isDownloaded ? Colors.green : NeumorphismTheme.textPrimary,
                                          size: 28,
                                        ),
                                        onPressed: () {
                                          final user = ref.read(currentUserProvider);
                                          final isPremium = user != null && 
                                              (user.subscriptionStatus == SubscriptionStatus.premium || 
                                               user.subscriptionStatus == SubscriptionStatus.vip);

                                          if (!isPremium) {
                                            context.go('/premium?showPackages=true');
                                            return;
                                          }

                                          final offlineNotifier = ref.read(offlineManagerProvider.notifier);
                                          if (isDownloaded) {
                                            offlineNotifier.removeDownload(song.id);
                                          } else {
                                            final songToDownload = song.copyWith(
                                              coverArtUrl: UrlNormalizer.normalizeImageUrl(song.coverArtUrl),
                                            );
                                            offlineNotifier.downloadSong(songToDownload);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  FavoriteButton(
                                    songId: song.id,
                                    song: song, // ✅ CRÍTICO: Pasar objeto completo para actualizar lista inmediatamente
                                    iconColor: NeumorphismTheme.textPrimary,
                                    iconSize: 28,
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.more_vert_rounded, color: NeumorphismTheme.textPrimary, size: 22),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 6),
                                  _PlayPauseButtonLarge(
                                    song: song,
                                    onTap: () => _onPlaySong(song),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          child: Row(
                            children: [
                            // Artista con avatar redondo pequeño - clickeable
                            GestureDetector(
                              onTap: _navigateToArtist,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Siempre mostrar avatar (con placeholder si no hay URL)
                                  Builder(
                                    builder: (context) {

                                      return _buildArtistAvatar(true, artistAvatarUrl);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    artist?.displayName ?? 'Artista desconocido',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: NeumorphismTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ),
                      const SizedBox(height: 16),
                      if (artist != null)
                        RepaintBoundary(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _navigateToArtist,
                                      child: Text(
                                        'Más de ${artist.displayName}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: NeumorphismTheme.coffeeMedium,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _navigateToArtist,
                                    child: Text(
                                      'Mostrar todo',
                                      style: TextStyle(
                                        color: NeumorphismTheme.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: ArtistSongsHorizontalList(
                                  artistId: artist.id,
                                  currentSongId: song.id,
                                  onSongTap: _navigateToSong,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 180), // Espacio para el reproductor inferior y NavigationBar
                      ],
                    ),
                  ),
                ),
              ), // Cierra SliverToBoxAdapter
            ], // Cierra slivers
          ), // Cierra CustomScrollView
        ), // Cierra SafeArea
      ), // Cierra Container
      ), // Cierra Scaffold
    ); // Cierra RepaintBoundary
  }
}

/// Botón de retroceso optimizado (widget separado para evitar rebuilds innecesarios)
/// 
/// Optimizaciones aplicadas:
/// - Widget separado para evitar rebuilds del Scaffold completo
/// - RepaintBoundary en el uso para evitar repintados innecesarios
/// - Const constructor para mejor optimización del compilador
class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
      child: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: NeumorphismTheme.textPrimary, size: 20),
        onPressed: onPressed,
        // OPTIMIZADO: tooltip para accesibilidad sin costo de rendimiento
        tooltip: 'Volver',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }
}

/// Botón de menú optimizado (widget separado para evitar rebuilds innecesarios)
/// 
/// Optimizaciones aplicadas:
/// - Widget separado para evitar rebuilds del Scaffold completo
/// - RepaintBoundary en el uso para evitar repintados innecesarios
/// - Const constructor para mejor optimización del compilador
class _MenuButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _MenuButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        boxShadow: NeumorphismTheme.floatingCardShadow,
      ),
      child: IconButton(
        icon: Icon(Icons.more_vert, color: NeumorphismTheme.textPrimary),
        onPressed: onPressed,
        // OPTIMIZADO: tooltip para accesibilidad sin costo de rendimiento
        tooltip: 'Más opciones',
      ),
    );
  }
}

/// ✅ OPTIMIZACIÓN: Widget memoizado para botón de play/pause grande (52x52)
/// Evita rebuilds innecesarios cuando cambia el estado del audio
/// ✅ CORRECCIÓN: Usa selectores separados para detectar cambios en currentSongId e isPlaying
/// Esto garantiza que el widget se reconstruya cuando cambie cualquiera de estos valores
class _PlayPauseButtonLarge extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;

  const _PlayPauseButtonLarge({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ CORRECCIÓN: Usar selectores separados para escuchar cambios en currentSongId e isPlaying
    // Esto garantiza que el widget se reconstruya cuando cambie cualquiera de estos valores
    final currentSongId = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong?.id),
    );
    final isPlaying = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlaying),
    );
    
    // ✅ LÓGICA EXACTA según especificación del usuario:
    // - Si NO es la canción actual → siempre Play
    // - Si ES la canción actual → Play si está pausada, Pause si está reproduciendo
    final bool isCurrent = currentSongId == song.id;
    final IconData icon;
    
    if (!isCurrent) {
      // No es la canción actual → siempre mostrar Play
      icon = Icons.play_arrow_rounded;
    } else {
      // Es la canción actual → mostrar Pause si está reproduciendo, Play si está pausada
      icon = isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    }
    
    return RepaintBoundary(
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF8D6E63), // Fijo a marrón para que no se aclare en modo oscuro
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D6E63).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(26)),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
