import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neumorphism_theme.dart';
import '../../../../core/theme/text_styles.dart';

class WebHeroBanner extends ConsumerWidget {
  const WebHeroBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aquí podríamos tomar datos reales del provider, por ahora haremos un diseño visual impactante
    // que invite a descubrir música.
    
    return Container(
      width: double.infinity,
      height: 380, // âœ… Aumentado para evitar overflow
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: AssetImage('assets/images/vintage_hero_wide.png'),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high, // Ensure best scaling quality
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Overlay para legibilidad del texto
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Fondo Decorativo (Círculos abstractos)
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          
          // Contenido
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
            child: Row(
              children: [
                // Texto y Botones (Izquierda)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ðŸŒŸ NUEVO EN STRUKY',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Descubre la Mejor\nMúsica Vintage',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: Colors.white,
                          fontSize: 42,
                          height: 1.1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Explora millones de canciones, artistas legendarios y playlists curadas para ti.',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _HeroButton(
                            text: 'Reproducir Ahora',
                            icon: Icons.play_arrow_rounded,
                            isPrimary: true,
                            onTap: () {},
                          ),
                          const SizedBox(width: 16),
                          _HeroButton(
                            text: 'Más Información',
                            icon: Icons.info_outline_rounded,
                            isPrimary: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Espacio o Imagen (Derecha) - Por ahora espacio para balance
                // Aquí iría una imagen grande recortada del artista destacado
                const Expanded(flex: 2, child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _HeroButton({
    required this.text,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: isPrimary ? null : Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: isPrimary ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary ? NeumorphismTheme.accent : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  color: isPrimary ? NeumorphismTheme.accent : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

