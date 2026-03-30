import 'package:flutter/material.dart';
import '../../../core/theme/neumorphism_theme.dart';
import 'package:go_router/go_router.dart';

class PremiumUpsellDialog extends StatelessWidget {
  const PremiumUpsellDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NeumorphismTheme.surface, // White surface
          borderRadius: BorderRadius.circular(24),
          // boxShadow removed
          // border removed
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono Estrella
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NeumorphismTheme.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: NeumorphismTheme.accent,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            
            // Título
            Text(
              'Desbloquea el Modo Offline',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Descripción
            Text(
              'Escucha tu música favorita sin conexión a internet. Descárgala y llévala contigo a todas partes.',
              style: TextStyle(
                 fontSize: 14,
                 color: NeumorphismTheme.textSecondary,
                 height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Features List
            _buildFeatureRow(Icons.file_download_off_outlined, 'Descargas ilimitadas'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.high_quality, 'Audio de Alta Calidad'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.check_circle_outline_rounded, 'Sin anuncios'),
            
            const SizedBox(height: 32),
            
            // Botón CTA
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  // Cerrar el diálogo primero
                  Navigator.of(context).pop();
                  // Navegar a la pantalla de Premium
                  // Asegurar import de go_router
                  context.go('/premium?showPackages=true'); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NeumorphismTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: const Text(
                  'Obtener Premium',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
             TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Ahora no',
                style: TextStyle(
                  color: NeumorphismTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: NeumorphismTheme.accent, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: NeumorphismTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

