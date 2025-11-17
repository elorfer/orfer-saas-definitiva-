import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../widgets/featured_artists_section.dart';
import '../widgets/featured_songs_section.dart';
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

  String _getInitials(String? firstName, String? lastName) {
    if (firstName == null && lastName == null) return 'U';
    final firstInitial = firstName?.isNotEmpty == true ? firstName![0].toUpperCase() : '';
    final lastInitial = lastName?.isNotEmpty == true ? lastName![0].toUpperCase() : '';
    return (firstInitial + lastInitial).isEmpty ? 'U' : (firstInitial + lastInitial);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    // Usar ref.read cuando solo necesitamos el valor una vez (no reconstruir)
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    
    // Cargar datos solo una vez (no watch continuo)
    ref.read(homeStateProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final homeNotifier = ref.read(homeStateProvider.notifier);
            await homeNotifier.refresh();
          },
          color: Colors.white,
          backgroundColor: const Color(0xFF667eea),
          child: SingleChildScrollView(
            physics: const FastScrollPhysics(), // Scroll más rápido y fluido
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header con avatar y bienvenida
                Row(
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
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF667eea),
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
                          Text(
                            'Bienvenido',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.firstName ?? 'Usuario',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Artistas destacados
                FeaturedArtistsSection(key: const ValueKey('artists')),

                const SizedBox(height: 32),

                // Canciones destacadas
                FeaturedSongsSection(key: const ValueKey('songs')),

                const SizedBox(height: 32),

                // Playlists destacadas
                FeaturedPlaylistsSection(key: const ValueKey('playlists')),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
