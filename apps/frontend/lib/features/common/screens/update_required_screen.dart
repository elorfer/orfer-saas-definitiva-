import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final bool isMandatory;
  final String? updateUrl;

  const UpdateRequiredScreen({
    super.key,
    this.isMandatory = true,
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
    return Scaffold(
      body: Stack(
        children: [
          // 🎨 Fondo con el gradiente oficial de la App
          Container(
            decoration: BoxDecoration(
              gradient: NeumorphismTheme.backgroundGradient,
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                  
                          // 🖼️ Ilustración Hero (Más ligera)
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: NeumorphismTheme.accent.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1000),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: NeumorphismTheme.accent.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 140, 
                                  backgroundColor: NeumorphismTheme.surface,
                                  backgroundImage: const AssetImage('assets/images/VIAJEVEJITO.webp'),
                                ),
                              ),
                            ),
                          ),
                  
                          const SizedBox(height: 60),

                          // 📜 Título Vintage
                          Text(
                            isMandatory ? 'CÁPSULA DEL TIEMPO\nACTUALIZADA' : 'NUEVA SINTONÍA\nDISPONIBLE',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: NeumorphismTheme.textPrimary,
                              letterSpacing: 1.5,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 🖋️ Descripción Elegante
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              isMandatory 
                                ? 'Para seguir el viaje por los clásicos y nuevas joyas musicales en Struky, es necesario sintonizar la última versión.'
                                : 'Hemos refinado la experiencia con mejoras que harán cada nota sonar más pura.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: NeumorphismTheme.textSecondary,
                                fontSize: 18,
                                height: 1.7,
                              ),
                            ),
                          ),

                          const SizedBox(height: 60), // Más espacio antes de botones

                          // ☕ Botón Premium Neumórfico
                          Container(
                            width: double.infinity,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: NeumorphismTheme.accent.withValues(alpha: 0.2),
                                  offset: const Offset(0, 4),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _launchUpdateUrl,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NeumorphismTheme.accent,
                                foregroundColor: Colors.black87,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                'SINTONIZAR AHORA',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          if (!isMandatory) ...[
                            // Botón Secundario
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'MÁS TARDE',
                                style: GoogleFonts.inter(
                                  color: NeumorphismTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),
                  
                          // Versión actual
                          Text(
                            'Struky v1.1.0 • Edición Coleccionista',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: NeumorphismTheme.textLight.withValues(alpha: 0.5),
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                  
                          // Espacio masivo para evitar que el Mini Reproductor tape nada
                          const SizedBox(height: 180),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
