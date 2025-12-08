import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../widgets/final_mini_player.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/logger.dart';

/// 🔥 SISTEMA PROFESIONAL DE NAVEGACIÓN CON PERSISTENCIA
/// 
/// Refactorizado para usar StatefulShellRoute.indexedStack de GoRouter.
/// Cada rama mantiene su propio stack de navegación independiente,
/// asegurando que el estado y scroll se mantengan intactos.

class PersistentNavigation extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  
  const PersistentNavigation({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<PersistentNavigation> createState() => _PersistentNavigationState();
}

class _PersistentNavigationState extends ConsumerState<PersistentNavigation>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  // Cachear valores para evitar recálculos
  double? _cachedBottomPadding;
  double? _cachedNavBarHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cachedBottomPadding == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedBottomPadding = mediaQuery.padding.bottom;
      _cachedNavBarHeight = 80.0 + _cachedBottomPadding!;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Obtener índice actual del navigationShell (ya viene de GoRouter)
    final currentIndex = widget.navigationShell.currentIndex;
    final currentSong = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong),
    );
    
    final navBarHeight = _cachedNavBarHeight ?? 80.0;

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 🔥 NAVIGATION SHELL: GoRouter maneja automáticamente el IndexedStack
          // Cada rama mantiene su propio Navigator y stack de navegación
          widget.navigationShell,
          
          // Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: _buildBottomNavigationBar(currentIndex),
            ),
          ),
          
          // Mini Player
          if (currentSong != null)
            Positioned(
              bottom: navBarHeight,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: FinalMiniPlayer(
                  onTap: () {
                    try {
                      final audioState = ref.read(unifiedAudioProviderFixed);
                      if (audioState.currentSong != null && 
                          !audioState.isPlayerExpanded) {
                        ref.read(unifiedAudioProviderFixed.notifier).openFullPlayer();
                        if (context.mounted) {
                          context.push('/player');
                        }
                      }
                    } catch (e) {
                      AppLogger.error('[PersistentNavigation] Error: $e');
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(int currentIndex) {
    final bottomPadding = _cachedBottomPadding ?? 0.0;
    final totalHeight = _cachedNavBarHeight ?? 80.0;
    
    return SizedBox(
      height: totalHeight,
      width: double.infinity,
      child: Container(
        decoration: const BoxDecoration(
          color: NeumorphismTheme.background,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.15),
              blurRadius: 15,
              offset: Offset(0, -3),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 6,
            bottom: bottomPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Inicio',
                isSelected: currentIndex == 0,
                onTap: () => _navigateToTab(0),
              ),
              _buildNavItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search,
                label: 'Buscar',
                isSelected: currentIndex == 1,
                onTap: () => _navigateToTab(1),
              ),
              _buildNavItem(
                icon: Icons.library_music_outlined,
                activeIcon: Icons.library_music,
                label: 'Biblioteca',
                isSelected: currentIndex == 2,
                onTap: () => _navigateToTab(2),
              ),
              _buildNavItem(
                icon: Icons.star_outline,
                activeIcon: Icons.star,
                label: 'Premium',
                isSelected: currentIndex == 3,
                onTap: () => _navigateToTab(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Flexible(
      flex: 1,
      child: RepaintBoundary(
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 30,
                  color: isSelected
                      ? NeumorphismTheme.coffeeDark
                      : NeumorphismTheme.textSecondary,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: _getLabelStyle(isSelected),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToTab(int index) {
    // 🔥 Usar goBranch para cambiar de pestaña
    // Esto mantiene el stack de navegación de cada rama intacto
    widget.navigationShell.goBranch(
      index,
      // Si queremos resetear el stack de la rama al cambiar, usar initialLocation
      // initialLocation: index == 0 ? '/home' : index == 1 ? '/search' : index == 2 ? '/library' : '/premium',
    );
  }
  
  // ⚡ OPTIMIZACIÓN: Cachear estilos de texto para evitar recrear GoogleFonts en cada build
  static TextStyle? _cachedSelectedStyle;
  static TextStyle? _cachedUnselectedStyle;
  
  TextStyle _getLabelStyle(bool isSelected) {
    if (isSelected) {
      _cachedSelectedStyle ??= GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: NeumorphismTheme.coffeeDark,
        height: 1.1,
      );
      return _cachedSelectedStyle!;
    } else {
      _cachedUnselectedStyle ??= GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: NeumorphismTheme.textSecondary,
        height: 1.1,
      );
      return _cachedUnselectedStyle!;
    }
  }
}

