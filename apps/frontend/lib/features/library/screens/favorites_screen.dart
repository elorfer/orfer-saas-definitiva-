import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../song_detail/screens/song_detail_screen.dart';
import '../../../core/utils/logger.dart';

/// Pantalla de canciones favoritas del usuario
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  // Cachear dimensiones de pantalla para evitar recálculos (si se necesita en el futuro)
  // double? _cachedScreenWidth;
  
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   // Cachear dimensiones de pantalla una sola vez
  //   if (_cachedScreenWidth == null) {
  //     final mediaQuery = MediaQuery.of(context);
  //     _cachedScreenWidth = mediaQuery.size.width;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final favoritesState = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: NeumorphismTheme.textPrimary,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library');
            }
          },
        ),
        title: Text(
          'Mis Favoritos',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: NeumorphismTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (favoritesState.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              color: NeumorphismTheme.textPrimary,
              onPressed: () {
                ref.read(favoritesProvider.notifier).refresh();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(favoritesProvider.notifier).refresh();
        },
        color: Colors.white,
        backgroundColor: NeumorphismTheme.coffeeMedium,
        child: _buildContent(favoritesState),
      ),
    );
  }

  Widget _buildContent(FavoritesState state) {
    if (state.isLoading && state.favorites.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NeumorphismTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar favoritos',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NeumorphismTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: NeumorphismTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(favoritesProvider.notifier).refresh();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (state.favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono animado
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.red.shade100,
                            Colors.red.shade200,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border,
                        size: 64,
                        color: Colors.red.shade400,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'No tienes favoritos aún',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Agrega canciones a tus favoritos\ntocando el corazón ❤️',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: NeumorphismTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      cacheExtent: 300, // ✅ Reducido de 500 a 300 para ahorrar memoria
      physics: const ClampingScrollPhysics(), // Más fluido que FastScrollPhysics
      clipBehavior: Clip.none, // Evitar clipping innecesario
      slivers: [
        // Header mejorado con gradiente
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                  NeumorphismTheme.coffeeDark.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
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
                // Icono de corazón grande
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade400,
                        Colors.red.shade600,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
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
                        'Mis Favoritos',
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
                            Icons.music_note,
                            size: 16,
                            color: NeumorphismTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${state.favorites.length} ${state.favorites.length == 1 ? 'canción guardada' : 'canciones guardadas'}',
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
        ),
        // Lista de canciones optimizada para scroll fluido y memoria
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final song = state.favorites[index];
              return RepaintBoundary(
                key: ValueKey('favorite_song_${song.id}'),
                child: _FavoriteSongItem(
                  key: ValueKey('favorite_item_${song.id}'), // ✅ Key estable para mejor reciclaje
                  song: song,
                  index: index,
                  onTap: () => _onSongTap(context, song),
                ),
              );
            },
            childCount: state.favorites.length,
            addAutomaticKeepAlives: false, // ✅ No mantener estado fuera de vista (ahorra memoria)
            addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 80), // Espacio para el reproductor
        ),
      ],
    );
  }

  void _onSongTap(BuildContext context, Song song) {
    try {
      // Usar el método estático de SongDetailScreen para mejor manejo de navegación
      SongDetailScreen.navigateToSong(context, song);
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesScreen] Error al navegar: $e', stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir detalles de la canción'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Widget para cada ítem de canción favorita con animaciones
/// Widget optimizado para ahorrar memoria - sin animaciones pesadas
class _FavoriteSongItem extends ConsumerWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _FavoriteSongItem({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;

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
            onTap: onTap,
            // ✅ Eliminado onTapDown/Up/Cancel para ahorrar memoria (sin animaciones)
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
                    tag: 'favorite_cover_${song.id}',
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
                                decoration: BoxDecoration(
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
                  // Información
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
                                song.artist?.displayName ?? 'Artista desconocido',
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
                  // Botón de favorito (ya está en favoritos, pero lo mostramos)
                  FavoriteButton(
                    songId: song.id,
                    iconColor: Colors.red,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 8),
                  // Botón de información (navega a detalles de la canción)
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
                        onTap: onTap, // Navegar a información de la canción
                        borderRadius: BorderRadius.circular(22),
                        child: const Center(
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 22,
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
}

