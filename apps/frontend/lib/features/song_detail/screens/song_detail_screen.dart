import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../widgets/artist_songs_list.dart';
import '../providers/song_detail_provider.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/favorite_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../artists/models/artist.dart';
import '../../../core/services/http_cache_service.dart' as cache_service;
import '../../artists/services/artists_api.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/data_normalizer.dart';

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
    _scrollController = ScrollController();
    
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
    cache_service.ImageCacheManager.instance.getFileFromCache(imageUrl).then((fileInfo) {
      // CRÍTICO: Si está en cache, marcar como lista INMEDIATAMENTE (no esperar precacheImage)
      if (mounted) {
        onReady(true);
      }
      
      // Precargar en memoria en segundo plano (no bloquea)
      precacheImage(CachedNetworkImageProvider(imageUrl), context).catchError((_) {
        // Ignorar errores - ya marcamos como lista
      });
    }).catchError((_) {
      // Si no está en cache o falla, marcar como lista igual y precargar desde red
      if (mounted) {
        onReady(true);
      }
      
      // Precargar desde red en segundo plano
      precacheImage(CachedNetworkImageProvider(imageUrl), context).catchError((_) {
        // Ignorar errores
      });
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

  @override
  void dispose() {
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

  String _formatReleaseDate(DateTime? date) {
    if (date == null) return '';
    final format = DateFormat('d \'de\' MMM \'de\' yyyy', 'es');
    return format.format(date);
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
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
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
            borderRadius: BorderRadius.circular(8),
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: NeumorphismTheme.floatingCardShadow, // Misma sombra que el real
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
              borderRadius: BorderRadius.circular(4),
            ),
          ),
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
              borderRadius: BorderRadius.circular(4),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: (imageSize * devicePixelRatio).round(),
            memCacheHeight: (imageSize * devicePixelRatio).round(),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
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
          boxShadow: NeumorphismTheme.floatingCardShadow,
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
        boxShadow: NeumorphismTheme.floatingCardShadow,
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
  
  /// Widget skeleton para los botones (play, like, share) - Colores del tema claro
  /// CRÍTICO: Debe tener exactamente las mismas dimensiones que los botones reales
  Widget _buildButtonsSkeleton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, // Misma alineación que el real
      children: [
        // Icono de corazón skeleton - iconSize: 22
        Shimmer.fromColors(
          baseColor: _shimmerBaseColor,
          highlightColor: _shimmerHighlightColor,
          period: _shimmerDuration,
          direction: ShimmerDirection.ltr,
          child: Container(
            width: 22, // Mismo tamaño que el icono real (iconSize: 22)
            height: 22,
            decoration: BoxDecoration(
              color: NeumorphismTheme.textSecondary.withValues(alpha: 0.2), // Color del tema claro
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 4), // Mismo espacio que el real (entre corazón y menú)
        // Icono de menú skeleton - size: 22
        Shimmer.fromColors(
          baseColor: _shimmerBaseColor,
          highlightColor: _shimmerHighlightColor,
          period: _shimmerDuration,
          direction: ShimmerDirection.ltr,
          child: Container(
            width: 22, // Mismo tamaño que el icono real (size: 22)
            height: 22,
            decoration: BoxDecoration(
              color: NeumorphismTheme.textSecondary.withValues(alpha: 0.2), // Color del tema claro
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6), // Mismo espacio que el real (entre menú y play)
        // Botón de Play skeleton - CRÍTICO: 52x52 con gradiente y sombra
        Container(
          width: 52, // Mismo tamaño que el botón real (52x52, no 56x56)
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                NeumorphismTheme.coffeeDark.withValues(alpha: 0.2),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Shimmer.fromColors(
            baseColor: _shimmerBaseColor,
            highlightColor: _shimmerHighlightColor,
            period: _shimmerDuration,
            direction: ShimmerDirection.ltr,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Widget skeleton para géneros - Colores del tema claro
  /// CRÍTICO: Debe tener exactamente las mismas dimensiones que el género real
  /// Solo muestra 1 género (no 3) con la misma estructura que el real
  Widget _buildGenresSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Mismo padding que el real
      decoration: BoxDecoration(
        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15), // Mismo color que el real
        borderRadius: BorderRadius.circular(16), // Mismo borderRadius que el real
      ),
      child: Shimmer.fromColors(
        baseColor: _shimmerBaseColor,
        highlightColor: _shimmerHighlightColor,
        period: _shimmerDuration,
        direction: ShimmerDirection.ltr,
        child: Container(
          height: 13, // Mismo fontSize que el texto real
          width: 80, // Ancho aproximado de un género
          decoration: BoxDecoration(
            color: NeumorphismTheme.textPrimary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    

    return Scaffold(
      key: ValueKey('song_detail_scaffold_${song.id}'), // Key estable para evitar rebuilds
      extendBody: false, // No extender el cuerpo detrás del NavigationBar
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false, // No agregar padding inferior, MainNavigation ya lo maneja
          child: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 300, // Optimizado: reducir cache de scroll para mejor rendimiento
              slivers: [
                // AppBar con botón de retroceso
                SliverAppBar(
                  expandedHeight: 60,
                  floating: true,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: RepaintBoundary(
                    child: _BackButton(
                      onPressed: () => context.pop(),
                    ),
                  ),
                  actions: [
                    RepaintBoundary(
                      child: _MenuButton(
                        onPressed: () {
                          // Mostrar menú de opciones (pendiente de implementar)
                        },
                      ),
                    ),
                  ],
                ),
                
                // Contenido principal
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        
                        // Portada centrada - Diseño compacto
                        RepaintBoundary(
                          child: Center(
                            child: _buildCoverImage(imageSize, devicePixelRatio, hasCacheData, coverUrl),
                          ),
                        ),
                        
                        const SizedBox(height: 24), // ✅ Espacio reducido después de la portada
                        
                        // Título de la canción con botones al lado - Diseño compacto
                        RepaintBoundary(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center, // ✅ Alineación centrada para alinear título con corazón
                            children: [
                              // Título de la canción (grande y bold) o skeleton
                              Expanded(
                                child: (!hasCacheData && song.title == null)
                                    ? _buildTitleSkeleton()
                                    : Text(
                                          song.title ?? 'Sin título',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: NeumorphismTheme.textPrimary,
                                            letterSpacing: -0.5,
                                            height: 0.75,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                              ),
                              const SizedBox(width: 8),
                              // Iconos: Corazón, Menú y Botón de Play - Compacto
                              (!hasCacheData && _isLoadingSong)
                                  ? _buildButtonsSkeleton()
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center, // ✅ Alineación centrada
                                      children: [
                                        // Icono de corazón
                                        FavoriteButton(
                                          songId: song.id,
                                          iconColor: NeumorphismTheme.textPrimary,
                                          iconSize: 22,
                                        ),
                                        const SizedBox(width: 4),
                                        // Icono de tres rayitas (menú)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.more_vert_rounded, color: NeumorphismTheme.textPrimary, size: 22),
                                          onPressed: () {
                                            // Menú de opciones - funcionalidad pendiente
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        // Botón de Play/Pause - Compacto
                                        Consumer(
                                          builder: (context, ref, child) {
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
                                                width: 52,
                                                height: 52,
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
                                                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.4),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
                                                      audioNotifier.togglePlay(song).catchError((e) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Error al reproducir la canción'),
                                                              backgroundColor: Colors.red,
                                                              duration: Duration(seconds: 2),
                                                            ),
                                                          );
                                                        }
                                                      });
                                                    },
                                                    borderRadius: BorderRadius.circular(26),
                                                    child: Center(
                                                      child: Icon(
                                                        showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                        color: Colors.white,
                                                        size: 26,
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
                          ],
                        ),
                        ),
                        // CRÍTICO: Espacio consistente entre título y artista (siempre presente)
                        const SizedBox(height: 16), // Espacio entre título y artista
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
                                            debugPrint('🎨 [BUILD] Construyendo avatar - URL: $artistAvatarUrl, Artista: ${artist?.displayName}');
                                            debugPrint('🎨 [BUILD] Artista completo: ${artist?.toJson()}');
                                            return _buildArtistAvatar(hasCacheData, artistAvatarUrl);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          artist?.displayName ?? 'Artista desconocido',
                                          style: const TextStyle(
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
                                  const SizedBox(width: 8),
                                  // Tipo (Sencillo)
                                  const Text(
                                    'Sencillo',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: NeumorphismTheme.textLight,
                                    ),
                                  ),
                                ],
                              ),
                        ),
                        // CRÍTICO: Espacio consistente entre artista y género (siempre presente)
                        const SizedBox(height: 12), // Espacio entre artista y género
                        RepaintBoundary(
                          child: (!hasCacheData && _isLoadingSong)
                              ? _buildGenresSkeleton()
                              : Builder(
                                  builder: (context) {
                                    if (song.genres != null && song.genres!.isNotEmpty) {
                                      // Mostrar solo el primer género alineado con título y artista
                                      return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            song.genres!.first.toLowerCase(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: NeumorphismTheme.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                    }
                                    return const SizedBox.shrink();
                                  },
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
                                    GestureDetector(
                                      onTap: _navigateToArtist,
                                      child: Text(
                                        'Más de ${artist.displayName}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: NeumorphismTheme.coffeeMedium,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _navigateToArtist,
                                      child: const Text(
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
              ],
            ),
        ),
      ),
      // El reproductor ya está en MainNavigation, no duplicar aquí
      // bottomNavigationBar: const ProfessionalAudioPlayer(),
    );
  }

  /// Construir contenido desde cache (sin skeleton loaders)
  Widget _buildContentFromCache(BuildContext context) {
    final imageSize = _cachedImageSize!;
    final devicePixelRatio = _cachedDevicePixelRatio!;
    final song = _loadedSong!;
    final artist = song.artist ?? widget.song.artist;
    final coverUrl = _cachedCoverUrl;
    final artistAvatarUrl = _cachedArtistAvatarUrl;

    return Scaffold(
      key: ValueKey('song_detail_scaffold_${song.id}'),
      extendBody: false, // No extender el cuerpo detrás del NavigationBar
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false, // No agregar padding inferior, MainNavigation ya lo maneja
          child: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 300,
            slivers: [
              SliverAppBar(
                expandedHeight: 60,
                floating: true,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: RepaintBoundary(
                  child: _BackButton(
                    onPressed: () => context.pop(),
                  ),
                ),
                actions: [
                  RepaintBoundary(
                    child: _MenuButton(
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      RepaintBoundary(
                        child: Center(
                          child: Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: coverUrl != null
                                  ? CachedNetworkImage(
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
                        const SizedBox(height: 24), // ✅ Espacio reducido después de la portada
                        RepaintBoundary(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center, // ✅ Alineación centrada para alinear título con corazón
                            children: [
                              Expanded(
                                child: Text(
                                  song.title ?? 'Sin título',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: NeumorphismTheme.textPrimary,
                                    letterSpacing: -0.5,
                                    height: 0.75,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center, // ✅ Alineación centrada
                                children: [
                                  FavoriteButton(
                                    songId: song.id,
                                    iconColor: NeumorphismTheme.textPrimary,
                                    iconSize: 22,
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.more_vert_rounded, color: NeumorphismTheme.textPrimary, size: 22),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 6),
                                  Consumer(
                                    builder: (context, ref, child) {
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
                                          width: 52,
                                          height: 52,
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
                                                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
                                                audioNotifier.togglePlay(song).catchError((e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Error al reproducir la canción'),
                                                        backgroundColor: Colors.red,
                                                        duration: Duration(seconds: 2),
                                                      ),
                                                    );
                                                  }
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(26),
                                              child: Center(
                                                child: Icon(
                                                  showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 26,
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
                            ],
                          ),
                        ),
                        // CRÍTICO: Espacio consistente entre título y artista (siempre presente)
                        const SizedBox(height: 16), // Espacio entre título y artista
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
                                      debugPrint('🎨 [BUILD CACHE] Construyendo avatar - URL: $artistAvatarUrl, Artista: ${artist?.displayName}');
                                      return _buildArtistAvatar(true, artistAvatarUrl);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    artist?.displayName ?? 'Artista desconocido',
                                    style: const TextStyle(
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
                            const SizedBox(width: 8),
                            const Text('Sencillo', style: TextStyle(fontSize: 14, color: NeumorphismTheme.textLight)),
                          ],
                        ),
                        ),
                        // CRÍTICO: Espacio consistente entre artista y género (siempre presente)
                        const SizedBox(height: 12), // Espacio entre artista y género
                        (song.genres != null && song.genres!.isNotEmpty)
                          ? RepaintBoundary(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  song.genres!.first.toLowerCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: NeumorphismTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      const SizedBox(height: 16),
                      if (artist != null)
                        RepaintBoundary(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: _navigateToArtist,
                                    child: Text(
                                      'Más de ${artist.displayName}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: NeumorphismTheme.coffeeMedium,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _navigateToArtist,
                                    child: const Text(
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
            ],
          ),
        ),
      ),
    );
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
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        boxShadow: NeumorphismTheme.floatingCardShadow,
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back, color: NeumorphismTheme.textPrimary),
        onPressed: onPressed,
        // OPTIMIZADO: tooltip para accesibilidad sin costo de rendimiento
        tooltip: 'Volver',
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
        icon: const Icon(Icons.more_vert, color: NeumorphismTheme.textPrimary),
        onPressed: onPressed,
        // OPTIMIZADO: tooltip para accesibilidad sin costo de rendimiento
        tooltip: 'Más opciones',
      ),
    );
  }
}
