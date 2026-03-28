import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/neumorphism_theme.dart';
import '../../core/providers/theme_provider.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 Refresh UI on Theme Change
    ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      appBar: AppBar(
        title: Text(
          'Política de Privacidad',
          style: TextStyle(
            color: NeumorphismTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: NeumorphismTheme.background,
        elevation: 0,
        systemOverlayStyle: NeumorphismTheme.isDark 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: NeumorphismTheme.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con Icono
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.privacy_tip_rounded,
                      color: NeumorphismTheme.coffeeMedium,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Privacidad en Struky',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            _buildSection(
              'Nuestro Compromiso',
              'En Struky, la privacidad de nuestros usuarios y compositores es fundamental. Nos comprometemos a proteger tu información personal y a ser transparentes sobre cómo la utilizamos.',
            ),
            
            const SizedBox(height: 32),
            
            _buildSection(
              'Recopilación de Datos',
              'Solo recopilamos los datos estrictamente necesarios para ofrecerte la mejor experiencia musical: tus preferencias de escucha, colecciones guardadas y datos de perfil básico para sincronización entre dispositivos.',
            ),

            const SizedBox(height: 32),

            _buildSection(
              'Seguridad',
              'Implementamos medidas de seguridad avanzadas para proteger tus datos contra accesos no autorizados. Tu confianza es nuestro activo más valioso.',
            ),

            const SizedBox(height: 40),

            // Footer / Contacto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: NeumorphismTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '¿Tienes dudas?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Puedes consultar la política completa en nuestro sitio web o escribirnos si tienes cualquier pregunta sobre tus datos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NeumorphismTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            // Espacio final
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: NeumorphismTheme.coffeeMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 15,
            color: NeumorphismTheme.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
