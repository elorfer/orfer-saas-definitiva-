import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// SearchScreen optimizado con AutomaticKeepAliveClientMixin
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // Eliminado AutomaticKeepAliveClientMixin: SearchScreen no necesita mantener estado
  // Esto reduce el uso de memoria y mejora el rendimiento

  @override
  Widget build(BuildContext context) {
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
                      'Buscar',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: NeumorphismTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: NeumorphismTheme.neumorphismShadow,
                  ),
                  child: TextField(
                    style: GoogleFonts.inter(
                      color: NeumorphismTheme.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar canciones, artistas, álbumes...',
                      hintStyle: GoogleFonts.inter(
                        color: NeumorphismTheme.textLight,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: NeumorphismTheme.textSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Placeholder content
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Busca tu música favorita',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Encuentra canciones, artistas y playlists',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



