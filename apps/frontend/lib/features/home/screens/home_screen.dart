import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/theme_provider.dart'; // 🚀 Added for theme reactivity

import '../../../core/widgets/struky_drawer_menu.dart';
import '../../../core/widgets/struky_zoom_drawer.dart';
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
import '../../../core/responsive/responsive_layout.dart';
import 'web/web_home_screen.dart';

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
  
  // 🔥 THROTTLE: Prevenir refreshes repetitivos
  DateTime? _lastRefreshTime;
  static const _refreshCooldown = Duration(seconds: 3);

  // 🚀 OPTIMIZATION: Static overlay style to prevent object creation per-frame
  static final SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  @override
  void initState() {
    super.initState();
    
    // 🔥 Nota: El tema se observa con ref.watch() en build()
    // ya no necesitamos listener aquí
    
    if (!_isLoaded) {
      // Solo cargar datos si no se han cargado antes
      Future.microtask(() async {
        final homeState = ref.read(homeStateProvider);
        if (homeState.isEmpty) {
          await ref.read(homeStateProvider.notifier).loadHomeData();
        }
        

        // 🚀 Precarga completamente async sin bloquear
        Future.microtask(() => _requestNotificationPermissions());

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🚀 Cache MediaQuery only once when dependencies change
    _cachedStatusBarHeight ??= MediaQuery.paddingOf(context).top;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _requestNotificationPermissions() async {
     try {
       // Solicitar permisos de notificación (Android 13+)
       final status = await Permission.notification.status;
       if (status.isDenied) {
         await Permission.notification.request();
       }
     } catch (_) {}
  }
  
  // Sin auto-hide: header fijo

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    // 🔥 FIX: Watch themeProvider para forzar rebuild cuando cambie el tema
    // Esto asegura que el gradiente de fondo se actualice en tiempo real
    ref.watch(themeProvider);
    
    // 🚀 OPTIMIZACIÓN: Usar statusBarHeight cacheado (ya no necesitamos fallback)
    final statusBarHeight = _cachedStatusBarHeight ?? 0.0;
    
    // 🚀 INTEGRACIÓN STRUKY ZOOM DRAWER + RESPONSIVE WEB
    // En móvil: Usamos ZoomDrawer (tu diseño actual)
    // En Web: Usamos WebHomeScreen (diseño nuevo)
    return ResponsiveLayout(
      desktop: const WebHomeScreen(),
      mobile: StrukyZoomDrawer(
        // 1. EL MENÚ DEL FONDO
        menuScreen: const StrukyDrawerMenu(),
        
        // 2. LA PANTALLA PRINCIPAL (Tu Scaffold original)
        mainScreen: Scaffold(
          key: const ValueKey('home_screen_scaffold'),
          backgroundColor: Colors.transparent,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: _overlayStyle, // 🚀 Used static constant
            child: Stack(
              children: [
                // 🚀 CAPA 0: Fondo fijo con gradiente (Isolado para el Raster)
                // 🔥 FIX: Ahora se actualiza cuando themeProvider cambia
                Positioned.fill(
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
                      // 🔥 THROTTLE: Evitar refreshes repetitivos (cooldown de 3 segundos)
                      final now = DateTime.now();
                      if (_lastRefreshTime != null && 
                          now.difference(_lastRefreshTime!) < _refreshCooldown) {
                        return; // Ignorar refresh si fue hace menos de 3 segundos
                      }
                      _lastRefreshTime = now;
                      
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
                   // 🚀 SCROLL PHYSICS: BouncingScrollPhysics para sensación nativa iOS/Android 12+
                   // Permite el "overscroll" elástico que pidio el usuario
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      cacheExtent: 500, // 🚀 BALANCED: Pre-renderiza lo necesario sin sobrecargar la GPU
                      slivers: <Widget>[
                      const SliverPadding(
                        padding: EdgeInsets.only(
                          top: 24.0, // ✅ Aumentado para más aire
                          left: 24.0,
                          right: 24.0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: HomeHeader(key: ValueKey('home_header')), // 🚀 Using extracted widget
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)), // ✅ Aumentado de 8 a 24 para bajar "Novedades"
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
        ),
      ),
    ); 
  }
}
