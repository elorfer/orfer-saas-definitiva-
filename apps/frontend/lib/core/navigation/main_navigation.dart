import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final Widget? child;

  const MainNavigation({super.key, this.child});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  // Sin AnimationController - animación simple con AnimatedContainer

  // Obtener el índice basado en la ruta actual
  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home') && !location.contains('/playlist')) {
      return 0;
    } else if (location.startsWith('/search')) {
      return 1;
    } else if (location.startsWith('/library')) {
      return 2;
    } else if (location.startsWith('/profile')) {
      return 3;
    }
    return 0; // Default a home
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    // Si hay un child (ruta anidada desde ShellRoute), mostrar el child en lugar del IndexedStack
    if (widget.child != null) {
      return Scaffold(
        body: widget.child!,
        bottomNavigationBar: _buildModernBottomNavigationBar(context, currentIndex),
      );
    }

    // Lista de pantallas para el IndexedStack (cuando no hay rutas anidadas)
    // Usando const para optimizar reconstrucciones
    final screens = const [
      HomeScreen(),
      SearchScreen(),
      LibraryScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildModernBottomNavigationBar(context, currentIndex),
    );
  }

  Widget _buildModernBottomNavigationBar(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          // Altura optimizada para evitar overflow - reducida de 75 a altura mínima necesaria
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernNavItem(
                context: context,
                index: 0,
                route: '/home',
                icon: Icons.home_rounded,
                activeIcon: Icons.home,
                label: 'Inicio',
                currentIndex: currentIndex,
              ),
              _buildModernNavItem(
                context: context,
                index: 1,
                route: '/search',
                icon: Icons.search_rounded,
                activeIcon: Icons.search,
                label: 'Buscar',
                currentIndex: currentIndex,
              ),
              _buildModernNavItem(
                context: context,
                index: 2,
                route: '/library',
                icon: Icons.library_music_rounded,
                activeIcon: Icons.library_music,
                label: 'Biblioteca',
                currentIndex: currentIndex,
              ),
              _buildModernNavItem(
                context: context,
                index: 3,
                route: '/profile',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                currentIndex: currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavItem({
    required BuildContext context,
    required int index,
    required String route,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int currentIndex,
  }) {
    final isSelected = currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Navegar a la ruta usando GoRouter
          context.go(route);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF667eea).withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Minimizar tamaño vertical
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono con animación simple de tamaño y color
              AnimatedContainer(
                duration: const Duration(milliseconds: 200), // Animación suave
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF667eea)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200), // Animación de tamaño
                  curve: Curves.easeOut,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? Colors.white
                        : Colors.grey[600],
                    size: isSelected ? 24 : 22, // Cambia de tamaño cuando está seleccionado
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Texto simple sin animación compleja
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF667eea)
                        : Colors.grey[600],
                    letterSpacing: 0.1,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
