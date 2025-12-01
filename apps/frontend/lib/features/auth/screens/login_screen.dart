import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../widgets/social_auth_button.dart';
import '../utils/validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMIZACIÓN: usar select para escuchar solo isLoading y evitar rebuilds innecesarios
    final isLoading = ref.watch(authStateProvider.select((state) => state.isLoading));
    final authNotifier = ref.read(authStateProvider.notifier);

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      final previousError = previous?.error;
      final nextError = next.error;

      if (nextError != null && nextError != previousError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Logo y título
                FadeInDown(
                  duration: const Duration(milliseconds: 300), // Optimizado: reducido de 600ms a 300ms
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Vintage Music',
                        style: AppTextStyles.authTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión en tu cuenta',
                        style: AppTextStyles.authSubtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Formulario de login
                FadeInUp(
                  duration: const Duration(milliseconds: 350), // Optimizado: reducido de 800ms a 350ms
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Campo de email
                          AuthTextField(
                            controller: _emailController,
                            label: 'Correo electrónico',
                            hint: 'tu@email.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: AuthValidators.email,
                          ),

                          const SizedBox(height: 20),

                          // Campo de contraseña
                          AuthTextField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            hint: 'Tu contraseña',
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: AuthValidators.password,
                          ),

                          const SizedBox(height: 16),

                          // Recordar y olvidar contraseña
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                    activeColor: NeumorphismTheme.coffeeMedium,
                                  ),
                                  Text(
                                    'Recordarme',
                                    style: AppTextStyles.authText,
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  // TODO: Implementar recuperación de contraseña
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Función próximamente disponible'),
                                    ),
                                  );
                                },
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: AppTextStyles.authTextSecondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Botón de login
                          AuthButton(
                            text: 'Iniciar Sesión',
                            isLoading: isLoading,
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await authNotifier.login(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text,
                                );
                              }
                            },
                          ),

                          const SizedBox(height: 24),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[300],
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'O continúa con',
                                  style: AppTextStyles.authText,
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[300],
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Botones de autenticación social
                          Row(
                            children: [
                              Expanded(
                                child: SocialAuthButton(
                                  icon: Icons.g_mobiledata,
                                  text: 'Google',
                                  onPressed: () {
                                    // TODO: Implementar login con Google
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Login con Google próximamente'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SocialAuthButton(
                                  icon: Icons.apple,
                                  text: 'Apple',
                                  onPressed: () {
                                    // TODO: Implementar login con Apple
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Login con Apple próximamente'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Enlace a registro
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '¿No tienes cuenta? ',
                                style: AppTextStyles.authText,
                              ),
                              TextButton(
                                onPressed: () {
                                  context.push('/register');
                                },
                                child: Text(
                                  'Regístrate',
                                  style: AppTextStyles.authLink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
