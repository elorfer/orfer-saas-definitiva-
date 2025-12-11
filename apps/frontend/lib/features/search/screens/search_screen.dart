import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/search_provider.dart';
import '../../../core/services/search_service.dart';
import '../../../core/utils/intersection_observer.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/models/genre_model.dart';
import '../../../core/models/artist_model.dart';
import '../../../core/models/song_model.dart';
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

  // Filtro de tipo de búsqueda
  String? _selectedFilter; // null = todos, 'artistas', 'canciones', 'playlists'

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

    // Precachear imágenes de géneros visibles
    final genreImageUrls = results.genres
        .map((genre) => genre.imageUrl)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    
    // Combinar todas las URLs
    _cachedImageUrls = [...artistImageUrls, ...songImageUrls, ...playlistImageUrls, ...genreImageUrls];
    _cachedResultsCount = results.artists.length + results.songs.length + results.playlists.length + results.genres.length;
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
    
    // Detectar términos de filtro en la búsqueda
    final filterInfo = _detectFilterFromQuery(currentText);
    
    // Aplicar filtro automáticamente si se detectó
    if (filterInfo['filter'] != _selectedFilter) {
      setState(() {
        _selectedFilter = filterInfo['filter'] as String?;
      });
    }
    
    // ✅ OPTIMIZACIÓN: Debounce - Esperar 500ms antes de buscar
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      // Solo buscar si tiene al menos 2 caracteres o está vacío
      if (currentText.isEmpty || currentText.trim().length >= 2) {
        // Usar la query limpia (sin términos de filtro) para la búsqueda
        final cleanQuery = filterInfo['cleanQuery'] as String;
        ref.read(searchProvider.notifier).updateQuery(cleanQuery);
      }
    });
  }

  /// Detecta términos de filtro en la query y retorna el filtro y la query limpia
  Map<String, dynamic> _detectFilterFromQuery(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return {'filter': null, 'cleanQuery': query};
    }
    
    final lowerQuery = trimmedQuery.toLowerCase();
    final words = lowerQuery.split(RegExp(r'\s+'));
    
    // Términos que indican filtro de artistas (ordenados por longitud descendente)
    final artistTerms = ['artistas', 'artista', 'artist'];
    // Términos que indican filtro de canciones
    final songTerms = ['canciones', 'cancion', 'canción', 'songs', 'song', 'musica', 'música'];
    // Términos que indican filtro de playlists
    final playlistTerms = ['playlists', 'playlist', 'listas', 'lista'];
    
    String? detectedFilter;
    String cleanQuery = trimmedQuery;
    
    // Verificar si alguna palabra coincide exactamente con un término de filtro
    for (final term in artistTerms) {
      if (words.contains(term)) {
        detectedFilter = 'artistas';
        // Remover el término de la query (como palabra completa)
        cleanQuery = trimmedQuery.replaceAll(
          RegExp('\\b$term\\b', caseSensitive: false),
          '',
        ).trim();
        break;
      }
    }
    
    if (detectedFilter == null) {
      for (final term in songTerms) {
        if (words.contains(term)) {
          detectedFilter = 'canciones';
          // Remover el término de la query (como palabra completa)
          cleanQuery = trimmedQuery.replaceAll(
            RegExp('\\b$term\\b', caseSensitive: false),
            '',
          ).trim();
          break;
        }
      }
    }
    
    if (detectedFilter == null) {
      for (final term in playlistTerms) {
        if (words.contains(term)) {
          detectedFilter = 'playlists';
          // Remover el término de la query (como palabra completa)
          cleanQuery = trimmedQuery.replaceAll(
            RegExp('\\b$term\\b', caseSensitive: false),
            '',
          ).trim();
          break;
        }
      }
    }
    
    // Limpiar espacios múltiples
    cleanQuery = cleanQuery.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Si después de limpiar la query queda vacía, no aplicar filtro y usar la query original
    if (cleanQuery.isEmpty) {
      return {
        'filter': null,
        'cleanQuery': trimmedQuery,
      };
    }
    
    return {
      'filter': detectedFilter,
      'cleanQuery': cleanQuery,
    };
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
                child: Text(
                  'Buscar',
                  style: AppTextStyles.searchTitle,
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
                      hintText: 'Buscar canciones, artistas, playlists... (ej: "artistas reggaeton")',
                      hintStyle: AppTextStyles.searchHint,
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
                                    setState(() {
                                      _selectedFilter = null; // Resetear filtro
                                    });
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

              // Filtros de tipo
              if (query.isNotEmpty && results != null && !results.isEmpty)
                _buildFilterChips(),

              const SizedBox(height: 8),

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
    // Si no hay búsqueda activa, mostrar secciones de inicio
    if (query.isEmpty && !isLoading && error == null) {
      return _buildHomeSections();
    }

    if (isLoading) {
      // Mostrar skeleton loaders mientras carga
      return _buildLoadingSkeletons();
    }

    if (error != null) {
      return RepaintBoundary(
        child: Center(
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
        ),
      );
    }

    if (isEmpty) {
      return RepaintBoundary(
        child: Center(
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
                'No se encontraron resultados',
                style: AppTextStyles.searchEmptyTitle,
              ),
              const SizedBox(height: 12),
              Text(
                'Intenta con otros términos de búsqueda',
                style: AppTextStyles.searchEmptySubtitle,
              ),
            ],
          ),
        ),
      );
    }

    final searchResults = results!;

    // Aplicar filtro si está seleccionado
    final filteredResults = _applyFilter(searchResults);

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
        // Géneros (siempre mostrar si hay, independiente del filtro)
        if (filteredResults.genres.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Géneros',
                style: AppTextStyles.searchSectionTitle,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildGenres(filteredResults.genres),
          ),
        ],

        // Artistas
        if (filteredResults.artists.isNotEmpty) ...[
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
                  key: ValueKey('artist_${filteredResults.artists[index].id}'),
                  child: ArtistSearchCard(
                    key: ValueKey('artist_card_${filteredResults.artists[index].id}'),
                    artist: filteredResults.artists[index],
                  ),
                );
              },
              childCount: filteredResults.artists.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ],

        // Canciones
        if (filteredResults.songs.isNotEmpty) ...[
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
                  key: ValueKey('song_${filteredResults.songs[index].id}'),
                  child: SongSearchCard(
                    key: ValueKey('song_card_${filteredResults.songs[index].id}'),
                    song: filteredResults.songs[index],
                  ),
                );
              },
              childCount: filteredResults.songs.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ],

        // Playlists
        if (filteredResults.playlists.isNotEmpty) ...[
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
                  key: ValueKey('playlist_${filteredResults.playlists[index].id}'),
                  child: PlaylistSearchCard(
                    key: ValueKey('playlist_card_${filteredResults.playlists[index].id}'),
                    playlist: filteredResults.playlists[index],
                  ),
                );
              },
              childCount: filteredResults.playlists.length,
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

  /// Construir secciones de inicio cuando no hay búsqueda activa
  Widget _buildHomeSections() {
    return RepaintBoundary(
      child: CustomScrollView(
        key: const PageStorageKey<String>('search_home_scroll'),
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 400,
        clipBehavior: Clip.none,
        slivers: [
          // Tendencias en búsquedas - Artistas destacados
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Tendencias en búsquedas',
                style: AppTextStyles.searchSectionTitle,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildTrendingArtists(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Géneros
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Géneros',
                style: AppTextStyles.searchSectionTitle,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildGenresSection(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Las más escuchadas - Canciones populares
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Las más escuchadas',
                style: AppTextStyles.searchSectionTitle,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildTopCharts(),
          ),

          // Espacio al final para el player
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  /// Construir sección de artistas trending
  Widget _buildTrendingArtists() {
    final trendingArtistsAsync = ref.watch(trendingArtistsProvider);

    return trendingArtistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, index) {
              final artist = artists[index];
              return _buildTrendingArtistCard(artist);
            },
          ),
        );
      },
      loading: () => SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, __) => _buildTrendingArtistCardSkeleton(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Construir tarjeta de artista trending
  Widget _buildTrendingArtistCard(Artist artist) {
    final profileUrl = artist.profilePhotoUrl != null && artist.profilePhotoUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(artist.profilePhotoUrl!)
        : null;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          // Nota: Navegación al perfil del artista pendiente de implementar
        },
        child: SizedBox(
          width: 140,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  boxShadow: NeumorphismTheme.softShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: profileUrl != null
                    ? CachedNetworkImage(
                        imageUrl: profileUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 50),
                        fadeOutDuration: const Duration(milliseconds: 50),
                        placeholder: (context, url) => Container(
                          decoration: const BoxDecoration(
                            gradient: NeumorphismTheme.imagePlaceholderGradient,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: const BoxDecoration(
                            gradient: NeumorphismTheme.imagePlaceholderGradient,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: NeumorphismTheme.imagePlaceholderGradient,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                artist.stageName ?? 'Artista',
                style: AppTextStyles.searchTitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Skeleton para tarjeta de artista trending
  Widget _buildTrendingArtistCardSkeleton() {
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: NeumorphismTheme.shimmerBaseColor,
        highlightColor: NeumorphismTheme.shimmerHighlightColor,
        child: SizedBox(
          width: 140,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.shimmerContentColor,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 14,
                width: 100,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.shimmerContentColor,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construir sección de géneros
  Widget _buildGenresSection() {
    final genresAsync = ref.watch(allGenresProvider);

    return genresAsync.when(
      data: (genres) {
        if (genres.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildGenres(genres);
      },
      loading: () => SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => _buildGenreCardSkeleton(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Construir sección de Top Charts
  Widget _buildTopCharts() {
    final topSongsAsync = ref.watch(topSongsProvider);

    return topSongsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return const SizedBox.shrink();
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return _buildTopChartItem(song, index + 1);
          },
        );
      },
      loading: () => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (_, __) => _buildTopChartItemSkeleton(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Construir item de Top Chart
  Widget _buildTopChartItem(Song song, int rank) {
    final coverUrl = song.coverArtUrl != null && song.coverArtUrl!.isNotEmpty
        ? UrlNormalizer.normalizeImageUrl(song.coverArtUrl!)
        : null;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          // Nota: Reproducción de canción pendiente de implementar
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeumorphismTheme.surface.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            boxShadow: NeumorphismTheme.softShadow,
          ),
          child: Row(
            children: [
              // Ranking
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  style: AppTextStyles.searchTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: NeumorphismTheme.coffeeMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              // Portada
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  boxShadow: NeumorphismTheme.softShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 50),
                        fadeOutDuration: const Duration(milliseconds: 50),
                        placeholder: (context, url) => Container(
                          decoration: const BoxDecoration(
                            gradient: NeumorphismTheme.imagePlaceholderGradient,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: const BoxDecoration(
                            gradient: NeumorphismTheme.imagePlaceholderGradient,
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: NeumorphismTheme.imagePlaceholderGradient,
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Título y artista
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title ?? 'Canción sin título',
                      style: AppTextStyles.searchTitle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist?.stageName ?? 'Artista desconocido',
                      style: AppTextStyles.searchSubtitle.copyWith(
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Skeleton para item de Top Chart
  Widget _buildTopChartItemSkeleton() {
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: NeumorphismTheme.shimmerBaseColor,
        highlightColor: NeumorphismTheme.shimmerHighlightColor,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeumorphismTheme.shimmerContentColor,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
        // Skeleton para sección de Géneros
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildSectionTitleSkeleton(),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => _buildGenreCardSkeleton(),
            ),
          ),
        ),

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
    return RepaintBoundary(
      child: Shimmer.fromColors(
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
      ),
    );
  }

  /// Skeleton para tarjeta de artista
  Widget _buildArtistCardSkeleton() {
    return RepaintBoundary(
      child: Shimmer.fromColors(
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
                  mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  /// Skeleton para tarjeta de canción
  Widget _buildSongCardSkeleton() {
    return RepaintBoundary(
      child: Shimmer.fromColors(
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
                  mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  /// Skeleton para tarjeta de playlist
  Widget _buildPlaylistCardSkeleton() {
    return RepaintBoundary(
      child: Shimmer.fromColors(
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
                  mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  Widget _buildGenres(List<Genre> genres) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        itemCount: genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final genre = genres[index];
          // Normalizar URL de imagen para que funcione en todas las plataformas
          final normalizedImageUrl = genre.imageUrl != null && genre.imageUrl!.isNotEmpty
              ? UrlNormalizer.normalizeImageUrl(genre.imageUrl!)
              : null;
          
          if (kDebugMode) {
            debugPrint('[SearchScreen._buildGenres] Género: ${genre.name}, imageUrl original: ${genre.imageUrl}, normalized: $normalizedImageUrl');
          }
          
          return RepaintBoundary(
            child: GestureDetector(
              onTap: () {
                // Buscar por género
                _searchController.text = genre.name;
                ref.read(searchProvider.notifier).updateQuery(genre.name);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: NeumorphismTheme.softShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: normalizedImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: normalizedImageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 50),
                            fadeOutDuration: const Duration(milliseconds: 50),
                            placeholder: (context, url) => Container(
                              decoration: const BoxDecoration(
                                gradient: NeumorphismTheme.imagePlaceholderGradient,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: const BoxDecoration(
                                gradient: NeumorphismTheme.imagePlaceholderGradient,
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: NeumorphismTheme.imagePlaceholderGradient,
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 80,
                    height: 16,
                    child: Text(
                      genre.name,
                      style: AppTextStyles.searchSubtitle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenreCardSkeleton() {
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: NeumorphismTheme.shimmerBaseColor,
        highlightColor: NeumorphismTheme.shimmerHighlightColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: NeumorphismTheme.shimmerContentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: 16,
              width: 60,
              decoration: BoxDecoration(
                color: NeumorphismTheme.shimmerContentColor,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir chips de filtro por tipo
  Widget _buildFilterChips() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('Todos', null),
          const SizedBox(width: 8),
          _buildFilterChip('Artistas', 'artistas'),
          const SizedBox(width: 8),
          _buildFilterChip('Canciones', 'canciones'),
          const SizedBox(width: 8),
          _buildFilterChip('Playlists', 'playlists'),
        ],
      ),
    );
  }

  /// Construir un chip de filtro individual
  Widget _buildFilterChip(String label, String? filterValue) {
    final isSelected = _selectedFilter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? NeumorphismTheme.coffeeMedium
              : NeumorphismTheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          boxShadow: isSelected ? NeumorphismTheme.softShadow : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.searchSubtitle.copyWith(
              color: isSelected
                  ? Colors.white
                  : NeumorphismTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// Aplicar filtro a los resultados de búsqueda
  SearchResults _applyFilter(SearchResults results) {
    if (_selectedFilter == null) {
      return results;
    }

    switch (_selectedFilter) {
      case 'artistas':
        return SearchResults(
          artists: results.artists,
          songs: const [],
          playlists: const [],
          genres: results.genres, // Mantener géneros siempre
          totals: SearchTotals(
            artists: results.artists.length,
            songs: 0,
            playlists: 0,
            genres: results.genres.length,
          ),
        );
      case 'canciones':
        return SearchResults(
          artists: const [],
          songs: results.songs,
          playlists: const [],
          genres: results.genres, // Mantener géneros siempre
          totals: SearchTotals(
            artists: 0,
            songs: results.songs.length,
            playlists: 0,
            genres: results.genres.length,
          ),
        );
      case 'playlists':
        return SearchResults(
          artists: const [],
          songs: const [],
          playlists: results.playlists,
          genres: results.genres, // Mantener géneros siempre
          totals: SearchTotals(
            artists: 0,
            songs: 0,
            playlists: results.playlists.length,
            genres: results.genres.length,
          ),
        );
      default:
        return results;
    }
  }
}
