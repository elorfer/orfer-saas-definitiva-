import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/search_provider.dart';
import '../../../core/services/search_service.dart';
import '../../../core/utils/intersection_observer.dart';
import '../widgets/artist_search_card.dart';
import '../widgets/song_search_card.dart';
import '../widgets/playlist_search_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 🔥 Mantener estado al cambiar de pestaña

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce; // Debounce para búsquedas
  
  // ScrollController simple
  late final ScrollController _scrollController;
  
  // ✅ OPTIMIZACIÓN: Cache de URLs de imágenes para evitar recálculos en _onScroll
  List<String> _cachedImageUrls = [];
  int _cachedResultsCount = 0;
  
  // ✅ OPTIMIZACIÓN: Timer para debounce en _onScroll
  Timer? _scrollDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // 🔥 OPTIMIZACIÓN: Listener para precache dinámico de imágenes
    _scrollController.addListener(_onScroll);
    
    // Optimizar listener: solo actualizar si el texto realmente cambió
    _searchController.addListener(_onSearchTextChanged);
  }
  
  /// ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambian los datos
  void _updateImageUrlsCache() {
    final results = ref.read(searchProvider).results;
    if (results == null) {
      _cachedImageUrls = [];
      _cachedResultsCount = 0;
      return;
    }
    
    // Precachear imágenes de artistas visibles
    final artistImageUrls = results.artists
        .map((artist) => artist.profilePhotoUrl)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    
    // Precachear imágenes de canciones visibles
    final songImageUrls = results.songs
        .map((song) => song.coverArtUrl)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    
    // Precachear imágenes de playlists visibles
    final playlistImageUrls = results.playlists
        .map((playlist) => playlist.coverArtUrl)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    
    // Combinar todas las URLs
    _cachedImageUrls = [...artistImageUrls, ...songImageUrls, ...playlistImageUrls];
    _cachedResultsCount = results.artists.length + results.songs.length + results.playlists.length;
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
        // ✅ OPTIMIZACIÓN: Usar URLs cacheadas en lugar de leer del provider cada vez
        if (_cachedImageUrls.isEmpty) {
          // Si no hay cache, actualizar desde el provider (solo una vez)
          _updateImageUrlsCache();
        }
        
        // Precachear imágenes visibles basado en posición del scroll (IntersectionObserver)
        if (_cachedImageUrls.isNotEmpty) {
          LazyImageLoader.precacheVisibleVerticalImages(
            scrollController: _scrollController,
            itemExtent: 80.0, // Altura estimada de cada item
            itemCount: _cachedResultsCount,
            imageUrls: _cachedImageUrls,
            context: context,
            precacheCount: 5, // Precachear 5 items antes y después del viewport
          );
        }
      } catch (e) {
        // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente para no bloquear la app
        debugPrint('[SearchScreen] Error en _onScroll: $e');
      }
    });
  }

  void _onSearchTextChanged() {
    final currentText = _searchController.text;
    final currentQuery = ref.read(searchProvider).query;
    
    // ✅ Solo actualizar si el texto realmente cambió (evitar loops)
    if (currentText == currentQuery) return;
    
    // ✅ OPTIMIZACIÓN: Debounce - Esperar 500ms antes de buscar
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      // Solo buscar si tiene al menos 2 caracteres o está vacío
      if (currentText.isEmpty || currentText.trim().length >= 2) {
        ref.read(searchProvider.notifier).updateQuery(currentText);
      }
    });
  }

  @override
  void dispose() {
    // ✅ Cancelar debounce timer antes de dispose
    _searchDebounce?.cancel();
    _scrollDebounceTimer?.cancel();
    
    // ✅ Remover listener antes de dispose para evitar memory leaks
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 🔥 Requerido por AutomaticKeepAliveClientMixin
    
    // OPTIMIZACIÓN: usar select específico para cada campo y evitar rebuilds innecesarios
    final isLoading = ref.watch(searchProvider.select((state) => state.isLoading));
    final error = ref.watch(searchProvider.select((state) => state.error));
    final isEmpty = ref.watch(searchProvider.select((state) => state.isEmpty));
    final query = ref.watch(searchProvider.select((state) => state.query));
    final results = ref.watch(searchProvider.select((state) => state.results));

    // ✅ OPTIMIZACIÓN: Actualizar cache de URLs cuando cambian los datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateImageUrlsCache();
      }
    });

    // 🚀 OPTIMIZACIÓN 60 FPS: RepaintBoundary y const donde sea posible
    return RepaintBoundary(
      child: Scaffold(
        key: const ValueKey('search_screen_scaffold'),
        resizeToAvoidBottomInset: false, // ✅ Evitar que el teclado empuje el contenido
        body: Container(
          decoration: const BoxDecoration(
            gradient: NeumorphismTheme.backgroundGradient,
          ),
          child: SafeArea(
          child: Column(
            children: [
              // ⚡ Header simplificado (sin gradientes ni sombras pesadas)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // ⚡ Reducido padding
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: NeumorphismTheme.coffeeMedium,
                      size: 28, // ⚡ Reducido de 32
                    ),
                    const SizedBox(width: 12), // ⚡ Reducido de 20
                    Text(
                      'Buscar',
                      style: AppTextStyles.searchTitle,
                    ),
                  ],
                ),
              ),

              // ⚡ Search Bar simplificada (sin sombras pesadas)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.all(Radius.circular(20)), // ⚡ Reducido de 26
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: false, // ✅ No abrir teclado automáticamente
                    keyboardType: TextInputType.text, // ✅ Tipo de teclado optimizado
                    textInputAction: TextInputAction.search, // ✅ Acción de búsqueda
                    enableInteractiveSelection: true, // ✅ Permitir selección de texto
                    enableSuggestions: true, // ✅ Sugerencias del teclado
                    autocorrect: true, // ✅ Autocorrección
                    style: AppTextStyles.searchInput,
                    decoration: InputDecoration(
                      hintText: 'Buscar canciones, artistas, playlists...',
                      hintStyle: AppTextStyles.searchHint,
                      prefixIcon: Icon(
                        Icons.search,
                        color: NeumorphismTheme.textSecondary,
                      ),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, value, child) {
                          return value.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: NeumorphismTheme.textSecondary,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(searchProvider.notifier).clear();
                                    // ✅ No forzar focus después de limpiar (mejor UX)
                                  },
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    // ✅ onChanged ya está manejado por el listener del controller
                    onSubmitted: (value) {
                      // ✅ Ocultar teclado al presionar buscar
                      _searchFocusNode.unfocus();
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Results - con GestureDetector para ocultar teclado al tocar fuera
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // ✅ Ocultar teclado al tocar fuera del campo de búsqueda
                    _searchFocusNode.unfocus();
                  },
                  child: _buildResults(isLoading, error, isEmpty, query, results),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildResults(bool isLoading, String? error, bool isEmpty, String query, SearchResults? results) {
    if (isLoading) {
      // Mostrar skeleton loaders mientras carga
      return _buildLoadingSkeletons();
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al buscar',
              style: AppTextStyles.searchErrorTitle,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.searchErrorBody,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 80,
              color: NeumorphismTheme.coffeeDark,
            ),
            const SizedBox(height: 24),
            Text(
              query.isEmpty ? 'Busca tu música favorita' : 'No se encontraron resultados',
              style: AppTextStyles.searchEmptyTitle,
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'Encuentra canciones, artistas y playlists'
                  : 'Intenta con otros términos de búsqueda',
              style: AppTextStyles.searchEmptySubtitle,
            ),
          ],
        ),
      );
    }

    final searchResults = results!;

    return RepaintBoundary(
      child: CustomScrollView(
        key: const PageStorageKey<String>('search_screen_scroll'),
        controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache dinámico
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ), // ✅ Scroll estilo iPhone (igual que Home)
        cacheExtent: 400, // OPTIMIZACIÓN: reducido de 500 a 400 (≈5 items de altura ~80px)
        clipBehavior: Clip.none,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // ✅ Ocultar teclado al hacer scroll
        slivers: [
        // Artistas
        if (searchResults.artists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Artistas',
                style: AppTextStyles.searchSectionTitle,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return RepaintBoundary(
                  key: ValueKey('artist_${searchResults.artists[index].id}'),
                  child: ArtistSearchCard(
                    key: ValueKey('artist_card_${searchResults.artists[index].id}'),
                    artist: searchResults.artists[index],
                  ),
                );
              },
              childCount: searchResults.artists.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ],

        // Canciones
        if (searchResults.songs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Canciones',
                style: AppTextStyles.searchSectionTitle,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return RepaintBoundary(
                  key: ValueKey('song_${searchResults.songs[index].id}'),
                  child: SongSearchCard(
                    key: ValueKey('song_card_${searchResults.songs[index].id}'),
                    song: searchResults.songs[index],
                  ),
                );
              },
              childCount: searchResults.songs.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ],

        // Playlists
        if (searchResults.playlists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Playlists',
                style: AppTextStyles.searchSectionTitle,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return RepaintBoundary(
                  key: ValueKey('playlist_${searchResults.playlists[index].id}'),
                  child: PlaylistSearchCard(
                    key: ValueKey('playlist_card_${searchResults.playlists[index].id}'),
                    playlist: searchResults.playlists[index],
                  ),
                );
              },
              childCount: searchResults.playlists.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ],

          // Espacio al final para el player
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  /// Skeleton loaders para mostrar mientras se cargan los resultados
  Widget _buildLoadingSkeletons() {
    return CustomScrollView(
      key: const PageStorageKey<String>('search_screen_scroll'),
      controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache dinámico
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ), // ✅ Scroll estilo iPhone (igual que Home)
      cacheExtent: 400,
      clipBehavior: Clip.none,
      slivers: [
        // Skeleton para sección de Artistas
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildSectionTitleSkeleton(),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildArtistCardSkeleton(),
            childCount: 3, // Mostrar 3 skeletons de artistas
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
          ),
        ),

        // Skeleton para sección de Canciones
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildSectionTitleSkeleton(),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildSongCardSkeleton(),
            childCount: 5, // Mostrar 5 skeletons de canciones
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
          ),
        ),

        // Skeleton para sección de Playlists
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildSectionTitleSkeleton(),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildPlaylistCardSkeleton(),
            childCount: 3, // Mostrar 3 skeletons de playlists
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
          ),
        ),

        // Espacio al final para el player
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  /// Skeleton para título de sección
  Widget _buildSectionTitleSkeleton() {
    return Shimmer.fromColors(
      baseColor: NeumorphismTheme.shimmerBaseColor,
      highlightColor: NeumorphismTheme.shimmerHighlightColor,
      child: Container(
        height: 20,
        width: 100,
        decoration: BoxDecoration(
          color: NeumorphismTheme.shimmerContentColor,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
    );
  }

  /// Skeleton para tarjeta de artista
  Widget _buildArtistCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: NeumorphismTheme.shimmerBaseColor,
      highlightColor: NeumorphismTheme.shimmerHighlightColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeumorphismTheme.shimmerContentColor,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Row(
          children: [
            // Avatar circular
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            // Nombre y tipo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 18,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skeleton para tarjeta de canción
  Widget _buildSongCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: NeumorphismTheme.shimmerBaseColor,
      highlightColor: NeumorphismTheme.shimmerHighlightColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeumorphismTheme.shimmerContentColor,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Row(
          children: [
            // Portada cuadrada
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
            ),
            const SizedBox(width: 16),
            // Título y artista
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
            // Botón play
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skeleton para tarjeta de playlist
  Widget _buildPlaylistCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: NeumorphismTheme.shimmerBaseColor,
      highlightColor: NeumorphismTheme.shimmerHighlightColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeumorphismTheme.shimmerContentColor,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Row(
          children: [
            // Portada cuadrada
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
            ),
            const SizedBox(width: 16),
            // Nombre y descripción
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 18,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
