import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../widgets/mini_player.dart';
import '../widgets/professional_audio_player.dart';
import '../providers/professional_audio_provider.dart';
import '../models/song_model.dart';
import '../utils/full_player_tracker.dart';
import '../audio/audio_manager.dart';

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
    // Configurar callback en AudioManager para abrir el full player
    // Se configura en cada build para asegurar que el contexto esté disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.mounted) {
        final audioManager = ref.read(audioManagerProvider);
        audioManager.setOnOpenFullPlayerCallback(() => _openFullPlayer(context));
      }
    });
    
    final currentIndex = _getCurrentIndex(context);

    // Si hay un child (ruta anidada desde ShellRoute), mostrar el child
    // Si no hay child, mostrar IndexedStack con las pantallas principales
    final bodyContent = widget.child ?? IndexedStack(
      index: currentIndex,
      children: const [
        HomeScreen(),
        SearchScreen(),
        LibraryScreen(),
        ProfileScreen(),
      ],
    );
    
    // Renderizar el Scaffold con MiniPlayer arriba y navigation bar abajo
    // Ambos en bottomNavigationBar usando Column (NO hace scroll, solo organiza)
    // El navigation bar queda tal cual como está ahora (abajo)
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco explícito para evitar fondo beige del tema
      body: bodyContent,
      // bottomNavigationBar contiene: MiniPlayer (arriba) + Navigation bar (abajo)
      // Estilo Spotify: pegado directamente sin espacios
      bottomNavigationBar: Container(
        color: const Color(0xFFF2E8DD), // beigeLight del tema - mismo fondo que navigation bar
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MiniPlayer arriba, pegado directamente al navigation bar (sin espacios)
            MiniPlayer(
              onTap: () => _openFullPlayer(context),
            ),
            // Navigation bar abajo - sin separación
            _buildModernBottomNavigationBar(context, currentIndex),
          ],
        ),
      ),
    );
  }

  /// Método optimizado para abrir el reproductor completo con transición fluida estilo Spotify/Apple Music
  /// El FullPlayer aparece DESDE el MiniPlayer con animación suave (250-320ms)
  void _openFullPlayer(BuildContext context) {
    // Verificar si ya hay un reproductor abierto
    if (FullPlayerTracker.isOpen) {
      return; // Ya está abierto, no abrir otro
    }
    
    // Verificar que hay una canción cargada antes de mostrar el modal
    final currentSongAsync = ref.read(professionalCurrentSongProvider);
    Song? currentSong;
    
    // Obtener la canción desde el provider
    currentSong = currentSongAsync.maybeWhen(
      data: (song) => song,
      orElse: () => null,
    );
    
    // Si no hay canción en el provider, intentar obtenerla directamente del controller
    if (currentSong == null) {
      try {
        final audioService = ref.read(professionalAudioServiceProvider);
        if (audioService.isInitialized && audioService.controller != null) {
          currentSong = audioService.controller!.currentSong;
        }
      } catch (e) {
        // Ignorar errores
      }
    }

    if (currentSong == null) {
      // Si no hay canción, no mostrar el modal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ninguna canción reproduciéndose'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Marcar como abierto
    FullPlayerTracker.setOpen(true);
    
    // Mostrar modal con transición optimizada estilo Spotify/Apple Music
    // El modal aparece DESDE el MiniPlayer con animación suave (280ms, GPU-optimizada)
    // showModalBottomSheet usa animación optimizada por defecto que empieza desde abajo
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true, // Usar SafeArea como solicitado
      routeSettings: const RouteSettings(name: '/full_player'),
      builder: (context) => RepaintBoundary(
        // Usar RepaintBoundary para optimizar rendimiento y evitar rebuilds innecesarios
        // Esto mantiene el FullPlayer aislado del resto de la UI
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28), // Bordes redondeados arriba
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.98, // Ocupar casi toda la pantalla desde el inicio
            minChildSize: 0.6,
            maxChildSize: 0.98,
            snap: true,
            snapSizes: const [0.98],
            builder: (context, scrollController) => RepaintBoundary(
              // RepaintBoundary interno para evitar rebuilds del contenido debajo
              // Mantiene el FullPlayer aislado del resto de la UI
              child: const SafeArea(
                child: ProfessionalAudioPlayer(),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // Cuando el modal se cierra, marcar como cerrado
      FullPlayerTracker.setOpen(false);
    });
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
          // Altura optimizada - debe quedar justo debajo del MiniPlayer
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
                ? const Color(0xFFB8A894).withValues(alpha: 0.15)
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
                      ? const Color(0xFFB8A894)
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
                        ? const Color(0xFFB8A894)
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
