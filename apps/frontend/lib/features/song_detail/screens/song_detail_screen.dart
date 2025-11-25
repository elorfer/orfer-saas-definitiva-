import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/audio/audio_manager.dart';
import '../../../core/widgets/play_button_icon.dart';
import '../widgets/artist_songs_list.dart';
import '../../../core/utils/url_normalizer.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
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
      final audioManager = ref.read(audioManagerProvider);
      
      // Verificar si hay una canción reproduciéndose
      final currentSong = audioManager.currentSong;
      final isPlaying = audioManager.isPlaying;
      final isCurrentSong = currentSong?.id == widget.song.id;
      
      // Si es la canción actual y está reproduciéndose → abrir full player
      if (isCurrentSong && isPlaying) {
        audioManager.openFullPlayer();
        return;
      }
      
      // Si hay otra canción reproduciéndose → playSong se encargará de abrir el full player
      // Si no hay canción reproduciéndose → reproduce normalmente
      await audioManager.playSong(widget.song);
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
    final audioManager = ref.read(audioManagerProvider);

    final coverUrl = widget.song.coverArtUrl != null && widget.song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(widget.song.coverArtUrl)
        : null;
    
    final artist = widget.song.artist;
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
                            tag: 'album_cover_${widget.song.id}',
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
                                widget.song.title ?? 'Sin título',
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
                                        child: StreamBuilder<Song?>(
                                          stream: audioManager.currentSongStream,
                                          initialData: audioManager.currentSong,
                                          builder: (context, currentSongSnapshot) {
                                            final currentSong = currentSongSnapshot.data;
                                            final isCurrentSong = currentSong?.id == widget.song.id;
                                            
                                            if (!isCurrentSong) {
                                              return const PlayButtonIcon(
                                                isPlaying: false,
                                                color: Colors.white,
                                                size: 24,
                                              );
                                            }
                                            
                                            return StreamBuilder<bool>(
                                              stream: audioManager.isPlayingStream,
                                              initialData: audioManager.isPlaying,
                                              builder: (context, isPlayingSnapshot) {
                                                final isPlaying = isPlayingSnapshot.data ?? false;
                                                return PlayButtonIcon(
                                                  isPlaying: isPlaying,
                                                  color: Colors.white,
                                                  size: 24,
                                                );
                                              },
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
                                if (widget.song.releaseDate != null) ...[
                                  Text(
                                    ' • ${_formatReleaseDate(widget.song.releaseDate)}',
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
                              currentSongId: widget.song.id,
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
