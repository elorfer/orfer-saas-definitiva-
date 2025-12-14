import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  void initState() {
    super.initState();
    // #region agent log
    try {
      final logEntry = {
        'sessionId': 'debug-session',
        'runId': 'run1',
        'hypothesisId': 'H-init',
        'location': 'home_screen.dart:initState',
        'message': 'init_home_screen',
        'data': {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      debugPrint(jsonEncode(logEntry));
    } catch (_) {}
    // #endregion
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  // Sin auto-hide: header fijo

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    // #region agent log
    final buildStartTime = DateTime.now().millisecondsSinceEpoch;
    _writeDebugLog('home_screen.dart:44', 'HomeScreen build started', {'timestamp': buildStartTime}, 'D');
    // #endregion
    
    // 🚀 OPTIMIZACIÓN 60 FPS: RepaintBoundary y const donde sea posible
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    // #region agent log
    try {
      final logEntry = {
        'sessionId': 'debug-session',
        'runId': 'run1',
        'hypothesisId': 'H-build',
        'location': 'home_screen.dart:build',
        'message': 'build_metrics',
        'data': {
          'statusBarHeight': statusBarHeight,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      debugPrint(jsonEncode(logEntry));
    } catch (_) {}
    // #endregion
    
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
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: SliverToBoxAdapter(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final homeMessage = ref.watch(homeMessageProvider);
                          if (homeMessage == null || !homeMessage.isActive) {
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
    // #region agent log
    final buildEndTime = DateTime.now().millisecondsSinceEpoch;
    final buildDuration = buildEndTime - buildStartTime;
    _writeDebugLog('home_screen.dart:122', 'HomeScreen build completed', {'duration': buildDuration, 'timestamp': buildEndTime}, 'D');
    // #endregion
    return widget;
  }
  
  // #region agent log
  void _writeDebugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
    if (!kDebugMode) return;
    final logEntry = {
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
      'runId': 'run1',
      'hypothesisId': hypothesisId,
    };
    debugPrint('[DEBUG] ${jsonEncode(logEntry)}');
    // Escribir a disco fuera del hilo de UI y solo en debug para evitar jank
    Future.microtask(() async {
      try {
        final logPath = r'c:\app definitiva\.cursor\debug.log';
        final logFile = File(logPath);
        final logDir = logFile.parent;
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        await logFile.writeAsString('${jsonEncode(logEntry)}\n', mode: FileMode.append);
      } catch (_) {
        // Ignorar errores de escritura en debug
      }
    });
  }
  // #endregion
}

/// Widget del header scrolleable (avatar, bienvenido, nombre, logo)
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userFirstName = ref.watch(currentUserProvider.select((u) => u?.firstName));
    final isLoading = ref.watch(homeStateProvider.select((state) => 
      state.isLoading && state.featuredArtists.isEmpty));

    return isLoading && userFirstName == null
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
                        _getInitialsFromFirstName(userFirstName ?? 'Usuario'),
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
                      userFirstName ?? 'Usuario',
                      style: AppTextStyles.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Logo
              Image.asset(
                'assets/images/logo.webp',
                width: 60,
                height: 60,
                cacheWidth: 120,
                cacheHeight: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  try {
                    return Image.asset(
                      'assets/images/logo.webp',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    );
                  } catch (e) {
                    return Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: NeumorphismTheme.coffeeDark,
                        size: 32,
                      ),
                    );
                  }
                },
              ),
            ],
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
