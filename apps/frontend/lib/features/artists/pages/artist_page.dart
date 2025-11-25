import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/api_config.dart';
import '../../../core/models/song_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/professional_audio_provider.dart';
import '../../artists/services/artists_api.dart';
import '../models/artist.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/network_image_with_fallback.dart';
import '../../../core/theme/neumorphism_theme.dart';

// Clase helper para resultado del procesamiento en isolate
class _ProcessedSong {
  final Song song;
  final String? normalizedCoverUrl;

  _ProcessedSong({
    required this.song,
    this.normalizedCoverUrl,
  });
}

// Función top-level para procesar canciones y URLs en un solo isolate
List<_ProcessedSong> _parseAndProcessSongs(List<Map<String, dynamic>> songsRaw) {
  // Procesar JSON
  final songs = songsRaw.map((e) => Song.fromJson(e)).toList();
  
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
  
  static const int _initialSongsLimit = 20;
  static const int _loadMoreSongsLimit = 20;

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _api = ArtistsApi(ApiConfig.baseUrl);
    // Leer estado de admin una sola vez al inicio
    final currentUser = ref.read(currentUserProvider);
    _isAdmin = currentUser?.isAdmin == true;
    _initializeCalculatedValues();
    
    // Pre-cachear imágenes iniciales ANTES de cargar datos (evita tirón)
    _precacheInitialImages();
    
    // Diferir carga de datos al siguiente frame para evitar bloqueo del primer render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
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
    _coverUrl = UrlNormalizer.normalizeImageUrl(detailCover ?? artist.coverPhotoUrl);
    
    final detailProfile = _details?['profilePhotoUrl'] as String? ?? 
                         _details?['profile_photo_url'] as String?;
    _profileUrl = UrlNormalizer.normalizeImageUrl(detailProfile ?? artist.profilePhotoUrl);
    
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
    
    // NO pre-cachear aquí - se hace después del setState en _load()
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
  void _precacheImages() {
    if (!mounted) return;
    
    // Pre-cachear portada grande (mejora tiempo de apertura)
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
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
    
    // Pre-cachear avatar
    if (_profileUrl != null && _profileUrl!.isNotEmpty) {
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

  // Cargar datos en paralelo y procesar en isolate optimizado
  Future<void> _load() async {
    if (!mounted) return;
    
    // Mostrar loading inmediatamente (necesario para UX)
    setState(() => _loading = true);
    
    // Pequeño delay para permitir que el primer frame se renderice sin bloqueo
    await Future.delayed(const Duration(milliseconds: 16)); // ~1 frame a 60fps
    
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
      setState(() {
        _allProcessedSongs = allProcessedSongs;
        _displayedSongs = initialSongs;
        _hasMoreSongs = hasMore;
        _loading = false;
      });
      
      // Pre-cachear imágenes actualizadas después del setState
      _precacheImages();
    } catch (e) {
      // Error al cargar datos del artista
      if (!mounted) return;
      
      setState(() {
        _details = null;
        _allProcessedSongs = [];
        _displayedSongs = [];
        _hasMoreSongs = false;
        _loading = false;
        _initializeCalculatedValues(); // Resetear a valores iniciales
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
    
    // Actualizar _isAdmin solo si cambió (fuera de build)
    if (isAdmin != _isAdmin && _details != null) {
      // Usar WidgetsBinding para actualizar después del frame actual
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isAdmin = isAdmin;
            _updateCalculatedValues(); // Recalcular bio y phone con nuevo estado
          });
        }
      });
    }

    // Cachear dimensiones de pantalla (solo calcular una vez)
    if (_cachedScreenWidth == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedScreenWidth = mediaQuery.size.width;
      _cachedCoverHeight = _cachedScreenWidth! / 2.4; // AspectRatio 2.4
      _cachedDevicePixelRatio = mediaQuery.devicePixelRatio;
    }

    final screenWidth = _cachedScreenWidth!;
    final coverHeight = _cachedCoverHeight!;
    final devicePixelRatio = _cachedDevicePixelRatio!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_effectiveName ?? widget.artist.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: CustomScrollView(
        cacheExtent: 500, // Mejorar scroll performance
        physics: const ClampingScrollPhysics(), // Android-style scroll
        slivers: [
          // Header fijo con portada y avatar
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // Cabecera con portada y overlay
                  AspectRatio(
                    aspectRatio: 2.4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Usar CachedNetworkImage optimizado para la portada grande
                        NetworkImageWithFallback(
                          imageUrl: _coverUrl,
                          fit: BoxFit.cover,
                          useCachedImage: true,
                          cacheWidth: (screenWidth * devicePixelRatio).toInt(),
                          cacheHeight: (coverHeight * devicePixelRatio).toInt(),
                          fadeInDuration: const Duration(milliseconds: 150),
                        ),
                        Container(
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
                              child: NetworkImageWithFallback.small(
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
                  // Loading indicator
                  if (_loading) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          // Biografía - Sin RepaintBoundary (sección pequeña)
          if (_bio.isNotEmpty)
            SliverToBoxAdapter(
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
            )
          else
            SliverToBoxAdapter(
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
            ),
          // Contacto (solo admin) - Sin RepaintBoundary
          if (isAdmin && _phone != null && _phone!.isNotEmpty)
            SliverToBoxAdapter(
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
            ),
          // Título de canciones
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Canciones',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 12),
          ),
          // Lista de canciones optimizada con SliverFixedExtentList
          if (_displayedSongs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
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
              ),
            )
          else
            // SliverFixedExtentList optimizado (no necesita RepaintBoundary externo)
            SliverFixedExtentList(
              itemExtent: 60.0, // Altura fija conocida (mejora rendimiento de scroll)
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    // Separador
                    return const Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 16,
                    );
                  }
                  // Item de canción (índice par)
                  final songIndex = index ~/ 2;
                  
                  // Botón "Ver más" al final
                  if (songIndex >= _displayedSongs.length) {
                    if (_hasMoreSongs && songIndex == _displayedSongs.length) {
                      return _buildLoadMoreButton();
                    }
                    return null;
                  }
                  
                  return RepaintBoundary(
                    key: ValueKey('song_${_displayedSongs[songIndex].song.id}'),
                    child: _buildSongRow(
                      songIndex,
                      _displayedSongs[songIndex],
                      _effectiveName ?? widget.artist.name,
                    ),
                  );
                },
                childCount: _displayedSongs.isEmpty 
                    ? 0 
                    : (_displayedSongs.length * 2) - 1 + (_hasMoreSongs ? 2 : 0),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  String _calculateFlagEmoji(String code) {
    if (code.length != 2) return '🏳️';
    final cc = code.toUpperCase();
    final runes = cc.runes.map((c) => 0x1F1E6 - 65 + c).toList();
    return String.fromCharCodes(runes);
  }

  Future<void> _loadMoreSongs() async {
    if (_loadingMore || !_hasMoreSongs) return;

    setState(() => _loadingMore = true);

    // Simular delay mínimo para mejor UX
    await Future.delayed(const Duration(milliseconds: 100));

    final currentCount = _displayedSongs.length;
    final nextBatch = _allProcessedSongs.skip(currentCount).take(_loadMoreSongsLimit).toList();
    final hasMore = currentCount + nextBatch.length < _allProcessedSongs.length;

    if (!mounted) return;

    setState(() {
      _displayedSongs = [..._displayedSongs, ...nextBatch];
      _hasMoreSongs = hasMore;
      _loadingMore = false;
    });
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
    // URL ya está normalizada y cacheada en _ProcessedSong
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NetworkImageWithFallback.medium(
              imageUrl: processedSong.normalizedCoverUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              borderRadius: 8,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  processedSong.song.title ?? 'Sin título',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            processedSong.song.durationFormatted,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.play_arrow_rounded, color: NeumorphismTheme.coffeeMedium),
            onPressed: () => _onPlaySong(processedSong.song),
            splashRadius: 22,
          ),
        ],
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
      final audioService = container.read(professionalAudioServiceProvider);
      final messenger = ScaffoldMessenger.of(context);
      
      try {
        // Asegurar que el servicio esté inicializado
        if (!audioService.isInitialized) {
          await audioService.initialize(enableBackground: true);
        }
        
        // Cargar y reproducir automáticamente
        await audioService.loadSong(song);
        await audioService.play();
        
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
}
