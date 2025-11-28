import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../widgets/artist_songs_list.dart';
import '../providers/song_detail_provider.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/widgets/favorite_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../artists/pages/artist_page.dart';
import '../../artists/models/artist.dart';

/// Pantalla de detalle de canción estilo Spotify con diseño moderno
class SongDetailScreen extends ConsumerStatefulWidget {
  final Song song;

  const SongDetailScreen({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
  
  // Variables estáticas para prevenir múltiples llamadas simultáneas
  static DateTime? _lastNavigationTime;
  static String? _lastNavigatedSongId;
  
  /// Función estática helper para navegar a una canción desde cualquier contexto
  /// Verifica si ya existe una pantalla abierta con esa canción y vuelve a ella
  /// 
  /// Esta función previene abrir múltiples instancias de la misma canción.
  /// Si la pantalla ya existe en el stack, vuelve a ella en lugar de crear una nueva.
  /// 
  /// Ejemplo de uso:
  /// ```dart
  /// SongDetailScreen.navigateToSong(context, song);
  /// ```
  static void navigateToSong(BuildContext context, Song song) {
    if (!context.mounted) return;
    
    // Prevenir múltiples navegaciones simultáneas (debounce)
    final now = DateTime.now();
    if (_lastNavigationTime != null && 
        _lastNavigatedSongId == song.id &&
        now.difference(_lastNavigationTime!) < const Duration(milliseconds: 500)) {
      return;
    }
    
    _lastNavigationTime = now;
    _lastNavigatedSongId = song.id;
    
    // Verificar si ya estamos en la pantalla de esta canción
    final currentRoute = ModalRoute.of(context);
    final currentRouteName = currentRoute?.settings.name;
    final routeName = '/song_detail/${song.id}';
    
    if (currentRouteName == routeName) return;
    
    if (currentRoute?.settings.arguments is Song) {
      final currentSong = currentRoute!.settings.arguments as Song;
      if (currentSong.id == song.id) return;
    }
    
    final navigator = Navigator.of(context, rootNavigator: false);
    if (!navigator.canPop() && navigator.widget.initialRoute == routeName) {
      return;
    }
    
    try {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => SongDetailScreen(song: song),
          settings: RouteSettings(
            name: routeName,
            arguments: song,
          ),
        ),
      );
    } catch (e) {
      // Error silencioso
    }
  }
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  late ScrollController _scrollController;
  Song? _loadedSong; // Canción cargada desde el backend
  bool _isLoadingSong = false; // Indicador de carga

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Cargar la canción completa desde el backend para asegurar datos actualizados
    // Usar Future.microtask para no bloquear el primer render
    Future.microtask(() {
      if (mounted) {
        _loadSongFromBackend();
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Carga la canción completa desde el backend para asegurar datos actualizados
  /// Siempre carga desde el backend para garantizar datos completos (especialmente desde favoritos)
  Future<void> _loadSongFromBackend() async {
    // Siempre cargar desde el backend para garantizar datos completos
    // Esto es especialmente importante cuando la canción viene de favoritos
    // que pueden tener datos incompletos
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingSong = true;
    });
    
    try {
      final songDetailService = ref.read(songDetailServiceProvider);
      final loadedSong = await songDetailService.getSongById(widget.song.id);
      
      if (!mounted) return;
      
      if (loadedSong != null && mounted) {
        setState(() {
          _loadedSong = loadedSong;
          _isLoadingSong = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingSong = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      if (mounted) {
        setState(() {
          _isLoadingSong = false;
        });
      }
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistPage(artist: artistLite),
        ),
      );
    }
  }

  String _formatReleaseDate(DateTime? date) {
    if (date == null) return '';
    final format = DateFormat('d \'de\' MMM \'de\' yyyy', 'es');
    return format.format(date);
  }

  @override
  Widget build(BuildContext context) {
    // Usar la canción cargada desde el backend si está disponible, sino usar la que viene como parámetro
    final song = _loadedSong ?? widget.song;

    // Normalizar URLs - priorizar song cargada, luego widget.song
    String? coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : (widget.song.coverArtUrl != null && widget.song.coverArtUrl!.isNotEmpty
            ? UrlNormalizer.normalizeImageUrl(widget.song.coverArtUrl)
            : null);
    
    final artist = song.artist ?? widget.song.artist;
    final artistAvatarUrl = artist?.profilePhotoUrl != null
        ? UrlNormalizer.normalizeImageUrl(artist!.profilePhotoUrl)
        : null;
    

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
            child: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 500, // Optimizar cache de scroll
              slivers: [
                // AppBar con botón de retroceso
                SliverAppBar(
                  expandedHeight: 60,
                  floating: true,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      boxShadow: NeumorphismTheme.floatingCardShadow,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: NeumorphismTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        boxShadow: NeumorphismTheme.floatingCardShadow,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.more_vert, color: NeumorphismTheme.textPrimary),
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
                        const SizedBox(height: 20),
                        
                        // Portada grande centrada - Optimizada
                        RepaintBoundary(
                          child: Center(
                            child: Hero(
                              tag: 'favorite_cover_${song.id}',
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.85,
                                height: MediaQuery.of(context).size.width * 0.85,
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
                                child: Stack(
                                  children: [
                                    // Imagen de portada
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(32),
                                      child: coverUrl != null
                                          ? Image.network(
                                              coverUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) {
                                                  debugPrint('[SongDetailScreen] ✅ Imagen cargada: $coverUrl');
                                                  return child;
                                                }
                                                debugPrint('[SongDetailScreen] 🖼️ Cargando imagen: $coverUrl - ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}');
                                                return Container(
                                                  color: NeumorphismTheme.coffeeMedium,
                                                  child: Center(
                                                    child: CircularProgressIndicator(
                                                      value: loadingProgress.expectedTotalBytes != null
                                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                          : null,
                                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: NeumorphismTheme.coffeeMedium,
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(
                                                        Icons.music_note,
                                                        color: Colors.white,
                                                        size: 64,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Error cargando imagen',
                                                        style: TextStyle(
                                                          color: Colors.white.withValues(alpha: 0.7),
                                                          fontSize: 12,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              color: NeumorphismTheme.coffeeMedium,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.music_note,
                                                    color: Colors.white,
                                                    size: 64,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Sin portada',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.7),
                                                      fontSize: 12,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                    // Indicador de carga mientras se obtienen datos del backend
                                    if (_isLoadingSong)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(32),
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Título de la canción con botones al lado - Optimizado
                        RepaintBoundary(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título de la canción (grande y bold)
                              Expanded(
                                child: Text(
                                  song.title ?? 'Sin título',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: NeumorphismTheme.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Iconos: Corazón, Menú y Botón de Play
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Icono de corazón
                                  FavoriteButton(
                                    songId: song.id,
                                    iconColor: NeumorphismTheme.textPrimary,
                                    iconSize: 24,
                                  ),
                                  // Icono de tres rayitas (menú)
                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded, color: NeumorphismTheme.textPrimary),
                                    onPressed: () {
                                      // TODO: Implementar menú de opciones
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  // Botón de Play/Pause grande - Solo escucha cambios necesarios
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final currentAudioState = ref.watch(unifiedAudioProviderFixed);
                                      final currentSong = currentAudioState.currentSong;
                                      final isCurrentSong = currentSong?.id == song.id;
                                      final isPlaying = isCurrentSong && currentAudioState.isPlaying;
                                      
                                      return RepaintBoundary(
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
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
                                                blurRadius: 15,
                                                offset: const Offset(0, 5),
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () async {
                                                try {
                                                  final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
                                                  
                                                  if (isCurrentSong && isPlaying) {
                                                    await audioNotifier.togglePlayPause();
                                                  } else if (isCurrentSong && !isPlaying) {
                                                    await audioNotifier.play();
                                                  } else {
                                                    await audioNotifier.playSong(song);
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Error al reproducir: ${e.toString()}'),
                                                        backgroundColor: Colors.red,
                                                        duration: const Duration(seconds: 2),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(28),
                                              child: Center(
                                                child: Icon(
                                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 28,
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
                        
                        const SizedBox(height: 12),
                        
                        // Artista con avatar pequeño y "Sencillo" - Optimizado
                        RepaintBoundary(
                          child: Row(
                            children: [
                              // Artista con avatar redondo pequeño - clickeable
                              GestureDetector(
                                onTap: _navigateToArtist,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (artistAvatarUrl != null)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: NeumorphismTheme.floatingCardShadow,
                                        ),
                                        child: ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: artistAvatarUrl,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 48,
                                            memCacheHeight: 48,
                                            fadeInDuration: const Duration(milliseconds: 100), // Más rápido
                                            fadeOutDuration: const Duration(milliseconds: 50), // Más rápido
                                            fadeInCurve: Curves.easeOut, // Curva más rápida
                                            placeholder: (context, url) => Container(
                                              color: NeumorphismTheme.coffeeMedium,
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: NeumorphismTheme.coffeeMedium,
                                              child: const Icon(Icons.person, color: Colors.white, size: 14),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (artistAvatarUrl != null) const SizedBox(width: 8),
                                    Text(
                                      artist?.displayName ?? 'Artista desconocido',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: NeumorphismTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Información adicional (tipo, fecha)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.song.isExplicit)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'E',
                                        style: TextStyle(
                                          color: NeumorphismTheme.textPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (widget.song.isExplicit) const SizedBox(width: 8),
                                  Text(
                                    'Sencillo',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: NeumorphismTheme.textLight,
                                    ),
                                  ),
                                  if (song.releaseDate != null) ...[
                                    Text(
                                      ' • ${_formatReleaseDate(song.releaseDate)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: NeumorphismTheme.textLight,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Géneros musicales - Optimizado
                        RepaintBoundary(
                          child: Builder(
                            builder: (context) {
                              if (song.genres != null && song.genres!.isNotEmpty) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: song.genres!.map((genre) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        genre,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: NeumorphismTheme.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
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
                                          color: NeumorphismTheme.textPrimary,
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
                        
                        const SizedBox(height: 100), // Espacio para el reproductor inferior
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
}
