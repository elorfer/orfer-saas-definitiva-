import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';

class ComposerPromoScreen extends ConsumerWidget {
  const ComposerPromoScreen({super.key});

  Future<void> _launchWhatsApp(BuildContext context) async {
    final String phoneNumber = "573009012217";
    final String message = Uri.encodeComponent("Me gustaría publicar mi música con ustedes");
    final Uri url = Uri.parse("https://wa.me/$phoneNumber?text=$message");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      body: Stack(
        children: [
          // Background Gradient (Same as Home for consistency)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: NeumorphismTheme.backgroundGradient,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header with Back Button and Aligned Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: NeumorphismTheme.textPrimary),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      Text(
                        'Dale vida a tus letras',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: NeumorphismTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balancing back button
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      left: 24, 
                      right: 24, 
                      top: 24, 
                      bottom: 100, // Espacio extra para que el mini-reproductor no tape nada
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        
                        // New Image
                        Hero(
                          tag: 'app_logo_hero',
                          child: FractionallySizedBox(
                            widthFactor: 0.9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/BOTIFY-MUSIC-_2_-_1_.webp',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // Body Text
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: NeumorphismTheme.cardDecoration,
                          child: Text(
                            'Sabemos que tienes grandes canciones esperando ser escuchadas.\n\nJunto a nuestros aliados expertos, no solo convertimos tus letras en producciones profesionales, sino que te damos la oportunidad directa de publicarlas en Struky App.',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: NeumorphismTheme.textPrimary,
                              height: 1.6,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // CTA Button
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () => _launchWhatsApp(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NeumorphismTheme.accent,
                              foregroundColor: NeumorphismTheme.isDark 
                                  ? const Color(0xFF2D2420) 
                                  : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Quiero producir y publicar',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Legal Note
                        Text(
                          'Aplican términos y condiciones.',
                          style: AppTextStyles.overline.copyWith(
                            color: NeumorphismTheme.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
