import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';

class ComposerPromoScreen extends ConsumerWidget {
  const ComposerPromoScreen({super.key});

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
                // Header with Back Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: NeumorphismTheme.coffeeDark),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        
                        // Logo
                        Hero(
                          tag: 'app_logo_hero',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                             
                            ),
                             child: Image.asset(
                              'assets/images/logo.webp',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // Title
                        Text(
                          'Dale vida a tus letras',
                          style: AppTextStyles.titleLarge.copyWith( // Replaced headlineMedium
                            color: NeumorphismTheme.coffeeDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Body Text
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
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
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Implement external link or application form
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Contactando... (Integración pendiente)')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NeumorphismTheme.coffeeMedium,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Quiero producir y publicar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Legal Note
                        Text(
                          'Aplican términos y condiciones.',
                          style: AppTextStyles.overline.copyWith( // Replaced labelSmall
                            color: NeumorphismTheme.textSecondary,
                            fontSize: 12,
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
