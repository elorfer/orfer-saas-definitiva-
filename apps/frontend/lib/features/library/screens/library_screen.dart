import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// LibraryScreen optimizado con AutomaticKeepAliveClientMixin
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Mantener estado al cambiar de pestaña

  // Lista de secciones estáticas para optimización
  static final List<Map<String, dynamic>> _librarySections = [
    {
      'icon': Icons.favorite,
      'title': 'Canciones Favoritas',
      'subtitle': '0 canciones',
      'onTap': () {},
    },
    {
      'icon': Icons.playlist_play,
      'title': 'Mis Playlists',
      'subtitle': '0 playlists',
      'onTap': null, // Se maneja en el build
    },
    {
      'icon': Icons.download,
      'title': 'Descargadas',
      'subtitle': '0 canciones',
      'onTap': () {},
    },
    {
      'icon': Icons.history,
      'title': 'Recientemente Reproducidas',
      'subtitle': '0 canciones',
      'onTap': () {},
    },
    {
      'icon': Icons.album,
      'title': 'Álbumes Guardados',
      'subtitle': '0 álbumes',
      'onTap': () {},
    },
    {
      'icon': Icons.person,
      'title': 'Artistas Seguidos',
      'subtitle': '0 artistas',
      'onTap': () {},
    },
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      'Mi Biblioteca',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: NeumorphismTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Library sections optimizadas
                Expanded(
                  child: ListView.builder(
                    cacheExtent: 800, // Aumentado a 800px para scroll más rápido
                    physics: const FastScrollPhysics(), // Scroll más rápido y fluido
                    itemCount: _librarySections.length,
                    itemExtent: 80.0, // Altura fija para mejor rendimiento
                    itemBuilder: (context, index) {
                      final section = _librarySections[index];
                      return RepaintBoundary(
                        key: ValueKey('library_section_$index'),
                        child: _buildLibrarySection(
                          icon: section['icon'] as IconData,
                          title: section['title'] as String,
                          subtitle: section['subtitle'] as String,
                          onTap: section['onTap'] as VoidCallback? ?? () {
                            // Manejar tap específico para "Mis Playlists"
                            if (index == 1) {
                              context.push('/playlists');
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLibrarySection({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: NeumorphismTheme.neumorphismShadow,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: NeumorphismTheme.coffeeMedium,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: NeumorphismTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: NeumorphismTheme.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: NeumorphismTheme.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}



