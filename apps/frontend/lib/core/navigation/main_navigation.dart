import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../services/player_navigation_service.dart';
import '../widgets/final_mini_player.dart';
import '../../features/ads/widgets/ads_mini_player.dart';
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
  
  // 🔥 OPTIMIZACIÓN: Cachear valores para evitar recálculos
  double? _cachedBottomPadding;
  double? _cachedNavBarHeight;
  int? _cachedCurrentIndex; // 🔥 Cachear índice actual para evitar recálculos
  
  @override
  bool get wantKeepAlive => true; // Mantener estado de navegación

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializar valores UNA SOLA VEZ cuando cambian las dependencias
    if (_cachedBottomPadding == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedBottomPadding = mediaQuery.padding.bottom;
      _cachedNavBarHeight = 80.0 + _cachedBottomPadding!;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // ✅ OPTIMIZACIÓN: Solo escuchar cambios necesarios
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    final currentSong = playbackState.currentSong;
    final isPlayingAd = playbackState.isPlayingAd;
    
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
          
          // 📢 Mini Player de Anuncios (prioridad sobre el mini player normal)
          if (isPlayingAd)
            Positioned(
              bottom: navBarHeight,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: AdsMiniPlayer(
                  // ✅ MEJOR PRÁCTICA: Usar servicio centralizado (el widget tiene fallback)
                  onTap: () => PlayerNavigationService.openFullPlayer(
                    context: context,
                    ref: ref,
                  ),
                ),
              ),
            )
          // Mini Player normal (solo cuando no hay anuncio)
          else if (currentSong != null)
            Positioned(
              bottom: navBarHeight, // Ajustado para la nueva altura de barra
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: FinalMiniPlayer(
                  // ✅ MEJOR PRÁCTICA: Usar servicio centralizado (el widget tiene fallback)
                  onTap: () => PlayerNavigationService.openFullPlayer(
                    context: context,
                    ref: ref,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    // 🔥 OPTIMIZACIÓN: Cachear índice actual para evitar recálculos
    final currentIndex = _getCurrentIndexCached(context);
    
    // Usar valores cacheados para evitar recálculos
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
              onTap: () => _navigateToTab(context, 0, '/home'),
            ),
            _buildNavItem(
              icon: Icons.search_outlined,
              activeIcon: Icons.search,
              label: 'Buscar',
              isSelected: currentIndex == 1,
              onTap: () => _navigateToTab(context, 1, '/search'),
            ),
            _buildNavItem(
              icon: Icons.library_music_outlined,
              activeIcon: Icons.library_music,
              label: 'Biblioteca',
              isSelected: currentIndex == 2,
              onTap: () => _navigateToTab(context, 2, '/library'),
            ),
            _buildNavItem(
              icon: Icons.star_outline,
              activeIcon: Icons.star,
              label: 'Premium',
              isSelected: currentIndex == 3,
              onTap: () => _navigateToTab(context, 3, '/premium'),
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
    // 🔥 OPTIMIZACIÓN: RepaintBoundary dentro del Flexible, no envolviéndolo
    // ✅ CORRECCIÓN: Flexible debe estar directamente en el Row, RepaintBoundary va dentro
    return Flexible(
      flex: 1,
      child: RepaintBoundary(
        child: InkWell(
          onTap: () {
            // 🔥 OPTIMIZACIÓN: Ejecutar callback inmediatamente sin delay
            onTap();
          },
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          splashColor: Colors.transparent, // Sin splash para mejor rendimiento
          highlightColor: Colors.transparent, // Sin highlight para mejor rendimiento
          hoverColor: Colors.transparent, // Sin hover para mejor rendimiento
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
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected 
                      ? NeumorphismTheme.coffeeDark
                      : NeumorphismTheme.textSecondary,
                    height: 1.1,
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

  // 🔥 OPTIMIZACIÓN: Cachear índice para evitar recálculos constantes
  int _getCurrentIndexCached(BuildContext context) {
    // Solo recalcular si el índice no está cacheado o cambió la ruta
    final router = GoRouter.of(context);
    final location = router.routerDelegate.currentConfiguration.uri.path;
    final matchedLocation = GoRouterState.of(context).matchedLocation;
    final currentPath = location.isNotEmpty ? location : matchedLocation;
    
    int newIndex;
    if (currentPath == '/home' || currentPath.startsWith('/home/')) {
      newIndex = 0;
    } else if (currentPath == '/search' || currentPath.startsWith('/search')) {
      newIndex = 1;
    } else if (currentPath == '/library' || currentPath.startsWith('/library')) {
      newIndex = 2;
    } else if (currentPath == '/premium' || currentPath.startsWith('/premium')) {
      newIndex = 3;
    } else {
      newIndex = 0; // Default
    }
    
    // Solo actualizar cache si cambió
    if (_cachedCurrentIndex != newIndex) {
      _cachedCurrentIndex = newIndex;
    }
    
    return _cachedCurrentIndex ?? 0;
  }

  // 🔥 OPTIMIZACIÓN: Navegación instantánea sin delay
  void _navigateToTab(BuildContext context, int targetIndex, String route) {
    // Solo navegar si no estamos ya en esa ruta
    if (_cachedCurrentIndex == targetIndex) return;
    
    // Pre-actualizar cache para feedback visual inmediato
    setState(() {
      _cachedCurrentIndex = targetIndex;
    });
    
    // 🔥 Navegación síncrona directa - sin microtask ni delay
    if (context.mounted) {
      context.go(route);
    }
  }

}
