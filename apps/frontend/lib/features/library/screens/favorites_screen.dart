import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../core/models/song_model.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/widgets/optimized_image.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/utils/intersection_observer.dart';
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
  
  // Cache de URLs normalizadas para evitar recálculos
  final Map<String, String?> _cachedCoverUrls = {};
  
  // ScrollController para detectar visibilidad
  final ScrollController _scrollController = ScrollController();
  
  // ✅ OPTIMIZACIÓN: Cache de lista de URLs para evitar recálculos en _onScroll
  List<String> _cachedImageUrls = [];
  int _cachedFavoritesCount = 0;
  
  // ✅ OPTIMIZACIÓN: Timer para debounce en _onScroll
  Timer? _scrollDebounceTimer;
  
  @override
  void initState() {
    super.initState();
    // Precargar imágenes después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages();
    });
    
    // Listener para precachear imágenes visibles al hacer scroll
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    // ✅ OPTIMIZACIÓN: Cancelar timer de debounce de scroll
    _scrollDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  /// ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambian los datos
  void _updateImageUrlsCache() {
    final favorites = ref.read(favoritesProvider).favorites;
    _cachedImageUrls = favorites
        .map((song) => _cachedCoverUrls[song.id])
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    _cachedFavoritesCount = favorites.length;
  }
  
  /// 🔥 OPTIMIZACIÓN: Precargar imágenes iniciales usando LazyImageLoader (como en Home)
  void _precacheImages() {
    if (!mounted) return;
    
    final favorites = ref.read(favoritesProvider).favorites;
    
    // Extraer URLs de imágenes y actualizar cache
    final imageUrls = favorites
        .map((song) {
          final coverUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl);
          if (coverUrl != null && coverUrl.isNotEmpty) {
            _cachedCoverUrls[song.id] = coverUrl;
            return coverUrl;
          }
          return null;
        })
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    
    // ✅ OPTIMIZACIÓN: Actualizar cache de lista de URLs
    _cachedImageUrls = imageUrls;
    _cachedFavoritesCount = favorites.length;
    
    // Precachear solo las primeras imágenes visibles inicialmente
    if (imageUrls.isNotEmpty) {
      LazyImageLoader.precacheInitialImages(
        imageUrls: imageUrls,
        context: context,
        count: 10, // Primeras 10 visibles inicialmente
      );
    }
  }
  
  /// 🔥 OPTIMIZACIÓN: Precargar imágenes visibles cuando el usuario hace scroll (como en Home)
  /// ✅ CORRECCIÓN: Agregado debounce para evitar ejecuciones excesivas
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    
    // ✅ OPTIMIZACIÓN: Cancelar timer anterior si existe
    _scrollDebounceTimer?.cancel();
    
    // ✅ OPTIMIZACIÓN: Debounce de 300ms para evitar ejecuciones excesivas
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_scrollController.hasClients) return;
      
      try {
        // ✅ OPTIMIZACIÓN: Usar URLs cacheadas en lugar de leer de favoritesProvider cada vez
        if (_cachedImageUrls.isEmpty) {
          // Si no hay cache, actualizar desde favoritesProvider (solo una vez)
          _updateImageUrlsCache();
        }
        
        // Precachear imágenes visibles basado en posición del scroll (IntersectionObserver)
        if (_cachedImageUrls.isNotEmpty) {
          LazyImageLoader.precacheVisibleVerticalImages(
            scrollController: _scrollController,
            itemExtent: 80.0, // Altura estimada de cada item
            itemCount: _cachedFavoritesCount,
            imageUrls: _cachedImageUrls,
            context: context,
            precacheCount: 5, // Precachear 5 items antes y después del viewport
          );
        }
      } catch (e) {
        // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente para no bloquear la app
        debugPrint('[FavoritesScreen] Error en _onScroll: $e');
      }
    });
  }
  
  @override
  void didUpdateWidget(FavoritesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambian los favoritos, precargar nuevas imágenes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Optimización: usar select para escuchar solo cambios en isLoading y favorites
    final isLoading = ref.watch(favoritesProvider.select((state) => state.isLoading));
    final favorites = ref.watch(favoritesProvider.select((state) => state.favorites));
    final error = ref.watch(favoritesProvider.select((state) => state.error));

    // ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambian los datos
    if (favorites.length != _cachedFavoritesCount) {
      // Actualizar cache de URLs normalizadas
      for (final song in favorites) {
        if (!_cachedCoverUrls.containsKey(song.id)) {
          final coverUrl = UrlNormalizer.normalizeImageUrl(song.coverArtUrl);
          if (coverUrl != null && coverUrl.isNotEmpty) {
            _cachedCoverUrls[song.id] = coverUrl;
          }
        }
      }
      // Actualizar cache de lista de URLs
      _updateImageUrlsCache();
    }

    // 🚀 OPTIMIZACIÓN 60 FPS: RepaintBoundary y const donde sea posible
    return RepaintBoundary(
      child: Scaffold(
        key: const ValueKey('favorites_screen_scaffold'),
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
        actions: [
          if (isLoading)
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
        child: _buildContent(isLoading, favorites, error),
      ),
      ),
    );
  }

  Widget _buildContent(bool isLoading, List<Song> favorites, String? error) {
    if (isLoading && favorites.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null && favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: NeumorphismTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar favoritos',
              style: AppTextStyles.subtitleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall,
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

    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono animado (optimizado - animación más rápida)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300), // Reducido de 800ms
                curve: Curves.easeOut, // Cambiado de elasticOut (más pesado) a easeOut
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
                      ), // No puede ser const porque usa Colors.red.shade400 que es dinámico
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'No tienes favoritos aún',
                style: AppTextStyles.emptyStateTitle,
              ),
              const SizedBox(height: 12),
              const Text(
                'Agrega canciones a tus favoritos\ntocando el corazón ❤️',
                style: AppTextStyles.emptyStateBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache basado en visibilidad
      cacheExtent: 400, // ✅ Optimizado para mejor rendimiento
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ), // ✅ Scroll estilo iPhone (igual que Home)
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
                      const Text(
                        'Mis Favoritos',
                        style: AppTextStyles.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.music_note,
                            size: 16,
                            color: NeumorphismTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${favorites.length} ${favorites.length == 1 ? 'canción guardada' : 'canciones guardadas'}',
                            style: AppTextStyles.bodyMedium,
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
        SliverFixedExtentList(
          itemExtent: 80.0, // ✅ Altura fija conocida (mejora rendimiento significativamente)
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final song = favorites[index];
              // Cachear devicePixelRatio una sola vez para toda la lista (optimización)
              final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
              
              return RepaintBoundary(
                key: ValueKey('favorite_song_${song.id}'),
                child: _FavoriteSongItem(
                  key: ValueKey('favorite_item_${song.id}'), // ✅ Key estable para mejor reciclaje
                  song: song,
                  index: index,
                  devicePixelRatio: devicePixelRatio, // Pasar como parámetro para evitar MediaQuery en cada item
                  onTap: () => _onSongTap(context, song),
                ),
              );
            },
            childCount: favorites.length,
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
  final double devicePixelRatio; // Recibir como parámetro para evitar MediaQuery en cada build
  final VoidCallback onTap;

  const _FavoriteSongItem({
    super.key,
    required this.song,
    required this.index,
    required this.devicePixelRatio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // ✅ Reducido de 6 a 4
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeumorphismTheme.surface.withValues(alpha: 0.8),
            NeumorphismTheme.beigeMedium.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
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
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            onTap: onTap,
            // ✅ Eliminado onTapDown/Up/Cancel para ahorrar memoria (sin animaciones)
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // ✅ Reducido vertical de 16 a 12
              child: Row(
                children: [
                  // Número de posición
                  Container(
                    width: 28, // ✅ Reducido de 32 a 28
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 14, // ✅ Reducido de 16 a 14
                        fontWeight: FontWeight.bold,
                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10), // ✅ Reducido de 12 a 10
                  // Portada con efecto de elevación - Más pequeña pero cuadrada
                  // Hero eliminado para evitar animaciones pesadas al navegar desde favoritos
                  Container(
                    width: 56, // ✅ Reducido de 64 a 56
                    height: 56, // ✅ Reducido de 64 a 56 (mantiene forma cuadrada)
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      maxWidth: 56,
                      minHeight: 56,
                      maxHeight: 56,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: const BorderRadius.all(Radius.circular(8)), // ✅ Más cuadrado (reducido de 12 a 8)
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
                      borderRadius: const BorderRadius.all(Radius.circular(8)), // ✅ Más cuadrado (reducido de 12 a 8)
                      clipBehavior: Clip.antiAlias,
                      child: coverUrl != null
                            ? OptimizedImage(
                                imageUrl: coverUrl,
                                width: 56, // ✅ Reducido de 64 a 56
                                height: 56, // ✅ Reducido de 64 a 56
                                fit: BoxFit.cover,
                                isLargeCover: false,
                                maxCacheWidth: 112, // 2x el tamaño de visualización (56 * 2)
                                maxCacheHeight: 112,
                                lazyLoad: true, // ✅ Lazy loading con IntersectionObserver
                                visibilityThreshold: 0.1, // Cargar cuando 10% visible
                                skipFade: true, // Sin fade para mejor rendimiento
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
                                  size: 24, // ✅ Reducido de 28 a 24
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(width: 12), // ✅ Reducido de 16 a 12
                  // Información
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, // ✅ Evitar overflow
                      children: [
                        Text(
                          song.title ?? 'Sin título',
                          style: AppTextStyles.songTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4), // ✅ Reducido de 6 a 4
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: NeumorphismTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible( // ✅ Cambiado de Expanded a Flexible para evitar overflow
                              child: Text(
                                song.artist?.displayName ?? 'Artista desconocido',
                                style: AppTextStyles.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8), // ✅ Reducido de 12 a 8
                  // Botón de favorito (ya está en favoritos, pero lo mostramos)
                  FavoriteButton(
                    songId: song.id,
                    iconColor: Colors.red,
                    iconSize: 20, // ✅ Reducido de 22 a 20
                  ),
                  const SizedBox(width: 6), // ✅ Reducido de 8 a 6
                  // Botón de información (navega a detalles de la canción)
                  Container(
                    width: 40, // ✅ Reducido de 44 a 40
                    height: 40, // ✅ Reducido de 44 a 40
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
                        borderRadius: const BorderRadius.all(Radius.circular(20)), // ✅ Reducido de 22 a 20
                        child: const Center(
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 20, // ✅ Reducido de 22 a 20
                          ),
                        ), // Ya es const
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

