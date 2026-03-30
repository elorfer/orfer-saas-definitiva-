import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';

class UpdateOptionalBottomSheet extends StatelessWidget {
  final String? updateUrl;

  const UpdateOptionalBottomSheet({
    super.key,
    this.updateUrl,
  });

  Future<void> _launchUpdateUrl() async {
    final url = Uri.parse(updateUrl ?? 'https://struky.com/download');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definimos el color oro de la marca
    const goldColor = Color(0xFFD4AF37);
    final isDark = NeumorphismTheme.isDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120), // 🎯 FIX: 120px abajo para que NUNCA lo tape el mini player
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: NeumorphismTheme.floatingShadow,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de arrastre (Handle)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NeumorphismTheme.textLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Icono Central con brillo - ¡AHORA MÁS COMPACTO PARA NO EMPUJAR TANTO!
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: Container(
                padding: const EdgeInsets.all(24), // De 32 a 24 (más compacto)
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goldColor.withValues(alpha: 0.15),
                  border: Border.all(color: goldColor.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: goldColor.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 50, // De 60 a 50 (más balanceado)
                  color: goldColor,
                ),
              ),
            ),
            const SizedBox(height: 24), // De 32 a 24

            // Título Premium - ¡MÁS GRANDE!
            FadeInDown(
              delay: const Duration(milliseconds: 200),
              child: Text(
                '¡NUEVA VERSIÓN!',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32, // De 26 a 32
                  fontWeight: FontWeight.w900,
                  color: NeumorphismTheme.textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Descripción - ¡MÁS GRANDE!
            FadeInDown(
              delay: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Hemos pulido cada detalle para que tu experiencia musical sea perfecta. ¿Quieres ver lo nuevo?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    height: 1.6,
                    fontSize: 17, // De 14 a 17
                    color: NeumorphismTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48), // Más espacio antes de botones

            // Botón de Actualizar (Oro) - ¡MÁS GRANDE!
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _launchUpdateUrl();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldColor,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 64), // De 72 a 64 (más balanceado)
                  elevation: 12,
                  shadowColor: goldColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // De 24 a 20
                  ),
                ),
                child: const Text(
                  'ACTUALIZAR AHORA',
                  style: TextStyle(
                    fontSize: 17, // De 18 a 17
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16), // De 24 a 16

            // Botón "Quizás más tarde"
            FadeInUp(
              delay: const Duration(milliseconds: 800),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: NeumorphismTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'QUIZÁS MÁS TARDE',
                  style: TextStyle(
                    fontSize: 14, // De 13 a 14
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
