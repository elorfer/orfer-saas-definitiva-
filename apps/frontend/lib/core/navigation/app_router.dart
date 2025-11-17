import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/playlists/screens/playlists_screen.dart';
import '../../features/playlists/screens/playlist_detail_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/artists/pages/artist_page.dart';
import '../../features/artists/models/artist.dart';
import '../providers/auth_provider.dart';
import 'main_navigation.dart';
import 'page_transitions.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterNotifier(ref);

  final router = GoRouter(
    initialLocation: notifier.initialLocation,
    refreshListenable: notifier,
    routes: notifier.routes,
    redirect: notifier.handleRedirect,
    debugLogDiagnostics: false,
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});

class GoRouterNotifier extends ChangeNotifier {
  GoRouterNotifier(this.ref) {
    _subscription = ref.listen<AuthState>(
      authStateProvider,
      (_, __) => notifyListeners(),
      fireImmediately: true,
    );
  }

  final Ref ref;
  late final ProviderSubscription<AuthState> _subscription;

  AuthState get _authState => ref.read(authStateProvider);

  String get initialLocation =>
      _authState.isAuthenticated ? '/home' : '/splash';

  List<RouteBase> get routes => [
        // Splash - sin transición
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const SplashScreen(),
          ),
        ),
        // Login - transición fade suave
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder: SpotifyPageTransitions.fadeSlideTransition,
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 200),
          ),
        ),
        // Register - transición fade suave
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder: SpotifyPageTransitions.fadeSlideTransition,
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 200),
          ),
        ),
        // ShellRoute envuelve todas las rutas autenticadas para mantener la barra de navegación
        ShellRoute(
          builder: (context, state, child) {
            // Si estamos en rutas de autenticación o splash, no mostrar MainNavigation
            final path = state.matchedLocation;
            if (path == '/splash' || path == '/login' || path == '/register') {
              return child;
            }
            // Para todas las demás rutas autenticadas, mostrar MainNavigation con la barra
            return MainNavigation(child: child);
          },
          routes: [
            // Home - transición ultra rápida solo fade (estilo Spotify tabs)
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: const HomeScreen(),
                transitionsBuilder: SpotifyPageTransitions.tabTransition,
                transitionDuration: const Duration(milliseconds: 100),
                reverseTransitionDuration: const Duration(milliseconds: 100),
              ),
            ),
            // Search - transición ultra rápida solo fade
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: const SearchScreen(),
                transitionsBuilder: SpotifyPageTransitions.tabTransition,
                transitionDuration: const Duration(milliseconds: 100),
                reverseTransitionDuration: const Duration(milliseconds: 100),
              ),
            ),
            // Library - transición ultra rápida solo fade
            GoRoute(
              path: '/library',
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: const LibraryScreen(),
                transitionsBuilder: SpotifyPageTransitions.tabTransition,
                transitionDuration: const Duration(milliseconds: 100),
                reverseTransitionDuration: const Duration(milliseconds: 100),
              ),
            ),
            // Profile - transición ultra rápida solo fade
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: const ProfileScreen(),
                transitionsBuilder: SpotifyPageTransitions.tabTransition,
                transitionDuration: const Duration(milliseconds: 100),
                reverseTransitionDuration: const Duration(milliseconds: 100),
              ),
            ),
            // Playlists - transición horizontal (desde la derecha)
            GoRoute(
              path: '/playlists',
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: const PlaylistsScreen(),
                transitionsBuilder: SpotifyPageTransitions.horizontalTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            // Artist Detail
            GoRoute(
              path: '/artist/:id',
              pageBuilder: (context, state) {
                final artistId = state.pathParameters['id'] ?? '';
                final extra = state.extra;
                ArtistLite? artistLite;
                if (extra is ArtistLite) {
                  artistLite = extra;
                } else {
                  // Si no llega extra, mostrar un placeholder mínimo
                  artistLite = ArtistLite(
                    id: artistId,
                    name: 'Artista',
                    profilePhotoUrl: null,
                    coverPhotoUrl: null,
                    nationalityCode: null,
                    featured: false,
                  );
                }
                return CustomTransitionPage<void>(
                  key: state.pageKey,
                  child: ArtistPage(artist: artistLite),
                  transitionsBuilder: SpotifyPageTransitions.horizontalTransition,
                  transitionDuration: const Duration(milliseconds: 250),
                  reverseTransitionDuration: const Duration(milliseconds: 200),
                );
              },
            ),
            // Playlist Detail - transición de escala (se expande como modal)
            GoRoute(
              path: '/playlist/:id',
              pageBuilder: (context, state) {
                final playlistId = state.pathParameters['id'] ?? '';
                return CustomTransitionPage<void>(
                  key: state.pageKey,
                  child: PlaylistDetailScreen(playlistId: playlistId),
                  transitionsBuilder: SpotifyPageTransitions.scaleTransition,
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(milliseconds: 250),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
        ),
      ];

  String? handleRedirect(BuildContext context, GoRouterState state) {
    final authState = _authState;
    final isSplashRoute = state.matchedLocation == '/splash';
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (!authState.isInitialized) {
      return isSplashRoute ? null : '/splash';
    }

    if (!authState.isAuthenticated) {
      if (isAuthRoute) {
        return null;
      }
      return '/login';
    }

    if (authState.isAuthenticated && (isAuthRoute || isSplashRoute)) {
      return '/home';
    }

    return null;
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

