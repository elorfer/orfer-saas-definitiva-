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
  final _scrollController = ScrollController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMIZACIÓN: usar select para escuchar solo isLoading y evitar rebuilds innecesarios
    final isLoading = ref.watch(authStateProvider.select((state) => state.isLoading));
    final authNotifier = ref.read(authStateProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;

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

    // Padding responsive
    final horizontalPadding = isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final formPadding = isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final topSpacing = isSmallScreen ? 10.0 : (isMediumScreen ? 16.0 : 20.0);
    // Logo con tamaño aumentado y prominente
    final logoSize = isSmallScreen ? 150.0 : (isMediumScreen ? 180.0 : 200.0);
    final logoIconSize = isSmallScreen ? 75.0 : (isMediumScreen ? 90.0 : 100.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF3E2723), // Marrón oscuro
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16.0),
            clipBehavior: Clip.none,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500, // Limitar ancho máximo para tablets
                  minHeight: (MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom - 32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  SizedBox(height: topSpacing),
                  
                  // Logo y título - Tamaño considerado y prominente
                  FadeInDown(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      children: [
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: const BorderRadius.all(Radius.circular(24)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(24)),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback a icono si la imagen no se carga
                                return Icon(
                                  Icons.music_note,
                                  size: logoIconSize,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Text(
                          'struky',
                          style: AppTextStyles.authTitle.copyWith(
                            fontSize: isSmallScreen ? 28 : (isMediumScreen ? 32 : 36),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 10),
                        Text(
                          'Inicia sesión en tu cuenta',
                          style: AppTextStyles.authSubtitle.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: isSmallScreen ? 15 : (isMediumScreen ? 16 : 17),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 20 : 28),

                  // Formulario de login
                  FadeInUp(
                    duration: const Duration(milliseconds: 350),
                    child: Container(
                      padding: EdgeInsets.all(formPadding),
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Campo de email o username
                            AuthTextField(
                              controller: _emailController,
                              label: 'Correo electrónico o nombre de usuario',
                              hint: 'tu@email.com o @tu_usuario',
                              keyboardType: TextInputType.text,
                              prefixIcon: Icons.email_outlined,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu correo o nombre de usuario';
                                }
                                // Si contiene @, validar como email
                                if (value.contains('@')) {
                                  return AuthValidators.email(value);
                                }
                                // Si no contiene @, validar como username básico
                                if (value.length < 3) {
                                  return 'El nombre de usuario debe tener al menos 3 caracteres';
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: isSmallScreen ? 16 : 20),

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

                            SizedBox(height: isSmallScreen ? 12 : 16),

                            // Recordar y olvidar contraseña - RESPONSIVE
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // Si el ancho disponible es menor a 300, usar columna
                                if (constraints.maxWidth < 300 || isSmallScreen) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            'Recordarme',
                                            style: AppTextStyles.authText.copyWith(
                                              fontSize: isSmallScreen ? 13 : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                          onPressed: () {
                                            context.push('/forgot-password');
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            '¿Olvidaste tu contraseña?',
                                            style: AppTextStyles.authTextSecondary.copyWith(
                                              fontSize: isSmallScreen ? 12 : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                // Para pantallas más grandes, usar Row
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        // ✅ CORRECCIÓN: No usar mainAxisSize.min cuando hay Flexible
                                        children: [
                                          Checkbox(
                                            value: _rememberMe,
                                            onChanged: (value) {
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                            },
                                            activeColor: NeumorphismTheme.coffeeMedium,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Flexible(
                                            child: Text(
                                              'Recordarme',
                                              style: AppTextStyles.authText,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Flexible(
                                      child: TextButton(
                                        onPressed: () {
                                          context.push('/forgot-password');
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          '¿Olvidaste tu contraseña?',
                                          style: AppTextStyles.authTextSecondary.copyWith(
                                            fontSize: isSmallScreen ? 11 : null,
                                          ),
                                          textAlign: TextAlign.end,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            SizedBox(height: isSmallScreen ? 20 : 24),

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

                            SizedBox(height: isSmallScreen ? 20 : 24),

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
                                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16),
                                  child: Text(
                                    'O continúa con',
                                    style: AppTextStyles.authText.copyWith(
                                      fontSize: isSmallScreen ? 12 : null,
                                    ),
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

                            SizedBox(height: isSmallScreen ? 20 : 24),

                            // Botones de autenticación social - RESPONSIVE
                            isSmallScreen
                                ? Column(
                                    children: [
                                      SocialAuthButton(
                                        icon: Icons.g_mobiledata,
                                        text: 'Google',
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Login con Google próximamente'),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      SocialAuthButton(
                                        icon: Icons.apple,
                                        text: 'Apple',
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Login con Apple próximamente'),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Flexible(
                                        flex: 1,
                                        child: SocialAuthButton(
                                          icon: Icons.g_mobiledata,
                                          text: 'Google',
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Login con Google próximamente'),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        flex: 1,
                                        child: SocialAuthButton(
                                          icon: Icons.apple,
                                          text: 'Apple',
                                          onPressed: () {
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

                            SizedBox(height: isSmallScreen ? 24 : 32),

                            // Enlace a registro
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    '¿No tienes cuenta? ',
                                    style: AppTextStyles.authText.copyWith(
                                      fontSize: isSmallScreen ? 13 : null,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    context.push('/register');
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Regístrate',
                                    style: AppTextStyles.authLink.copyWith(
                                      fontSize: isSmallScreen ? 13 : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 16 : 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
