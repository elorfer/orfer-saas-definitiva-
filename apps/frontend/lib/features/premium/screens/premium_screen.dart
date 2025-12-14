import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// Pantalla Premium con mensaje emocional y llamada a la acción
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // ⚡ Scroll estilo iPhone
            cacheExtent: 400, // ⚡ Cache optimizado para mejor rendimiento
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                // ⚡ OPTIMIZADO: Título principal con RepaintBoundary
                RepaintBoundary(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 64,
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
                ),
                
                const SizedBox(height: 40),
                
                // ⚡ OPTIMIZADO: Subtítulo emocional con sombra reducida
                RepaintBoundary(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15),
                          NeumorphismTheme.coffeeDark.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                      boxShadow: [
                        // ⚡ OPTIMIZACIÓN: Reducir sombra para mejor rendimiento
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12, // Reducido de 20 a 12
                          offset: const Offset(0, 4), // Reducido de 8 a 4
                        ),
                      ],
                    ),
                  child: Text(
                    'Cada suscripción impulsa a un compositor real. No a una marca. No a una multinacional. A un creador que por fin quiere ser escuchado.',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: NeumorphismTheme.textPrimary,
                      height: 1.6,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 💬 Mensaje central
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
                
                const SizedBox(height: 32),
                
                // ⚡ OPTIMIZADO: Beneficio emocional con RepaintBoundary
                RepaintBoundary(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                      border: Border.all(
                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                        width: 2,
                      ),
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
                        'apoyas a un compositor a crear, a crecer y a ser libre.',
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
                ),
                
                const SizedBox(height: 32),
                
                // ⚡ OPTIMIZADO: Beneficios Premium con RepaintBoundary
                RepaintBoundary(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✨ Beneficios Premium',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: NeumorphismTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                
                const SizedBox(height: 40),
                
                // 💛 Mensajes de impacto
                _buildImpactMessage(
                  'La industria ocultó sus nombres.',
                ),
                _buildImpactMessage(
                  'La historia ignoró sus voces.',
                ),
                _buildImpactMessage(
                  'El crédito nunca llegó.',
                ),
                _buildImpactMessage(
                  'Hasta hoy.',
                  isHighlight: true,
                ),
                const SizedBox(height: 16),
                _buildImpactMessage(
                  'La música necesita héroes silenciosos.',
                ),
                _buildImpactMessage(
                  'Tú puedes ser uno.',
                  isHighlight: true,
                ),
                
                const SizedBox(height: 40),
                
                // ⚡ OPTIMIZADO: Llamado a la acción con sombra reducida
                RepaintBoundary(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NeumorphismTheme.coffeeMedium,
                          NeumorphismTheme.coffeeDark,
                        ],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(28)),
                      boxShadow: [
                        // ⚡ OPTIMIZACIÓN: Reducir sombra para mejor rendimiento
                        BoxShadow(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                          blurRadius: 16, // Reducido de 24 a 16
                          offset: const Offset(0, 8), // Reducido de 12 a 8
                        ),
                      ],
                    ),
                  child: Column(
                    children: [
                      Text(
                        'Suscríbete ahora y da voz a quienes escriben la banda sonora de tu vida.',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.5,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'O, si quieres algo más emocional:',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hazte Premium y convierte a un compositor olvidado… en una leyenda.',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.4,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Nota: Funcionalidad de suscripción premium pendiente de implementar
                            },
                            borderRadius: const BorderRadius.all(Radius.circular(16)),
                            child: Center(
                              child: Text(
                                'Suscribirse a Premium',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: NeumorphismTheme.coffeeDark,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // ⚡ OPTIMIZADO: Frase final poderosa con RepaintBoundary
                RepaintBoundary(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.4),
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
                ),
                
                const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageSection({
    required String title,
    required List<String> content,
  }) {
    // ⚡ OPTIMIZADO: Mensaje con RepaintBoundary y sombra reducida
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.5),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          boxShadow: [
            // ⚡ OPTIMIZACIÓN: Reducir sombra para mejor rendimiento
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, // Reducido de 16 a 8
              offset: const Offset(0, 3), // Reducido de 6 a 3
            ),
          ],
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



