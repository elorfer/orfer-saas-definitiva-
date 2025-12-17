import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/widgets/premium_profile_drawer.dart';
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
    
    // 🚀 OPTIMIZACIÓN: Eliminar logging del build para mejor rendimiento
    // El logging se mueve fuera del build para evitar trabajo en el hilo principal
    
    // 🚀 OPTIMIZACIÓN 60 FPS: RepaintBoundary y const donde sea posible
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    
    final widget = RepaintBoundary(
      child: Scaffold(
        key: const ValueKey('home_screen_scaffold'),
        backgroundColor: Colors.transparent,
        drawer: const PremiumProfileDrawer(), // 🔥 Drawer lateral desde la izquierda
        drawerEdgeDragWidth: 20, // ⚡ Ancho de arrastre reducido para mejor control
        drawerEnableOpenDragGesture: true, // ⚡ Habilitar arrastre para abrir
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: Container(
            key: const ValueKey('home_screen_container'),
            decoration: const BoxDecoration(
              gradient: NeumorphismTheme.backgroundGradient,
            ),
            child: RefreshIndicator(
              onRefresh: () async {
                final isLoading = ref.read(
                  homeStateProvider.select((state) => state.isLoading),
                );
                if (isLoading) {
                  return;
                }
                // Refrescar perfil del usuario para actualizar estado premium
                ref.read(authStateProvider.notifier).refreshProfile().catchError((_) {});
                final homeNotifier = ref.read(homeStateProvider.notifier);
                await homeNotifier.refresh();
                ref.read(intelligentFeaturedProvider.notifier)
                    .refreshIntelligentRecommendations()
                    .catchError((_) {});
              },
              color: Colors.white,
              backgroundColor: NeumorphismTheme.coffeeMedium,
              child: CustomScrollView(
                key: const PageStorageKey<String>('home_screen_scroll'),
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // ✅ Scroll estilo iPhone
                cacheExtent: 400, // ✅ Optimizado: cache de scroll para mejor rendimiento
                slivers: [
                  // ⚡ Header scrolleable (avatar, bienvenido, nombre, logo)
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: statusBarHeight + 16.0, // Espacio para status bar
                      left: 24.0,
                      right: 24.0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _HomeHeader(
                        key: const ValueKey('home_header'),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  // ⚡ Mensaje destacado (notificaciones) ahora en el scroll junto al contenido
                  // ⚡ OPTIMIZACIÓN: Usar select para observar solo isActive y message
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: SliverToBoxAdapter(
                      child: Consumer(
                        builder: (context, ref, _) {
                          // ⚡ OPTIMIZACIÓN: Observar solo los campos necesarios
                          final homeMessage = ref.watch(
                            homeMessageProvider.select((msg) => 
                              msg != null && msg.isActive ? msg : null)
                          );
                          if (homeMessage == null) {
                            return const SizedBox.shrink();
                          }
                          return RepaintBoundary(
                            child: HomeMessageBanner(
                              message: homeMessage.message,
                              updatedAt: homeMessage.updatedAt,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      // Compositores destacados
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: FeaturedArtistsSection(key: const ValueKey('artists')),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 48),
                      ),
                      // Canciones destacadas inteligentes
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: IntelligentFeaturedSongsSection(key: const ValueKey('intelligent_songs')),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 48),
                      ),
                      // Playlists destacadas (más arriba)
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: FeaturedPlaylistsSection(key: const ValueKey('playlists')),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 180), // Espacio para el mini reproductor
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
    // OPTIMIZACIÓN: Logging removido del build para mejor rendimiento
    return widget;
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
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NeumorphismTheme.coffeeMedium,
                          NeumorphismTheme.coffeeDark,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
              // Logo - Tamaño aumentado con RepaintBoundary para mejor rendimiento
              RepaintBoundary(
                child: Image.asset(
                  'assets/images/logo.webp',
                  width: 90,
                  height: 90,
                  cacheWidth: 180,
                  cacheHeight: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    try {
                      return Image.asset(
                        'assets/images/logo.webp',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                      );
                    } catch (e) {
                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: NeumorphismTheme.coffeeDark,
                          size: 48,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildHeaderSkeleton() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NeumorphismTheme.coffeeMedium,
                NeumorphismTheme.coffeeDark,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Shimmer.fromColors(
            baseColor: NeumorphismTheme.shimmerBaseColor,
            highlightColor: NeumorphismTheme.shimmerHighlightColor,
            period: const Duration(milliseconds: 1200),
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: NeumorphismTheme.shimmerContentColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: NeumorphismTheme.shimmerBaseColor,
                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                period: const Duration(milliseconds: 1200),
                child: Container(
                  height: 16,
                  width: 100,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.shimmerContentColor,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Shimmer.fromColors(
                baseColor: NeumorphismTheme.shimmerBaseColor,
                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                period: const Duration(milliseconds: 1200),
                child: Container(
                  height: 20,
                  width: 150,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.shimmerContentColor,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitialsFromFirstName(String firstName) {
    if (firstName.isEmpty) return 'U';
    return firstName[0].toUpperCase();
  }
}
