import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
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
  // Normalizar datos antes de parsear (igual que en favoritos)
  final normalizedSongs = songsRaw.map((e) => DataNormalizer.normalizeSong(e)).toList();
  
  // Procesar JSON
  final songs = normalizedSongs.map((e) => Song.fromJson(e)).toList();
  
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
  bool _loading = true;
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
  
  // Cachear dimensiones de pantalla para evitar recálculos
  double? _cachedScreenWidth;
  double? _cachedCoverHeight;
  double? _cachedDevicePixelRatio;
  
  // Timer para debounce en botones de play
  Timer? _playSongDebounce;
  
  static const Duration _debounceDuration = Duration(milliseconds: 300);
  
  // Keys estables para evitar reconstrucciones innecesarias
  final _headerKey = GlobalKey();
  final _biographyKey = GlobalKey();
  final _contactKey = GlobalKey();
  final _songsHeaderKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _api = ArtistsApi(ApiConfig.baseUrl);
    // Leer estado de admin una sola vez al inicio
    final currentUser = ref.read(currentUserProvider);
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
        _lastLoadTime = lastLoadTime;
        _effectiveName = cachedData['effectiveName'] as String?;
        _coverUrl = cachedData['coverUrl'] as String?;
        _profileUrl = cachedData['profileUrl'] as String?;
        _bio = cachedData['bio'] as String? ?? '';
        _nationality = cachedData['nationality'] as String?;
        _phone = cachedData['phone'] as String?;
        _flagEmoji = cachedData['flagEmoji'] as String?;
        _hasLoadedOnce = true;
        _loading = false; // NO mostrar loading si tenemos datos en caché
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
      _cachedCoverHeight = _cachedScreenWidth! / 2.4; // AspectRatio 2.4
      _cachedDevicePixelRatio = mediaQuery.devicePixelRatio;
    }
  }
  
  /// Verifica si debe recargar los datos (cache expirado)
  bool _shouldReload() {
    if (_lastLoadTime == null) return true;
    final now = DateTime.now();
    return now.difference(_lastLoadTime!) > _cacheValidDuration;
  }

  @override
  void dispose() {
    // Cancelar timers de debounce al destruir el widget
    _playSongDebounce?.cancel();
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
  void _precacheInitialImages() {
    // Pre-cachear inmediatamente las imágenes que ya tenemos del widget.artist
    // Esto evita el tirón al abrir la pantalla
    if (widget.artist.coverPhotoUrl != null && widget.artist.coverPhotoUrl!.isNotEmpty) {
      final coverUrl = UrlNormalizer.normalizeImageUrl(widget.artist.coverPhotoUrl);
      if (coverUrl != null && coverUrl.isNotEmpty) {
        // Usar scheduleMicrotask para no bloquear el initState
        scheduleMicrotask(() {
          if (mounted) {
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
    
    if (widget.artist.profilePhotoUrl != null && widget.artist.profilePhotoUrl!.isNotEmpty) {
      final profileUrl = UrlNormalizer.normalizeImageUrl(widget.artist.profilePhotoUrl);
      if (profileUrl != null && profileUrl.isNotEmpty) {
        scheduleMicrotask(() {
          if (mounted) {
            precacheImage(
              CachedNetworkImageProvider(profileUrl),
              context,
            ).catchError((_) {
              // Ignorar errores de pre-cache
            });
          }
        });
      }
    }
  }

  // Pre-cachear imágenes actualizadas (después de cargar detalles)
  // Solo se ejecuta cuando realmente se cargan nuevos datos
  void _precacheImages() {
    if (!mounted) return;
    
    // Pre-cachear portada grande (mejora tiempo de apertura)
    // Solo si la URL es diferente a la inicial para evitar recargas innecesarias
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      final initialCoverUrl = UrlNormalizer.normalizeImageUrl(widget.artist.coverPhotoUrl);
      // Solo pre-cachear si la URL cambió
      if (_coverUrl != initialCoverUrl) {
        // Diferir al siguiente frame para no bloquear
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            precacheImage(
              CachedNetworkImageProvider(_coverUrl!),
              context,
            ).catchError((_) {
              // Ignorar errores de pre-cache
            });
          }
        });
      }
    }
    
    // Pre-cachear avatar
    // Solo si la URL es diferente a la inicial
    if (_profileUrl != null && _profileUrl!.isNotEmpty) {
      final initialProfileUrl = UrlNormalizer.normalizeImageUrl(widget.artist.profilePhotoUrl);
      // Solo pre-cachear si la URL cambió
      if (_profileUrl != initialProfileUrl) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            precacheImage(
              CachedNetworkImageProvider(_profileUrl!),
              context,
            ).catchError((_) {
              // Ignorar errores de pre-cache
            });
          }
        });
      }
    }
  }

  // Cargar datos en paralelo y procesar en isolate optimizado
  Future<void> _load() async {
    if (!mounted) return;
    
    // Solo mostrar loading si NO tenemos datos previos (evita parpadeo al volver)
    if (!_hasLoadedOnce && mounted) {
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
        _api.getSongsByArtist(widget.artist.id, limit: 100), // Cargar más para paginación
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Timeout cargando datos del artista'),
      );
      
      final details = results[0] as Map<String, dynamic>;
      final songsRaw = results[1] as List<Map<String, dynamic>>;
      
      // Procesar JSON y URLs en un solo isolate (optimizado)
      final allProcessedSongs = await compute(_parseAndProcessSongs, songsRaw);
      
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
          _loading = false;
          _hasLoadedOnce = true; // Marcar que ya se cargó
          _lastLoadTime = now; // Guardar timestamp de carga
        });
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
    
    // Usar select() para evitar rebuilds cuando solo cambia el estado de admin
    final isAdmin = ref.watch(
      currentUserProvider.select((user) => user?.isAdmin == true),
    );
    
    // Actualizar estado de admin fuera de build (optimización)
    _updateAdminState(isAdmin);

    // Usar dimensiones cacheadas (ya calculadas en didChangeDependencies)
    final screenWidth = _cachedScreenWidth ?? MediaQuery.of(context).size.width;
    final coverHeight = _cachedCoverHeight ?? (screenWidth / 2.4);
    final devicePixelRatio = _cachedDevicePixelRatio ?? MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      appBar: AppBar(
        title: Text(_effectiveName ?? widget.artist.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: CustomScrollView(
        cacheExtent: 1000, // Aumentado para mejor scroll performance (más agresivo)
        physics: const ClampingScrollPhysics(), // Android-style scroll
        // Optimizar scroll con mejor rendimiento
        clipBehavior: Clip.none, // Evitar clipping innecesario
        slivers: [
          // Header fijo con portada y avatar - Optimizado con RepaintBoundary y memoización
          SliverToBoxAdapter(
            child: _buildHeader(screenWidth, coverHeight, devicePixelRatio),
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
          // Título de canciones - Optimizado con RepaintBoundary y memoización
          SliverToBoxAdapter(
            child: _buildSongsHeader(),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 12),
          ),
          // Lista de canciones optimizada con SliverFixedExtentList
          if (_displayedSongs.isEmpty)
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
                // Optimizaciones adicionales del delegate
                addAutomaticKeepAlives: false, // Ya usamos AutomaticKeepAliveClientMixin
                addRepaintBoundaries: false, // Ya agregamos RepaintBoundary manualmente
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  // Construir header optimizado
  Widget _buildHeader(double screenWidth, double coverHeight, double devicePixelRatio) {
    return RepaintBoundary(
      key: _headerKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera con portada y overlay
          AspectRatio(
            aspectRatio: 2.4,
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
              ],
            ),
          ),
          // Avatar superpuesto y nombre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
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
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
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
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Loading indicator - Solo mostrar si realmente estamos cargando por primera vez
          if (_loading && !_hasLoadedOnce) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            const SizedBox(height: 12),
          ],
        ],
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
              style: Theme.of(context).textTheme.titleMedium,
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
              style: Theme.of(context).textTheme.titleMedium,
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

  // Construir header de canciones optimizado
  Widget _buildSongsHeader() {
    return RepaintBoundary(
      key: _songsHeaderKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Canciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_allProcessedSongs.isNotEmpty)
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
          onTap: () => _onPlaySong(song),
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
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Portada con efecto de elevación
                Hero(
                  tag: 'artist_song_cover_${song.id}',
                  child: Container(
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
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: coverUrl != null
                          ? SizedBox(
                              width: 64,
                              height: 64,
                              child: Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                repeat: ImageRepeat.noRepeat,
                              // Optimización: cargar imagen de forma asíncrona sin bloquear scroll
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) return child;
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  child: child,
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                // Placeholder simple sin CircularProgressIndicator para mejor rendimiento
                                return Container(
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
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
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
                                );
                              },
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
                        style: GoogleFonts.inter(
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
                          Icon(
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
                              style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: NeumorphismTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                // Botón de play circular marrón (como en la foto)
                Container(
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
                      onTap: () => _onPlaySong(song),
                      borderRadius: BorderRadius.circular(22),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
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
    );
  }

  void _onPlaySong(Song song) async {
    // Debounce: cancelar acción anterior si existe
    _playSongDebounce?.cancel();
    
    // Crear nuevo timer con debounce
    _playSongDebounce = Timer(_debounceDuration, () async {
      if (!mounted) return;
      
      final container = ProviderScope.containerOf(context);
      final audioNotifier = container.read(unifiedAudioProviderFixed.notifier);
      final messenger = ScaffoldMessenger.of(context);
      
      try {
        // Validar que la canción tenga fileUrl antes de reproducir
        if (song.fileUrl == null || song.fileUrl!.isEmpty) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error: La canción "${song.title ?? "Canción"}" no tiene archivo de audio disponible'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        
        // Usar provider unificado corregido - reproducir canción específica
        AppLogger.info('[ArtistPage] 🎵 Reproduciendo canción: ${song.title}');
        AppLogger.info('[ArtistPage] 🎵 File URL: ${song.fileUrl}');
        await audioNotifier.playSong(song);
        
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Reproduciendo ${song.title ?? "Canción"}'),
            backgroundColor: NeumorphismTheme.coffeeMedium,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        AppLogger.error('[ArtistPage] Error al reproducir: $error');
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
  
  void _onPlayAll() async {
    if (_allProcessedSongs.isEmpty) return;
    
    final container = ProviderScope.containerOf(context);
    final audioNotifier = container.read(unifiedAudioProviderFixed.notifier);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      // Usar provider unificado corregido - reproducir primera canción
      final allSongs = _allProcessedSongs.map((ps) => ps.song).toList();
      if (allSongs.isNotEmpty) {
        AppLogger.info('[ArtistPage] 🎵 Reproduciendo todas las canciones del artista desde el inicio');
        await audioNotifier.playSong(allSongs.first);
        
        // TODO: Implementar contexto de playlist completa en el provider unificado
      }
      
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al reproducir: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
