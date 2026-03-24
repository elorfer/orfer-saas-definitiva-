import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Fondo con degradado elegante
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A1A),
                  Color(0xFF0A0A0A),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),
          
          // Elementos decorativos vintage (Círculos difuminados)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono / Ilustración Premium
                  FadeInDown(
                    duration: const Duration(seconds: 1),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        size: 80,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Título
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      isMandatory ? 'ACTUALIZACIÓN\nOBLIGATORIA' : 'NUEVA VERSIÓN\nDISPONIBLE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Descripción
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: Text(
                      isMandatory 
                        ? 'Para seguir disfrutando de la mejor música y las nuevas funciones de Struky, es necesario que actualices la aplicación a la última versión.'
                        : 'Hemos lanzado una nueva versión con mejoras de rendimiento y nuevas funciones que te encantarán.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Botón Principal (Actualizar)
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    child: ElevatedButton(
                      onPressed: _launchUpdateUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectanglePlatform.borderRadius12,
                        elevation: 10,
                        shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                      ),
                      child: const Text(
                        'ACTUALIZAR AHORA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  if (!isMandatory) ...[
                    const SizedBox(height: 20),
                    // Botón Secundario (Más tarde)
                    FadeInUp(
                      delay: const Duration(milliseconds: 900),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                        ),
                        child: const Text(
                          'MÁS TARDE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Versión actual en pequeño al fondo
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: FadeIn(
              delay: const Duration(seconds: 1),
              child: const Text(
                'Struky v1.1.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper para bordes si no existe
class RoundedRectanglePlatform {
  static final borderRadius12 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
}
