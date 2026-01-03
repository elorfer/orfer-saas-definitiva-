import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
// import '../../../core/widgets/ultra_light_profile_drawer.dart'; // Legacy
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../widgets/v2/sliver_featured_artists_section.dart';
import '../widgets/v2/sliver_intelligent_songs_section.dart';
import '../widgets/v2/home_skeletons.dart';
import '../widgets/featured_playlists_section.dart';
import '../widgets/home_message_banner.dart';

/// Home Screen V2.0 - Arquitectura de Slivers para Máximo Rendimiento
/// Tier 1 Experience: Glassmorphism, Scale Interactions & Zero-Logic Build.
class HomeScreenV2 extends ConsumerStatefulWidget {
  const HomeScreenV2({super.key});

  @override
  ConsumerState<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends ConsumerState<HomeScreenV2> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    Future.microtask(() async {
      final homeState = ref.read(homeStateProvider);
      if (homeState.isEmpty) {
        await ref.read(homeStateProvider.notifier).loadHomeData();
      }
      ref.read(intelligentFeaturedProvider.notifier).refreshIntelligentRecommendations().catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final featuredArtists = ref.watch(featuredArtistsProvider);
    final intelligentSongs = ref.watch(intelligentFeaturedSongsProvider);
    final isLoading = (featuredArtists.isEmpty || intelligentSongs.isEmpty) && 
                      ref.watch(homeStateProvider.select((s) => s.isLoading));
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      // drawer: const UltraLightProfileDrawer(), // Fix: Removed broken reference
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          cacheExtent: 500, // 🚀 Scroll "Persistente" Premium
          slivers: [
            // 1. AppBar Flexible con Glassmorphism
            _buildAppBar(context),
            
            // 2. Banner de Mensaje (Si existe)
            _buildMessageBannerSliver(),
            
            // 3. SECCIONES V2 (Slivers Nativos)
            if (isLoading) ...[
              HomeSkeletons.artistGridSkeleton(),
              HomeSkeletons.songListSkeleton(),
            ] else ...[
              const SliverFeaturedArtistsSection(),
              const SliverIntelligentSongsSection(),
            ],
            
            // 4. Playlists Destacadas (Horizontal = SliverToBoxAdapter)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 32),
                child: FeaturedPlaylistsSection(key: ValueKey('playlists_v2')),
              ),
            ),
            
            // Espaciado final para no chocar con el mini-player (si existiera)
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final userFirstName = ref.watch(currentUserProvider.select((u) => u?.firstName ?? 'Usuario'));
    
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      elevation: 0,
      stretch: true,
      backgroundColor: Colors.white.withValues(alpha: 0.01),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FlexibleSpaceBar(
            stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
            centerTitle: false,
            titlePadding: const EdgeInsets.only(left: 70, bottom: 16),
            title: LayoutBuilder(
              builder: (context, constraints) {
                final isCollapsed = constraints.maxHeight <= kToolbarHeight + (MediaQuery.of(context).padding.top);
                return AnimatedOpacity( duration: const Duration(milliseconds: 200),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: Text('Vintage Music', style: AppTextStyles.userName),
                );
              },
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.8),
                    Colors.white.withValues(alpha: 0.4),
                  ],
                ),
              ),
              padding: const EdgeInsets.only(left: 24, right: 24, top: 70),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bienvenido', style: AppTextStyles.welcomeText),
                      Text(userFirstName, style: AppTextStyles.userName),
                    ],
                  ),
                  RepaintBoundary(
                    child: Hero(
                      tag: 'logo_hero',
                      child: Image.asset(
                        'assets/images/logo.webp',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: _AppBarAvatar(firstName: userFirstName),
        ),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  Widget _buildMessageBannerSliver() {
    return SliverToBoxAdapter(
      child: Consumer(
        builder: (context, ref, _) {
          final homeMessage = ref.watch(
            homeMessageProvider.select((msg) => msg != null && msg.isActive ? msg : null),
          );
          if (homeMessage == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: HomeMessageBanner(
              message: homeMessage.message,
              updatedAt: homeMessage.updatedAt,
            ),
          );
        },
      ),
    );
  }
}

class _AppBarAvatar extends StatelessWidget {
  final String firstName;
  const _AppBarAvatar({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Scaffold.of(context).openDrawer(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: NeumorphismTheme.coffeeMedium,
        ),
        child: Center(
          child: Text(
            firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
