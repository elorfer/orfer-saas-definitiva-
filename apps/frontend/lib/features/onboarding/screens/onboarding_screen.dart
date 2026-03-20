import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/intelligent_featured_provider.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// Pantalla de onboarding narrativo con 7 imágenes
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Textos narrativos para cada pantalla
  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      image: 'assets/images/onboarding/1.webp',
      title: 'Por años, otros se llevaban los aplausos... y el dinero.',
      subtitle: 'El compositor trabajaba en silencio mientras otros celebraban.',
    ),
    OnboardingPageData(
      image: 'assets/images/onboarding/2.webp',
      title: 'Millones de personas disfrutaron de su música.',
      subtitle: 'Y el mundo entero... lo escuchó.',
    ),
    OnboardingPageData(
      image: 'assets/images/onboarding/3.webp',
      title: 'La mente se resiste... Pero lo intenta.',
      subtitle: 'La tecnología abre nuevas posibilidades para crear.',
    ),
    OnboardingPageData(
      image: 'assets/images/onboarding/4.webp',
      title: 'La caída',
      subtitle: 'Miles de compositores quedaron en el olvido.',
    ),
    OnboardingPageData(
      image: 'assets/images/onboarding/5.webp',
      title: 'El renacimiento del compositor',
      subtitle: 'Disfruta de la buena música...',
    ),
    OnboardingPageData(
      image: 'assets/images/onboarding/6.webp',
      title: 'El Descubrimiento',
      subtitle: 'Un día descubrió que podía publicar sin arrodillarse ante nadie.',
    ),
    OnboardingPageData(
      image: 'assets/images/onboarding/7.webp',
      title: 'Toda canción empieza con alguien que nadie ve.',
      subtitle: 'Hoy, tu suscripción cambia el juego.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 🔥 Precargar Home en background mientras se muestra el onboarding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadHome();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Precargar la pantalla de Home en background
  void _preloadHome() {
    try {
      // ✅ FIX: Usar watch o listen en lugar de read para evitar error de inicialización
      // Inicializar el provider de Home para que cargue los datos
      // Esto activará el build() del Notifier que carga los datos automáticamente
      // Usar un Future.microtask para evitar acceder al provider durante su construcción
      Future.microtask(() {
        try {
          ref.read(homeStateProvider.notifier);
          // También precargar las recomendaciones inteligentes
          ref.read(intelligentFeaturedProvider.notifier);
          debugPrint('✅ Home precargado en background');
        } catch (e) {
          debugPrint('⚠️ Error precargando Home (no crítico): $e');
        }
      });
    } catch (e) {
      debugPrint('⚠️ Error en _preloadHome (no crítico): $e');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _nextPage() {
    try {
      if (_currentPage < _pages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _completeOnboarding();
      }
    } catch (e) {
      // 🔥 Manejo de error para evitar crashes
      debugPrint('Error navegando página: $e');
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    try {
      // Guardar el estado del onboarding
      await ref.read(onboardingProvider.notifier).completeOnboarding();
      
      // ✅ FIX: Navegar directamente sin esperar Home
      // El router ya maneja la redirección y Home se cargará cuando sea necesario
      if (mounted) {
        // Esperar un frame para asegurar que el estado se actualice
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Navegar a Home (el router manejará la carga)
        if (mounted) {
          context.go('/home');
        }
      }
    } catch (e, stackTrace) {
      // 🔥 Manejo de error para evitar crashes
      debugPrint('⚠️ Error completando onboarding: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        // Intentar navegar de todas formas
        try {
          context.go('/home');
        } catch (navError) {
          debugPrint('⚠️ Error navegando a home: $navError');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphismTheme.isDark 
          ? NeumorphismTheme.background 
          : const Color(0xFF3E2723), // Mantener el marrón oscuro característico para el onboarding si es light
      body: Stack(
        children: [
          // PageView con las imágenes ocupando toda la pantalla
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildPage(_pages[index], index);
            },
          ),

          // Contenido superpuesto (botones e indicadores)
          SafeArea(
            child: Column(
              children: [
                // Skip button
                if (_currentPage < _pages.length - 1)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.all(Radius.circular(20)),
                        ),
                        child: TextButton(
                          onPressed: _skipOnboarding,
                          child: Text(
                            'Omitir',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const Spacer(),

                // Indicadores de página
                _buildPageIndicators(),

                // Botón de acción
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildActionButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPageData pageData, int index) {
    return RepaintBoundary(
      child: Container(
        color: NeumorphismTheme.isDark 
            ? NeumorphismTheme.background 
            : const Color(0xFF3E2723), // 🔥 Fondo marrón oscuro
        child: Center(
          child: Image.asset(
            pageData.image,
            package: null,
            fit: BoxFit.contain, // 🔥 Mantener tamaño original sin estirar
            // Ajuste de caché: limitar ancho de decodificación (~1.5x ancho típico)
            cacheWidth: 1080,
            errorBuilder: (context, error, stackTrace) {
              // 🔥 Manejo de error silencioso para evitar crashes
              return Container(
                color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.3),
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _pages.length,
          (index) => _buildIndicator(index == _currentPage),
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final isLastPage = _currentPage == _pages.length - 1;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D6E63), // 🔥 Café Premium (Constante para branding)
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            elevation: 0,
          ),
          child: Text(
            isLastPage ? 'Comenzar' : 'Siguiente',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String image;
  final String title;
  final String subtitle;

  OnboardingPageData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}

