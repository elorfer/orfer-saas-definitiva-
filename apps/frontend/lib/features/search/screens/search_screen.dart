import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/search_provider.dart';
import '../../../core/services/search_service.dart';
import '../widgets/artist_search_card.dart';
import '../widgets/song_search_card.dart';
import '../widgets/playlist_search_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce; // ✅ Debounce para búsquedas

  @override
  void initState() {
    super.initState();
    // ✅ Optimizar listener: solo actualizar si el texto realmente cambió
    _searchController.addListener(_onSearchTextChanged);
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
    // ✅ Remover listener antes de dispose para evitar memory leaks
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMIZACIÓN: usar select específico para cada campo y evitar rebuilds innecesarios
    final isLoading = ref.watch(searchProvider.select((state) => state.isLoading));
    final error = ref.watch(searchProvider.select((state) => state.error));
    final isEmpty = ref.watch(searchProvider.select((state) => state.isEmpty));
    final query = ref.watch(searchProvider.select((state) => state.query));
    final results = ref.watch(searchProvider.select((state) => state.results));

    return Scaffold(
      resizeToAvoidBottomInset: false, // ✅ Evitar que el teclado empuje el contenido
      body: Container(
        decoration: const BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                margin: const EdgeInsets.all(16.0),
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
                    Container(
                      width: 64,
                      height: 64,
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
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buscar',
                            style: AppTextStyles.searchTitle,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.explore_rounded,
                                size: 16,
                                color: NeumorphismTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Descubre nueva música',
                                  style: AppTextStyles.searchSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: NeumorphismTheme.neumorphismShadow,
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
        physics: const ClampingScrollPhysics(),
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
                return ArtistSearchCard(
                  key: ValueKey('artist_${searchResults.artists[index].id}'),
                  artist: searchResults.artists[index],
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
                return SongSearchCard(
                  key: ValueKey('song_${searchResults.songs[index].id}'),
                  song: searchResults.songs[index],
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
                return PlaylistSearchCard(
                  key: ValueKey('playlist_${searchResults.playlists[index].id}'),
                  playlist: searchResults.playlists[index],
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
      physics: const ClampingScrollPhysics(),
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
          borderRadius: BorderRadius.circular(4),
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
          borderRadius: BorderRadius.circular(20),
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Portada cuadrada
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Portada cuadrada
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
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
