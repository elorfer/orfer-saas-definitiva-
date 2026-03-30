import 'package:flutter/material.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/neumorphism_theme.dart';

class LandingInfoSection extends StatelessWidget {
  const LandingInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      width: double.infinity,
      color: NeumorphismTheme.background, // Usar tema central (Marrón Oscuro)
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          // Main Headline & Description
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Text(
                  'Struky',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: const Color(0xFFD7CCC8), // Coffee light
                    fontSize: isDesktop ? 64 : 48,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Descubre la música que ha estado oculta por mucho tiempo.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 32 : 24,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Apoya a compositores reales y disfruta de nuestro algoritmo de recomendaciones basado en tus gustos.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.grey[400],
                    fontSize: isDesktop ? 20 : 16,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 80),

          // Feature Grid
          Wrap(
            spacing: 30,
            runSpacing: 30,
            alignment: WrapAlignment.center,
            children: [
              _FeatureCard(
                imagePath: 'assets/images/feature_hidden_music.png',
                title: 'Joyas Ocultas',
                description: 'Accede a un catálogo exclusivo de música inédita que no encontrarás en ningún otro lugar.',
              ),
              _FeatureCard(
                imagePath: 'assets/images/feature_composers.png',
                title: 'Apoyo Real',
                description: 'Conectamos directamente a los compositores con su audiencia, asegurando un trato justo.',
              ),
              _FeatureCard(
                imagePath: 'assets/images/feature_algorithm.png',
                title: 'IA Musical 2026',
                description: 'Nuestro avanzado algoritmo entiende tus gustos y te presenta tu próxima canción favorita.',
              ),
            ],
          ),

          const SizedBox(height: 120),

          // COMPOSER SERVICE SECTION (New)
          const _ComposerServiceSection(),

          const SizedBox(height: 120),

          // Footer minimalista
           Text(
            'Â© 2026 Struky Music. Todos los derechos reservados.',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ComposerServiceSection extends StatelessWidget {
  const _ComposerServiceSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1100),
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface, // Café Tostado Oscuro
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: isDesktop 
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Image Side (50%)
                  Expanded(
                    flex: 1,
                    child: Image.asset(
                      'assets/images/composer_service_bg.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Content Side (50%)
                  Expanded(
                    flex: 1,
                    child: _buildContent(context),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                 // Image Side (Top)
                 SizedBox(
                   height: 300,
                   width: double.infinity,
                   child: Image.asset(
                      'assets/images/composer_service_bg.png',
                      fit: BoxFit.cover,
                    ),
                 ),
                 // Content Side (Bottom)
                 _buildContent(context),
              ],
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD7CCC8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0xFFD7CCC8).withValues(alpha: 0.3)),
            ),
            child: const Text(
              'PARA COMPOSITORES',
              style: TextStyle(
                color: Color(0xFFD7CCC8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¿Eres Compositor?',
            style: AppTextStyles.displayLarge.copyWith(
              color: Colors.white,
              fontSize: 42,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Si escribes canciones y tu presupuesto no te alcanza, brindamos un servicio especial para ti.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 18,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
           Text(
            'Crearemos la canción escrita por ti con producción profesional y la publicaremos directamente en nuestra app.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.grey[400],
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD7CCC8), // Coffee Accent
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                 Text(
                  'Más Información',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final String imagePath;
  final String title;
  final String description;

  const _FeatureCard({
    required this.imagePath,
    required this.title,
    required this.description,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Adaptar ancho para móviles pequeños para evitar overflow
    final cardWidth = screenWidth < 380 ? screenWidth - 48 : 320.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: cardWidth, // Responsive width
        height: 400, // Taller structure
        decoration: BoxDecoration(
          color: NeumorphismTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isHovering ? const Color(0xFFD7CCC8) : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: _isHovering
              ? [
                  BoxShadow(
                    color: const Color(0xFFD7CCC8).withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ]
              : [],
        ),
        clipBehavior: Clip.antiAlias, // Clip image to border radius
        child: Column(
          children: [
            // Image Section
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.imagePath,
                    fit: BoxFit.cover,
                  ),
                  // Gradient Overlay for text readability transition
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          NeumorphismTheme.surface.withValues(alpha: 0.8),
                          NeumorphismTheme.surface,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Text Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

