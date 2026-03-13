import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/onboarding_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}


class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _imageLoaded = false;
  bool _showError = false;
  bool _isFading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _preloadImage();
    // Intentar inicialización y navegación tras 2s
    Future.delayed(const Duration(milliseconds: 2000), _tryNavigate);
  }

  Future<void> _tryNavigate() async {
    // ✅ 1. Chequeo antes de empezar
    if (!mounted) return;
    
    // ✅ 2. Chequeo antes de setState
    if (!mounted) return;
    setState(() {
      _showError = false;
      _errorMessage = null;
    });
    
    try {
      // Esperar a que auth y onboarding estén inicializados
      final authState = ref.read(authStateProvider);
      if (!authState.isInitialized) {
        // Esperar máximo 5s
        await Future.any([
          Future.doWhile(() async {
            await Future.delayed(const Duration(milliseconds: 100));
            return !ref.read(authStateProvider).isInitialized;
          }),
          Future.delayed(const Duration(seconds: 5)),
        ]);
      }
      
      // ✅ 3. Chequeo crítico después de await
      if (!mounted) return;
      
      _navigateWithFade();
    } catch (e) {
      // ✅ 4. Chequeo antes de setState en catch
      if (!mounted) return;
      
      setState(() {
        _showError = true;
        _errorMessage = 'Error al inicializar: $e';
      });
      
      // ✅ 5. Chequeo antes de programar reintento
      if (!mounted) return;
      
      // Permitir reintento tras 5s
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _showError) _tryNavigate();
      });
    }
  }

  void _navigateWithFade() async {
    // ✅ Chequeo inicial
    if (_isFading || !mounted) return;
    
    // ✅ Chequeo antes de setState
    if (!mounted) return;
    setState(() => _isFading = true);
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    // ✅ Chequeo crítico después de await
    if (!mounted) return;
    
    final authState = ref.read(authStateProvider);
    final onboardingCompleted = ref.read(onboardingProvider);
    final router = GoRouter.of(context);
    
    // ✅ Chequeo final antes de navegar
    if (!mounted) return;
    
    // Navegación condicional
    if (!onboardingCompleted) {
      router.go('/onboarding');
    } else if (!authState.isAuthenticated) {
      router.go('/login');
    } else {
      router.go('/home');
    }
  }

  Future<void> _preloadImage() async {
    try {
      await precacheImage(
        const AssetImage('assets/images/logo.webp'),
        context,
      );
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;
    final logoSize = isSmallScreen ? 100.0 : (isMediumScreen ? 120.0 : 140.0);
    final logoIconSize = isSmallScreen ? 75.0 : (isMediumScreen ? 90.0 : 100.0);

    return Scaffold(
      body: AnimatedOpacity(
        opacity: _isFading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF3E2723),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                            'assets/images/logo.webp',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
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
                if (_showError)
                  Column(
                    children: [
                      Text(
                        _errorMessage ?? 'Error al inicializar',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _tryNavigate,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                else
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
      ),
    );
  }
}
















