
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neumorphism_theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../widgets/home_header.dart';
// import '../../widgets/featured_artists_section.dart'; // Replaced by Web version
// import '../../widgets/featured_songs_section.dart';   // Replaced by Web version
// import '../../widgets/featured_playlists_section.dart';// Replaced by Web version
import '../../widgets/web/web_hero_banner.dart'; // 🌟 Hero Banner
import '../../widgets/home_message_banner.dart';
import '../../widgets/web/web_featured_artists_section.dart';
import '../../widgets/web/web_featured_songs_section.dart';
import '../../widgets/web/web_featured_playlists_section.dart';
import '../../../../core/providers/home_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class WebHomeScreen extends ConsumerWidget {
  const WebHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 AHORA EL SIDEBAR LO GESTIONA PersistentNavigation (Layout Padre)
    // Aquí solo nos preocupamos del contenido central.
    
    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      body: Center(
        child: Container(
          // Constraint content width for large screens
          constraints: const BoxConstraints(maxWidth: 1400),
          color: NeumorphismTheme.background,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Espaciador superior
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              
              // Reutilizamos Header
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 60),
                sliver: SliverToBoxAdapter(
                  child: HomeHeader(key: ValueKey('home_header')),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 30)),

              // 🌟 HERO BANNER (Nuevo)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 60),
                sliver: SliverToBoxAdapter(
                  child: WebHeroBanner(),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 40)),

              // Mensaje del día
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                sliver: SliverToBoxAdapter(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final homeMessage = ref.watch(
                        homeMessageProvider.select((msg) => msg != null && msg.isActive ? msg : null),
                      );
                      if (homeMessage == null) return const SizedBox.shrink();
                      return HomeMessageBanner(
                        message: homeMessage.message,
                        updatedAt: homeMessage.updatedAt,
                      );
                    },
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Artistas (Web Grid)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 60),
                sliver: SliverToBoxAdapter(
                  child: WebFeaturedArtistsSection(key: ValueKey('web_artists')),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 60)),

              // Canciones (Web Grid)
              const SliverPadding(
                 padding: EdgeInsets.symmetric(horizontal: 60),
                sliver: SliverToBoxAdapter(
                  child: WebFeaturedSongsSection(key: ValueKey('web_featured_songs')),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 60)),

              // Playlists (Web Grid)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 60),
                sliver: SliverToBoxAdapter(
                  child: WebFeaturedPlaylistsSection(key: ValueKey('web_playlists')),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}
