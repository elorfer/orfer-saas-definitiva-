import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../widgets/final_mini_player.dart';
import '../theme/neumorphism_theme.dart';

/// Navegación principal con bottom navigation bar y mini player
class MainNavigation extends ConsumerStatefulWidget {
  final Widget child;

  const MainNavigation({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // ✅ Mantener estado de navegación

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // ✅ OPTIMIZACIÓN: Solo escuchar cambios en currentSong, no todo el estado
    final currentSong = ref.watch(unifiedAudioProviderFixed.select((state) => state.currentSong));

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      body: Stack(
        children: [
          // Contenido principal con nueva navigation bar
          Column(
            children: [
              Expanded(child: widget.child),
              _buildBottomNavigationBar(context), // ✅ NUEVA BARRA SENCILLA
            ],
          ),
          
          // ✅ MINI PLAYER OPTIMIZADO - Solo se muestra cuando hay canción
          if (currentSong != null)
            Positioned(
              bottom: 70, // Ajustado para la nueva altura de barra (60px + 10px separación)
              left: 0,
              right: 0,
              child: RepaintBoundary( // ✅ Evitar repintados innecesarios
                child: FinalMiniPlayer(
                  onTap: () {
                    // Abrir reproductor completo con transición estilo Spotify
                    context.push('/player');
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);
    
    return Container(
      height: 70, // 🎯 Altura fija estable
      decoration: BoxDecoration(
        color: NeumorphismTheme.background,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Inicio',
                isSelected: currentIndex == 0,
                onTap: () => context.go('/home'),
              ),
              _buildNavItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search,
                label: 'Buscar',
                isSelected: currentIndex == 1,
                onTap: () => context.go('/search'),
              ),
              _buildNavItem(
                icon: Icons.library_music_outlined,
                activeIcon: Icons.library_music,
                label: 'Biblioteca',
                isSelected: currentIndex == 2,
                onTap: () => context.go('/library'),
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Perfil',
                isSelected: currentIndex == 3,
                onTap: () => context.go('/profile'),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 60, // Altura fija igual al contenedor
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 32, // Mantiene el tamaño de iconos
                color: isSelected 
                  ? NeumorphismTheme.coffeeMedium 
                  : NeumorphismTheme.textSecondary,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                    ? NeumorphismTheme.coffeeMedium 
                    : NeumorphismTheme.textSecondary,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    switch (location) {
      case '/home':
        return 0;
      case '/search':
        return 1;
      case '/library':
        return 2;
      case '/profile':
        return 3;
      default:
        return 0;
    }
  }

}
