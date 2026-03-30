import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/version_service.dart';
import '../../common/widgets/update_optional_sheet.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/theme_provider.dart'; // 🚀 Added for theme reactivity
import '../../../core/providers/search_provider.dart';
import '../../../core/providers/intelligent_featured_provider.dart';

import '../../../core/widgets/struky_drawer_menu.dart';
import '../../../core/widgets/struky_zoom_drawer.dart';
import '../../../core/utils/intersection_observer.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/services/http_cache_service.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../widgets/featured_artists_section.dart';
import '../widgets/featured_songs_section.dart';
import '../widgets/featured_playlists_section.dart';
import '../widgets/home_message_banner.dart';
import '../widgets/home_header.dart'; // Extracted header
import '../../../core/responsive/responsive_layout.dart';
import 'web/web_home_screen.dart';
import '../../../core/widgets/native_ad_list_tile.dart'; // 🚀 NIVEL DIOS: Anuncio Nativo

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
  static final SystemUiOverlayStyle _overlayStyle =
      SystemUiOverlayStyle.dark.copyWith(
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
          // 🚀 PARALLEL LOAD: Cargar datos principales y destacadas inteligentes a la vez
          await Future.wait([
            ref.read(homeStateProvider.notifier).loadHomeData(),
            ref
                .read(intelligentFeaturedProvider.notifier)
                .loadIntelligentFeaturedSongs(limit: 15),
          ]);
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
                imageUrls
                    .add(UrlNormalizer.normalizeImageUrl(fs.song.coverArtUrl));
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

        // 🆙 VERIFICACIÓN DE VERSIÓN DIFERIDA (0.5s)
        _checkVersionWithDelay();
      });
    }
  }

  /// Verifica si hay actualizaciones 1.0s después de cargar el Home
  /// Enfoque HÍBRIDO: 
  /// - Si es MANDATORIA: Redirige a pantalla completa (Splash debería haberlo bloqueado, pero esto es fail-safe).
  /// - Si es OPCIONAL: Muestra un Bottom Sheet Premium sin bloquear la app.
  static bool _hasShownUpdateSheet = false;

  Future<void> _checkVersionWithDelay() async {
    // 1. Esperar 1 segundo para no saturar al usuario nada más entrar
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted || _hasShownUpdateSheet) return;

    try {
      final versionResult = await VersionService().checkVersion();
      
      if (!mounted) return;

      // A. CASO MANDATORIO: Bloqueo total (Fail-safe si el Splash falló)
      if (versionResult['mustUpdate'] == true) {
        context.go('/update-required', extra: {
          'isMandatory': true,
          'updateUrl': versionResult['storeUrl'],
        });
        return;
      }

      // B. CASO OPCIONAL: Bottom Sheet de diseño Premium
      if (versionResult['shouldUpdate'] == true) {
        _hasShownUpdateSheet = true; // No volver a mostrar esta sesión
        
        if (mounted) {
          showModalBottomSheet(
            context: context,
            useRootNavigator: true, // EXTREMO: Asegurar que salga por encima de TODO (incluyendo MiniPlayer)
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            barrierColor: Colors.black.withValues(alpha: 0.5),
            builder: (context) => UpdateOptionalBottomSheet(
              updateUrl: versionResult['storeUrl'],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error en verificación de versión híbrida: $e');
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
                    ref
                        .read(authStateProvider.notifier)
                        .refreshProfile()
                        .catchError((_) {});
                    final homeNotifier = ref.read(homeStateProvider.notifier);
                    await homeNotifier.refresh();

                    // 🔥 Refrescar también los providers de búsqueda (Géneros, Tendencias)
                    ref.invalidate(allGenresProvider);
                    ref.invalidate(trendingArtistsProvider);
                    ref.invalidate(topSongsProvider);
                    ref.read(searchProvider.notifier).clearCacheOnly();

                    // 🔥 Refrescar canciones inteligentes "Para ti"
                    ref
                        .read(intelligentFeaturedProvider.notifier)
                        .refreshIntelligentRecommendations();
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
                      cacheExtent: 500,
                      slivers: <Widget>[
                        // 🚀 GRUPO 1: Header y Mensajes
                        SliverMainAxisGroup(
                          slivers: [
                            const SliverPadding(
                              padding: EdgeInsets.only(
                                top: 24.0,
                                left: 24.0,
                                right: 24.0,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: HomeHeader(key: ValueKey('home_header')),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              sliver: SliverToBoxAdapter(
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final homeMessage = ref.watch(
                                      homeMessageProvider.select((msg) =>
                                          msg != null && msg.isActive ? msg : null),
                                    );
                                    if (homeMessage == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return HomeMessageBanner(
                                      message: homeMessage.message,
                                      updatedAt: homeMessage.updatedAt,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 6)),

                        // 🚀 GRUPO 2: Artistas Destacados
                        SliverMainAxisGroup(
                          slivers: [
                            SliverToBoxAdapter(
                              child: const FeaturedArtistsSection(key: ValueKey('artists')),
                            ),
                          ],
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 32)),

                        // 🚀 GRUPO 3: Novedades y Publicidad
                        SliverMainAxisGroup(
                          slivers: [
                            SliverToBoxAdapter(
                              child: const FeaturedSongsSection(key: ValueKey('featured_songs')),
                            ),
                            // 📢 ADMOB: Anuncio NATIVO integrado (Nivel Dios)
                            const SliverToBoxAdapter(
                              child: NativeAdListTile(key: ValueKey('home_section_native_ad')),
                            ),
                          ],
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 48)),

                        // 🚀 GRUPO 4: Listas de Reproducción y Pie
                        SliverMainAxisGroup(
                          slivers: [
                            SliverToBoxAdapter(
                              child: const FeaturedPlaylistsSection(key: ValueKey('playlists')),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 140)),
                          ],
                        ),
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
