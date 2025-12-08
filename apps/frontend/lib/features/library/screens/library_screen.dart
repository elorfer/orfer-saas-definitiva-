import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../core/providers/play_history_provider.dart';
import '../../../core/providers/follow_provider.dart';

/// LibraryScreen optimizado con AutomaticKeepAliveClientMixin
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Mantener estado al cambiar de pestaña

  @override
  void initState() {
    super.initState();
    // Cargar artistas seguidos inmediatamente al montar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    // Optimización: usar select para escuchar solo cambios en favorites, historial y artistas seguidos
    final favoritesCount = ref.watch(favoritesProvider.select((state) => state.favorites.length));
    final historyCount = ref.watch(playHistoryProvider.select((state) => state.length));
    final followedArtistsCount = ref.watch(followProvider.select((state) => state.followedArtistIds.length));
    final isLoadingFollowed = ref.watch(followProvider.select((state) => state.isLoading && state.followedArtistIds.isEmpty));
    
    // Construir secciones con datos reales
    final librarySections = [
      {
        'icon': Icons.favorite,
        'title': 'Canciones Favoritas',
        'subtitle': '$favoritesCount ${favoritesCount == 1 ? 'canción' : 'canciones'}',
        'onTap': () => context.push('/favorites'),
      },
      {
        'icon': Icons.playlist_play,
        'title': 'Mis Playlists',
        'subtitle': '0 playlists',
        'onTap': () => context.push('/playlists'),
      },
      {
        'icon': Icons.download,
        'title': 'Descargadas',
        'subtitle': '0 canciones',
        'onTap': () {},
      },
      {
        'icon': Icons.history,
        'title': 'Recientemente Reproducidas',
        'subtitle': '$historyCount ${historyCount == 1 ? 'canción' : 'canciones'}',
        'onTap': () => context.push('/recently-played'),
      },
      {
        'icon': Icons.album,
        'title': 'Álbumes Guardados',
        'subtitle': '0 álbumes',
        'onTap': () {},
      },
      {
        'icon': Icons.person,
        'title': 'Artistas Seguidos',
        'subtitle': isLoadingFollowed 
            ? 'Cargando...' 
            : '$followedArtistsCount ${followedArtistsCount == 1 ? 'artista' : 'artistas'}',
        'onTap': () => context.push('/followed-artists'),
      },
    ];
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header mejorado con icono
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                        NeumorphismTheme.coffeeDark.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icono de biblioteca grande
                      Container(
                        width: 64,
                        height: 64,
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
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.library_music_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Información
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mi Biblioteca',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: NeumorphismTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.collections_rounded,
                                  size: 16,
                                  color: NeumorphismTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tu música organizada',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: NeumorphismTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Library sections optimizadas
                Expanded(
                  child: ListView.builder(
                    cacheExtent: 300,
                    physics: const FastScrollPhysics(),
                    itemCount: librarySections.length,
                    itemExtent: 80.0,
                    itemBuilder: (context, index) {
                      final section = librarySections[index];
                      
                      return RepaintBoundary(
                        key: ValueKey('library_section_$index'),
                        child: _buildLibrarySection(
                          icon: section['icon'] as IconData,
                          title: section['title'] as String,
                          subtitle: section['subtitle'] as String,
                          onTap: section['onTap'] as VoidCallback,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLibrarySection({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: NeumorphismTheme.neumorphismShadow,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Icon(
            icon,
            color: NeumorphismTheme.coffeeMedium,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: NeumorphismTheme.textPrimary,
          ),
          maxLines: 1, // 🔥 Evitar desbordamiento
          overflow: TextOverflow.ellipsis, // 🔥 Mostrar "..." si es muy largo
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: NeumorphismTheme.textSecondary,
          ),
          maxLines: 1, // 🔥 Evitar desbordamiento
          overflow: TextOverflow.ellipsis, // 🔥 Mostrar "..." si es muy largo
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: NeumorphismTheme.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}



