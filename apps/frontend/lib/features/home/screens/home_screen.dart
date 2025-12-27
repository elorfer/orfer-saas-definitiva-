import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';

import '../../../core/widgets/ultra_light_profile_drawer.dart';
import '../../../core/utils/intersection_observer.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/services/http_cache_service.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../widgets/featured_artists_section.dart';
import '../widgets/featured_songs_section.dart';
import '../widgets/featured_playlists_section.dart';
import '../widgets/home_message_banner.dart';
import '../widgets/home_header.dart'; // Extracted header

/// HomeScreen optimizado con AutomaticKeepAliveClientMixin
/// Evita reconstrucciones innecesarias al cambiar de pestañas
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
  with AutomaticKeepAliveClientMixin {
  bool _isLoaded = false;
  double? _cachedStatusBarHeight;

  // 🚀 OPTIMIZATION: Static overlay style to prevent object creation per-frame
  static final SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  @override
  void initState() {
    super.initState();
    
    // 🚀 Cachear statusBarHeight en initState para evitar MediaQuery en build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cachedStatusBarHeight = MediaQuery.paddingOf(context).top;
      }
    });
    
    if (!_isLoaded) {
      // Solo cargar datos si no se han cargado antes
      Future.microtask(() async {
        final homeState = ref.read(homeStateProvider);
        if (homeState.isEmpty) {
          await ref.read(homeStateProvider.notifier).loadHomeData();
        }
        

        _isLoaded = true;

        // 🚀 Precarga completamente async sin bloquear
        AlbumArtCacheManager.ensureInitialized().then((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              final featuredArtists = ref.read(featuredArtistsProvider);
              final featuredSongs = ref.read(featuredSongsProvider);
              final List<String?> imageUrls = [];
              for (final fa in featuredArtists) {
                final raw = fa.artist.profilePhotoUrl ?? fa.imageUrl;
                imageUrls.add(UrlNormalizer.normalizeImageUrl(raw));
              }
              for (final fs in featuredSongs) {
                imageUrls.add(UrlNormalizer.normalizeImageUrl(fs.song.coverArtUrl));
              }
              LazyImageLoader.precacheInitialImages(
                imageUrls: imageUrls,
                context: context,
                count: 6,
              );
            } catch (e) {
              // Silenciar errores de precache
            }
          });
        });
      });
    }
  }
  @override
  bool get wantKeepAlive => true; // Mantener estado al cambiar de pestaña

  // Header fijo visible siempre

  @override
  void dispose() {
    super.dispose();
  }
  
  // Sin auto-hide: header fijo

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    // 🚀 OPTIMIZACIÓN: Usar statusBarHeight cacheado para evitar MediaQuery en cada build
    final statusBarHeight = _cachedStatusBarHeight ?? MediaQuery.paddingOf(context).top;
    
    // OPTIMIZACIÓN: Logging removido del build para mejor rendimiento
    return Scaffold(
        key: const ValueKey('home_screen_scaffold'),
        backgroundColor: Colors.transparent,
        drawer: const UltraLightProfileDrawer(),
        drawerEdgeDragWidth: 20,
        drawerEnableOpenDragGesture: true,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _overlayStyle, // 🚀 Used static constant
          child: Stack(
            children: [
              // 🚀 CAPA 0: Fondo fijo con gradiente (Isolado para el Raster)
              const Positioned.fill(
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: NeumorphismTheme.backgroundGradient,
                    ),
                  ),
                ),
              ),
              
              // 🚀 CAPA 1: Contenido scrolleable
              RefreshIndicator(
                onRefresh: () async {
                    final isLoading = ref.read(
                      homeStateProvider.select((state) => state.isLoading),
                    );
                    if (isLoading) return;
                    ref.read(authStateProvider.notifier).refreshProfile().catchError((_) {});
                    final homeNotifier = ref.read(homeStateProvider.notifier);
                    await homeNotifier.refresh();

                },
                color: Colors.white,
                backgroundColor: NeumorphismTheme.coffeeMedium,
                child: SafeArea(
                    child: CustomScrollView(
                      key: const PageStorageKey<String>('home_screen_scroll'), // 🚀 SCROLL NORMAL
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      cacheExtent: 250, // 🚀 Ajustado para balancear memoria y fluidez
                      slivers: <Widget>[
                    const SliverPadding(
                      padding: EdgeInsets.only(
                        top: 16.0, 
                        left: 24.0,
                        right: 24.0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: HomeHeader(key: ValueKey('home_header')), // 🚀 Using extracted widget
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverToBoxAdapter(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final homeMessage = ref.watch(
                              homeMessageProvider.select((msg) => msg != null && msg.isActive ? msg : null),
                            );
                            if (homeMessage == null) return const SizedBox.shrink();
                            // 🚀 OPTIMIZACIÓN: HomeMessageBanner no necesita RepaintBoundary (contenido estático)
                            return HomeMessageBanner(
                              message: homeMessage.message,
                              updatedAt: homeMessage.updatedAt,
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 6)),
                    SliverToBoxAdapter(
                      // 🚀 OPTIMIZACIÓN: Secciones ya gestionan su propio repintado si es complejo
                      child: const FeaturedArtistsSection(key: ValueKey('artists')),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    SliverToBoxAdapter(
                      child: const FeaturedSongsSection(key: ValueKey('featured_songs')),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 48)),
                    SliverToBoxAdapter(
                      child: const FeaturedPlaylistsSection(key: ValueKey('playlists')),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ); 
  }
}
// Local _HomeHeader removed (moved to home_header.dart)
