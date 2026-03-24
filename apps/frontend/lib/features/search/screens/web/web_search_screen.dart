
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/neumorphism_theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/providers/search_provider.dart';
import '../../../../core/services/search_service.dart';
import '../../../../core/models/genre_model.dart';
import '../../../../core/models/artist_model.dart';
import '../../widgets/artist_search_card.dart'; // âœ… Ruta corregida
import '../../widgets/song_search_card.dart'; // âœ… Ruta corregida
import '../../widgets/playlist_search_card.dart'; // âœ… Ruta corregida

// Import de widgets web especÃ­ficos si los hay

class WebSearchScreen extends ConsumerStatefulWidget {
  const WebSearchScreen({super.key});

  @override
  ConsumerState<WebSearchScreen> createState() => _WebSearchScreenState();
}

class _WebSearchScreenState extends ConsumerState<WebSearchScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    final currentText = _searchController.text;
    final currentQuery = ref.read(searchProvider).query;
    
    if (currentText == currentQuery) return;
    
    // LÃ³gica simple de filtro
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (currentText.isEmpty || currentText.trim().length >= 2) {
        ref.read(searchProvider.notifier).updateQuery(currentText.trim());
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final isLoading = ref.watch(searchProvider.select((state) => state.isLoading));
    final error = ref.watch(searchProvider.select((state) => state.error));
    final isEmpty = ref.watch(searchProvider.select((state) => state.isEmpty));
    final query = ref.watch(searchProvider.select((state) => state.query));
    final results = ref.watch(searchProvider.select((state) => state.results));

    // Refrescar tema
    ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Espaciador superior
          const SliverToBoxAdapter(child: SizedBox(height: 30)),

          // HEADER: "Buscar"
          SliverPadding(
             padding: const EdgeInsets.symmetric(horizontal: 60),
             sliver: SliverToBoxAdapter(
               child: Text(
                 'Buscar',
                 style: AppTextStyles.titleLarge.copyWith(fontSize: 40),
               ),
             ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 30)),

          // BARRA DE BÃšSQUEDA (Estilo Web - MÃ¡s ancha y centrada o a la izquierda)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            sliver: SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _searchFocusNode.hasFocus 
                        ? NeumorphismTheme.accent 
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.search, color: NeumorphismTheme.textSecondary, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: AppTextStyles.bodyLarge.copyWith(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'Â¿QuÃ© quieres escuchar hoy?',
                          hintStyle: AppTextStyles.bodyLarge.copyWith(color: NeumorphismTheme.textLight),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: (val) {}, // Manejado por listener
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clear();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),

          // CONTENIDO PRINCIPAL: Resultados o CategorÃ­as
          if (query.isEmpty)
             _buildCategoriesGrid()
          else 
             _buildSearchResults(isLoading, error, isEmpty, results),
             
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // 1. ESTADO INICIAL: GRID DE GÃ‰NEROS (Estilo Spotify Web)
  Widget _buildCategoriesGrid() {
    final genresAsync = ref.watch(allGenresProvider); // âœ… Provider correcto: allGenresProvider
    
    return genresAsync.when(
      data: (genres) {
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250, // Tarjetas anchas
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 1.6, // Rectangulares horizontales
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final genre = genres[index];
                return _WebGenreCard(genre: genre);
              },
              childCount: genres.length,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox()),
    );
  }

  // 2. ESTADO BÃšSQUEDA: RESULTADOS
  Widget _buildSearchResults(bool isLoading, String? error, bool isEmpty, SearchResults? results) {
     if (isLoading) {
       return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
     }
     
     if (isEmpty || results == null) {
       return SliverToBoxAdapter(
         child: Center(
           child: Padding(
             padding: const EdgeInsets.only(top: 50),
             child: Text('No encontramos nada ðŸ˜”', style: AppTextStyles.titleMedium),
           ),
         ),
       );
     }

     return SliverPadding(
       padding: const EdgeInsets.symmetric(horizontal: 60),
       sliver: SliverList(
         delegate: SliverChildListDelegate([
           
           // RESULTADOS DIVIDIDOS EN COLUMNAS (Si hay espacio)
           LayoutBuilder(
             builder: (context, constraints) {
               // Si es muy ancho, mostramos "Mejor Resultado" (Izquierda) y "Canciones" (Derecha)
               return Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // COLUMNA IZQUIERDA: Top Result + Artistas
                   Expanded(
                     flex: 4,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         if (results.artists.isNotEmpty) ...[
                           Text('Mejor Resultado', style: AppTextStyles.titleMedium),
                           const SizedBox(height: 16),
                           // Tarjeta Gigante del primer artista
                           _TopResultCard(artist: results.artists.first),
                           const SizedBox(height: 40),
                           Text('Artistas', style: AppTextStyles.titleMedium),
                           const SizedBox(height: 16),
                           ...results.artists.skip(1).take(3).map((a) => Padding(
                             padding: const EdgeInsets.only(bottom: 12),
                             child: ArtistSearchCard(key: ValueKey(a.id), artist: a),
                           )),
                         ]
                       ],
                     ),
                   ),
                   
                   const SizedBox(width: 40),
                   
                   // COLUMNA DERECHA: Canciones
                   Expanded(
                     flex: 6,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          if (results.songs.isNotEmpty) ...[
                            Text('Canciones', style: AppTextStyles.titleMedium),
                            const SizedBox(height: 16),
                             ...results.songs.take(6).map((s) => Padding(
                               padding: const EdgeInsets.only(bottom: 8),
                               child: SongSearchCard(key: ValueKey(s.id), song: s),
                             )),
                          ],
                          
                          if (results.playlists.isNotEmpty) ...[
                            const SizedBox(height: 40),
                            Text('Playlists', style: AppTextStyles.titleMedium),
                            const SizedBox(height: 16),
                            // Grid simple para playlists
                             GridView.builder(
                               shrinkWrap: true,
                               physics: const NeverScrollableScrollPhysics(),
                               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                 crossAxisCount: 2,
                                 childAspectRatio: 3,
                                 crossAxisSpacing: 16,
                                 mainAxisSpacing: 16,
                               ),
                               itemCount: results.playlists.take(4).length,
                               itemBuilder: (ctx, i) => PlaylistSearchCard(key: ValueKey(results.playlists[i].id), playlist: results.playlists[i]),
                             )
                          ]
                       ],
                     ),
                   ),
                 ],
               );
             },
           )
         ]),
       ),
     );
  }
}

// WIDGET EXTERNO 1: TARJETA DE GÃ‰NERO WEB
class _WebGenreCard extends StatelessWidget {
  final Genre genre;
  const _WebGenreCard({required this.genre});

  @override
  Widget build(BuildContext context) {
    // Generamos un color aleatorio basado en el ID para el fondo si no hay imagen
    final colors = [
      const Color(0xFFE13300), const Color(0xFF7358FF), const Color(0xFF1E3264),
      const Color(0xFFE8115B), const Color(0xFF148A08), const Color(0xFFBC5900),
       const Color(0xFFE91429), const Color(0xFF8C1932),
    ];
    final color = colors[genre.id.hashCode % colors.length];

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: Text(
              genre.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Imagen rotada decorativa
          Positioned(
            right: -20,
            bottom: -10,
            child: Transform.rotate(
              angle: 25 * 3.14159 / 180,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                   boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(genre.imageUrl ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// WIDGET EXTERNO 2: TARJETA DE "MEJOR RESULTADO"
class _TopResultCard extends StatelessWidget {
  final Artist artist;
  const _TopResultCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NeumorphismTheme.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: CachedNetworkImageProvider(artist.profilePhotoUrl ?? ''),
          ),
          const SizedBox(height: 20),
          Text(
            artist.displayName, // âœ… Corregido a displayName
            style: AppTextStyles.titleLarge.copyWith(fontSize: 32),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Artista',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

