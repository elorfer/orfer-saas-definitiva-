import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/widgets/play_button_icon.dart';
import '../widgets/artist_songs_list.dart';
import '../providers/song_detail_provider.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/utils/logger.dart';
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
    debugPrint('[SongDetailScreen] navigateToSong llamado para: ${song.title} (${song.id})');
    
    // Verificar que el contexto esté montado
    if (!context.mounted) {
      debugPrint('[SongDetailScreen] Contexto no montado, abortando navegación');
      return;
    }
    
    // Prevenir múltiples navegaciones simultáneas (debounce)
    final now = DateTime.now();
    if (_lastNavigationTime != null && 
        _lastNavigatedSongId == song.id &&
        now.difference(_lastNavigationTime!) < const Duration(milliseconds: 500)) {
      // Ya se está navegando a esta canción, ignorar llamada duplicada
      debugPrint('[SongDetailScreen] Navegación duplicada ignorada (debounce)');
      return;
    }
    
    _lastNavigationTime = now;
    _lastNavigatedSongId = song.id;
    
    // Verificar si ya estamos en la pantalla de esta canción
    final currentRoute = ModalRoute.of(context);
    final currentRouteName = currentRoute?.settings.name;
    final routeName = '/song_detail/${song.id}';
    
    debugPrint('[SongDetailScreen] Ruta actual: $currentRouteName, Ruta objetivo: $routeName');
    
    // Si ya estamos en la pantalla de esta canción, no hacer nada
    if (currentRouteName == routeName) {
      debugPrint('[SongDetailScreen] Ya estamos en esta pantalla, no navegar');
      return;
    }
    
    // Verificar si la canción actual en los argumentos es la misma
    if (currentRoute?.settings.arguments is Song) {
      final currentSong = currentRoute!.settings.arguments as Song;
      if (currentSong.id == song.id) {
        debugPrint('[SongDetailScreen] Misma canción en argumentos, no navegar');
        return;
      }
    }
    
    // Obtener el Navigator de forma segura
    final navigator = Navigator.of(context, rootNavigator: false);
    if (!navigator.canPop() && navigator.widget.initialRoute == routeName) {
      // Si es la ruta inicial y ya estamos ahí, no hacer nada
      debugPrint('[SongDetailScreen] Es la ruta inicial y ya estamos ahí');
      return;
    }
    
    debugPrint('[SongDetailScreen] Iniciando navegación...');
    
    // Navegar directamente sin usar popUntil para evitar problemas
    // Usar Navigator.push directamente para garantizar que siempre se muestre la pantalla
    try {
      navigator.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            debugPrint('[SongDetailScreen] Construyendo página para: ${song.title}');
            // Asegurar que el widget se construya correctamente
            return SongDetailScreen(song: song);
          },
          settings: RouteSettings(
            name: routeName,
            arguments: song,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          opaque: true, // Asegurar que la ruta sea opaca
          fullscreenDialog: false,
        ),
      ).then((_) {
        debugPrint('[SongDetailScreen] Navegación completada');
      }).catchError((error) {
        debugPrint('[SongDetailScreen] Error en navegación: $error');
      });
    } catch (e, stackTrace) {
      debugPrint('[SongDetailScreen] Excepción al navegar: $e');
      debugPrint('[SongDetailScreen] Stack trace: $stackTrace');
    }
  }
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  late ScrollController _scrollController;
  Song? _loadedSong; // Canción cargada desde el backend

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Cargar la canción completa desde el backend para asegurar datos actualizados
    _loadSongFromBackend();
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

  /// Carga la canción completa desde el backend para asegurar datos actualizados (incluyendo géneros)
  Future<void> _loadSongFromBackend() async {
    try {
      final songDetailService = ref.read(songDetailServiceProvider);
      final loadedSong = await songDetailService.getSongById(widget.song.id);
      if (loadedSong != null && mounted) {
        debugPrint('[SongDetailScreen] Canción cargada desde backend: ${loadedSong.title}');
        debugPrint('[SongDetailScreen] Géneros recibidos: ${loadedSong.genres}');
        debugPrint('[SongDetailScreen] Géneros es null: ${loadedSong.genres == null}');
        debugPrint('[SongDetailScreen] Géneros está vacío: ${loadedSong.genres?.isEmpty ?? true}');
        setState(() {
          _loadedSong = loadedSong;
        });
      } else {
        debugPrint('[SongDetailScreen] No se pudo cargar la canción desde el backend');
        debugPrint('[SongDetailScreen] Géneros de la canción inicial: ${widget.song.genres}');
      }
    } catch (e) {
      debugPrint('[SongDetailScreen] Error al cargar canción desde backend: $e');
      // Si falla, usar la canción que viene como parámetro
      debugPrint('[SongDetailScreen] Usando canción inicial. Géneros: ${widget.song.genres}');
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

  /// Maneja el botón de play principal
  /// Si NO hay canción reproduciéndose → reproduce normalmente
  /// Si HAY canción reproduciéndose → expande el full player
  Future<void> _handlePlay() async {
    try {
      // 🚀 USAR PROVIDER UNIFICADO CORREGIDO CON DEBUG
      final audioNotifier = ref.read(unifiedAudioProviderFixed.notifier);
      
      // Usar la canción cargada desde el backend si está disponible
      final songToPlay = _loadedSong ?? widget.song;
      
      // DEBUG: Verificar qué canción se está usando
      debugPrint('[SongDetailScreen] 🚀 GLOBAL PROVIDER - Canción a reproducir:');
      debugPrint('[SongDetailScreen] 🎵 Título: ${songToPlay.title}');
      debugPrint('[SongDetailScreen] 🎵 fileUrl: ${songToPlay.fileUrl}');
      debugPrint('[SongDetailScreen] 🎵 coverArtUrl: ${songToPlay.coverArtUrl}');
      
      // Verificar estado actual del reproductor unificado corregido
      final currentAudioState = ref.read(unifiedAudioProviderFixed);
      final isCurrentSong = currentAudioState.currentSong?.id == songToPlay.id;
      
      // Si es la canción actual y está reproduciéndose → toggle play/pause
      if (isCurrentSong && currentAudioState.isPlaying) {
        await audioNotifier.togglePlayPause();
        return;
      }
      
      // Si es la canción actual pero pausada → reanudar
      if (isCurrentSong && !currentAudioState.isPlaying) {
        await audioNotifier.play();
        return;
      }
      
      // Si es una canción diferente → reproducir nueva canción
      AppLogger.info('[SongDetailScreen] 🚀 Reproduciendo nueva canción: ${songToPlay.title}');
      await audioNotifier.playSong(songToPlay);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 USAR PROVIDER UNIFICADO CORREGIDO CON DEBUG
    final _ = ref.watch(unifiedAudioProviderFixed); // Solo para escuchar cambios

    // Usar la canción cargada desde el backend si está disponible, sino usar la que viene como parámetro
    final song = _loadedSong ?? widget.song;

    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;
    
    final artist = song.artist;
    final artistAvatarUrl = artist?.profilePhotoUrl != null
        ? UrlNormalizer.normalizeImageUrl(artist?.profilePhotoUrl)
        : null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
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
                        
                        // Portada grande centrada
                        Center(
                            child: Hero(
                            tag: 'album_cover_${song.id}',
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: coverUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: coverUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: NeumorphismTheme.coffeeMedium,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: NeumorphismTheme.coffeeMedium,
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white,
                                            size: 64,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: NeumorphismTheme.coffeeMedium,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Título de la canción con botones al lado
                        Row(
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
                            // Botones de acción en horizontal
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botón agregar
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, color: NeumorphismTheme.textPrimary),
                                  onPressed: () {
                                    // Agregar a playlist (pendiente de implementar)
                                  },
                                ),
                                // Botón descargar
                                IconButton(
                                  icon: const Icon(Icons.download_rounded, color: NeumorphismTheme.textPrimary),
                                  onPressed: () {
                                    // Descargar canción (pendiente de implementar)
                                  },
                                ),
                                // Botón más opciones
                                IconButton(
                                  icon: const Icon(Icons.more_vert_rounded, color: NeumorphismTheme.textPrimary),
                                  onPressed: () {
                                    // Mostrar más opciones (pendiente de implementar)
                                  },
                                ),
                                // Botón expandir/fullscreen
                                IconButton(
                                  icon: const Icon(Icons.open_in_full_rounded, color: NeumorphismTheme.textPrimary),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                // Botón Play/Pause
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: NeumorphismTheme.coffeeMedium,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _handlePlay,
                                      borderRadius: BorderRadius.circular(24),
                                      child: Center(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final currentAudioState = ref.watch(unifiedAudioProviderFixed);
                                            final currentSong = currentAudioState.currentSong;
                                            final isCurrentSong = currentSong?.id == song.id;
                                            
                                            if (!isCurrentSong) {
                                              return const PlayButtonIcon(
                                                isPlaying: false,
                                                color: Colors.white,
                                                size: 24,
                                              );
                                            }
                                            
                                            // Usar estado del provider unificado corregido
                                            final isPlaying = currentAudioState.isPlaying;
                                            return PlayButtonIcon(
                                              isPlaying: isPlaying,
                                              color: Colors.white,
                                              size: 24,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Artista con avatar pequeño y "Sencillo" - más arriba
                        Row(
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
                        
                        const SizedBox(height: 32),
                        
                        // Información de la canción actual que está sonando - DESHABILITADO
                        // if (currentSong?.id == widget.song.id)
                        //   Container(
                        //     ... código comentado ...
                        //   ),
                        
                        const SizedBox(height: 12),
                        
                        // Géneros musicales - DEBUG
                        Builder(
                          builder: (context) {
                            // Sin logs para mejor rendimiento
                            // Sin logs para mejor rendimiento
                            // Sin logs para mejor rendimiento
                            
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
                            } else {
                              // Sin logs para mejor rendimiento
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Sección "Más de este artista" estilo Spotify
                        if (artist != null) ...[
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
