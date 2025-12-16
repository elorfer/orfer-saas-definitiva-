import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _imageLoaded = false;
  bool _canNavigate = false;

  @override
  void initState() {
    super.initState();
    // Precargar imagen del logo
    _preloadImage();
    // OPTIMIZACIÓN: Delay mínimo de 2 segundos para asegurar que el splash se muestre
    // Esto es especialmente importante en hot restart donde la navegación puede ser instantánea
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _canNavigate = true;
        });
        _checkAndNavigate();
      }
    });
  }

  void _checkAndNavigate() {
    if (!_canNavigate || !mounted) return;
    
    final authState = ref.read(authStateProvider);
    final router = GoRouter.of(context);
    
    // Solo navegar si el estado está inicializado
    if (authState.isInitialized) {
      if (authState.isAuthenticated) {
        router.go('/home');
      } else {
        router.go('/login');
      }
    }
  }


  Future<void> _preloadImage() async {
    try {
      await precacheImage(
        const AssetImage('assets/images/Logo principal.webp'),
        context,
      );
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    } catch (e) {
      // Si falla la precarga, continuar de todas formas
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observar el estado de autenticación para reaccionar a cambios
    final authState = ref.watch(authStateProvider);
    
    // Si ya podemos navegar y el estado está inicializado, navegar
    if (_canNavigate && authState.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndNavigate();
        }
      });
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;
    
    // Logo con tamaño aumentado y prominente (igual que en login)
    final logoSize = isSmallScreen ? 150.0 : (isMediumScreen ? 180.0 : 200.0);
    final logoIconSize = isSmallScreen ? 75.0 : (isMediumScreen ? 90.0 : 100.0);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF3E2723), // Marrón oscuro (igual que login)
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo con tamaño aumentado
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  child: _imageLoaded
                      ? Image.asset(
                          'assets/images/Logo principal.webp',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback a icono si la imagen no se carga
                            return Icon(
                              Icons.music_note,
                              size: logoIconSize,
                              color: Colors.white,
                            );
                          },
                        )
                      : Icon(
                          Icons.music_note,
                          size: logoIconSize,
                          color: Colors.white,
                        ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Struky',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 36 : (isMediumScreen ? 42 : 48),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 32),
              SizedBox(
                width: isSmallScreen ? 32 : 40,
                height: isSmallScreen ? 32 : 40,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
















