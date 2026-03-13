import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pantalla de agradecimiento que se muestra cuando el usuario activa Premium.
///
/// Presenta un mensaje emocional y de reconocimiento por el apoyo
/// a los compositores independientes.
class PremiumActivatedScreen extends ConsumerStatefulWidget {
  const PremiumActivatedScreen({super.key});

  @override
  ConsumerState<PremiumActivatedScreen> createState() => _PremiumActivatedScreenState();
}

class _PremiumActivatedScreenState extends ConsumerState<PremiumActivatedScreen>
    with SingleTickerProviderStateMixin {
  // Constantes de diseño
  static const Duration _animationDuration = Duration(milliseconds: 800);
  static const double _horizontalPadding = 20.0;
  static const double _verticalPadding = 16.0;
  static const double _imageSize = 260.0;
  static const double _imageMaxWidth = 280.0;
  static const double _sectionSpacing = 24.0;
  static const double _compactSpacing = 12.0;
  static const double _borderRadius = 18.0;
  static const double _buttonHeight = 52.0;
  static const double _buttonBorderRadius = 14.0;

  // Constantes de colores
  static const Color _beigeLight = Color(0xFFF5E6D3);
  static const Color _beigeMedium = Color(0xFFE8D5C4);
  static const Color _brownLight = Color(0xFFD4C4A8);
  static const Color _brownMedium = Color(0xFF8D6E63);
  static const Color _brownDark = Color(0xFF5D4037);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _goldOrange = Color(0xFFFFA500);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    // Animación de fade más rápida y suave
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Animación de slide más rápida y fluida
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _beigeLight,
              _beigeMedium,
              _brownLight,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              cacheExtent: 400,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                    vertical: _verticalPadding,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildAnimatedSection(_buildHeadline()),
                      const SizedBox(height: _compactSpacing),
                      _buildAnimatedSection(_buildSubmessage()),
                      const SizedBox(height: _sectionSpacing),
                      _buildAnimatedSection(_buildVisualProtagonist()),
                      const SizedBox(height: 28),
                      _buildAnimatedSection(_buildPremiumBadge()),
                      const SizedBox(height: _sectionSpacing),
                      _buildAnimatedSection(_buildEmotionalPhrase()),
                      const SizedBox(height: _sectionSpacing),
                      _buildAnimatedSection(_buildRecognitionBlock()),
                      const SizedBox(height: 20),
                      _buildAnimatedSection(_buildSubtleBenefits()),
                      const SizedBox(height: _sectionSpacing),
                      _buildAnimatedSection(_buildMainButton()),
                      const SizedBox(height: 16),
                      _buildAnimatedSection(_buildFinalDetail()),
                      const SizedBox(height: 250),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSection(Widget child) {
    return RepaintBoundary(
      child: SlideTransition(
        position: _slideAnimation,
        child: child,
      ),
    );
  }

  Widget _buildHeadline() {
    return Center(
      child: Text(
        'Gracias! La barba crece, pero tu apoyo la hace brillar.',
        style: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _brownDark,
          letterSpacing: -0.6,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSubmessage() {
    return Center(
      child: Text(
        'Hoy la música se siente acompañada.',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _brownMedium,
          letterSpacing: -0.1,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVisualProtagonist() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: _imageMaxWidth),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/IMAJEN DE LAS SUSCRIPCIONES.webp',
              width: _imageSize,
              height: _imageSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildImagePlaceholder();
              },
            ),
            _buildGlowEffect(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: _imageSize,
      height: _imageSize,
      decoration: BoxDecoration(
        color: _brownLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.person,
        size: 80,
        color: _brownMedium,
      ),
    );
  }

  Widget _buildGlowEffect() {
    return Positioned(
      bottom: 15,
      child: Container(
        width: 100,
        height: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              _gold.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildRecognitionBlock() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(
          color: _brownLight.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu apoyo significa que:',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _brownDark,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecognitionItem(Icons.music_note_rounded, 'Un compositor puede seguir creando sin rendirse'),
          const SizedBox(height: _compactSpacing),
          _buildRecognitionItem(Icons.favorite_rounded, 'Años de espera ahora tienen sentido'),
          const SizedBox(height: _compactSpacing),
          _buildRecognitionItem(Icons.public_rounded, 'Música que no es tendencia sigue viva'),
        ],
      ),
    );
  }

  Widget _buildRecognitionItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, -1),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _brownMedium.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: _brownMedium,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _brownDark,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionalPhrase() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _brownLight.withValues(alpha: 0.3),
            _beigeMedium.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _brownLight.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            'La barba crece cuando nadie escucha.',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _brownDark,
              letterSpacing: -0.3,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tu apoyo la transformó en historia.',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _brownMedium,
              letterSpacing: -0.3,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  _gold,
                  _goldOrange,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Mecenas de la Música',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Apoyas directamente a quienes crean desde el silencio.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _brownMedium,
              letterSpacing: -0.1,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubtleBenefits() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _brownMedium.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beneficios Premium',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _brownDark,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 14),
          _buildSubtleBenefitItem('Escucha sin interrupciones'),
          const SizedBox(height: 8),
          _buildSubtleBenefitItem('Acceso anticipado a canciones inéditas'),
          const SizedBox(height: 8),
          _buildSubtleBenefitItem('Calidad de audio superior'),
          const SizedBox(height: 8),
          _buildSubtleBenefitItem('Música sin algoritmos cerrados'),
        ],
      ),
    );
  }

  Widget _buildSubtleBenefitItem(String text) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: _brownMedium,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _brownDark,
              letterSpacing: -0.1,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    return Container(
      width: double.infinity,
      height: _buttonHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _brownMedium,
            _brownDark,
          ],
        ),
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
        boxShadow: [
          BoxShadow(
            color: _brownDark.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleButtonTap,
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
          child: Center(
            child: Text(
              'Escuchar y apoyar',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinalDetail() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Gracias por creer en la música…\ny en quienes la han esperado toda la vida.',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _brownMedium.withValues(alpha: 0.8),
            letterSpacing: -0.1,
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _handleButtonTap() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }
}

