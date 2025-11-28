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
  
  // ✅ Cachear valores para evitar recálculos cuando cambia el teclado
  double? _cachedBottomPadding;
  double? _cachedNavBarHeight;
  
  @override
  bool get wantKeepAlive => true; // ✅ Mantener estado de navegación

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Inicializar valores UNA SOLA VEZ cuando cambian las dependencias
    // Esto se ejecuta antes del primer build y cuando cambian MediaQuery, etc.
    if (_cachedBottomPadding == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedBottomPadding = mediaQuery.padding.bottom;
      _cachedNavBarHeight = 80.0 + _cachedBottomPadding!;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // ✅ OPTIMIZACIÓN: Solo escuchar cambios en currentSong, no todo el estado
    final currentSong = ref.watch(unifiedAudioProviderFixed.select((state) => state.currentSong));
    
    // ✅ Usar valores cacheados - NUNCA recalcular
    final navBarHeight = _cachedNavBarHeight ?? 80.0;

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      resizeToAvoidBottomInset: false, // ✅ Evitar que el teclado empuje el NavigationBar
      body: Stack(
        children: [
          // Contenido principal - con padding inferior para el NavigationBar
          Padding(
            padding: EdgeInsets.only(bottom: navBarHeight), // Espacio para NavigationBar
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: widget.child,
            ),
          ),
          
          // ✅ NAVIGATION BAR COMPLETAMENTE ESTÁTICO - Sin animaciones, sin recálculos
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: _buildBottomNavigationBar(context),
            ),
          ),
          
          // ✅ MINI PLAYER OPTIMIZADO - Solo se muestra cuando hay canción
          if (currentSong != null)
            Positioned(
              bottom: navBarHeight, // Ajustado para la nueva altura de barra
              left: 0,
              right: 0,
              child: RepaintBoundary(
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
    
    // ✅ Usar valores cacheados para evitar recálculos - NUNCA cambiar
    final bottomPadding = _cachedBottomPadding ?? 0.0;
    final totalHeight = _cachedNavBarHeight ?? 80.0;
    
    return SizedBox(
      height: totalHeight, // 🎯 Altura fija - nunca cambia
      width: double.infinity, // ✅ Ancho completo
      child: Container(
        decoration: BoxDecoration(
          color: NeumorphismTheme.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, -3),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 6, // ✅ Reducido de 8 a 6 para evitar overflow
            bottom: bottomPadding, // ✅ Padding inferior fijo del SafeArea
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 60, // ✅ Reducido de 64 a 60 para evitar overflow
            padding: const EdgeInsets.symmetric(vertical: 4), // ✅ Reducido de 8 a 4
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 30, // ✅ Reducido de 32 a 30 para mejor ajuste
                  color: isSelected 
                    ? NeumorphismTheme.coffeeDark // ✅ Marrón más oscuro cuando está seleccionado
                    : NeumorphismTheme.textSecondary,
                ),
                const SizedBox(height: 3), // ✅ Reducido de 4 a 3
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11, // ✅ Reducido de 12 a 11
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, // ✅ Más bold cuando está seleccionado
                    color: isSelected 
                      ? NeumorphismTheme.coffeeDark // ✅ Marrón más oscuro cuando está seleccionado
                      : NeumorphismTheme.textSecondary,
                    height: 1.1, // ✅ Reducido de 1.2 a 1.1
                  ),
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

  int _getCurrentIndex(BuildContext context) {
    // ✅ Obtener la ruta actual de múltiples formas para asegurar detección correcta
    final router = GoRouter.of(context);
    final location = router.routerDelegate.currentConfiguration.uri.path;
    final matchedLocation = GoRouterState.of(context).matchedLocation;
    
    // Usar la ubicación más específica disponible
    final currentPath = location.isNotEmpty ? location : matchedLocation;
    
    // ✅ Debug: Log para verificar qué ruta se está detectando
    // print('[NavigationBar] Current path: $currentPath, Matched: $matchedLocation');
    
    if (currentPath == '/home' || currentPath.startsWith('/home/')) {
      return 0;
    } else if (currentPath == '/search' || currentPath.startsWith('/search')) {
      return 1;
    } else if (currentPath == '/library' || currentPath.startsWith('/library')) {
      return 2;
    } else if (currentPath == '/profile' || currentPath.startsWith('/profile')) {
      return 3;
    }
    
    return 0; // Default
  }

}
