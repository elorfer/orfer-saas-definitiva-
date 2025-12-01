import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/api_config.dart';
import '../../../core/models/song_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/utils/logger.dart';
import '../../artists/services/artists_api.dart';
import '../models/artist.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/utils/data_normalizer.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/services/http_cache_service.dart' as cache_service;

// Clase helper para resultado del procesamiento en isolate
class _ProcessedSong {
  final Song song;
  final String? normalizedCoverUrl;

  const _ProcessedSong({
    required this.song,
    this.normalizedCoverUrl,
  });
}

// Función top-level para procesar canciones y URLs en un solo isolate
// OPTIMIZADA: Un solo .map() en lugar de múltiples para evitar listas intermedias
List<_ProcessedSong> _parseAndProcessSongs(List<Map<String, dynamic>> songsRaw) {
  // Procesar todo en un solo paso: normalizar -> parsear -> crear _ProcessedSong
  // Esto evita crear 3 listas intermedias (normalizedSongs, songs, resultado)
  return songsRaw.map((e) {
    // Paso 1: Normalizar datos
    final normalized = DataNormalizer.normalizeSong(e);
    
    // Paso 2: Parsear JSON directamente
    final song = Song.fromJson(normalized);
    
    // Paso 3: Normalizar URL y crear _ProcessedSong
    final normalizedUrl = song.coverArtUrl != null
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    return _ProcessedSong(
      song: song,
      normalizedCoverUrl: normalizedUrl,
    );
  }).toList();
}

// Record para pasar parámetros a la función de isolate
typedef _ParseSongsRangeParams = ({List<Map<String, dynamic>> songsRaw, int start, int end});

// Función para procesar solo un rango de canciones (optimización: procesamiento lazy)
List<_ProcessedSong> _parseAndProcessSongsRange(_ParseSongsRangeParams params) {
  final range = params.songsRaw.sublist(
    params.start,
    params.end.clamp(0, params.songsRaw.length),
  );
  return _parseAndProcessSongs(range);
}

class ArtistPage extends ConsumerStatefulWidget {
  final ArtistLite artist;
  const ArtistPage({super.key, required this.artist});

  @override
  ConsumerState<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends ConsumerState<ArtistPage> 
    with AutomaticKeepAliveClientMixin {
  late final ArtistsApi _api;
  Map<String, dynamic>? _details;
  List<_ProcessedSong> _allProcessedSongs = []; // Todas las canciones procesadas
  List<_ProcessedSong> _displayedSongs = []; // Canciones mostradas (paginadas)
  List<Map<String, dynamic>> _songsRaw = []; // Canciones raw sin procesar (para procesamiento lazy)
  bool _loading = true; // Se establecerá en false inmediatamente si hay cache
  bool _hasMoreSongs = false;
  bool _loadingMore = false;
  bool _hasLoadedOnce = false; // Flag para saber si ya se cargó una vez
  Timer? _loadMoreDebounceTimer; // Timer para debounce de carga de más canciones
  static const Duration _loadMoreDebounceDuration = Duration(milliseconds: 300); // Debounce para evitar múltiples llamadas rápidas
  
  // Estados para controlar la carga de imágenes (evita parpadeo)
  bool _coverImageReady = false;
  bool _profileImageReady = false;
  
  // Cache estático para mantener datos entre navegaciones (evita parpadeo)
  // Estructura: { artistId: { 'details': ..., 'songs': ..., 'lastLoad': ... } }
  static final Map<String, Map<String, dynamic>> _artistCache = {};
  
  // Timer para limpieza periódica proactiva de memoria
  static Timer? _cacheCleanupTimer;
  
  // Constantes de configuración del cache
  static const int _maxCacheSize = 5; // Máximo de 5 artistas en cache
  static const int _initialSongsLimit = 15; // Reducido de 20 a 15 para carga más rápida
  static const int _loadMoreSongsLimit = 15; // Reducido de 20 a 15 para mejor rendimiento
  static const Duration _cacheValidDuration = Duration(minutes: 5); // Cache válido por 5 minutos
  static const Duration _cacheCleanupInterval = Duration(minutes: 2); // Limpieza proactiva cada 2 minutos
  
  /// Inicializa la limpieza periódica proactiva del cache
  /// Se ejecuta automáticamente cada cierto intervalo para liberar memoria
  static void _initializeProactiveCleanup() {
    // Cancelar timer existente si hay uno
    _cacheCleanupTimer?.cancel();
    
    // Crear nuevo timer para limpieza periódica
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _cleanOldCache(forceCleanup: true);
    });
  }
  
  /// Helper estático para limpiar imágenes de una entrada de cache - ELIMINA CÓDIGO DUPLICADO
  static void _cleanupCacheImages(Map<String, dynamic> cachedData) {
    final coverUrl = cachedData['coverUrl'] as String?;
    final profileUrl = cachedData['profileUrl'] as String?;
    
    if (coverUrl != null) {
      cache_service.ImageCacheManager.instance.removeFile(coverUrl).catchError((_) {});
    }
    if (profileUrl != null) {
      cache_service.ImageCacheManager.instance.removeFile(profileUrl).catchError((_) {});
    }
  }
  
  /// Limpia el cache de manera óptima:
  /// 1. Elimina entradas expiradas siempre
  /// 2. Si hay más del máximo permitido, elimina las más antiguas hasta llegar al límite
  /// 3. Ordena por fecha de acceso (LRU - Least Recently Used)
  /// 4. Limpia imágenes precacheadas cuando se eliminan entradas
  /// [forceCleanup] Si es true, también limpia entradas que están cerca de expirar (proactivo)
  static void _cleanOldCache({bool forceCleanup = false}) {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    final keysToRemove = <String>[];
    
    // Paso 1: Identificar entradas expiradas o próximas a expirar
    _artistCache.forEach((key, value) {
      final lastLoad = value['lastLoadTime'] as DateTime?;
      if (lastLoad != null) {
        final age = now.difference(lastLoad);
        // Si está expirado o si es limpieza proactiva y está cerca de expirar (80% del tiempo)
        if (age > _cacheValidDuration || 
            (forceCleanup && age > _cacheValidDuration * 0.8)) {
          expiredKeys.add(key);
        }
      }
    });
    
    // Paso 2: Limpiar imágenes precacheadas y eliminar entradas expiradas
    for (final key in expiredKeys) {
      final cachedData = _artistCache[key];
      if (cachedData != null) {
        _cleanupCacheImages(cachedData);
      }
      keysToRemove.add(key);
    }
    
    // Eliminar entradas del cache
    for (final key in keysToRemove) {
      _artistCache.remove(key);
    }
    
    // Paso 3: Si aún hay más del máximo permitido, eliminar las más antiguas (LRU)
    if (_artistCache.length > _maxCacheSize) {
      // Crear lista de entradas ordenadas por fecha de acceso (más antiguas primero)
      final sortedEntries = _artistCache.entries.toList()
        ..sort((a, b) {
          final aTime = a.value['lastLoadTime'] as DateTime? ?? DateTime(1970);
          final bTime = b.value['lastLoadTime'] as DateTime? ?? DateTime(1970);
          return aTime.compareTo(bTime); // Ordenar de más antiguo a más reciente
        });
      
      // Eliminar las entradas más antiguas hasta llegar al límite máximo
      final entriesToRemove = sortedEntries.length - _maxCacheSize;
      for (int i = 0; i < entriesToRemove; i++) {
        final key = sortedEntries[i].key;
        final cachedData = sortedEntries[i].value;
        
        // Limpiar imágenes antes de eliminar usando helper
        _cleanupCacheImages(cachedData);
        _artistCache.remove(key);
      }
      
      // Log solo en modo debug para producción
      if (kDebugMode) {
        debugPrint('[ArtistPage] Cache limpiado: ${sortedEntries.length} -> ${_artistCache.length} entradas');
      }
    }
    
    // Log solo en modo debug
    if (keysToRemove.isNotEmpty && !forceCleanup && kDebugMode) {
      debugPrint('[ArtistPage] Cache limpiado: ${keysToRemove.length} entradas expiradas eliminadas');
    }
  }
  
  /// Actualiza la fecha de acceso de una entrada en el cache (para LRU)
  static void _updateCacheAccessTime(String artistId) {
    final cachedData = _artistCache[artistId];
    if (cachedData != null) {
      cachedData['lastLoadTime'] = DateTime.now();
    }
  }

  // Variables calculadas una sola vez cuando cambian los datos
  String? _effectiveName;
  String? _coverUrl;
  String? _profileUrl;
  String _bio = '';
  String? _nationality;
  String? _phone;
  String? _flagEmoji;
  bool _isAdmin = false; // Cachear estado de admin
  
  // Cachear dimensiones de pantalla para evitar recálculos
  double? _cachedScreenWidth;
  double? _cachedCoverHeight;
  double? _cachedDevicePixelRatio;
  
  // Flags para evitar múltiples llamadas simultáneas (sin delay)
  bool _isPlayAllInProgress = false;
  
  // Keys estables para evitar reconstrucciones innecesarias
  final _headerKey = GlobalKey();
  final _biographyKey = GlobalKey();
  final _contactKey = GlobalKey();
  final _songsHeaderKey = GlobalKey();
  
  // Constantes para skeleton loaders - Colores del tema claro de la app
  static Color get _shimmerBaseColor => NeumorphismTheme.surface.withValues(alpha: 0.6);
  static Color get _shimmerHighlightColor => NeumorphismTheme.beigeMedium.withValues(alpha: 0.8);
  static const Duration _shimmerDuration = Duration(milliseconds: 1200); // Animación más lenta y suave
  
  // Colores para skeletons de canciones (deben coincidir con el tema claro)
  static Color get _songSkeletonBaseColor => NeumorphismTheme.surface.withValues(alpha: 0.6);
  static Color get _songSkeletonHighlightColor => NeumorphismTheme.beigeMedium.withValues(alpha: 0.8);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _api = ArtistsApi(ApiConfig.baseUrl);
    // Leer estado de admin una sola vez al inicio
    final currentUser = ref.read(currentUserProvider);
    _isAdmin = currentUser?.isAdmin == true;
    
    // Inicializar limpieza proactiva periódica (solo una vez, la primera vez)
    if (_cacheCleanupTimer == null) {
      _initializeProactiveCleanup();
    }
    
    // CRÍTICO: Verificar cache ANTES de cualquier otra operación para evitar parpadeo
    // Esto debe hacerse de forma síncrona para que el estado esté listo antes del primer render
    final cachedData = _artistCache[widget.artist.id];
    if (cachedData != null) {
      final lastLoadTime = cachedData['lastLoadTime'] as DateTime;
      if (!_shouldReloadCache(lastLoadTime)) {
        // Restaurar datos desde caché INMEDIATAMENTE y SINCRÓNICAMENTE (evita cualquier flash)
        // Esto debe hacerse ANTES de cualquier otra operación para evitar parpadeo
        _details = cachedData['details'] as Map<String, dynamic>?;
        _allProcessedSongs = List<_ProcessedSong>.from(
          cachedData['allProcessedSongs'] as List,
        );
        _displayedSongs = List<_ProcessedSong>.from(
          cachedData['displayedSongs'] as List,
        );
        _hasMoreSongs = cachedData['hasMoreSongs'] as bool;
        _effectiveName = cachedData['effectiveName'] as String?;
        _coverUrl = cachedData['coverUrl'] as String?;
        _profileUrl = cachedData['profileUrl'] as String?;
        _bio = cachedData['bio'] as String? ?? '';
        _nationality = cachedData['nationality'] as String?;
        _phone = cachedData['phone'] as String?;
        _flagEmoji = cachedData['flagEmoji'] as String?;
        _hasLoadedOnce = true;
        _loading = false; // CRÍTICO: Establecer loading en false ANTES de cualquier render
        
        // Actualizar fecha de acceso (LRU - mantener esta entrada como más reciente)
        _updateCacheAccessTime(widget.artist.id);
        
        // CRÍTICO: Verificar si las imágenes están realmente en cache ANTES de marcarlas como listas
        // Esto evita parpadeo al retroceder
        _checkAndPrecacheImages();
        
        // NO ejecutar ninguna otra operación si tenemos cache válido (evita parpadeo)
        return; // Salir temprano si tenemos cache válido
      } else {
        // Caché expirado, limpiar
        _artistCache.remove(widget.artist.id);
      }
    }
    
    // Solo llegar aquí si NO hay cache válido
    // Inicializar valores por defecto ANTES de establecer loading
    _initializeCalculatedValues();
    
    // CRÍTICO: Establecer loading en true SOLO si NO tenemos cache válido
    // Esto evita que se muestre skeleton loader cuando volvemos atrás con cache
    _loading = true;
    _hasLoadedOnce = false;
    
    // Resetear estados de imágenes cuando no hay cache
    _coverImageReady = false;
    _profileImageReady = false;
    
    // Limpiar cache antes de cargar (mantener siempre dentro del límite)
    _cleanOldCache();
    
    // Pre-cachear imágenes iniciales ANTES de cargar datos (evita tirón)
    _precacheInitialImages();
    
    // Diferir carga de datos al siguiente frame para evitar bloqueo del primer render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoadedOnce) {
        _load();
      }
    });
  }
  
  /// Verifica si el caché estático expiró
  bool _shouldReloadCache(DateTime cacheTime) {
    final now = DateTime.now();
    return now.difference(cacheTime) > _cacheValidDuration;
  }
  
  /// Helper para precargar una imagen individual - ELIMINA CÓDIGO DUPLICADO
  /// Marca como lista INMEDIATAMENTE para evitar sensación de carga forzada
  void _precacheSingleImage(String? imageUrl, void Function(bool) onReady) {
    if (imageUrl == null || imageUrl.isEmpty) {
      onReady(true);
      return;
    }
    
    // CRÍTICO: Marcar como lista INMEDIATAMENTE para mostrar la imagen sin delay
    // Esto evita la sensación de carga forzada y hace que la transición sea más natural
    if (mounted) {
      onReady(true);
    }
    
    // Verificar cache y precargar en segundo plano (no bloquea la UI)
    cache_service.ImageCacheManager.instance.getFileFromCache(imageUrl).then((fileInfo) {
      // Si está en cache, ya está marcada como lista, solo precargar en memoria
      precacheImage(CachedNetworkImageProvider(imageUrl), context).catchError((_) {
        // Ignorar errores
      });
    }).catchError((_) {
      // Si no está en cache, precargar desde red en segundo plano
      precacheImage(CachedNetworkImageProvider(imageUrl), context).catchError((_) {
        // Ignorar errores
      });
    });
  }
  
  /// Verifica si las imágenes están en cache y las precarga correctamente
  /// IMPLEMENTACIÓN OPTIMIZADA: Usa helper para eliminar código duplicado
  void _checkAndPrecacheImages() {
    // Precargar portada usando helper
    _precacheSingleImage(_coverUrl, (ready) {
      if (mounted) {
        setState(() {
          _coverImageReady = ready;
        });
      }
    });
    
    // Precargar avatar usando helper
    _precacheSingleImage(_profileUrl, (ready) {
      if (mounted) {
        setState(() {
          _profileImageReady = ready;
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cachear dimensiones de pantalla una sola vez (mejor que en build)
    // Asegurar que siempre tengamos valores cacheados
    if (_cachedScreenWidth == null || _cachedCoverHeight == null || _cachedDevicePixelRatio == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedScreenWidth ??= mediaQuery.size.width;
      _cachedCoverHeight ??= _cachedScreenWidth! / 2.4; // AspectRatio 2.4
      _cachedDevicePixelRatio ??= mediaQuery.devicePixelRatio;
    }
  }
  
  @override
  void dispose() {
    // Cancelar timer de debounce al dispose
    _loadMoreDebounceTimer?.cancel();
    super.dispose();
  }

  // Inicializar valores calculados con datos del widget.artist
  void _initializeCalculatedValues() {
    final artist = widget.artist;
    _effectiveName = artist.name;
    _coverUrl = UrlNormalizer.normalizeImageUrl(artist.coverPhotoUrl);
    _profileUrl = UrlNormalizer.normalizeImageUrl(artist.profilePhotoUrl);
    _nationality = artist.nationalityCode?.toUpperCase();
    _flagEmoji = _nationality != null ? _calculateFlagEmoji(_nationality!) : null;
    _bio = '';
    _phone = null;
  }

  // Actualizar valores calculados cuando llegan los detalles
  void _updateCalculatedValues() {
    final artist = widget.artist;

    // Datos efectivos: primero los del detalle, luego los del lite
    _effectiveName = (_details?['name'] as String?) ?? artist.name;
    
    final detailCover = _details?['coverPhotoUrl'] as String? ?? 
                        _details?['cover_photo_url'] as String?;
    final newCoverUrl = UrlNormalizer.normalizeImageUrl(detailCover ?? artist.coverPhotoUrl);
    // Solo actualizar si la URL realmente cambió (evita recargas innecesarias)
    if (newCoverUrl != _coverUrl) {
      _coverUrl = newCoverUrl;
    }
    
    final detailProfile = _details?['profilePhotoUrl'] as String? ?? 
                         _details?['profile_photo_url'] as String?;
    final newProfileUrl = UrlNormalizer.normalizeImageUrl(detailProfile ?? artist.profilePhotoUrl);
    // Solo actualizar si la URL realmente cambió (evita recargas innecesarias)
    if (newProfileUrl != _profileUrl) {
      _profileUrl = newProfileUrl;
    }
    
    final rawBio = ((_details?['biography'] as String?) ?? 
                   (_details?['bio'] as String?))?.trim();
    _bio = _sanitizeBio(rawBio, _isAdmin);
    
    _nationality = ((_details?['nationalityCode'] as String?) ?? 
                   (_details?['nationality_code'] as String?) ?? 
                   artist.nationalityCode)?.toUpperCase();
    _flagEmoji = _nationality != null ? _calculateFlagEmoji(_nationality!) : null;
    
    final social = (_details?['socialLinks'] as Map<String, dynamic>?) ?? 
                   (_details?['social_links'] as Map<String, dynamic>?) ?? 
                   const <String, dynamic>{};
    _phone = (social['phone'] as String?)?.trim();
    
    // Los widgets se reconstruirán automáticamente cuando cambien los datos
  }

  // Pre-cachear imágenes iniciales (del widget.artist) para evitar tirón al abrir
  // OPTIMIZADO: Usa helper para eliminar código duplicado
  void _precacheInitialImages() {
    // Precargar en segundo plano sin bloquear initState
    scheduleMicrotask(() {
      if (!mounted) return;
      
      final coverUrl = UrlNormalizer.normalizeImageUrl(widget.artist.coverPhotoUrl);
      final profileUrl = UrlNormalizer.normalizeImageUrl(widget.artist.profilePhotoUrl);
      
      // Precargar sin marcar como listas (solo para acelerar carga inicial)
      if (coverUrl != null && coverUrl.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(coverUrl), context).catchError((_) {});
      }
      if (profileUrl != null && profileUrl.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(profileUrl), context).catchError((_) {});
      }
    });
  }

  // Pre-cachear imágenes actualizadas (después de cargar detalles)
  // OPTIMIZADO: Usa helper para eliminar código duplicado
  void _precacheImages() {
    if (!mounted) return;
    
    // Usar helper para precargar ambas imágenes
    _precacheSingleImage(_coverUrl, (ready) {
      if (mounted) {
        setState(() {
          _coverImageReady = ready;
        });
      }
    });
    
    _precacheSingleImage(_profileUrl, (ready) {
      if (mounted) {
        setState(() {
          _profileImageReady = ready;
        });
      }
    });
  }

  // Cargar datos en paralelo y procesar en isolate optimizado
  Future<void> _load() async {
    if (!mounted) return;
    
    // CRÍTICO: NO establecer loading en true si ya tenemos datos del cache
    // Esto evita cualquier parpadeo al retroceder
    // Solo mostrar loading si realmente NO tenemos datos previos
    if (!_hasLoadedOnce && _displayedSongs.isEmpty && mounted) {
      setState(() => _loading = true);
    }
    
    // Pequeño delay para permitir que el primer frame se renderice sin bloqueo
    // Solo si no tenemos datos previos
    if (!_hasLoadedOnce) {
      await Future.delayed(const Duration(milliseconds: 16)); // ~1 frame a 60fps
    }
    
    if (!mounted) return;
    
    try {
      // Hacer ambas llamadas HTTP en paralelo
      final results = await Future.wait([
        _api.getById(widget.artist.id),
        _api.getSongsByArtist(widget.artist.id, limit: 50), // Reducido de 100 a 50 para mejor rendimiento inicial
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Timeout cargando datos del artista'),
      );
      
      final details = results[0] as Map<String, dynamic>;
      final songsRaw = results[1] as List<Map<String, dynamic>>;
      
      // OPTIMIZACIÓN: Procesar solo las canciones iniciales en el isolate
      // El resto se procesará de forma lazy cuando se necesiten
      final initialSongsRaw = songsRaw.take(_initialSongsLimit).toList();
      final initialProcessedSongs = await compute(_parseAndProcessSongs, initialSongsRaw);
      
      if (!mounted) return;
      
      // Guardar canciones raw para procesamiento lazy posterior
      _songsRaw = songsRaw;
      
      // Aplicar paginación inicial (ya procesadas)
      final initialSongs = initialProcessedSongs;
      final hasMore = songsRaw.length > _initialSongsLimit;
      
      // Inicializar lista completa con las procesadas iniciales y nulls para el resto
      // Esto permite procesamiento lazy cuando se necesiten
      final allProcessedSongs = <_ProcessedSong>[
        ...initialProcessedSongs,
        // El resto se procesará cuando se necesiten
      ];
      
      // Calcular valores ANTES del setState para no bloquear el UI thread
      _details = details;
      _updateCalculatedValues(); // Calcular fuera del setState
      
      // Actualizar estado una sola vez (sin cálculos pesados dentro)
      final now = DateTime.now();
      if (mounted) {
        setState(() {
          _allProcessedSongs = allProcessedSongs;
          _displayedSongs = initialSongs;
          _hasMoreSongs = hasMore;
          _loading = false;
          _hasLoadedOnce = true; // Marcar que ya se cargó
        });
      }
      
      // Guardar en caché estático para futuras navegaciones
      // Guardar también las canciones raw para procesamiento lazy
      _artistCache[widget.artist.id] = {
        'details': _details,
        'allProcessedSongs': allProcessedSongs,
        'displayedSongs': initialSongs,
        'songsRaw': _songsRaw, // Guardar raw para procesamiento lazy
        'hasMoreSongs': hasMore,
        'lastLoadTime': now,
        'effectiveName': _effectiveName,
        'coverUrl': _coverUrl,
        'profileUrl': _profileUrl,
        'bio': _bio,
        'nationality': _nationality,
        'phone': _phone,
        'flagEmoji': _flagEmoji,
      };
      
      // Limpiar cache automáticamente después de guardar (mantiene límite de 5 artistas)
      // Esto asegura que siempre tengamos máximo 5 entradas y eliminemos las más antiguas
      _cleanOldCache();
      
      // Actualizar fecha de acceso para LRU (marcar como más reciente)
      _updateCacheAccessTime(widget.artist.id);
      
      // Pre-cachear imágenes actualizadas después del setState
      _precacheImages();
    } catch (e) {
      // Error al cargar datos del artista
      if (!mounted) return;
      
      if (mounted) {
        setState(() {
          // Si ya teníamos datos, mantenerlos en caso de error
          if (!_hasLoadedOnce) {
            _details = null;
            _allProcessedSongs = [];
            _displayedSongs = [];
            _hasMoreSongs = false;
            _initializeCalculatedValues(); // Resetear a valores iniciales
          }
          _loading = false;
        });
      }
    }
  }

  // Actualizar estado de admin fuera de build() para evitar lógica compleja
  void _updateAdminState(bool newIsAdmin) {
    if (newIsAdmin != _isAdmin && _details != null) {
      // Usar WidgetsBinding para actualizar después del frame actual
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isAdmin = newIsAdmin;
            _updateCalculatedValues(); // Recalcular bio y phone con nuevo estado
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido para AutomaticKeepAliveClientMixin
    
    // CRÍTICO: Si tenemos cache válido, mostrar contenido inmediatamente sin verificaciones
    // Esto evita cualquier parpadeo al retroceder
    final hasValidCache = _hasLoadedOnce && 
                          _displayedSongs.isNotEmpty && 
                          _coverUrl != null && 
                          _profileUrl != null;
    
    if (hasValidCache) {
      // Tenemos cache válido - renderizar contenido inmediatamente SIN skeleton loaders
      final isAdmin = ref.watch(
        currentUserProvider.select((user) => user?.isAdmin == true),
      );
      _updateAdminState(isAdmin);
      final screenWidth = _cachedScreenWidth!;
      final coverHeight = _cachedCoverHeight!;
      final devicePixelRatio = _cachedDevicePixelRatio!;
      
      return Scaffold(
        key: ValueKey('artist_scaffold_${widget.artist.id}'),
        appBar: AppBar(
          title: Text(_effectiveName ?? widget.artist.name),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: CustomScrollView(
          cacheExtent: 300,
          physics: const ClampingScrollPhysics(),
          clipBehavior: Clip.none,
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(screenWidth, coverHeight, devicePixelRatio, true),
            ),
            if (_bio.isNotEmpty)
              SliverToBoxAdapter(child: _buildBiography())
            else
              SliverToBoxAdapter(child: _buildEmptyBiography()),
            if (isAdmin && _phone != null && _phone!.isNotEmpty)
              SliverToBoxAdapter(child: _buildContact()),
            SliverToBoxAdapter(child: _buildSongsHeader(true)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_displayedSongs.isEmpty)
              SliverToBoxAdapter(child: _buildEmptySongs())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= _displayedSongs.length) {
                      if (_hasMoreSongs && index == _displayedSongs.length) {
                        return _buildLoadMoreButton();
                      }
                      return null;
                    }
                    final song = _displayedSongs[index];
                    final artistName = _effectiveName ?? widget.artist.name;
                    return RepaintBoundary(
                      key: ValueKey('song_${song.song.id}'),
                      child: _buildSongRow(index, song, artistName),
                    );
                  },
                  childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      );
    }
    
    // Solo llegar aquí si NO hay cache válido
    // Usar select() para evitar rebuilds cuando solo cambia el estado de admin
    final isAdmin = ref.watch(
      currentUserProvider.select((user) => user?.isAdmin == true),
    );
    
    // Actualizar estado de admin fuera de build (optimización)
    _updateAdminState(isAdmin);

    // Usar dimensiones cacheadas (ya calculadas en didChangeDependencies) - NO recalcular en build
    final screenWidth = _cachedScreenWidth!;
    final coverHeight = _cachedCoverHeight!;
    final devicePixelRatio = _cachedDevicePixelRatio!;
    
    // Determinar si tenemos datos del cache
    final hasCacheData = _hasLoadedOnce && 
                        _displayedSongs.isNotEmpty && 
                        _coverUrl != null && 
                        _profileUrl != null;

    return Scaffold(
      key: ValueKey('artist_scaffold_${widget.artist.id}'), // Key estable para evitar rebuilds
      appBar: AppBar(
        title: Text(_effectiveName ?? widget.artist.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: CustomScrollView(
        cacheExtent: 300, // Optimizado: reducir cache de scroll para mejor rendimiento
        physics: const ClampingScrollPhysics(), // Android-style scroll
        clipBehavior: Clip.none, // Evitar clipping innecesario
        slivers: [
          // Header fijo con portada y avatar - Optimizado con skeleton loaders
          SliverToBoxAdapter(
            child: _buildHeader(screenWidth, coverHeight, devicePixelRatio, hasCacheData),
          ),
          // Biografía - Optimizado con RepaintBoundary y memoización
          if (_bio.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildBiography(),
            )
          else
            SliverToBoxAdapter(
              child: _buildEmptyBiography(),
            ),
          // Contacto (solo admin) - Optimizado con RepaintBoundary y memoización
          if (isAdmin && _phone != null && _phone!.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildContact(),
            ),
          // Título de canciones - Optimizado con skeleton loader
          SliverToBoxAdapter(
            child: _buildSongsHeader(hasCacheData),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 12),
          ),
          // Lista de canciones optimizada con skeleton loaders
          if (!hasCacheData && _loading)
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
              child: _buildEmptySongs(),
            )
          else
            // SliverList optimizado para tarjetas mejoradas
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Botón "Ver más" al final
                  if (index >= _displayedSongs.length) {
                    if (_hasMoreSongs && index == _displayedSongs.length) {
                      return _buildLoadMoreButton();
                    }
                    return null;
                  }
                  
                  final song = _displayedSongs[index];
                  final artistName = _effectiveName ?? widget.artist.name;
                  
                  return RepaintBoundary(
                    key: ValueKey('song_${song.song.id}'),
                    child: _buildSongRow(
                      index,
                      song,
                      artistName,
                    ),
                  );
                },
                childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ), // Ya es const
        ],
      ),
    );
  }

  // Construir header RECONSTRUIDO - Sin parpadeo al retroceder
  Widget _buildHeader(double screenWidth, double coverHeight, double devicePixelRatio, bool hasCacheData) {
    return RepaintBoundary(
      key: _headerKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PORTADA: Nueva implementación sin parpadeo
          AspectRatio(
            aspectRatio: 2.4,
            child: _buildCoverImage(screenWidth, coverHeight, devicePixelRatio, hasCacheData),
          ),
          // AVATAR Y NOMBRE: Nueva implementación sin parpadeo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: _buildProfileAvatar(hasCacheData),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildArtistName(hasCacheData),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Construir imagen de portada SIN parpadeo
  Widget _buildCoverImage(double screenWidth, double coverHeight, double devicePixelRatio, bool hasCacheData) {
    // Si tenemos cache y la imagen está lista, mostrar directamente sin skeleton
    if (hasCacheData && _coverImageReady && _coverUrl != null && _coverUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de portada - Sin placeholder cuando hay cache
          Image(
            image: CachedNetworkImageProvider(_coverUrl!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              // Si el frame está disponible, mostrar directamente sin fade
              if (frame != null) {
                return child;
              }
              // Si no hay frame pero tenemos cache, mostrar placeholder transparente
              return Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildCoverSkeleton();
            },
          ),
          // Overlay con gradiente
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Si NO tenemos cache o la imagen no está lista, usar OptimizedImage con skeleton
    if (!hasCacheData || !_coverImageReady || _coverUrl == null || _coverUrl!.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Mostrar skeleton solo si realmente no tenemos datos
          if (!hasCacheData && _coverUrl == null)
            _buildCoverSkeleton()
          else
            OptimizedImage(
              key: ValueKey('artist_cover_${widget.artist.id}_${_coverUrl ?? 'null'}'),
              imageUrl: _coverUrl,
              fit: BoxFit.cover,
              isLargeCover: true,
              maxCacheWidth: (screenWidth * devicePixelRatio).toInt(),
              maxCacheHeight: (coverHeight * devicePixelRatio).toInt(),
              skipFade: true, // Sin fade para carga más natural (evita sensación forzada)
            ),
          // Overlay con gradiente
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Fallback: skeleton
    return _buildCoverSkeleton();
  }
  
  // Construir avatar de perfil SIN parpadeo
  Widget _buildProfileAvatar(bool hasCacheData) {
    // Si tenemos cache y la imagen está lista, mostrar directamente sin skeleton
    if (hasCacheData && _profileImageReady && _profileUrl != null && _profileUrl!.isNotEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: OptimizedImage(
            key: ValueKey('artist_profile_${widget.artist.id}_${_profileUrl}'),
            imageUrl: _profileUrl,
            fit: BoxFit.cover,
            width: 72,
            height: 72,
            skipFade: true, // Sin fade cuando hay cache (evita parpadeo)
          ),
        ),
      );
    }
    
    // Si NO tenemos cache o la imagen no está lista, usar OptimizedImage con skeleton
    if (!hasCacheData || !_profileImageReady || _profileUrl == null || _profileUrl!.isEmpty) {
      if (!hasCacheData && _profileUrl == null) {
        return _buildAvatarSkeleton();
      }
      
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: OptimizedImage(
            key: ValueKey('artist_profile_${widget.artist.id}_${_profileUrl ?? 'null'}'),
            imageUrl: _profileUrl,
            fit: BoxFit.cover,
            width: 72,
            height: 72,
            skipFade: true, // Sin fade para carga más natural (evita sensación forzada)
          ),
        ),
      );
    }
    
    // Fallback: skeleton
    return _buildAvatarSkeleton();
  }
  
  // Construir nombre del artista
  Widget _buildArtistName(bool hasCacheData) {
    if (!hasCacheData && _effectiveName == null) {
      return _buildNameSkeleton();
    }
    
    return Row(
      children: [
        Expanded(
          child: Text(
            _effectiveName ?? widget.artist.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_flagEmoji != null) ...[
          const SizedBox(width: 8),
          Text(
            _flagEmoji!,
            style: const TextStyle(fontSize: 22),
          ),
        ],
      ],
    );
  }
  
  /// Widget skeleton para la portada del artista - Colores del tema claro
  Widget _buildCoverSkeleton() {
    return Shimmer.fromColors(
      baseColor: _shimmerBaseColor,
      highlightColor: _shimmerHighlightColor,
      period: _shimmerDuration,
      direction: ShimmerDirection.ltr,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: _shimmerBaseColor, // Color del tema claro
        ),
      ),
    );
  }
  
  /// Widget skeleton para el avatar del artista - Colores del tema claro
  /// CRÍTICO: Debe tener exactamente las mismas dimensiones y decoración que el avatar real
  Widget _buildAvatarSkeleton() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3), // Mismo borde que el avatar real
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Shimmer.fromColors(
          baseColor: _shimmerBaseColor,
          highlightColor: _shimmerHighlightColor,
          period: _shimmerDuration,
          direction: ShimmerDirection.ltr,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _shimmerBaseColor, // Color del tema claro
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
  
  /// Widget skeleton para el nombre del artista - Colores del tema claro
  /// CRÍTICO: Debe tener exactamente la misma estructura y altura que el texto real (fontSize: 22)
  Widget _buildNameSkeleton() {
    // Calcular altura exacta: fontSize (22) * lineHeight (1.0 por defecto) = 22px
    // Con fontWeight.w700, usar 24px para estar seguro
    const textHeight = 24.0;
    return Row(
      children: [
        Expanded(
          child: Shimmer.fromColors(
            baseColor: _shimmerBaseColor,
            highlightColor: _shimmerHighlightColor,
            period: _shimmerDuration,
            direction: ShimmerDirection.ltr,
            child: Container(
              height: textHeight, // Misma altura que el texto real
              width: double.infinity, // Usar todo el ancho disponible como el texto real
              decoration: BoxDecoration(
                color: NeumorphismTheme.textPrimary.withValues(alpha: 0.15), // Color del tema claro
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        // No mostrar skeleton del flagEmoji ya que no sabemos si habrá uno
      ],
    );
  }
  
  /// Widget skeleton para botones (play all) - Colores del tema claro
  /// CRÍTICO: Debe tener exactamente las mismas dimensiones que el botón real
  /// Botón real: padding EdgeInsets.symmetric(horizontal: 16, vertical: 8)
  /// Icono: 18px, Texto: fontSize 14, SizedBox: 6px
  /// Altura aproximada: 8 + max(18, 14*1.2) + 8 ≈ 36px
  Widget _buildPlayAllButtonSkeleton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20), // Mismo borderRadius que el botón real
      ),
      child: Shimmer.fromColors(
        baseColor: _shimmerBaseColor,
        highlightColor: _shimmerHighlightColor,
        period: _shimmerDuration,
        direction: ShimmerDirection.ltr,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Mismo padding que el botón real
          decoration: BoxDecoration(
            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2), // Color del tema claro
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18, // Mismo tamaño que el icono real
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6), // Mismo espacio que el botón real
              Container(
                height: 14, // Mismo fontSize que el texto real
                width: 100, // Ancho aproximado del texto "Reproducir todo"
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Widget skeleton para fila de canción - Coincide con el tamaño y estilo de las tarjetas reales
  Widget _buildSongRowSkeleton() {
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
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: _songSkeletonBaseColor,
        highlightColor: _songSkeletonHighlightColor,
        period: _shimmerDuration,
        direction: ShimmerDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Mismo padding que las tarjetas reales
          child: Row(
            children: [
              // Número de posición skeleton - CRÍTICO: Mismo tamaño que el texto real (fontSize: 16)
              Container(
                width: 32,
                alignment: Alignment.center, // Mismo alignment que el real
                child: Container(
                  height: 16, // Mismo fontSize que el texto real
                  width: 20, // Ancho aproximado para números de 1-2 dígitos
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Portada skeleton (64x64) - CRÍTICO: Exactamente igual al real
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
                  color: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 16),
              // Información skeleton - CRÍTICO: Mismas alturas que los textos reales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Título skeleton - fontSize: 17, fontWeight.w700
                    Container(
                      height: 17, // Mismo fontSize que el texto real
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.textPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6), // Mismo espacio que el real
                    // Artista skeleton - fontSize: 14, fontWeight.w500
                    Row(
                      children: [
                        Container(
                          width: 14, // Mismo tamaño que el icono real
                          height: 14,
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4), // Mismo espacio que el real
                        Container(
                          height: 14, // Mismo fontSize que el texto real
                          width: 120,
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.textSecondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Duración skeleton - fontSize: 12
              Container(
                width: 40,
                height: 12, // Mismo fontSize que el texto real
                decoration: BoxDecoration(
                  color: NeumorphismTheme.textSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              // Botón play skeleton - CRÍTICO: Mismo tamaño que el botón real (44x44)
              Container(
                width: 44, // Mismo tamaño que el botón real
                height: 44,
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
                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Construir biografía optimizada
  Widget _buildBiography() {
    return RepaintBoundary(
      key: _biographyKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Biografía',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _bio,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // Construir biografía vacía optimizada
  Widget _buildEmptyBiography() {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Biografía',
              style: AppTextStyles.sectionTitle,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Sin biografía',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // Construir contacto optimizado
  Widget _buildContact() {
    return RepaintBoundary(
      key: _contactKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Contacto',
              style: AppTextStyles.sectionTitle,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  _phone!,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // Construir header de canciones optimizado con skeleton loader
  Widget _buildSongsHeader(bool hasCacheData) {
    return RepaintBoundary(
      key: _songsHeaderKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Canciones',
              style: AppTextStyles.sectionTitle,
            ),
            if (!hasCacheData && _loading)
              _buildPlayAllButtonSkeleton()
            else if (_allProcessedSongs.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      NeumorphismTheme.coffeeMedium,
                      NeumorphismTheme.coffeeDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
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
                    onTap: _onPlayAll,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Reproducir todo',
                            style: TextStyle(
                              fontSize: 14,
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
          ],
        ),
      ),
    );
  }

  // Construir mensaje de canciones vacías
  Widget _buildEmptySongs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.music_off, color: Colors.black45),
          SizedBox(width: 8),
          Text(
            'Este artista aún no tiene canciones subidas',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // Memoizar emojis de banderas para evitar recálculos
  static final Map<String, String> _flagEmojiCache = {};
  
  String _calculateFlagEmoji(String code) {
    if (code.length != 2) return '🏳️';
    // Usar caché para evitar recálculos
    return _flagEmojiCache.putIfAbsent(code, () {
      final cc = code.toUpperCase();
      final runes = cc.runes.map((c) => 0x1F1E6 - 65 + c).toList();
      return String.fromCharCodes(runes);
    });
  }

  Future<void> _loadMoreSongs() async {
    // Protección: evitar múltiples llamadas simultáneas
    if (_loadingMore || !_hasMoreSongs) return;
    
    // Debounce: cancelar timer anterior si existe
    _loadMoreDebounceTimer?.cancel();
    
    // Crear nuevo timer para ejecutar después del debounce
    _loadMoreDebounceTimer = Timer(_loadMoreDebounceDuration, () {
      _performLoadMore();
    });
  }
  
  /// Ejecuta la carga de más canciones después del debounce
  Future<void> _performLoadMore() async {
    if (_loadingMore || !_hasMoreSongs || !mounted) return;

    if (mounted) {
      setState(() => _loadingMore = true);
    }

    // Simular delay mínimo para mejor UX
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    final currentCount = _displayedSongs.length;
    
    // OPTIMIZACIÓN: Procesar solo las canciones necesarias de forma lazy
    List<_ProcessedSong> nextBatch;
    
    if (_songsRaw.isNotEmpty && currentCount < _songsRaw.length) {
      // Procesar el siguiente batch desde las canciones raw
      final startIndex = currentCount;
      final endIndex = (currentCount + _loadMoreSongsLimit).clamp(0, _songsRaw.length);
      
      // Procesar en isolate solo las canciones necesarias
      final params = (
        songsRaw: _songsRaw,
        start: startIndex,
        end: endIndex,
      );
      final processedBatch = await compute(_parseAndProcessSongsRange, params);
      
      nextBatch = processedBatch;
      
      // Agregar a la lista completa de procesadas
      _allProcessedSongs = [..._allProcessedSongs, ...processedBatch];
    } else {
      // Fallback: usar las ya procesadas (si no hay raw disponibles)
      nextBatch = _allProcessedSongs.skip(currentCount).take(_loadMoreSongsLimit).toList();
    }
    
    final hasMore = _songsRaw.isNotEmpty
        ? currentCount + nextBatch.length < _songsRaw.length
        : currentCount + nextBatch.length < _allProcessedSongs.length;

    if (!mounted) return;

    if (mounted) {
      setState(() {
        _displayedSongs = [..._displayedSongs, ...nextBatch];
        _hasMoreSongs = hasMore;
        _loadingMore = false;
      });
    }
  }

  String _sanitizeBio(String? bio, bool isAdmin) {
    if (bio == null || bio.trim().isEmpty) return '';
    if (isAdmin) return bio.trim();
    // Ocultar posibles líneas de teléfono para usuarios no admin
    final lines = bio.split('\n');
    final filtered = lines.where((line) {
      final l = line.toLowerCase().trim();
      final hasTelWord = l.startsWith('tel') || l.contains('tel:');
      final hasManyDigits = RegExp(r'(?:\+?\d[\s-]?){8,}').hasMatch(l);
      return !(hasTelWord || hasManyDigits);
    }).toList();
    return filtered.join('\n').trim();
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: const Text(
                  'Ver más canciones',
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

  Widget _buildSongRow(int index, _ProcessedSong processedSong, String artistName) {
    final song = processedSong.song;
    final coverUrl = processedSong.normalizedCoverUrl;
    
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
            blurRadius: 8, // Reducido de 15 a 8 para mejor rendimiento
            offset: const Offset(0, 3), // Reducido de 5 a 3
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Navegar a la pantalla de detalles de la canción (igual que featured_songs_screen)
            SongDetailScreen.navigateToSong(context, song);
          },
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
                    child: OptimizedImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 64,
                      borderRadius: 16,
                      useThumbnail: true, // Usar thumbnail para carga más rápida
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
                        song.title ?? 'Sin título',
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
                              song.artist?.stageName ?? 
                              song.artist?.displayName ?? 
                              artistName,
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

  void _onPlayAll() async {
    // Protección: evitar múltiples llamadas simultáneas
    if (_isPlayAllInProgress) return;
    
    if (!mounted) return;
    
    _isPlayAllInProgress = true;
    
    try {
      final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
      final messenger = ScaffoldMessenger.of(context);
      
      // OPTIMIZACIÓN: Procesar todas las canciones solo si no están todas procesadas
      List<Song> allSongs;
      
      if (_songsRaw.isNotEmpty && _allProcessedSongs.length < _songsRaw.length) {
        // Procesar todas las canciones restantes de forma lazy
        final startIndex = _allProcessedSongs.length;
        final params = (
          songsRaw: _songsRaw,
          start: startIndex,
          end: _songsRaw.length,
        );
        final remainingProcessed = await compute(_parseAndProcessSongsRange, params);
        
        // Actualizar lista completa
        _allProcessedSongs = [..._allProcessedSongs, ...remainingProcessed];
        
        // Extraer todas las canciones
        allSongs = _allProcessedSongs.map((ps) => ps.song).toList();
      } else {
        // Ya están todas procesadas o no hay raw disponibles
        allSongs = _allProcessedSongs.map((ps) => ps.song).toList();
      }
      
      if (allSongs.isEmpty) {
        _isPlayAllInProgress = false;
        return;
      }
      
      // Reproducir primera canción inmediatamente
      AppLogger.info('[ArtistPage] 🎵 Reproduciendo todas las canciones del artista desde el inicio');
      await audioNotifier.playSong(allSongs.first);
      
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Reproduciendo todas las canciones de ${widget.artist.name} (${allSongs.length} canciones)'),
          backgroundColor: NeumorphismTheme.coffeeMedium,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      _isPlayAllInProgress = false;
    }
  }
}
