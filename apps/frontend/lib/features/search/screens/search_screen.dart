import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/search_provider.dart';
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
    if (currentText != currentQuery) {
      ref.read(searchProvider.notifier).updateQuery(currentText);
    }
  }

  @override
  void dispose() {
    // ✅ Remover listener antes de dispose para evitar memory leaks
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

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
                                Icons.explore_rounded,
                                size: 16,
                                color: NeumorphismTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Descubre nueva música',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
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
                    style: GoogleFonts.inter(
                      color: NeumorphismTheme.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar canciones, artistas, playlists...',
                      hintStyle: GoogleFonts.inter(
                        color: NeumorphismTheme.textLight,
                      ),
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
                  child: _buildResults(searchState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
        ),
      );
    }

    if (state.error != null) {
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
          ],
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 80,
              color: NeumorphismTheme.coffeeDark, // ✅ Marrón oscuro para el icono
            ),
            const SizedBox(height: 24),
            Text(
              state.query.isEmpty ? 'Busca tu música favorita' : 'No se encontraron resultados',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: NeumorphismTheme.coffeeDark, // ✅ Marrón oscuro para el título
              ),
            ),
            const SizedBox(height: 12),
            Text(
              state.query.isEmpty
                  ? 'Encuentra canciones, artistas y playlists'
                  : 'Intenta con otros términos de búsqueda',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: NeumorphismTheme.coffeeMedium, // ✅ Marrón medio para el subtítulo
              ),
            ),
          ],
        ),
      );
    }

    final results = state.results!;

    return RepaintBoundary(
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        cacheExtent: 500,
        clipBehavior: Clip.none,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // ✅ Ocultar teclado al hacer scroll
        slivers: [
        // Artistas
        if (results.artists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Artistas',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return ArtistSearchCard(
                  key: ValueKey('artist_${results.artists[index].id}'),
                  artist: results.artists[index],
                );
              },
              childCount: results.artists.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ],

        // Canciones
        if (results.songs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Canciones',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return SongSearchCard(
                  key: ValueKey('song_${results.songs[index].id}'),
                  song: results.songs[index],
                );
              },
              childCount: results.songs.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ],

        // Playlists
        if (results.playlists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Playlists',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return PlaylistSearchCard(
                  key: ValueKey('playlist_${results.playlists[index].id}'),
                  playlist: results.playlists[index],
                );
              },
              childCount: results.playlists.length,
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
}
