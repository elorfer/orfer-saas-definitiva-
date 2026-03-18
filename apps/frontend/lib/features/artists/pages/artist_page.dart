import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
import 'package:flutter/scheduler.dart';
import '../../../core/config/api_config.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/artist_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/providers/playback_state.dart';
import '../../../core/providers/secondary_screens_scroll_provider.dart';
import '../../../core/utils/logger.dart';
import '../../artists/services/artists_api.dart';
import '../models/artist.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/follow_button.dart';
import '../../../core/providers/follow_provider.dart';
import '../../../core/utils/number_formatter.dart';
// ✅ OPTIMIZACIÓN: GoogleFonts removido - usando estilos constantes para mejor rendimiento
import '../../../core/widgets/verified_badge.dart';
import '../../../core/utils/intersection_observer.dart';

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
List<_ProcessedSong> _parseAndProcessSongs(List<Map<String, dynamic>> songsRaw) {
  // Procesar JSON y normalizar campos
  final songs = songsRaw.map((e) {
    // ✅ Normalizar campos: el backend puede devolver camelCase o snake_case
    final normalizedJson = <String, dynamic>{...e};
    
    // Normalizar fileUrl (verificar ambas variantes)
    if (normalizedJson['file_url'] != null && normalizedJson['fileUrl'] == null) {
      normalizedJson['fileUrl'] = normalizedJson['file_url'];
    }
    if (normalizedJson['fileUrl'] != null && normalizedJson['file_url'] == null) {
      normalizedJson['file_url'] = normalizedJson['fileUrl'];
    }
    
    // Normalizar coverArtUrl (verificar ambas variantes)
    if (normalizedJson['cover_art_url'] != null && normalizedJson['coverArtUrl'] == null) {
      normalizedJson['coverArtUrl'] = normalizedJson['cover_art_url'];
    }
    if (normalizedJson['coverArtUrl'] != null && normalizedJson['cover_art_url'] == null) {
      normalizedJson['cover_art_url'] = normalizedJson['coverArtUrl'];
    }
    
    // ✅ LOG: Verificar que los datos están presentes
    if (kDebugMode && normalizedJson['fileUrl'] == null && normalizedJson['file_url'] == null) {
      debugPrint('⚠️ [ArtistPage] Canción sin fileUrl: ${normalizedJson['id']} - ${normalizedJson['title']}');
    }
    if (kDebugMode && normalizedJson['coverArtUrl'] == null && normalizedJson['cover_art_url'] == null) {
      debugPrint('⚠️ [ArtistPage] Canción sin coverArtUrl: ${normalizedJson['id']} - ${normalizedJson['title']}');
    }
    
    return Song.fromJson(normalizedJson);
  }).toList();
  
  // Pre-procesar URLs normalizadas
  return songs.map((song) {
    final normalizedUrl = song.coverArtUrl != null
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    return _ProcessedSong(
      song: song,
      normalizedCoverUrl: normalizedUrl,
    );
  }).toList();
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
  List<_ProcessedSong> _allProcessedSongs = []; // Todas las canciones
  List<_ProcessedSong> _displayedSongs = []; // Canciones mostradas (paginadas)
  bool _hasMoreSongs = false;
  bool _loadingMore = false;
  bool _hasLoadedOnce = false; // Flag para saber si ya se cargó una vez
  DateTime? _lastLoadTime; // Timestamp de última carga
  
  // Cache estático para mantener datos entre navegaciones (evita parpadeo)
  // Estructura: { artistId: { 'details': ..., 'songs': ..., 'lastLoad': ... } }
  static final Map<String, Map<String, dynamic>> _artistCache = {};
  
  // Limpiar caché antiguo periódicamente (evitar acumulación de memoria)
  static void _cleanOldCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _artistCache.forEach((key, value) {
      final lastLoad = value['lastLoadTime'] as DateTime?;
      if (lastLoad != null && now.difference(lastLoad) > _cacheValidDuration) {
        expiredKeys.add(key);
      }
    });
    
    // Limpiar solo si hay más de 10 entradas (optimización)
    if (_artistCache.length > 10) {
      for (final key in expiredKeys) {
        _artistCache.remove(key);
      }
    }
  }
  
  static const int _initialSongsLimit = 20;
  static const int _loadMoreSongsLimit = 20;
  static const Duration _cacheValidDuration = Duration(minutes: 5); // Cache válido por 5 minutos

  // Variables calculadas una sola vez cuando cambian los datos
  String? _effectiveName;
  String? _coverUrl;
  String? _profileUrl;
  String _bio = '';
  String? _nationality;
  String? _phone;
  String? _flagEmoji;
  bool _isAdmin = false; // Cachear estado de admin
  
  // ✅ Estado local para el conteo de seguidores (actualización optimista)
  int _localFollowersCount = 0;
  
  // Cachear dimensiones de pantalla para evitar recálculos
  double? _cachedScreenWidth;
  double? _cachedCoverHeight;
  double? _cachedDevicePixelRatio;
  
  // Timer para debounce en botones de play
  Timer? _playSongDebounce;
  Timer? _playAllDebounce;
  static const Duration _debounceDuration = Duration(milliseconds: 300);
  
  // 🔥 OPTIMIZACIÓN: ScrollController para precache dinámico de imágenes (como en Home)
  late final ScrollController _scrollController;
  
  // 🔥 PERSISTENCIA: Guardar posición inicial para restaurar después del primer frame
  double? _savedInitialScrollPosition;
  bool _hasRestoredInitialScroll = false;
  
  // ✅ OPTIMIZACIÓN: Cache de URLs de imágenes para evitar recálculos en _onScroll
  List<String> _cachedImageUrls = [];
  int _cachedSongsCount = 0;
  
  // ✅ OPTIMIZACIÓN: Timer para debounce en _onScroll
  Timer? _scrollDebounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _api = ArtistsApi(ApiConfig.baseUrl);
    
    // 🔥 PERSISTENCIA: Restaurar scroll position desde Provider (más robusto)
    final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
    final savedPosition = scrollNotifier.getScrollPosition('artist_page_${widget.artist.id}');
    
    // También intentar desde PageStorage como backup
    final pageStoragePosition = PageStorage.of(context).readState(
      context, 
      identifier: PageStorageKey<String>('artist_page_scroll_${widget.artist.id}')
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
    
    _scrollController.addListener(_onScroll);
    // 🔥 PERSISTENCIA: Guardar posición del scroll cuando cambia
    _scrollController.addListener(_saveScrollPosition);
    
    // Leer estado de admin una sola vez al inicio
    final currentUser = ref.read(currentUserProvider);
    
    // Cargar artistas seguidos al inicializar (si está autenticado)
    if (currentUser != null) {
      Future.microtask(() {
        final notifier = ref.read(followProvider.notifier);
        notifier.loadFollowedArtists();
        // ✅ CRÍTICO: Verificar estado específico de ESTE artista inmediatamente para evitar falsos negativos
        notifier.syncArtistStatus(widget.artist.id);
      });
    }
    _isAdmin = currentUser?.isAdmin == true;
    
    // Intentar cargar desde caché estático primero (evita parpadeo)
    final cachedData = _artistCache[widget.artist.id];
    if (cachedData != null) {
      final lastLoadTime = cachedData['lastLoadTime'] as DateTime;
      if (!_shouldReloadCache(lastLoadTime)) {
        // Restaurar datos desde caché inmediatamente (optimizado con casting directo)
        _details = cachedData['details'] as Map<String, dynamic>?;
        _allProcessedSongs = List<_ProcessedSong>.from(
          cachedData['allProcessedSongs'] as List,
        );
        _displayedSongs = List<_ProcessedSong>.from(
          cachedData['displayedSongs'] as List,
        );
        _hasMoreSongs = cachedData['hasMoreSongs'] as bool;
        // ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando se cargan desde cache
        _updateImageUrlsCache();
        _lastLoadTime = lastLoadTime;
        _effectiveName = cachedData['effectiveName'] as String?;
        _coverUrl = cachedData['coverUrl'] as String?;
        _profileUrl = cachedData['profileUrl'] as String?;
        _bio = cachedData['bio'] as String? ?? '';
        _nationality = cachedData['nationality'] as String?;
        _phone = cachedData['phone'] as String?;
        _flagEmoji = cachedData['flagEmoji'] as String?;
        // ✅ CRÍTICO: Restaurar contador de seguidores desde caché
        _localFollowersCount = cachedData['localFollowersCount'] as int? ?? widget.artist.totalFollowers;
        _hasLoadedOnce = true;
        // NO mostrar loading si tenemos datos en caché
      } else {
        // Caché expirado, inicializar valores por defecto
        _initializeCalculatedValues();
        _artistCache.remove(widget.artist.id); // Limpiar caché expirado
      }
    } else {
      // No hay caché, inicializar valores por defecto
      _initializeCalculatedValues();
    }
    
    // Pre-cachear imágenes iniciales ANTES de cargar datos (evita tirón)
    _precacheInitialImages();
    
    // Diferir carga de datos al siguiente frame para evitar bloqueo del primer render
    // Solo cargar si no tenemos datos en caché o si el cache expiró
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (!_hasLoadedOnce || _shouldReload()) {
          _load();
        }
      }
    });
  }
  
  /// Verifica si el caché estático expiró
  bool _shouldReloadCache(DateTime cacheTime) {
    final now = DateTime.now();
    return now.difference(cacheTime) > _cacheValidDuration;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cachear dimensiones de pantalla una sola vez (mejor que en build)
    if (_cachedScreenWidth == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedScreenWidth = mediaQuery.size.width;
      _cachedCoverHeight = _cachedScreenWidth! / 1.2; // ✅ AspectRatio 1.2 (Aún más alto/inmersivo)
      _cachedDevicePixelRatio = mediaQuery.devicePixelRatio;
    }
  }
  
  /// Verifica si debe recargar los datos (cache expirado)
  bool _shouldReload() {
    if (_lastLoadTime == null) return true;
    final now = DateTime.now();
    return now.difference(_lastLoadTime!) > _cacheValidDuration;
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

  /// 🔥 PERSISTENCIA: Guardar posición del scroll en Provider (persistente) y PageStorage (backup)
  void _saveScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final position = _scrollController.offset;
    if (position < 0) return;
    
    final screenKey = 'artist_page_${widget.artist.id}';
    
    // 🔥 PERSISTENCIA: Guardar en Provider (persistente incluso si el widget se destruye)
    final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
    scrollNotifier.saveScrollPosition(screenKey, position);
    
    // También guardar en PageStorage como backup
    try {
      PageStorage.of(context).writeState(
        context,
        position,
        identifier: PageStorageKey<String>('artist_page_scroll_${widget.artist.id}'),
      );
    } catch (e) {
      // Ignorar errores de PageStorage
    }
  }

  @override
  void dispose() {
    // Cancelar timers de debounce al destruir el widget
    _playSongDebounce?.cancel();
    _playAllDebounce?.cancel();
    _scrollDebounceTimer?.cancel();
    
    // 🔥 CRÍTICO: Guardar posición final antes de destruir (sin debounce)
    if (_scrollController.hasClients) {
      final finalPosition = _scrollController.offset;
      if (finalPosition >= 0) {
        final screenKey = 'artist_page_${widget.artist.id}';
        final scrollNotifier = ref.read(secondaryScreensScrollProvider.notifier);
        scrollNotifier.saveScrollPosition(screenKey, finalPosition);
      }
    }
    
    // 🔥 OPTIMIZACIÓN: Limpiar ScrollController
    _scrollController.removeListener(_onScroll);
    _scrollController.removeListener(_saveScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }
  
  /// ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambian los datos
  void _updateImageUrlsCache() {
    _cachedImageUrls = _displayedSongs
        .map((ps) => ps.normalizedCoverUrl ?? ps.song.coverArtUrl)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    _cachedSongsCount = _displayedSongs.length;
  }
  
  /// 🔥 OPTIMIZACIÓN: Precargar imágenes visibles cuando el usuario hace scroll (como en Home)
  /// ✅ CORRECCIÓN: Agregado debounce para evitar ejecuciones excesivas
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients || _displayedSongs.isEmpty) return;
    
    // ✅ OPTIMIZACIÓN: Cancelar timer anterior si existe
    _scrollDebounceTimer?.cancel();
    
    // ✅ OPTIMIZACIÓN: Debounce de 300ms para evitar ejecuciones excesivas
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_scrollController.hasClients || _displayedSongs.isEmpty) return;
      
      try {
        // ✅ OPTIMIZACIÓN: Usar URLs cacheadas en lugar de leer de _displayedSongs cada vez
        if (_cachedImageUrls.isEmpty) {
          // Si no hay cache, actualizar desde _displayedSongs (solo una vez)
          _updateImageUrlsCache();
        }
        
        // Precachear imágenes visibles basado en posición del scroll (IntersectionObserver)
        if (_cachedImageUrls.isNotEmpty) {
          LazyImageLoader.precacheVisibleVerticalImages(
            scrollController: _scrollController,
            itemExtent: 80.0, // Altura estimada de cada item (ajustar según diseño real)
            itemCount: _cachedSongsCount,
            imageUrls: _cachedImageUrls,
            context: context,
            precacheCount: 5, // Precachear 5 items antes y después del viewport
          );
        }
      } catch (e) {
        // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente para no bloquear la app
        debugPrint('[ArtistPage] Error en _onScroll: $e');
      }
    });
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
    _localFollowersCount = artist.totalFollowers; // ✅ Inicializar conteo local
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
    
    // ✅ Actualizar conteo con datos frescos del servidor
    // ✅ Actualizar conteo con datos frescos del servidor
    final serverFollowers = (_details?['totalFollowers'] as int?) ?? 
                           (_details?['total_followers'] as int?);
                           
    if (serverFollowers != null) {
       _localFollowersCount = serverFollowers;
    } else if (_localFollowersCount == 0) {
       // Si el detalle no trajo seguidores, mantener el valor original del objeto artista
       _localFollowersCount = artist.totalFollowers;
    }
    
    // Los widgets se reconstruirán automáticamente cuando cambien los datos
  }

  // ✅ Callback para actualizar el conteo localmente al pulsar seguir
  void _handleFollowToggle() {
    // El provider ya se actualizó en FollowButton, leemos el nuevo estado
    final isFollowing = ref.read(followProvider).isFollowing(widget.artist.id);
    
    if (mounted) {
      setState(() {
        if (isFollowing) {
          _localFollowersCount++;
        } else {
          if (_localFollowersCount > 0) _localFollowersCount--;
        }
      });
    }
  }

  // 🔥 OPTIMIZACIÓN: Pre-cachear imágenes iniciales usando LazyImageLoader (como en Home)
  void _precacheInitialImages() {
    final imageUrls = <String?>[];
    
    // Agregar portada
    if (widget.artist.coverPhotoUrl != null && widget.artist.coverPhotoUrl!.isNotEmpty) {
      final coverUrl = UrlNormalizer.normalizeImageUrl(widget.artist.coverPhotoUrl);
      if (coverUrl != null && coverUrl.isNotEmpty) {
        imageUrls.add(coverUrl);
      }
    }
    
    // Agregar avatar
    if (widget.artist.profilePhotoUrl != null && widget.artist.profilePhotoUrl!.isNotEmpty) {
      final profileUrl = UrlNormalizer.normalizeImageUrl(widget.artist.profilePhotoUrl);
      if (profileUrl != null && profileUrl.isNotEmpty) {
        imageUrls.add(profileUrl);
      }
    }
    
    // Precachear usando LazyImageLoader
    if (imageUrls.isNotEmpty) {
      scheduleMicrotask(() {
        if (mounted) {
          LazyImageLoader.precacheInitialImages(
            imageUrls: imageUrls,
            context: context,
            count: imageUrls.length,
          );
        }
      });
    }
  }

  // 🔥 OPTIMIZACIÓN: Pre-cachear imágenes actualizadas usando LazyImageLoader (como en Home)
  void _precacheImages() {
    if (!mounted) return;
    
    final imageUrls = <String?>[];
    
    // Pre-cachear portada grande (mejora tiempo de apertura)
    // Solo si la URL es diferente a la inicial para evitar recargas innecesarias
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      final initialCoverUrl = UrlNormalizer.normalizeImageUrl(widget.artist.coverPhotoUrl);
      // Solo pre-cachear si la URL cambió
      if (_coverUrl != initialCoverUrl) {
        imageUrls.add(_coverUrl);
      }
    }
    
    // Pre-cachear avatar
    // Solo si la URL es diferente a la inicial
    if (_profileUrl != null && _profileUrl!.isNotEmpty) {
      final initialProfileUrl = UrlNormalizer.normalizeImageUrl(widget.artist.profilePhotoUrl);
      // Solo pre-cachear si la URL cambió
      if (_profileUrl != initialProfileUrl) {
        imageUrls.add(_profileUrl);
      }
    }
    
    // Precachear primeras canciones visibles
    final initialSongUrls = _displayedSongs
        .take(5)
        .map((ps) => ps.normalizedCoverUrl ?? ps.song.coverArtUrl)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    imageUrls.addAll(initialSongUrls);
    
    // Precachear usando LazyImageLoader
    if (imageUrls.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          LazyImageLoader.precacheInitialImages(
            imageUrls: imageUrls,
            context: context,
            count: imageUrls.length,
          );
        }
      });
    }
  }

  // Cargar datos en paralelo y procesar en isolate optimizado
  Future<void> _load() async {
    if (!mounted) return;
    
    // Los datos se cargan de forma asíncrona y el estado se actualiza cuando están listos
    
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
        _api.getSongsByArtist(widget.artist.id, limit: 100), // Cargar más para paginación
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Timeout cargando datos del artista'),
      );
      
      final details = results[0] as Map<String, dynamic>;
      final songsRaw = results[1] as List<Map<String, dynamic>>;
      
      // ✅ LOG: Verificar datos recibidos
      if (kDebugMode) {
        debugPrint('📥 [ArtistPage] Canciones recibidas: ${songsRaw.length}');
        if (songsRaw.isNotEmpty) {
          final firstSong = songsRaw.first;
          debugPrint('📥 [ArtistPage] Primera canción keys: ${firstSong.keys.join(", ")}');
          debugPrint('📥 [ArtistPage] file_url: ${firstSong['file_url']}');
          debugPrint('📥 [ArtistPage] fileUrl: ${firstSong['fileUrl']}');
          debugPrint('📥 [ArtistPage] cover_art_url: ${firstSong['cover_art_url']}');
          debugPrint('📥 [ArtistPage] coverArtUrl: ${firstSong['coverArtUrl']}');
        }
      }
      
      // Procesar JSON y URLs en un solo isolate (optimizado)
      final allProcessedSongs = await compute(_parseAndProcessSongs, songsRaw);
      
      // ✅ LOG: Verificar canciones procesadas
      if (kDebugMode) {
        debugPrint('✅ [ArtistPage] Canciones procesadas: ${allProcessedSongs.length}');
        for (var i = 0; i < allProcessedSongs.length && i < 3; i++) {
          final ps = allProcessedSongs[i];
          debugPrint('  ${i + 1}. ${ps.song.title} - fileUrl: ${ps.song.fileUrl != null ? "✅" : "❌"} - coverUrl: ${ps.song.coverArtUrl != null ? "✅" : "❌"}');
        }
      }
      
      if (!mounted) return;
      
      // Aplicar paginación inicial
      final initialSongs = allProcessedSongs.take(_initialSongsLimit).toList();
      final hasMore = allProcessedSongs.length > _initialSongsLimit;
      
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
          _hasLoadedOnce = true; // Marcar que ya se cargó
          _lastLoadTime = now; // Guardar timestamp de carga
        });
        // ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambian los datos
        _updateImageUrlsCache();
      }
      
      // Guardar en caché estático para futuras navegaciones
      _artistCache[widget.artist.id] = {
        'details': _details,
        'allProcessedSongs': allProcessedSongs,
        'displayedSongs': initialSongs,
        'hasMoreSongs': hasMore,
        'lastLoadTime': now,
        'effectiveName': _effectiveName,
        'coverUrl': _coverUrl,
        'profileUrl': _profileUrl,
        'bio': _bio,
        'nationality': _nationality,
        'phone': _phone,
        'flagEmoji': _flagEmoji,
        // ✅ CRÍTICO: Guardar contador de seguidores en caché
        'localFollowersCount': _localFollowersCount,
      };
      
      // Limpiar caché antiguo periódicamente (solo si hay muchas entradas)
      if (_artistCache.length > 10) {
        _cleanOldCache();
      }
      
      // Pre-cachear imágenes actualizadas después del setState
      _precacheImages();
    } catch (e) {
      // Error al cargar datos del artista
      if (!mounted) return;
      
      // ✅ MEJORA: Logging más específico del error
      AppLogger.error('[ArtistPage] Error al cargar datos del artista ${widget.artist.id}: $e', e is Error ? StackTrace.current : null);
      
      if (mounted) {
        setState(() {
          // Si ya teníamos datos, mantenerlos en caso de error
          if (!_hasLoadedOnce) {
            _details = null;
            _allProcessedSongs = [];
            _displayedSongs = [];
            _hasMoreSongs = false;
            _initializeCalculatedValues(); // Resetear a valores iniciales
            // ✅ OPTIMIZACIÓN: Limpiar cache de URLs cuando hay error
            _cachedImageUrls = [];
            _cachedSongsCount = 0;
          }
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

  // ✅ Pull to refresh method
  Future<void> _handleRefresh() async {
    // 1. Remove from static cache
    _artistCache.remove(widget.artist.id);
    
    // 2. Reset local state
    setState(() {
      _hasLoadedOnce = false;
      _lastLoadTime = null;
      _allProcessedSongs = [];
      _displayedSongs = [];
    });
    
    // 3. Reload data
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido para AutomaticKeepAliveClientMixin
    
    // Usar select() para evitar rebuilds cuando solo cambia el estado de admin
    final isAdmin = ref.watch(
      currentUserProvider.select((user) => user?.isAdmin == true),
    );
    
    // Actualizar estado de admin fuera de build (optimización)
    _updateAdminState(isAdmin);

    // 🚀 Refresh on Theme Change
    ref.watch(themeProvider);

    // Usar dimensiones cacheadas (ya calculadas en didChangeDependencies)
    final screenWidth = _cachedScreenWidth ?? MediaQuery.of(context).size.width;
    final coverHeight = _cachedCoverHeight ?? (screenWidth / 2.4);
    final devicePixelRatio = _cachedDevicePixelRatio ?? MediaQuery.of(context).devicePixelRatio;

    // 🚀 OPTIMIZACIÓN 60 FPS: RepaintBoundary y const donde sea posible
    return RepaintBoundary(
      child: Scaffold(
        key: const ValueKey('artist_page_scaffold'),
        // ✅ AppBar ELIMINADO para diseño inmersivo full screen
        extendBodyBehindAppBar: true, 
        // appBar: removed
        body: Container(
          decoration: BoxDecoration(
            gradient: NeumorphismTheme.backgroundGradient,
          ),
          child: SafeArea(
            top: false, // ✅ Contenido detrás del status bar
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Colors.white,
              backgroundColor: NeumorphismTheme.coffeeMedium,
              child: CustomScrollView(
                key: PageStorageKey<String>('artist_page_scroll_${widget.artist.id}'),
              controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache dinámico
              // 🔥 OPTIMIZADO: cacheExtent reducido para mejor rendimiento con grandes listas
              // Mantiene solo ~5 items fuera de vista (400px / ~80px por item)
              cacheExtent: 400, // Reducido de 1000 a 400 para mejor rendimiento
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ), // ✅ Scroll estilo iPhone (igual que Home)
              // Optimizar scroll con mejor rendimiento
              clipBehavior: Clip.none, // Evitar clipping innecesario
              slivers: [
              // ✅ Espacio superior y botón de retroceso
              // ✅ Header fijo con portada y avatar - Optimizado con RepaintBoundary y memoización
              SliverToBoxAdapter(
                child: !_hasLoadedOnce 
                    ? _buildHeaderSkeleton(screenWidth, coverHeight)
                    : _buildHeader(screenWidth, coverHeight, devicePixelRatio),
              ),
          // Biografía - Optimizado con RepaintBoundary y memoización
          if (!_hasLoadedOnce)
            SliverToBoxAdapter(
              child: _buildBiographySkeleton(),
            )
          else if (_bio.isNotEmpty)
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
          // Título de canciones - Optimizado con RepaintBoundary y memoización
          SliverToBoxAdapter(
            child: _buildSongsHeader(),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 12),
          ),
          // Lista de canciones optimizada con diseño de "recientemente escuchadas"
          if (!_hasLoadedOnce)
            // ✅ Skeleton loader mientras carga
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildSongSkeleton(),
                  childCount: 5, // Mostrar 5 skeletons
                  // 🔥 OPTIMIZACIONES PARA GRANDES VOLÚMENES:
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  addSemanticIndexes: false, // Desactivar índices semánticos (mejor rendimiento)
                ),
              ),
            )
          else if (_displayedSongs.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptySongs(),
            )
          else
            // SliverPadding para agregar padding horizontal como en "recientemente escuchadas"
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverFixedExtentList(
                itemExtent: 80.0, // ✅ Revertido a 80.0 (más compacto)
                delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Botón "Ver más" al final
                  if (index >= _displayedSongs.length) {
                    if (_hasMoreSongs && index == _displayedSongs.length) {
                      return _buildLoadMoreButton();
                    }
                    return null;
                  }
                  
                  // Item de canción
                  final song = _displayedSongs[index];
                  
                  return RepaintBoundary(
                    key: ValueKey('song_${song.song.id}'),
                    child: _SongRowWidget(
                      key: ValueKey('song_row_${song.song.id}'),
                      index: index,
                      processedSong: song,
                      artistId: widget.artist.id, // ✅ Pasar artistId para verificar contexto
                      onPlaySong: (song, {normalizedCoverUrl}) => _onPlaySong(song, normalizedCoverUrl: normalizedCoverUrl),
                    ),
                  );
                },
                childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
                // 🔥 OPTIMIZACIONES PARA GRANDES VOLÚMENES:
                addAutomaticKeepAlives: false, // Ya usamos AutomaticKeepAliveClientMixin (no mantener vivos items fuera de vista)
                addRepaintBoundaries: false, // Ya agregamos RepaintBoundary manualmente (evita duplicación)
                addSemanticIndexes: false, // Desactivar índices semánticos (mejor rendimiento)
              ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
          // ✅ Padding inferior para que el mini player no tape la última canción
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 120),
          ),
        ],
          ), // Cierra CustomScrollView
            ), // Cierra RefreshIndicator
          ), // Cierra SafeArea
        ), // Cierra Container
      ),
    );
  }

  // Construir header optimizado
  Widget _buildHeader(double screenWidth, double coverHeight, double devicePixelRatio) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Portada
          AspectRatio(
            aspectRatio: 1.2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Usar OptimizedImage con isLargeCover para mejor rendimiento
                // Key estable basado en URL para evitar recargas innecesarias
                OptimizedImage(
                  key: ValueKey('artist_cover_${widget.artist.id}_${_coverUrl ?? 'null'}'),
                  imageUrl: _coverUrl,
                  fit: BoxFit.cover,
                  isLargeCover: true,
                  maxCacheWidth: (screenWidth * devicePixelRatio).toInt(),
                  maxCacheHeight: (coverHeight * devicePixelRatio).toInt(),
                  skipFade: true, // ✅ Evitar fade que puede causar líneas visibles
                  lazyLoad: false, // Portada principal - cargar inmediatamente
                ),
                // Overlay con gradiente para mejor legibilidad
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
                // ✅ Botón de retroceso sobre la portada (overlay)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: _BackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
          // Avatar e información del artista - Completamente debajo de la portada
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 8.0), // Padding original restaurado
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar al lado izquierdo
                Container(
                    width: 120, // Aumentado de 100 a 120
                    height: 120, // Aumentado de 100 a 120
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      // boxShadow removido para performance
                    ),
                    child: ClipOval(
                      child: OptimizedImage(
                        key: ValueKey('artist_profile_${widget.artist.id}_${_profileUrl ?? 'null'}'),
                        imageUrl: _profileUrl,
                        fit: BoxFit.cover,
                        width: 120, // Aumentado de 100 a 120
                        height: 120, // Aumentado de 100 a 120
                        lazyLoad: false, // Avatar principal - cargar inmediatamente
                      ),
                    ),
                  ),
                const SizedBox(width: 10), // Reducido de 14 a 10
                // Información a la derecha del avatar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila: Nombre, badge de verificación y bandera
                      const SizedBox(height: 8), // Baja el nombre/badge/bandera 8 píxeles
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _effectiveName ?? widget.artist.name,
                              style: const TextStyle(
                                fontSize: 24, // Aumentado de 22 a 24
                                fontWeight: FontWeight.w600, // Semi-bold
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Badge de verificación
                          Builder(
                            builder: (context) {
                              final isVerified = (_details?['isVerified'] as bool?) ?? 
                                                (_details?['is_verified'] as bool?) ??
                                                (_details?['verificationStatus'] as bool?) ??
                                                (_details?['verification_status'] as bool?) ??
                                                false;
                              if (isVerified) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 4), // Reducido de 6 a 4
                                  child: SizedBox(
                                    width: 20.0, // Tamaño fijo para evitar movimiento
                                    height: 20.0, // Tamaño fijo para evitar movimiento
                                    child: VerifiedBadge(
                                      size: 20,
                                      showTooltip: true,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          if (_flagEmoji != null) ...[
                            const SizedBox(width: 8), // Aumentado de 4 a 8 para separar más la bandera
                            Text(
                              _flagEmoji!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2), // Mantenido para no mover los seguidores
                      // Número de seguidores
                      Builder(
                        builder: (context) {
                          // ✅ Usar estado local actualizado
                          final totalFollowers = _localFollowersCount;
                          
                          if (totalFollowers > 0) {
                            final followerText = totalFollowers == 1 ? 'seguidor' : 'seguidores';
                            return Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: NumberFormatter.format(totalFollowers),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: NeumorphismTheme.isDark ? NeumorphismTheme.accent : const Color(0xFF5D4037),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' $followerText',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: NeumorphismTheme.textSecondary,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 0), // Mantenido en 0 para no mover el botón
                      // Botón de seguir - Más pequeño
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FollowButton(
                          artistId: widget.artist.id,
                          onToggle: _handleFollowToggle, // ✅ Conectar callback para actualizar contador
                          width: 85.0, // Reducido de 95 a 85
                          height: 28.0, // Reducido de 32 a 28
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }

  // Construir biografía optimizada - Más compacta
  Widget _buildBiography() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Biografía',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4), // Reducido de 6 a 4
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _bio,
              style: TextStyle(fontSize: 14, color: NeumorphismTheme.textPrimary),
            ),
          ),
          const SizedBox(height: 8), // Reducido de 12 a 8
        ],
      );
  }

  // Construir biografía vacía optimizada
  Widget _buildEmptyBiography() {
    return Column(
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
              'Sin biografía',
              style: TextStyle(fontSize: 14, color: NeumorphismTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
  }

  // Construir contacto optimizado
  Widget _buildContact() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Contacto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.phone, size: 16, color: NeumorphismTheme.textSecondary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _phone!,
                    style: TextStyle(fontSize: 14, color: NeumorphismTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
  }

  // Construir header de canciones optimizado
  Widget _buildSongsHeader() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Canciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // ✅ OPTIMIZACIÓN: Widget separado con RepaintBoundary para evitar rebuilds innecesarios
            // ✅ OPTIMIZACIÓN: Eliminado Opacity costoso. Si no hay canciones, no mostrar nada.
            if (_allProcessedSongs.isNotEmpty)
              _PlayAllButton(
                artistId: widget.artist.id,
                onTap: _onPlayAll,
              ),
          ],
        ),
      );
  }

  // Construir mensaje de canciones vacías
  Widget _buildEmptySongs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.music_off, color: NeumorphismTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Este artista aún no tiene canciones subidas',
            style: TextStyle(color: NeumorphismTheme.textSecondary),
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
    if (_loadingMore || !_hasMoreSongs) return;

    if (mounted) {
      setState(() => _loadingMore = true);
    }

    // Simular delay mínimo para mejor UX
    await Future.delayed(const Duration(milliseconds: 100));

    final currentCount = _displayedSongs.length;
    final nextBatch = _allProcessedSongs.skip(currentCount).take(_loadMoreSongsLimit).toList();
    final hasMore = currentCount + nextBatch.length < _allProcessedSongs.length;

    if (!mounted) return;

    if (mounted) {
      setState(() {
        _displayedSongs = [..._displayedSongs, ...nextBatch];
        _hasMoreSongs = hasMore;
        _loadingMore = false;
      });
      // ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambian los datos
      _updateImageUrlsCache();
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
                child: Text(
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

  // Helper para asegurar que la canción tenga el artista completo
  Song _ensureSongHasArtist(Song song, {String? normalizedCoverUrl}) {
    // Si ya tiene artista con stageName, no hacer nada
    if (song.artist != null && song.artist!.stageName != null && song.artist!.stageName!.isNotEmpty) {
      return song;
    }
    
    // Crear artista con la información del widget
    final artist = Artist(
      id: widget.artist.id,
      stageName: _effectiveName ?? widget.artist.name,
      profilePhotoUrl: _profileUrl,
      coverPhotoUrl: _coverUrl,
      bio: _bio.isNotEmpty ? _bio : null,
      verificationStatus: false, // ArtistLite no tiene esta propiedad
      totalStreams: 0, // ArtistLite no tiene esta propiedad
      totalFollowers: 0, // ArtistLite no tiene esta propiedad
      monthlyListeners: 0, // ArtistLite no tiene esta propiedad
    );
    
    // ✅ Usar URL normalizada pasada como parámetro, o normalizar si no está disponible
    final finalCoverUrl = normalizedCoverUrl ?? 
        (song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
            ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
            : null);
    
    // Crear nueva canción con el artista incluido
    return Song(
      id: song.id,
      artistId: song.artistId ?? widget.artist.id,
      albumId: song.albumId,
      title: song.title,
      duration: song.duration,
      fileUrl: song.fileUrl != null ? UrlNormalizer.normalizeUrl(song.fileUrl!) : null, // ✅ Normalizar URL para IP de red local
      coverArtUrl: finalCoverUrl, // ✅ Usar URL normalizada (preferir la pasada)
      lyrics: song.lyrics,
      genreId: song.genreId,
      genres: song.genres,
      trackNumber: song.trackNumber,
      status: song.status,
      isExplicit: song.isExplicit,
      releaseDate: song.releaseDate,
      totalStreams: song.totalStreams,
      totalLikes: song.totalLikes,
      totalShares: song.totalShares,
      featured: song.featured,
      createdAt: song.createdAt,
      updatedAt: song.updatedAt,
      artist: artist,
    );
  }

  void _onPlaySong(Song song, {String? normalizedCoverUrl}) async {
    // ✅ VALIDACIÓN TEMPRANA: Verificar que la canción tenga fileUrl antes de intentar reproducir
    if (song.fileUrl == null || song.fileUrl!.isEmpty) {
      return;
    }

    // ✅ Verificar si es la canción actual - si es pausa, ejecutar inmediatamente sin debounce
    final container = ProviderScope.containerOf(context);
    final audioState = container.read(unifiedAudioProviderFixed);
    final audioNotifier = container.read(unifiedAudioProviderFixed.notifier);
    final isCurrentSong = audioState.currentSong?.id == song.id;
    final isPlaying = audioState.isPlaying;
    
    // Si es pausar la canción actual, ejecutar inmediatamente
    if (isCurrentSong && isPlaying) {
      audioNotifier.togglePlayPause();
      return;
    }

    // Debounce: cancelar acción anterior si existe
    _playSongDebounce?.cancel();
    
    // Crear nuevo timer con debounce (reducido para mejor respuesta)
    _playSongDebounce = Timer(const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      
      try {
        // ✅ Asegurar que la canción tenga la información del artista completa
        // ✅ Pasar la URL normalizada de la portada si está disponible
        final songWithArtist = _ensureSongHasArtist(song, normalizedCoverUrl: normalizedCoverUrl);
        
        // Verificar nuevamente el fileUrl después de asegurar el artista
        if (songWithArtist.fileUrl == null || songWithArtist.fileUrl!.isEmpty) {
          return;
        }
        
        // ✅ Verificar que la portada esté presente antes de reproducir
        AppLogger.info('[ArtistPage] 🎵 Reproduciendo canción desde tarjeta (algoritmo): ${songWithArtist.title}');
        AppLogger.info('[ArtistPage] 🖼️ Portada: ${songWithArtist.coverArtUrl ?? "NO DISPONIBLE"}');
        
        // ✅ DESDE TARJETAS: Usar playFromCard para activar modo ALGORITMO (recomendaciones)
        // Esto permite que el algoritmo recomiende otros artistas
        await audioNotifier.playFromCard(songWithArtist, useAlgorithm: true);
      } catch (error) {
        AppLogger.error('[ArtistPage] Error al reproducir canción: $error');
      }
    });
  }
  
  void _onPlayAll() async {
    // ✅ DEBOUNCE: Cancelar acción anterior si existe para evitar múltiples activaciones
    _playAllDebounce?.cancel();
    
    // ✅ Solo proceder si el usuario toca explícitamente el botón
    if (_allProcessedSongs.isEmpty) return;
    
    // Crear nuevo timer con debounce
    _playAllDebounce = Timer(_debounceDuration, () async {
      if (!mounted) return;
      
      // Filtrar solo canciones con fileUrl válido
      final validSongs = _allProcessedSongs
          .where((ps) => ps.song.fileUrl != null && ps.song.fileUrl!.isNotEmpty)
          .map((ps) => _ensureSongHasArtist(ps.song))
          .toList();
      
      if (validSongs.isEmpty) {
        // No mostrar notificación - el usuario puede ver que no hay canciones disponibles
        return;
      }
      
      final container = ProviderScope.containerOf(context);
      final audioNotifier = container.read(unifiedAudioProviderFixed.notifier);
      
      try {
        AppLogger.info('[ArtistPage] 🎵 Reproduciendo ${validSongs.length} canciones del artista');
        // ✅ Usar onPressPlayAll() con contextId del artista
        await audioNotifier.onPressPlayAll(
          validSongs.first,
          widget.artist.id,
          allSongs: validSongs,
        );
        
        // SnackBar eliminado para mejor UX
      } catch (error) {
        // Error silencioso - el usuario puede ver el estado en el mini player
      }
    });
  }

  // ✅ Skeleton loader para el header - OPTIMIZADO: Más liviano (Static colors)
  Widget _buildHeaderSkeleton(double screenWidth, double coverHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Portada skeleton
        AspectRatio(
          aspectRatio: 1.2,
          child: Container(
            color: NeumorphismTheme.shimmerBaseColor,
          ),
        ),
        // Avatar y nombre skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NeumorphismTheme.shimmerBaseColor,
                  border: Border.all(
                    color: NeumorphismTheme.isDark ? Colors.transparent : Colors.white, 
                    width: 3
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: screenWidth * 0.5,
                      height: 24,
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.shimmerBaseColor,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Skeleton loader para la biografía - OPTIMIZADO: Más liviano (Static colors)
  Widget _buildBiographySkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Container(
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              color: NeumorphismTheme.shimmerBaseColor,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
          ),
          const SizedBox(height: 6),
          // Líneas de texto
          ...List.generate(2, (index) => Padding(
            padding: EdgeInsets.only(bottom: index < 1 ? 8 : 0),
            child: Container(
              width: double.infinity,
              height: 16,
              decoration: BoxDecoration(
                color: NeumorphismTheme.shimmerBaseColor,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
            ),
          )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ✅ Skeleton loader para tarjetas de canciones - OPTIMIZADO: Más liviano (Static colors)
  Widget _buildSongSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Número skeleton
            Container(
              width: 32,
              height: 20,
              decoration: BoxDecoration(
                color: NeumorphismTheme.shimmerBaseColor,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
            ),
            const SizedBox(width: 12),
            // Portada skeleton
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: NeumorphismTheme.shimmerBaseColor,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                    height: 18,
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.shimmerBaseColor,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.shimmerBaseColor,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Botón play skeleton
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: NeumorphismTheme.shimmerBaseColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ OPTIMIZACIÓN: Widget separado para botón "Reproducir todo" con RepaintBoundary
/// Evita rebuilds innecesarios del Scaffold completo cuando cambia el estado de reproducción
class _PlayAllButton extends ConsumerWidget {
  final String artistId;
  final VoidCallback onTap;

  const _PlayAllButton({
    required this.artistId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Solo escuchar las propiedades específicas que necesitamos
    final contextId = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.contextId),
    );
    final playbackMode = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.playbackMode),
    );
    final isPlaying = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlaying),
    );
    final currentSong = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong),
    );
    
    // ✅ VERIFICACIÓN ESTRICTA: Solo mostrar pausa si:
    // 1. Está en el contexto correcto (mismo artista)
    // 2. Está en modo fixedQueue (playlist)
    // 3. Está reproduciendo
    // 4. La canción actual pertenece al artista (verificación adicional)
    final isSameContext = contextId == artistId &&
                         playbackMode == PlaybackMode.fixedQueue;
    final currentSongBelongsToArtist = currentSong?.artistId == artistId ||
                                       currentSong?.artist?.id == artistId;
    final showPause = isSameContext && 
                     isPlaying && 
                     currentSongBelongsToArtist;
    
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark ? NeumorphismTheme.accent : NeumorphismTheme.coffeeMedium,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: NeumorphismTheme.isDark ? NeumorphismTheme.coffeeDark : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Reproducir todo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NeumorphismTheme.isDark ? NeumorphismTheme.coffeeDark : Colors.white,
                    ),
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

/// Widget para la fila de canción con el mismo diseño que "recientemente escuchadas"
class _SongRowWidget extends ConsumerWidget {
  final int index;
  final _ProcessedSong processedSong;
  final String artistId; // ✅ ArtistId para verificar contexto
  final Function(Song, {String? normalizedCoverUrl}) onPlaySong;

  const _SongRowWidget({
    super.key,
    required this.index,
    required this.processedSong,
    required this.artistId,
    required this.onPlaySong,
  });

  // ⚡ OPTIMIZACIÓN CRÍTICA: Estilos estáticos para evitar re-computación
  // Los TextStyle se recomputaban en CADA build de CADA item de la lista
  // Ahora se calculan una sola vez y se reusan
  static TextStyle? _cachedSongTitleStyle;
  static TextStyle? _cachedSongNumberStyle;
  static TextStyle? _cachedSongNumberStyleDisabled;
  
  static TextStyle get _songTitleStyle {
    return _cachedSongTitleStyle ??= TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: NeumorphismTheme.textPrimary,
      fontFamily: 'Inter',
    );
  }
  
  static TextStyle get _songNumberStyle {
    return _cachedSongNumberStyle ??= TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: NeumorphismTheme.textSecondary,
      fontFamily: 'Inter',
    );
  }
  
  static TextStyle get _songNumberStyleDisabled {
    return _cachedSongNumberStyleDisabled ??= TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
      fontFamily: 'Inter',
    );
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = processedSong.song;
    
    // ✅ Verificar si la canción está disponible para reproducir
    final isAvailable = song.fileUrl != null && song.fileUrl!.isNotEmpty;
    
    // ✅ GRANULAR REBUILDS: Solo reconstruir si cambia el estado de ESTA canción
    final isCurrent = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong?.id == song.id)
    );
    final isPlaying = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlaying)
    );

    // Color base para el texto/contenido (con o sin opacidad según disponibilidad)
    final contentOpacity = isAvailable ? 1.0 : 0.5;

    final playingIcon = SizedBox(
      width: 28, // ✅ Ancho fijo igual al ícono de play para evitar saltos
      height: 28,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: (isCurrent && isPlaying)
              ? MiniEqualizer(
                  key: ValueKey('eq_${song.id}'),
                  size: 22,
                  color: NeumorphismTheme.coffeeMedium.withValues(alpha: contentOpacity),
                  active: true,
                )
              : Icon(Icons.play_circle_filled,
                  key: ValueKey('play_${song.id}'),
                  color: NeumorphismTheme.coffeeMedium.withValues(alpha: contentOpacity),
                  size: 28),
        ),
      ),
    );

    // ⚡ OPTIMIZACIÓN CRÍTICA: Sin Container, sin BoxDecoration, sin borders
    // Solo InkWell + Padding (igual que playlist) = MUCHO más rápido
    return InkWell(
      onTap: isAvailable
          ? () {
              // ✅ Tocar la  = reproducir (igual que el botón play)
              onPlaySong(song);
            }
          : null, // Deshabilitar tap si no está disponible
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // ⚡ Similar a playlist
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // ✅ Alineación vertical centrada explícita
          children: [
              // Número de posición
            SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: (isAvailable 
                      ? _songNumberStyle 
                      : _songNumberStyleDisabled).copyWith(
                        color: (isAvailable 
                          ? _songNumberStyle.color 
                          : _songNumberStyleDisabled.color)
                          ?.withValues(alpha: isAvailable ? 1.0 : 0.5)
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 16), // ⚡ Similar a playlist
            // Portada optimizada con Overlay en lugar de Opacity
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)), // ⚡ Menos redondeado = más rápido
              child: Stack(
                children: [
                  processedSong.normalizedCoverUrl != null
                      ? OptimizedImage(
                          imageUrl: processedSong.normalizedCoverUrl,
                          width: 56, // ⚡ Tamaño de playlist (48 -> 56)
                          height: 56,
                          fit: BoxFit.cover,
                          isLargeCover: false,
                          maxCacheWidth: 112,
                          maxCacheHeight: 112,
                          useThumbnail: true,
                          skipFade: true,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                          child: const Icon(Icons.music_note, color: Colors.white30),
                        ),
                  // Overlay para simular opacidad (más barato que Opacity widget)
                  if (!isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: NeumorphismTheme.surface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16), // ⚡ Más espacio
            // ✅ TÍTULO - Expanded para empujar el botón
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title ?? 'Sin título',
                    style: (isAvailable 
                        ? _songTitleStyle 
                        : _songTitleStyle.copyWith(
                            color: NeumorphismTheme.textPrimary.withValues(alpha: 0.6),
                          )).copyWith(
                            color: (isAvailable 
                              ? _songTitleStyle.color 
                              : NeumorphismTheme.textPrimary.withValues(alpha: 0.6))
                              ?.withValues(alpha: contentOpacity)
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isAvailable) ...[
                    const SizedBox(height: 4),
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.orange.withValues(alpha: 0.7 * contentOpacity),
                    ),
                  ],
                ],
              ),
            ),
            // Spacer eliminado - Expanded hace el trabajo
            playingIcon,
          ],
        ),
      ),
    );
  }
}

/// Mini ecualizador ligero (3 barras) para indicar canción en reproducción.
/// ⚡ OPTIMIZADO: RepaintBoundary por barra + animación más lenta
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
      duration: const Duration(milliseconds: 800), // ⚡ Más lento = menos repaints (650ms -> 800ms)
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
          // ⚡ OPTIMIZACIÓN CRÍTICA: RepaintBoundary por cada barra
          // Esto evita que las 3 barras se repinten juntas constantemente
          return Expanded(
            child: RepaintBoundary(
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
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: NeumorphismTheme.background,
        shape: BoxShape.circle,
        // boxShadow removido
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(8), // ✅ Reducido de 12 a 8 para botón más pequeño
            child: Icon(
              Icons.arrow_back_rounded,
              color: NeumorphismTheme.textPrimary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
