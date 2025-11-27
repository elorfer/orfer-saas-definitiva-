import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/theme/neumorphism_theme.dart';
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
        gradient: NeumorphismTheme.backgroundGradient,
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final homeNotifier = ref.read(homeStateProvider.notifier);
            await homeNotifier.refresh();
          },
          color: Colors.white,
          backgroundColor: NeumorphismTheme.coffeeMedium,
          child: SingleChildScrollView(
            physics: const FastScrollPhysics(), // Scroll más rápido y fluido
            padding: const EdgeInsets.only(top: 24.0, bottom: 40.0), // ✅ Más padding inferior
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header con avatar y bienvenida
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
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
                            color: NeumorphismTheme.textPrimary,
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
                              color: NeumorphismTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.firstName ?? 'Usuario',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: NeumorphismTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  ),
                ),

                const SizedBox(height: 32),

                // Artistas destacados
                FeaturedArtistsSection(key: const ValueKey('artists')),

                const SizedBox(height: 32),

                // Canciones destacadas inteligentes (usa tu algoritmo avanzado)
                IntelligentFeaturedSongsSection(key: const ValueKey('intelligent_songs')),

                const SizedBox(height: 32),

                // Playlists destacadas
                FeaturedPlaylistsSection(key: const ValueKey('playlists')),

                const SizedBox(height: 80), // ✅ Más espacio en blanco al final
              ],
            ),
          ),
        ),
      ),
    );
  }
}
