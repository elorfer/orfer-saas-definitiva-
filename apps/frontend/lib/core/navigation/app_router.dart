import '../../features/privacy/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/ads/screens/ad_stats_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/playlists/screens/playlists_screen.dart';
import '../../features/playlists/screens/playlist_detail_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/home_screen_v2.dart';
import '../../features/home/screens/featured_songs_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/library/screens/library_screen_v2.dart';
import '../../features/library/screens/favorites_screen.dart';
import '../../features/library/screens/recently_played_screen.dart';
import '../../features/library/screens/followed_artists_screen.dart';
import '../../features/premium/screens/premium_activated_screen.dart';
import '../../features/premium/screens/premium_router_screen.dart';
import '../../features/premium/screens/composer_promo_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../features/artists/pages/artist_page.dart';
import '../../features/artists/models/artist.dart';
import '../../features/artists/screens/featured_artists_full_screen.dart';
import '../../features/player/screens/full_player_screen.dart';
import '../../features/song_detail/screens/song_detail_screen.dart';
import '../../core/models/song_model.dart';
import '../providers/auth_provider.dart';
import 'persistent_navigation.dart';
import 'page_transitions.dart' show SpotifyPageTransitions, createCustomTransitionPage, createNoTransitionPage;

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterNotifier(ref);

  final router = GoRouter(
    initialLocation: notifier.initialLocation,
    refreshListenable: notifier,
    routes: notifier.routes,
    redirect: notifier.handleRedirect,
    debugLogDiagnostics: false, // Deshabilitado para mejor rendimiento en producción
    // 🔥 OPTIMIZACIÓN: Deshabilitar observadores para mejor rendimiento
    observers: const [], // Sin observadores para navegación más rápida
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});

class GoRouterNotifier extends ChangeNotifier {
  GoRouterNotifier(this.ref) {
    // ✅ OPTIMIZACIÓN: fireImmediately: false para evitar trabajo innecesario al inicio
    // El estado de auth se leerá cuando realmente se necesite (en getters)
    _authSubscription = ref.listen<AuthState>(
      authStateProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false, // Optimización: no ejecutar inmediatamente
    );
    
    // ✅ FIX: Escuchar cambios en el onboarding para actualizar el router
    _onboardingSubscription = ref.listen<bool>(
      onboardingProvider,
      (_, __) {
        // Cuando cambia el estado del onboarding, notificar al router
        notifyListeners();
      },
      fireImmediately: false,
    );
  }

  final Ref ref;
  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<bool> _onboardingSubscription;

  AuthState get _authState => ref.read(authStateProvider);
  
  // ✅ FIX: Manejar errores al leer onboardingProvider
  bool get _onboardingCompleted {
    try {
      return ref.read(onboardingProvider);
    } catch (e) {
      // Si hay error leyendo el provider, asumir que no está completado
      // Esto evita crashes durante la inicialización
      return false;
    }
  }

  String get initialLocation {
    if (!_authState.isAuthenticated) {
      return '/splash';
    }
    // Si está autenticado pero no completó onboarding, mostrar onboarding
    if (!_onboardingCompleted) {
      return '/onboarding';
    }
    return '/home';
  }

  List<RouteBase> get routes => [
                // Privacy Policy
                GoRoute(
                  path: '/privacy',
                  pageBuilder: (context, state) => createCustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const PrivacyScreen(),
                    transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                  ),
                ),
        // Splash - sin transición
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) => createNoTransitionPage<void>(
            key: state.pageKey,
            child: const SplashScreen(),
          ),
        ),
        // Onboarding - sin transición
        GoRoute(
          path: '/onboarding',
          pageBuilder: (context, state) => createNoTransitionPage<void>(
            key: state.pageKey,
            child: const OnboardingScreen(),
          ),
        ),
        // Login - transición optimizada sin parpadeo
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => createCustomTransitionPage<void>(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 150),
          ),
        ),
        // Register - transición optimizada sin parpadeo
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) => createCustomTransitionPage<void>(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 150),
          ),
        ),
        // Forgot Password - transición optimizada sin parpadeo
        GoRoute(
          path: '/forgot-password',
          pageBuilder: (context, state) => createCustomTransitionPage<void>(
            key: state.pageKey,
            child: const ForgotPasswordScreen(),
            transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 150),
          ),
        ),
        // Reset Password - transición optimizada sin parpadeo
        GoRoute(
          path: '/reset-password/:token',
          pageBuilder: (context, state) {
            final token = state.pathParameters['token'] ?? '';
            return createCustomTransitionPage<void>(
              key: state.pageKey,
              child: ResetPasswordScreen(token: token),
              transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 150),
            );
          },
        ),
        // 🔥 REFACTORIZADO: StatefulShellRoute.indexedStack para persistencia real
        // Cada rama mantiene su propio stack de navegación independiente
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            // Si estamos en rutas de autenticación o splash, no mostrar navegación
            final path = state.matchedLocation;
            if (path == '/splash' || 
                path == '/login' || 
                path == '/register' || 
                path.startsWith('/forgot-password') || 
                path.startsWith('/reset-password')) {
              return navigationShell;
            }
            
            // Usar PersistentNavigation con StatefulNavigationShell
            return PersistentNavigation(navigationShell: navigationShell);
          },
          branches: [
            // Rama 0: Home
            StatefulShellBranch(
              navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'home_branch'),
              routes: [
                GoRoute(
                  path: '/home',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: const HomeScreen(),
                  ),
                ),
                GoRoute(
                  path: '/home-v2',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: const HomeScreenV2(),
                  ),
                ),
                // Compositores - subruta de Home (evita crear navigator separado)
                GoRoute(
                  path: '/compositores',
                  pageBuilder: (context, state) => createCustomTransitionPage<void>(
                    key: state.pageKey,
                    child: FeaturedArtistsFullScreen(),
                    transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                  ),
                ),
                // Featured Songs - subruta de Home
                GoRoute(
                  path: '/featured-songs',
                  pageBuilder: (context, state) => createCustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const FeaturedSongsScreen(),
                    transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                  ),
                ),
                // Song Detail - accesible desde Home
                GoRoute(
                  path: '/song/:id',
                  pageBuilder: (context, state) {
                    final songId = state.pathParameters['id'] ?? '';
                    final extra = state.extra;
                    Song? song;
                    
                    if (extra is Song) {
                      song = extra;
                    } else {
                      song = Song(
                        id: songId,
                        status: SongStatus.published,
                        isExplicit: false,
                        totalStreams: 0,
                        totalLikes: 0,
                        totalShares: 0,
                        featured: false,
                      );
                    }
                    
                    return createCustomTransitionPage<void>(
                      key: state.pageKey, // ✅ Usar pageKey único de go_router para evitar claves duplicadas
                      child: SongDetailScreen(song: song),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
                // Playlist Detail - accesible desde Home
                GoRoute(
                  path: '/playlist/:id',
                  pageBuilder: (context, state) {
                    final playlistId = state.pathParameters['id'] ?? '';
                    return createCustomTransitionPage<void>(
                      key: state.pageKey,
                      child: PlaylistDetailScreen(playlistId: playlistId),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
                // Artist Detail - accesible desde Home
                GoRoute(
                  path: '/artist/:id',
                  pageBuilder: (context, state) {
                    final artistId = state.pathParameters['id'] ?? '';
                    final extra = state.extra;
                    ArtistLite? artistLite;
                    if (extra is ArtistLite) {
                      artistLite = extra;
                    } else {
                      artistLite = ArtistLite(
                        id: artistId,
                        name: 'Artista',
                        profilePhotoUrl: null,
                        coverPhotoUrl: null,
                        nationalityCode: null,
                        featured: false,
                      );
                    }
                    return createCustomTransitionPage<void>(
                      key: state.pageKey, // ✅ Usar pageKey único de go_router para evitar claves duplicadas
                      child: ArtistPage(artist: artistLite),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
              ],
            ),
            // Rama 1: Search
            StatefulShellBranch(
              navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'search_branch'),
              routes: [
                GoRoute(
                  path: '/search',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: const SearchScreen(),
                  ),
                ),
                // Song Detail - accesible desde Search
                GoRoute(
                  path: '/song/:id',
                  pageBuilder: (context, state) {
                    final songId = state.pathParameters['id'] ?? '';
                    final extra = state.extra;
                    Song? song;
                    
                    if (extra is Song) {
                      song = extra;
                    } else {
                      song = Song(
                        id: songId,
                        status: SongStatus.published,
                        isExplicit: false,
                        totalStreams: 0,
                        totalLikes: 0,
                        totalShares: 0,
                        featured: false,
                      );
                    }
                    
                    return createCustomTransitionPage<void>(
                      key: state.pageKey, // ✅ Usar pageKey único de go_router para evitar claves duplicadas
                      child: SongDetailScreen(song: song),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
                // Playlist Detail - accesible desde Search
                GoRoute(
                  path: '/playlist/:id',
                  pageBuilder: (context, state) {
                    final playlistId = state.pathParameters['id'] ?? '';
                    return createCustomTransitionPage<void>(
                      key: state.pageKey,
                      child: PlaylistDetailScreen(playlistId: playlistId),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
                // Artist Detail - accesible desde Search (muy común)
                GoRoute(
                  path: '/artist/:id',
                  pageBuilder: (context, state) {
                    final artistId = state.pathParameters['id'] ?? '';
                    final extra = state.extra;
                    ArtistLite? artistLite;
                    if (extra is ArtistLite) {
                      artistLite = extra;
                    } else {
                      artistLite = ArtistLite(
                        id: artistId,
                        name: 'Artista',
                        profilePhotoUrl: null,
                        coverPhotoUrl: null,
                        nationalityCode: null,
                        featured: false,
                      );
                    }
                    return createCustomTransitionPage<void>(
                      key: state.pageKey, // ✅ Usar pageKey único de go_router para evitar claves duplicadas
                      child: ArtistPage(artist: artistLite),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
              ],
            ),
            // Rama 2: Library
            StatefulShellBranch(
              navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'library_branch'),
              routes: [
                GoRoute(
                  path: '/library',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: const LibraryScreen(),
                  ),
                ),
                // Playlists - subruta de Library
                GoRoute(
                  path: '/playlists',
                  pageBuilder: (context, state) => createCustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const PlaylistsScreen(),
                    transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                  ),
                ),
                // Favorites - subruta de Library
                GoRoute(
                  path: '/favorites',
                  pageBuilder: (context, state) => createCustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const FavoritesScreen(),
                    transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                  ),
                ),
                // Recently Played - subruta de Library
                GoRoute(
                  path: '/recently-played',
                  pageBuilder: (context, state) => createCustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const RecentlyPlayedScreen(),
                    transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                  ),
                ),
                // Followed Artists - subruta de Library
                GoRoute(
                  path: '/followed-artists',
                  pageBuilder: (context, state) => createCustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const FollowedArtistsScreen(),
                    transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                  ),
                ),
                // Song Detail - accesible desde Library
                GoRoute(
                  path: '/song/:id',
                  pageBuilder: (context, state) {
                    final songId = state.pathParameters['id'] ?? '';
                    final extra = state.extra;
                    Song? song;
                    
                    if (extra is Song) {
                      song = extra;
                    } else {
                      song = Song(
                        id: songId,
                        status: SongStatus.published,
                        isExplicit: false,
                        totalStreams: 0,
                        totalLikes: 0,
                        totalShares: 0,
                        featured: false,
                      );
                    }
                    
                    return createCustomTransitionPage<void>(
                      key: state.pageKey, // ✅ Usar pageKey único de go_router para evitar claves duplicadas
                      child: SongDetailScreen(song: song),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
                // Playlist Detail - accesible desde Library (muy común)
                GoRoute(
                  path: '/playlist/:id',
                  pageBuilder: (context, state) {
                    final playlistId = state.pathParameters['id'] ?? '';
                    return createCustomTransitionPage<void>(
                      key: state.pageKey,
                      child: PlaylistDetailScreen(playlistId: playlistId),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
                // Artist Detail - accesible desde Library
                GoRoute(
                  path: '/artist/:id',
                  pageBuilder: (context, state) {
                    final artistId = state.pathParameters['id'] ?? '';
                    final extra = state.extra;
                    ArtistLite? artistLite;
                    if (extra is ArtistLite) {
                      artistLite = extra;
                    } else {
                      artistLite = ArtistLite(
                        id: artistId,
                        name: 'Artista',
                        profilePhotoUrl: null,
                        coverPhotoUrl: null,
                        nationalityCode: null,
                        featured: false,
                      );
                    }
                    return createCustomTransitionPage<void>(
                      key: state.pageKey, // ✅ Usar pageKey único de go_router para evitar claves duplicadas
                      child: ArtistPage(artist: artistLite),
                      transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration: Duration.zero,
                    );
                  },
                ),
              ],
            ),
            // Rama 3: Premium
            StatefulShellBranch(
              navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'premium_branch'),
              routes: [
                GoRoute(
                  path: '/premium',
                  name: 'premium',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: const PremiumRouterScreen(),
                  ),
                ),
                // Composer Promo - Accessible from Premium branch or potentially others if needed
                GoRoute(
                  path: '/composer-promo',
                  pageBuilder: (context, state) => createCustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const ComposerPromoScreen(),
                     transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Premium Activated Screen - se muestra cuando se activa premium
        GoRoute(
          path: '/premium/activated',
          pageBuilder: (context, state) => createCustomTransitionPage<void>(
            key: state.pageKey,
            child: const PremiumActivatedScreen(),
            transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 200),
          ),
        ),
        // Full Player - FUERA del ShellRoute para que no muestre el mini player
        // Sin transición para apertura/cierre inmediata
        GoRoute(
          path: '/player',
          pageBuilder: (context, state) => createNoTransitionPage<void>(
            key: state.pageKey,
            child: const FullPlayerScreen(),
          ),
        ),
        // Redirect raíz - DEBE estar al final para no interceptar otras rutas
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
        ),
        // ADMIN ROUTES
        GoRoute(
          path: '/admin/ads-stats',
          pageBuilder: (context, state) => createCustomTransitionPage<void>(
            key: state.pageKey,
            child: const AdStatsScreen(),
            transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 150),
          ),
        ),
      ];

  String? handleRedirect(BuildContext context, GoRouterState state) {
    final authState = _authState;
    final location = state.matchedLocation;
    final isSplashRoute = location == '/splash';
    final isAuthRoute = location == '/login' || 
                        location == '/register' || 
                        location == '/forgot-password' ||
                        location.startsWith('/reset-password');
    
    // No redirigir rutas de player u otras rutas específicas fuera del ShellRoute
    // Nota: /song/ ahora está dentro del ShellRoute, así que no necesita tratamiento especial aquí
    if (location == '/player') {
      // Permitir acceso a estas rutas si el usuario está autenticado
      if (!authState.isAuthenticated && authState.isInitialized) {
        return '/login';
      }
      return null; // No redirigir, permitir acceso
    }

    if (!authState.isInitialized) {
      return isSplashRoute ? null : '/splash';
    }

    if (!authState.isAuthenticated) {
      if (isAuthRoute || location == '/onboarding') {
        return null;
      }
      return '/login';
    }

    // Si está autenticado pero no completó onboarding, redirigir a onboarding
    if (authState.isAuthenticated && !_onboardingCompleted && location != '/onboarding') {
      return '/onboarding';
    }

    // Si completó onboarding y está en onboarding, redirigir a home
    if (authState.isAuthenticated && _onboardingCompleted && location == '/onboarding') {
      return '/home';
    }

    if (authState.isAuthenticated && (isAuthRoute || isSplashRoute)) {
      return '/home';
    }

    return null;
  }

  @override
  void dispose() {
    _authSubscription.close();
    _onboardingSubscription.close();
    super.dispose();
  }
}

