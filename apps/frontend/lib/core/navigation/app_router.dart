import '../../features/privacy/privacy_screen.dart' deferred as privacy;
import '../../features/common/screens/update_required_screen.dart';
import '../../features/offline/screens/downloads_screen.dart' deferred as downloads;
import '../../features/profile/screens/profile_screen.dart' deferred as profile;
import '../../features/notifications/screens/notifications_screen.dart' deferred as notifications;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/verify_code_screen.dart';
import '../../features/ads/screens/ad_stats_screen.dart' deferred as ad_stats;
import '../../features/splash/splash_screen.dart';
import '../../features/playlists/screens/playlists_screen.dart';
import '../../features/playlists/screens/playlist_detail_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/featured_songs_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/library/screens/library_screen_v2.dart';
import '../../features/library/screens/favorites_screen.dart';
import '../../features/library/screens/recently_played_screen.dart';
import '../../features/library/screens/followed_artists_screen.dart';
import '../../features/premium/screens/premium_activated_screen.dart' deferred as premium_activated;
import '../../features/premium/screens/premium_router_screen.dart' deferred as premium_router;
import '../../features/premium/screens/composer_promo_screen.dart' deferred as composer_promo;
import '../../features/premium/screens/invite_coffee_screen.dart' deferred as invite_coffee;
import '../../features/onboarding/screens/onboarding_screen.dart' deferred as onboarding;
import '../../core/widgets/deferred_widget.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../features/artists/pages/artist_page.dart';
import '../../features/artists/models/artist.dart';
import '../../features/artists/screens/featured_artists_full_screen.dart' deferred as featured_artists;
import '../../features/player/screens/full_player_screen.dart';
import '../../features/song_detail/screens/song_detail_screen.dart';
import '../../core/models/song_model.dart';
import '../providers/auth_provider.dart';
import '../services/app_initializer.dart';
import '../services/realtime_service.dart';
import '../utils/logger.dart';
import 'persistent_navigation.dart';
import 'page_transitions.dart'
    show
        SpotifyPageTransitions,
        createCustomTransitionPage,
        createNoTransitionPage;

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final realtimeUpdateProvider = Provider<void>((ref) {
  // Escuchar eventos de prueba de actualización
  final subscription = RealtimeService.instance.updateTestStream.listen((event) {
    AppLogger.info('[RealtimeUpdateProvider] 🆙 Trigger de actualización real-time recibido!');
    try {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        GoRouter.of(context).push('/update-required', extra: {
          'isMandatory': event['isMandatory'] ?? true,
          'updateUrl': null, // Es solo un test visual
        });
      }
    } catch (e) {
      AppLogger.error('[RealtimeUpdateProvider] Error al navegar a pantalla de actualización', e);
    }
  });

  ref.onDispose(() => subscription.cancel());
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterNotifier(ref);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: notifier.initialLocation,
    refreshListenable: notifier,
    routes: notifier.routes,
    redirect: notifier.handleRedirect,
    debugLogDiagnostics:
        false, // Deshabilitado para mejor rendimiento en producción
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
    // ✅ OPTIMIZACIÓN: fireImmediately: false para evitar trabajo innecesario al inicio
    // El estado de auth se leerá cuando realmente se necesite (en getters)
    _authSubscription = ref.listen<AuthState>(
      authStateProvider,
      (previous, next) {
        // 🚀 INSTANT PLAY TRIGGER
        // Si el usuario pasa de no autenticado a autenticado, disparar prefetch
        if (next.isAuthenticated &&
            (previous == null || !previous.isAuthenticated)) {
          AppInitializer.onUserAuthenticated(ref);
        }
        notifyListeners();
      },
      fireImmediately: false, // Optimización: no ejecutar inmediatamente
    );

    // ✅ FIX: Escuchar cambios en el onboarding para actualizar el router
    _onboardingSubscription = ref.listen<bool>(
      onboardingProvider,
      (_, _) {
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
        // Splash - sin transición
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) => createNoTransitionPage<void>(
            key: state.pageKey,
            child: const SplashScreen(),
          ),
        ),
        // Update Required - Bloqueo de versión (Usar rootNavigator para que no salga el MiniPlayer)
        GoRoute(
          path: '/update-required',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final isMandatory = extra?['isMandatory'] as bool? ?? true;
            final updateUrl = extra?['updateUrl'] as String?;
            return MaterialPage<void>(
              key: state.pageKey,
              child: UpdateRequiredScreen(
                isMandatory: isMandatory,
                updateUrl: updateUrl,
              ),
            );
          },
        ),
        // Onboarding - transición suave
        GoRoute(
          path: '/onboarding',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: DeferredWidget(
              loader: onboarding.loadLibrary,
              builder: () => onboarding.OnboardingScreen(),
            ),
          ),
        ),
        // Login - transición optimizada sin parpadeo
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const LoginScreen(),
          ),
        ),
        // Register - transición optimizada sin parpadeo
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const RegisterScreen(),
          ),
        ),
        // Forgot Password - transición optimizada sin parpadeo
        GoRoute(
          path: '/forgot-password',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const ForgotPasswordScreen(),
          ),
        ),
        // Reset Password - transición optimizada sin parpadeo
        GoRoute(
          path: '/reset-password/:token',
          pageBuilder: (context, state) {
            final token = state.pathParameters['token'] ?? '';
            return MaterialPage<void>(
              key: state.pageKey,
              child: ResetPasswordScreen(token: token),
            );
          },
        ),
        // Verify Code - Nueva pantalla para OTP de 6 dígitos
        GoRoute(
          path: '/verify-code/:email',
          pageBuilder: (context, state) {
            final email = state.pathParameters['email'] ?? '';
            return MaterialPage<void>(
              key: state.pageKey,
              child: VerifyCodeScreen(email: email),
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
                path == '/update-required' ||
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
              navigatorKey:
                  GlobalKey<NavigatorState>(debugLabel: 'home_branch'),
              routes: [
                GoRoute(
                  path: '/home',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: const HomeScreen(),
                  ),
                ),
                // Compositores - subruta de Home (evita crear navigator separado)
                GoRoute(
                  path: '/compositores',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: featured_artists.loadLibrary,
                      builder: () => featured_artists.FeaturedArtistsFullScreen(),
                    ),
                  ),
                ),
                // Featured Songs - subruta de Home
                GoRoute(
                  path: '/featured-songs',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: const FeaturedSongsScreen(),
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

                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: SongDetailScreen(song: song),
                    );
                  },
                ),
                // Playlist Detail - accesible desde Home
                GoRoute(
                  path: '/playlist/:id',
                  pageBuilder: (context, state) {
                    final playlistId = state.pathParameters['id'] ?? '';
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: PlaylistDetailScreen(playlistId: playlistId),
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
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: ArtistPage(artist: artistLite),
                    );
                  },
                ),
                // User Profile - accesible desde Home
                GoRoute(
                  path: '/profile',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: profile.loadLibrary,
                      builder: () => profile.ProfileScreen(),
                    ),
                  ),
                ),
                // Favorites - accesible desde Home
                GoRoute(
                  path: '/favorites',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: const FavoritesScreen(),
                  ),
                ),
                // Downloads (Premium) - accesible desde Home
                GoRoute(
                  path: '/downloads',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: downloads.loadLibrary,
                      builder: () => downloads.DownloadsScreen(),
                    ),
                  ),
                ),
                // Notifications - accesible desde Home
                GoRoute(
                  path: '/notifications',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: notifications.loadLibrary,
                      builder: () => notifications.NotificationsScreen(),
                    ),
                  ),
                ),
                // Privacy Policy - accesible desde Home
                GoRoute(
                  path: '/privacy',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: privacy.loadLibrary,
                      builder: () => privacy.PrivacyScreen(),
                    ),
                  ),
                ),
                // Invite a Coffee - accesible desde Home
                GoRoute(
                  path: '/invite-coffee',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: invite_coffee.loadLibrary,
                      builder: () => invite_coffee.InviteCoffeeScreen(),
                    ),
                  ),
                ),
              ],
            ),
            // Rama 1: Search
            StatefulShellBranch(
              navigatorKey:
                  GlobalKey<NavigatorState>(debugLabel: 'search_branch'),
              routes: [
                GoRoute(
                  path: '/search',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: const SearchScreen(),
                  ),
                  routes: [
                    // 📊 Tendencias en búsquedas (Full Screen) - Accesible desde Search
                    GoRoute(
                      path: 'trending-artists',
                      pageBuilder: (context, state) => MaterialPage<void>(
                        key: state.pageKey,
                        child: DeferredWidget(
                          loader: featured_artists.loadLibrary,
                          builder: () =>
                              featured_artists.FeaturedArtistsFullScreen(),
                        ),
                      ),
                    ),
                    // 📊 Las más escuchadas (Full Screen) - Accesible desde Search
                    GoRoute(
                      path: 'top-songs',
                      pageBuilder: (context, state) => MaterialPage<void>(
                        key: state.pageKey,
                        child: const FeaturedSongsScreen(),
                      ),
                    ),
                  ],
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

                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: SongDetailScreen(song: song),
                    );
                  },
                ),
                // Playlist Detail - accesible desde Search
                GoRoute(
                  path: '/playlist/:id',
                  pageBuilder: (context, state) {
                    final playlistId = state.pathParameters['id'] ?? '';
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: PlaylistDetailScreen(playlistId: playlistId),
                    );
                  },
                ),
                // Artist Detail - accesible desde Search
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
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: ArtistPage(artist: artistLite),
                    );
                  },
                ),
                // User Profile - accesible desde Search
                GoRoute(
                  path: '/profile',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: profile.loadLibrary,
                      builder: () => profile.ProfileScreen(),
                    ),
                  ),
                ),
                // Favorites - accesible desde Search
                GoRoute(
                  path: '/favorites',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: const FavoritesScreen(),
                  ),
                ),
                // Downloads (Premium) - accesible desde Search
                GoRoute(
                  path: '/downloads',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: downloads.loadLibrary,
                      builder: () => downloads.DownloadsScreen(),
                    ),
                  ),
                ),
                // Notifications - accesible desde Search
                GoRoute(
                  path: '/notifications',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: notifications.loadLibrary,
                      builder: () => notifications.NotificationsScreen(),
                    ),
                  ),
                ),
                // Privacy Policy - accesible desde Search
                GoRoute(
                  path: '/privacy',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: privacy.loadLibrary,
                      builder: () => privacy.PrivacyScreen(),
                    ),
                  ),
                ),
                // Invite a Coffee - accesible desde Search
                GoRoute(
                  path: '/invite-coffee',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: invite_coffee.loadLibrary,
                      builder: () => invite_coffee.InviteCoffeeScreen(),
                    ),
                  ),
                ),
              ],
            ),
            // Rama 2: Library
            StatefulShellBranch(
              navigatorKey:
                  GlobalKey<NavigatorState>(debugLabel: 'library_branch'),
              routes: [
                GoRoute(
                  path: '/library',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: const LibraryScreen(),
                  ),
                ),
                // User Profile
                GoRoute(
                  path: '/profile',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: profile.loadLibrary,
                      builder: () => profile.ProfileScreen(),
                    ),
                  ),
                ),
                // Notifications
                GoRoute(
                  path: '/notifications',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: notifications.loadLibrary,
                      builder: () => notifications.NotificationsScreen(),
                    ),
                  ),
                ),
                // Privacy Policy
                GoRoute(
                  path: '/privacy',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: privacy.loadLibrary,
                      builder: () => privacy.PrivacyScreen(),
                    ),
                  ),
                ),
                // Downloads (Premium)
                GoRoute(
                  path: '/downloads',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: downloads.loadLibrary,
                      builder: () => downloads.DownloadsScreen(),
                    ),
                  ),
                ),
                // Downloads Song Detail
                GoRoute(
                  path: '/downloads/song/:id',
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

                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: SongDetailScreen(
                        song: song,
                      ),

                    );
                  },
                ),
                // Playlists - subruta de Library
                GoRoute(
                  path: '/playlists',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: const PlaylistsScreen(),
                  ),
                ),
                // Favorites - subruta de Library
                GoRoute(
                  path: '/favorites',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: const FavoritesScreen(),
                  ),
                ),
                // Recently Played - subruta de Library
                GoRoute(
                  path: '/recently-played',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: const RecentlyPlayedScreen(),
                  ),
                ),
                // Followed Artists - subruta de Library
                GoRoute(
                  path: '/followed-artists',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: const FollowedArtistsScreen(),
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

                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: SongDetailScreen(song: song),
                    );
                  },
                ),
                // Playlist Detail - accesible desde Library (muy común)
                GoRoute(
                  path: '/playlist/:id',
                  pageBuilder: (context, state) {
                    final playlistId = state.pathParameters['id'] ?? '';
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: PlaylistDetailScreen(playlistId: playlistId),
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
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: ArtistPage(artist: artistLite),
                    );
                  },
                ),
                // Invite a Coffee - accesible desde Library para que mantenga el MiniPlayer
                GoRoute(
                  path: '/invite-coffee',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: invite_coffee.loadLibrary,
                      builder: () => invite_coffee.InviteCoffeeScreen(),
                    ),
                  ),
                ),
              ],
            ),
            // Rama 3: Premium
            StatefulShellBranch(
              navigatorKey:
                  GlobalKey<NavigatorState>(debugLabel: 'premium_branch'),
              routes: [
                GoRoute(
                  path: '/premium',
                  name: 'premium',
                  pageBuilder: (context, state) => createNoTransitionPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: premium_router.loadLibrary,
                      builder: () => premium_router.PremiumRouterScreen(),
                    ),
                  ),
                ),
                // Composer Promo - Accessible from Premium branch or potentially others if needed
                GoRoute(
                  path: '/composer-promo',
                  pageBuilder: (context, state) =>
                      MaterialPage<void>(
                    key: state.pageKey,
                    child: DeferredWidget(
                      loader: composer_promo.loadLibrary,
                      builder: () => composer_promo.ComposerPromoScreen(),
                    ),

                  ),
                ),
              ],
            ),
          ],
        ),
        // Premium Activated Screen - se muestra cuando se activa premium
        GoRoute(
          path: '/premium/activated',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: DeferredWidget(
              loader: premium_activated.loadLibrary,
              builder: () => premium_activated.PremiumActivatedScreen(),
            ),
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
          redirect: (_, _) => '/home',
        ),
        // ADMIN ROUTES
        GoRoute(
          path: '/admin/ads-stats',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: DeferredWidget(
              loader: ad_stats.loadLibrary,
              builder: () => ad_stats.AdStatsScreen(),
            ),
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
        location.startsWith('/reset-password') ||
        location.startsWith('/verify-code');

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
    if (authState.isAuthenticated &&
        !_onboardingCompleted &&
        location != '/onboarding') {
      return '/onboarding';
    }

    // Si completó onboarding y está en onboarding, redirigir a home
    if (authState.isAuthenticated &&
        _onboardingCompleted &&
        location == '/onboarding') {
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