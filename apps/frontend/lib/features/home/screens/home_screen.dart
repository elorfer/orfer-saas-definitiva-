import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/widgets/ultra_light_profile_drawer.dart';
import '../../../core/utils/intersection_observer.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/services/http_cache_service.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../widgets/featured_artists_section.dart';
import '../widgets/intelligent_featured_songs_section.dart';
import '../widgets/featured_playlists_section.dart';
import '../widgets/home_message_banner.dart';

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
  Timer? _visibilityDebounce;
  double? _cachedStatusBarHeight;
  

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
        
        ref.read(intelligentFeaturedProvider.notifier)
            .refreshIntelligentRecommendations()
            .catchError((_) {});
        _isLoaded = true;

        // 🚀 Precarga completamente async sin bloquear
        AlbumArtCacheManager.ensureInitialized().then((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              final featuredArtists = ref.read(featuredArtistsProvider);
              final featuredSongs = ref.read(intelligentFeaturedSongsProvider);
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
    _visibilityDebounce?.cancel();
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
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
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
                    ref.read(intelligentFeaturedProvider.notifier)
                        .refreshIntelligentRecommendations()
                        .catchError((_) {});
                },
                color: Colors.white,
                backgroundColor: NeumorphismTheme.coffeeMedium,
                child: SafeArea(
                    child: CustomScrollView(
                      key: const PageStorageKey<String>('home_screen_scroll'),
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      cacheExtent: 250, // 🚀 Ajustado para balancear memoria y fluidez
                      slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: statusBarHeight + 16.0,
                        left: 24.0,
                        right: 24.0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _HomeHeader(key: const ValueKey('home_header')),
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
                      child: const IntelligentFeaturedSongsSection(key: ValueKey('intelligent_songs')),
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
  
  // OPTIMIZACIÓN: Método de logging removido para mejor rendimiento
}

/// Widget del header scrolleable (avatar, bienvenido, nombre, logo)
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚡ OPTIMIZACIÓN: Usar select para escuchar solo los valores necesarios
    // Solo observar firstName, no isLoading (evita rebuilds innecesarios)
    final userFirstName = ref.watch(currentUserProvider.select((u) => u?.firstName));
    
    // ⚡ OPTIMIZACIÓN: Remover watch de isLoading - solo se usa para skeleton inicial
    // El skeleton solo se muestra cuando userFirstName es null, no necesitamos observar isLoading
    final isLoading = userFirstName == null;
    
    // OPTIMIZACIÓN: RepaintBoundary para aislar el header y evitar rebuilds innecesarios

    return RepaintBoundary(
      child: isLoading && userFirstName == null
          ? _buildHeaderSkeleton()
          : Row(
            children: [
              // ⚡ Avatar clickeable para abrir drawer
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
                  child: RepaintBoundary(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: NeumorphismTheme.coffeeMedium,
                      ),
                      child: Center(
                        child: Text(
                          _getInitialsFromFirstName(userFirstName),
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Texto de bienvenida
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bienvenido',
                      style: AppTextStyles.welcomeText,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userFirstName,
                      style: AppTextStyles.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Logo - Tamaño aumentado con caché optimizado
              Image.asset(
                  'assets/images/logo.webp',
                  width: 90,
                  height: 90,
                  cacheWidth: 180,
                  cacheHeight: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EBE3), // 🚀 Sólido
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: NeumorphismTheme.coffeeDark,
                        size: 40,
                      ),
                    );
                  },
                ),

            ],
          ),
    );
  }

  Widget _buildHeaderSkeleton() {
    // ✅ OPTIMIZACIÓN: Skeleton estático sin animaciones pesadas de Shimmer
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 16,
                width: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFDED1C4), // 🚀 Sólido
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 20,
                width: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFDED1C4), // 🚀 Sólido
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitialsFromFirstName(String? firstName) {
    if (firstName == null || firstName.isEmpty) return 'U';
    return firstName[0].toUpperCase();
  }
}
