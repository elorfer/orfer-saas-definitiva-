import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import 'package:animate_do/animate_do.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../utils/validators.dart';
import '../../../core/providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authNotifier = ref.read(authStateProvider.notifier);
        final result = await authNotifier.forgotPassword(_emailController.text.trim());
        
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });

        // En modo desarrollo, si hay token, mostrar opción para ir a reset-password
        if (result.containsKey('token') && result['token'] != null) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Token de recuperación (Solo desarrollo)'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('En producción, este token se enviaría por email.'),
                      const SizedBox(height: 12),
                      SelectableText(
                        result['token'] as String,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/reset-password/${result['token']}');
                        },
                        child: const Text('Ir a restablecer contraseña'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            });
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF3E2723), // Marrón oscuro
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Botón de regreso
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/login'),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF3E2723),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Título
                FadeInDown(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      Text(
                        'Recuperar Contraseña',
                        style: AppTextStyles.authFormTitle.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ingresa tu email y te enviaremos un enlace para restablecer tu contraseña',
                        style: AppTextStyles.authSubtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Formulario
                FadeInUp(
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _emailSent
                        ? Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Email enviado',
                                style: AppTextStyles.authFormTitle.copyWith(
                                  color: NeumorphismTheme.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Si el email existe en nuestro sistema, recibirás un enlace para restablecer tu contraseña.',
                                style: AppTextStyles.authText,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              AuthButton(
                                text: 'Volver al inicio de sesión',
                                isLoading: false,
                                onPressed: () => context.go('/login'),
                              ),
                            ],
                          )
                        : Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AuthTextField(
                                  controller: _emailController,
                                  label: 'Correo electrónico',
                                  hint: 'tu@email.com',
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  validator: AuthValidators.email,
                                ),
                                const SizedBox(height: 24),
                                AuthButton(
                                  text: 'Enviar enlace de recuperación',
                                  isLoading: _isLoading,
                                  onPressed: _handleForgotPassword,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

