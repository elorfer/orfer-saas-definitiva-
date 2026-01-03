import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/theme_provider.dart';

/// Pantalla de suscripción Premium que presenta los beneficios
/// y motiva al usuario a convertirse en premium.
///
/// Esta pantalla se muestra cuando el usuario no tiene una suscripción activa.
class PremiumDeactivatedScreen extends ConsumerStatefulWidget {
  const PremiumDeactivatedScreen({super.key});

  @override
  ConsumerState<PremiumDeactivatedScreen> createState() => _PremiumDeactivatedScreenState();
}

class _PremiumDeactivatedScreenState extends ConsumerState<PremiumDeactivatedScreen>
    with AutomaticKeepAliveClientMixin {
  // Constantes de diseño
  static const double _horizontalPadding = 24.0;
  static const double _verticalPadding = 20.0;
  static const double _sectionSpacing = 32.0;
  static const double _largeSpacing = 40.0;
  static const double _imageSize = 280.0;
  static const double _iconSize = 64.0;
  static const double _borderRadius = 24.0;
  static const double _buttonHeight = 56.0;
  static const double _buttonBorderRadius = 16.0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 🚀 Refresh on Theme Change
    ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
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
                    _buildHeader(),
                    const SizedBox(height: _largeSpacing),
                    _buildHeroSection(),
                    const SizedBox(height: _sectionSpacing),
                    _buildSubscribeButton(isHighlighted: true),
                    const SizedBox(height: _sectionSpacing),
                    _buildMessageSection(
                      title: 'Durante décadas, las canciones que amaste tuvieron un autor invisible.',
                      content: [
                        'Las historias que cantaste, las melodías que te salvaron, salieron de alguien que casi nunca recibió el reconocimiento.',
                        'El artista se llevó los aplausos.',
                        'El compositor, el silencio.',
                        'Pero hoy todo cambia.',
                        'Hoy, tu suscripción cambia el juego.',
                      ],
                    ),
                    const SizedBox(height: _sectionSpacing),
                    _buildEmotionalBenefitSection(),
                    const SizedBox(height: _sectionSpacing),
                    _buildBenefitsList(),
                    const SizedBox(height: _largeSpacing),
                    _buildImpactMessages(),
                    const SizedBox(height: _largeSpacing),
                    _buildFinalMessage(),
                    const SizedBox(height: _largeSpacing),
                    _buildSubscribeButton(isHighlighted: true),
                    const SizedBox(height: 250),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return RepaintBoundary(
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.diamond_rounded,
              size: _iconSize,
              color: NeumorphismTheme.coffeeMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Hazte Premium y Libera la Música que Nunca Escuchaste',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.textPrimary,
                letterSpacing: -0.5,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_borderRadius),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : const Color(0xFFF2EFEC), // 🚀 OPTIMIZACIÓN: Dinámico
          borderRadius: const BorderRadius.all(Radius.circular(_borderRadius)),
          // boxShadow removido
        ),
        child: Column(
          children: [
            Text(
              'Cada suscripción impulsa a un compositor real. No a una marca. No a una multinacional.',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: NeumorphismTheme.textPrimary,
                height: 1.6,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _borderRadius),
            RepaintBoundary(
              child: Center(
                child: Image.asset(
                  'assets/images/anciano_premiun.webp',
                  width: _imageSize,
                  height: _imageSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: _imageSize,
                      height: _imageSize,
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: _borderRadius),
            Text(
              'A un creador que por fin quiere ser escuchado.',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: NeumorphismTheme.textPrimary,
                height: 1.6,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionalBenefitSection() {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_borderRadius),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : const Color(0xFFF5F2EF), // 🚀 OPTIMIZACIÓN: Dinámico
          borderRadius: const BorderRadius.all(Radius.circular(_borderRadius)),
          // Border removido para evitar costo de renderizado
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: NeumorphismTheme.coffeeMedium,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cuando te vuelves Premium, no compras "más funciones":',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Apoyas a un compositor a crear, a crecer y a ser libre.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: NeumorphismTheme.coffeeMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pagas por talento.\nPor arte.\nPor verdad.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: NeumorphismTheme.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsList() {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_borderRadius),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : const Color(0xFFF7F5F3), // 🚀 OPTIMIZACIÓN: Dinámico
          borderRadius: const BorderRadius.all(Radius.circular(_borderRadius)),
          // boxShadow removido
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                '✨ Beneficios Premium',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _buildBenefitItem(
              icon: Icons.download_rounded,
              text: 'Música sin conexión a internet',
            ),
            _buildBenefitItem(
              icon: Icons.explore_rounded,
              text: 'Descubre canciones exclusivas antes que nadie',
            ),
            _buildBenefitItem(
              icon: Icons.people_rounded,
              text: 'Conecta directamente con compositores independientes',
            ),
            _buildBenefitItem(
              icon: Icons.history_rounded,
              text: 'Accede a historias detrás de cada canción',
            ),
            _buildBenefitItem(
              icon: Icons.attach_money_rounded,
              text: 'Apoya económicamente a los creadores',
            ),
            _buildBenefitItem(
              icon: Icons.trending_up_rounded,
              text: 'Sé parte del nuevo movimiento musical',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactMessages() {
    return Column(
      children: [
        _buildImpactMessage('La industria ocultó sus nombres.'),
        _buildImpactMessage('La historia ignoró sus voces.'),
        _buildImpactMessage('El crédito nunca llegó.'),
        _buildImpactMessage('Hasta hoy.', isHighlight: true),
        const SizedBox(height: 16),
        _buildImpactMessage('La música necesita héroes silenciosos.'),
        _buildImpactMessage('Tú puedes ser uno.', isHighlight: true),
      ],
    );
  }

  Widget _buildSubscribeButton({bool isHighlighted = false}) {
    if (isHighlighted) {
      return Container(
        width: double.infinity,
        height: _buttonHeight + 4,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NeumorphismTheme.coffeeMedium,
              NeumorphismTheme.coffeeDark,
            ],
          ),
          borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
        ),
        // 🚀 OPTIMIZACIÓN: Sin sombras pesadas
        child: Material(
          color: Colors.transparent, 
          borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
          child: InkWell(
            onTap: _handleSubscribeTap,
            borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(
                    Icons.diamond_rounded,
                    color: NeumorphismTheme.isDark ? const Color(0xFF2D2420) : Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Suscribirse a Premium',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.isDark ? const Color(0xFF2D2420) : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      height: _buttonHeight,
      decoration: BoxDecoration(
        color: NeumorphismTheme.isDark ? NeumorphismTheme.surface : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
        border: Border.all(
          color: NeumorphismTheme.isDark ? NeumorphismTheme.accent.withValues(alpha: 0.2) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSubscribeTap,
          borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
          child: Center(
            child: Text(
              'Suscribirse a Premium',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.isDark ? NeumorphismTheme.accent : NeumorphismTheme.coffeeDark,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinalMessage() {
    return RepaintBoundary(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(_borderRadius),
          decoration: BoxDecoration(
            color: NeumorphismTheme.isDark 
                ? NeumorphismTheme.surface 
                : const Color(0xFFF0EBE6), // 🚀 OPTIMIZACIÓN: Dinámico
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          child: Column(
            children: [
              Text(
                'Porque por primera vez,',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: NeumorphismTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'la música le pertenece a quien la crea,',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'y a quien la apoya.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.coffeeMedium,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSubscribeTap() {
    // TODO: Implementar funcionalidad de suscripción premium
  }

  Widget _buildMessageSection({
    required String title,
    required List<String> content,
  }) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_borderRadius),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : const Color(0xFFF7F5F3), // 🚀 OPTIMIZACIÓN: Dinámico
          borderRadius: const BorderRadius.all(Radius.circular(_borderRadius)),
          // boxShadow removido
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.textPrimary,
                letterSpacing: -0.3,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ...content.map((text) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: NeumorphismTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(
              icon,
              color: NeumorphismTheme.coffeeMedium,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: NeumorphismTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMessage(String text, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: isHighlight ? 20 : 18,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
          color: isHighlight
              ? NeumorphismTheme.coffeeMedium
              : NeumorphismTheme.textPrimary,
          letterSpacing: isHighlight ? -0.3 : -0.2,
          height: 1.4,
        ),
      ),
    );
  }
}

