import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../services/player_navigation_service.dart';
import '../widgets/final_mini_player.dart';
import '../../features/ads/widgets/ads_mini_player.dart';
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
      // Evitar alturas fraccionadas que pueden causar un overflow por 1px
      _cachedNavBarHeight = (80.0 + _cachedBottomPadding!).ceilToDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Obtener índice actual del navigationShell (ya viene de GoRouter)
    final currentIndex = widget.navigationShell.currentIndex;
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    final currentSong = playbackState.currentSong;
    final isPlayingAd = playbackState.isPlayingAd;
    
    final navBarHeight = _cachedNavBarHeight ?? 80.0;

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 🔥 NAVIGATION SHELL: GoRouter maneja automáticamente el IndexedStack
          // Cada rama mantiene su propio Navigator y stack de navegación
          // ✅ FIX LAYOUT SHIFT: Animar el padding inferior para evitar saltos bruscos
          AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.only(
              bottom: (isPlayingAd || currentSong != null) ? 72.0 : 0.0,
            ),
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
          
          // 📢 Mini Player de Anuncios (Animación Slide-Up)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic, // Curva "Apple-like" más natural
            bottom: isPlayingAd ? navBarHeight : -(navBarHeight + 20),
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: AdsMiniPlayer(
                // ✅ MEJOR PRÁCTICA: Usar servicio centralizado (el widget tiene fallback)
                onTap: () => PlayerNavigationService.openFullPlayer( // Nota: AdsMiniPlayer debe soportar onTap externo
                  context: context,
                  ref: ref,
                ),
              ),
            ),
          ),

          // 🎵 Mini Player de Música (Animación Slide-Up)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            // Solo mostramos player de música si no hay anuncio sonando
            bottom: (!isPlayingAd && currentSong != null) 
                ? navBarHeight 
                : -(navBarHeight + 100), // Ocultar completamente fuera de pantalla
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
    // 🔥 UX PRO: Haptic feedback al cambiar de tab
    // Da una sensación táctil de respuesta inmediata
    HapticFeedback.lightImpact();

    // Lógica de "Doble Toque":
    // Si el usuario toca el tab en el que YA está...
    if (widget.navigationShell.currentIndex == index) {
      // ...reseteamos el stack de esa rama a su ruta inicial.
      // Esto permite "volver al inicio" rápidamente si te perdiste navegando.
      widget.navigationShell.goBranch(
        index,
        initialLocation: true, // 🚀 FORCE RESET
      );
    } else {
      // Si es un tab diferente, cambiamos de rama normalmente.
      // El estado del stack anterior se preserva en memoria.
      widget.navigationShell.goBranch(
        index,
        // No forzamos initialLocation aquí para mantener la persistencia
        // del historial cuando vuelvas a este tab más tarde.
      );
    }
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

