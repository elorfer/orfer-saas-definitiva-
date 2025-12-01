import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/playlists/screens/playlists_screen.dart';
import '../../features/playlists/screens/playlist_detail_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/featured_songs_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/library/screens/favorites_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/artists/pages/artist_page.dart';
import '../../features/artists/models/artist.dart';
import '../../features/player/screens/full_player_screen.dart';
import '../../features/song_detail/screens/song_detail_screen.dart';
import '../../core/models/song_model.dart';
import '../providers/auth_provider.dart';
import 'main_navigation.dart';
import 'page_transitions.dart' show SpotifyPageTransitions, createCustomTransitionPage, createNoTransitionPage;

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterNotifier(ref);

  final router = GoRouter(
    initialLocation: notifier.initialLocation,
    refreshListenable: notifier,
    routes: notifier.routes,
    redirect: notifier.handleRedirect,
    debugLogDiagnostics: false, // Deshabilitado para mejor rendimiento en producción
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
          pageBuilder: (context, state) => createNoTransitionPage<void>(
            key: state.pageKey,
            child: const SplashScreen(),
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
            // Home - sin transición para tabs (mejor rendimiento)
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => createNoTransitionPage<void>(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
            ),
            // Search - transición optimizada sin parpadeo
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => createCustomTransitionPage<void>(
                key: state.pageKey,
                child: const SearchScreen(),
                transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                transitionDuration: const Duration(milliseconds: 200),
                reverseTransitionDuration: const Duration(milliseconds: 150),
              ),
            ),
            // Library - sin transición para tabs (mejor rendimiento)
            GoRoute(
              path: '/library',
              pageBuilder: (context, state) => createNoTransitionPage<void>(
                key: state.pageKey,
                child: const LibraryScreen(),
              ),
            ),
            // Profile - IDÉNTICO a song details (sin parpadeo)
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => createCustomTransitionPage<void>(
                key: state.pageKey,
                child: const ProfileScreen(),
                transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                transitionDuration: const Duration(milliseconds: 200),
                reverseTransitionDuration: const Duration(milliseconds: 150),
              ),
            ),
            // Playlists - IDÉNTICO a song details (sin parpadeo)
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
            // Featured Songs - transición optimizada sin parpadeo
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
            // Favorites - transición optimizada sin parpadeo
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
            // Artist Detail - transición optimizada sin parpadeo (igual que song details)
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
                // Key estable basada en artistId para preservar estado
                return createCustomTransitionPage<void>(
                  key: ValueKey('artist_page_${artistLite.id}'),
                  child: ArtistPage(artist: artistLite),
                  transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                  transitionDuration: const Duration(milliseconds: 200),
                  reverseTransitionDuration: Duration.zero, // CRÍTICO: Sin duración al retroceder (evita parpadeo)
                );
              },
            ),
            // Playlist Detail - transición optimizada sin parpadeo (igual que song details)
            GoRoute(
              path: '/playlist/:id',
              pageBuilder: (context, state) {
                final playlistId = state.pathParameters['id'] ?? '';
                // Key estable basada en playlistId para preservar estado
                return createCustomTransitionPage<void>(
                  key: ValueKey('playlist_detail_$playlistId'),
                  child: PlaylistDetailScreen(playlistId: playlistId),
                  transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                  transitionDuration: const Duration(milliseconds: 200),
                  reverseTransitionDuration: Duration.zero, // CRÍTICO: Sin duración al retroceder (evita parpadeo)
                );
              },
            ),
            // Song Detail - DENTRO del ShellRoute para que respete el NavigationBar
            GoRoute(
              path: '/song/:id',
              pageBuilder: (context, state) {
                final songId = state.pathParameters['id'] ?? '';
                final extra = state.extra;
                Song? song;
                
                if (extra is Song) {
                  song = extra;
                } else {
                  // Si no hay canción en extra, crear una básica con el ID
                  // La pantalla cargará los datos completos desde el backend
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
                
                // Usar transición optimizada para SongDetail: Sin transición al retroceder
                // Key estable basada en songId para preservar estado
                return createCustomTransitionPage<void>(
                  key: ValueKey('song_detail_${song.id}'),
                  child: SongDetailScreen(song: song),
                  transitionsBuilder: SpotifyPageTransitions.songDetailTransition,
                  transitionDuration: const Duration(milliseconds: 200),
                  reverseTransitionDuration: Duration.zero, // CRÍTICO: Sin duración al retroceder (evita parpadeo)
                );
              },
            ),
          ],
        ),
        // Full Player - FUERA del ShellRoute para que no muestre el mini player
        // Transición vertical optimizada (más rápida)
        GoRoute(
          path: '/player',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const FullPlayerScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Transición vertical desde abajo como Spotify (optimizada)
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOut; // Más rápida que easeOutCubic
              
              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );
              
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 200), // Reducido de 300ms
            reverseTransitionDuration: const Duration(milliseconds: 150), // Reducido de 250ms
          ),
        ),
        // Redirect raíz - DEBE estar al final para no interceptar otras rutas
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
        ),
      ];

  String? handleRedirect(BuildContext context, GoRouterState state) {
    final authState = _authState;
    final location = state.matchedLocation;
    final isSplashRoute = location == '/splash';
    final isAuthRoute = location == '/login' || location == '/register';
    
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

