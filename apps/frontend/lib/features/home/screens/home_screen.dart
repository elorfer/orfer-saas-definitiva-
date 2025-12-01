import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../widgets/featured_artists_section.dart';
import '../widgets/intelligent_featured_songs_section.dart';
import '../widgets/featured_playlists_section.dart';

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


  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    // 🆕 OPTIMIZACIÓN: Usar ValueKey estable para evitar rebuilds innecesarios
    return RepaintBoundary(
      child: Container(
        key: const ValueKey('home_screen_container'),
        decoration: const BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // Refrescar todo el home (artistas, canciones, playlists, etc.)
              final homeNotifier = ref.read(homeStateProvider.notifier);
              await homeNotifier.refresh();
              // También refrescar las recomendaciones inteligentes
              await ref.read(intelligentFeaturedProvider.notifier)
                  .refreshIntelligentRecommendations();
            },
            color: Colors.white,
            backgroundColor: NeumorphismTheme.coffeeMedium,
            child: SingleChildScrollView(
              physics: const FastScrollPhysics(), // Scroll más rápido y fluido
              padding: const EdgeInsets.only(top: 24.0, bottom: 40.0), // ✅ Más padding inferior
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🆕 Header optimizado con RepaintBoundary y select específico
                  RepaintBoundary(
                    child: _HomeHeader(
                      key: const ValueKey('home_header'),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Artistas destacados - Optimizado con RepaintBoundary
                  RepaintBoundary(
                    child: FeaturedArtistsSection(key: const ValueKey('artists')),
                  ),

                  const SizedBox(height: 32),

                  // Canciones destacadas inteligentes (usa tu algoritmo avanzado) - Optimizado con RepaintBoundary
                  RepaintBoundary(
                    child: IntelligentFeaturedSongsSection(key: const ValueKey('intelligent_songs')),
                  ),

                  const SizedBox(height: 32),

                  // Playlists destacadas - Optimizado con RepaintBoundary
                  RepaintBoundary(
                    child: FeaturedPlaylistsSection(key: const ValueKey('playlists')),
                  ),

                  const SizedBox(height: 80), // ✅ Más espacio en blanco al final
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 🆕 Widget separado para el header - Evita rebuilds innecesarios del resto de la pantalla
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Optimización: usar select para escuchar solo cambios en user
    final user = ref.watch(authStateProvider.select((state) => state.user));
    
    // Inicializar provider si no está inicializado (optimización: solo leer isInitialized)
    final isInitialized = ref.watch(homeStateProvider.select((state) => state.isInitialized));
    final isLoading = ref.watch(homeStateProvider.select((state) => state.isLoading));
    
    if (!isInitialized) {
      // Solo leer el provider para inicializarlo si no está inicializado
      ref.read(homeStateProvider);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: isLoading && user == null
          ? _buildHeaderSkeleton()
          : Row(
              children: [
                // Avatar con inicial
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(user?.firstName, user?.lastName),
                      style: AppTextStyles.titleMedium,
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
                        user?.firstName ?? 'Usuario',
                        style: AppTextStyles.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Skeleton loader para el header de bienvenida
  /// CRÍTICO: Debe tener exactamente las mismas dimensiones que el header real
  Widget _buildHeaderSkeleton() {
    return Row(
      children: [
        // Avatar skeleton - CRÍTICO: Mismo tamaño y decoración que el real
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.9),
                Colors.white.withValues(alpha: 0.7),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Shimmer.fromColors(
            baseColor: NeumorphismTheme.shimmerBaseColor,
            highlightColor: NeumorphismTheme.shimmerHighlightColor,
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
        const SizedBox(width: 16), // Mismo espacio que el real
        // Texto skeleton - CRÍTICO: Mismas alturas que los textos reales
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Bienvenido" skeleton - AppTextStyles.welcomeText
              Shimmer.fromColors(
                baseColor: NeumorphismTheme.shimmerBaseColor,
                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                child: Container(
                  height: 16, // Misma altura que welcomeText
                  width: 100,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.shimmerContentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 2), // Mismo espacio que el real
              // Nombre skeleton - AppTextStyles.userName
              Shimmer.fromColors(
                baseColor: NeumorphismTheme.shimmerBaseColor,
                highlightColor: NeumorphismTheme.shimmerHighlightColor,
                child: Container(
                  height: 20, // Misma altura que userName
                  width: 150,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.shimmerContentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitials(String? firstName, String? lastName) {
    if (firstName == null && lastName == null) {
      return 'U';
    }
    
    final firstInitial = firstName?.isNotEmpty == true ? firstName![0].toUpperCase() : '';
    final lastInitial = lastName?.isNotEmpty == true ? lastName![0].toUpperCase() : '';
    return (firstInitial + lastInitial).isEmpty ? 'U' : (firstInitial + lastInitial);
  }
}
