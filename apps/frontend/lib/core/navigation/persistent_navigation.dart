import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // StatefulNavigationShell + context.push
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart'; // Import user model
import '../providers/auth_provider.dart'; // Import auth provider
import '../providers/theme_provider.dart'; // Import theme provider
import '../providers/unified_audio_provider_fixed.dart';
import '../widgets/spotify_player_sheet.dart';
import '../theme/neumorphism_theme.dart';
import '../responsive/responsive_layout.dart';
import '../widgets/web_sidebar.dart'; // ðŸš€ Sidebar para Web

/// ðŸ”¥ SISTEMA PROFESIONAL DE NAVEGACIÃ“N CON PERSISTENCIA
/// 
/// Refactorizado para usar StatefulShellRoute.indexedStack de GoRouter.
/// Cada rama mantiene su propio stack de navegaciÃ³n independiente,
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

  // Cachear valores para evitar recÃ¡lculos
  double? _cachedBottomPadding;
  double? _cachedNavBarHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cachedBottomPadding == null) {
      final mediaQuery = MediaQuery.of(context);
      _cachedBottomPadding = mediaQuery.padding.bottom;
      // Evitar alturas fraccionadas que pueden causar un overflow por 1px
      _cachedNavBarHeight = (80.0 + _cachedBottomPadding!).ceilToDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Obtener Ã­ndice actual del navigationShell (ya viene de GoRouter)
    final currentIndex = widget.navigationShell.currentIndex;
    
    // ðŸš€ Refresh UI on Theme Change
    ref.watch(themeProvider);
    // Invalidate cached styles to force refresh
    _cachedSelectedStyle = null;
    _cachedUnselectedStyle = null;

    final isDesktop = ResponsiveLayout.isDesktop(context);

    // ðŸ”¥ LISTENER DE CAMBIO A PREMIUM (Nuevo: Post-Flash Bug Fix)
    // Detectar cuando el usuario pasa de Free -> Premium y redirigir
    ref.listen<User?>(currentUserProvider, (previous, next) {
        if (previous != null && next != null) {
            final wasPremium = previous.subscriptionStatus == SubscriptionStatus.premium || 
                               previous.subscriptionStatus == SubscriptionStatus.vip;
            final isPremium = next.subscriptionStatus == SubscriptionStatus.premium || 
                              next.subscriptionStatus == SubscriptionStatus.vip;

            // Si NO era premium y AHORA SÃ es premium -> Navegar a celebraciÃ³n
            if (!wasPremium && isPremium) {
                // Usar microtask para evitar conflictos de build
                Future.microtask(() {
                    if (context.mounted) {
                        context.push('/premium/activated');
                    }
                });
            }
        }
    });
    
    // â³ LISTENER DE ESPERA DE CANCIONES: Mostrar SnackBar cuando no hay canciones disponibles
    ref.listen(
      unifiedAudioProviderFixed.select((state) => state.isWaitingForMoreSongs),
      (previous, current) {
        if (current == true && previous != true) {
          // Mostrar SnackBar de espera
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Cargando mÃ¡s canciones...'),
                ],
              ),
              backgroundColor: NeumorphismTheme.coffeeMedium,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: 160, // Arriba del mini player
                left: 16,
                right: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else if (current == false && previous == true) {
          // Ocultar SnackBar cuando ya hay canciones
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      },
    );

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      resizeToAvoidBottomInset: false,
      body: isDesktop 
      // ðŸ–¥ï¸ DISEÃ‘O ESCRITORIO: Row con Sidebar Lateral
      ? Row(
          children: [
            WebSidebar(
              currentIndex: currentIndex,
              onTabSelected: (index) => _navigateToTab(index),
            ),
            // Separador vertical sutil
            VerticalDivider(
              width: 1, 
              thickness: 1, 
              color: NeumorphismTheme.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)
            ),
            // Contenido Principal
            Expanded(
              child: Stack(
                children: [
                  widget.navigationShell,
                  
                  // ðŸŽµ SPOTIFY-STYLE DRAG-TO-EXPAND PLAYER SHEET (Desktop)
                  const SpotifyPlayerSheet(),
                ],
              ),
            ),
          ],
        )
      // ðŸ“± DISEÃ‘O MÃ“VIL: Stack Original
      : Stack(
          children: [
            // Contenido con padding inferior para navbar
             AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.only(bottom: 84.0),
                child: widget.navigationShell,
              ),
            
            // Navigation Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: _buildBottomNavigationBar(currentIndex),
              ),
            ),
            
            // ðŸŽµ SPOTIFY-STYLE DRAG-TO-EXPAND PLAYER SHEET
            const SpotifyPlayerSheet(),
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
        decoration: BoxDecoration(
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
                icon: Icons.grid_view_rounded,
                activeIcon: Icons.grid_view_rounded,
                label: 'Inicio',
                isSelected: currentIndex == 0,
                onTap: () => _navigateToTab(0),
              ),
              _buildNavItem(
                icon: Icons.search_rounded,
                activeIcon: Icons.search_rounded,
                label: 'Buscar',
                isSelected: currentIndex == 1,
                onTap: () => _navigateToTab(1),
              ),
              _buildNavItem(
                icon: Icons.collections_bookmark_rounded,
                activeIcon: Icons.collections_bookmark_rounded,
                label: 'Biblioteca',
                isSelected: currentIndex == 2,
                onTap: () => _navigateToTab(2),
              ),
              _buildNavItem(
                icon: Icons.diamond_outlined,
                activeIcon: Icons.diamond_rounded,
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
                      // âœ… FIX: Dynamic colors for active state
                      ? (NeumorphismTheme.isDark ? const Color(0xFFD7CCC8) : NeumorphismTheme.coffeeDark)
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
    // ðŸ”¥ UX PRO: Haptic feedback al cambiar de tab
    // Da una sensaciÃ³n tÃ¡ctil de respuesta inmediata
    HapticFeedback.lightImpact();

    // LÃ³gica de "Doble Toque":
    // Si el usuario toca el tab en el que YA estÃ¡...
    if (widget.navigationShell.currentIndex == index) {
      // ...reseteamos el stack de esa rama a su ruta inicial.
      // Esto permite "volver al inicio" rÃ¡pidamente si te perdiste navegando.
      widget.navigationShell.goBranch(
        index,
        initialLocation: true, // ðŸš€ FORCE RESET
      );
    } else {
      // Si es un tab diferente, cambiamos de rama normalmente.
      // El estado del stack anterior se preserva en memoria.
      widget.navigationShell.goBranch(
        index,
        // No forzamos initialLocation aquÃ­ para mantener la persistencia
        // del historial cuando vuelvas a este tab mÃ¡s tarde.
      );
    }
  }
  
  // âš¡ OPTIMIZACIÃ“N: Cachear estilos de texto para evitar recrear GoogleFonts en cada build
  static TextStyle? _cachedSelectedStyle;
  static TextStyle? _cachedUnselectedStyle;
  
  TextStyle _getLabelStyle(bool isSelected) {
    if (isSelected) {
      _cachedSelectedStyle ??= GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        // âœ… FIX: Dynamic colors for active label
        color: NeumorphismTheme.isDark ? const Color(0xFFD7CCC8) : NeumorphismTheme.coffeeDark,
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


