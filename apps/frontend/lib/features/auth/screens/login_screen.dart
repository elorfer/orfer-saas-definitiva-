import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
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
  double _keyboardHeight = 0.0;

  @override
  void initState() {
    super.initState();
    // OPTIMIZACIÓN: Precargar imagen del logo para evitar lag al mostrarla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/images/Logo principal.webp'),
        context,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // OPTIMIZACIÓN: Escuchar cambios en el teclado usando addPostFrameCallback
    // para evitar rebuilds durante el frame actual
    final mediaQuery = MediaQuery.of(context);
    final newKeyboardHeight = mediaQuery.viewInsets.bottom;
    
    // Solo actualizar si realmente cambió (evitar rebuilds innecesarios)
    if ((_keyboardHeight - newKeyboardHeight).abs() > 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        setState(() {
          _keyboardHeight = newKeyboardHeight;
        });
        
        // Scroll automático solo cuando aparece el teclado (no cuando se oculta)
        if (newKeyboardHeight > 0 && _scrollController.hasClients) {
          // Usar un delay mínimo para que el layout se estabilice primero
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent * 0.3,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Método auxiliar para construir la sección del logo
  // OPTIMIZACIÓN: Método separado para evitar rebuilds cuando el teclado aparece
  Widget _buildLogoSection(double logoSize, double logoIconSize, bool isSmallScreen, bool isMediumScreen) {
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000), // Colors.black.withValues(alpha: 0.4) precalculado
                blurRadius: 15,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            child: Image.asset(
              'assets/images/Logo principal.webp',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              cacheWidth: logoSize.toInt(),
              cacheHeight: logoSize.toInt(),
              errorBuilder: (context, error, stackTrace) {
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
          'Struky',
          style: AppTextStyles.authTitle.copyWith(
            fontSize: isSmallScreen ? 36 : (isMediumScreen ? 42 : 48),
            fontWeight: FontWeight.w900,
            color: NeumorphismTheme.accentLight,
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 10),
        Text(
          'Inicia sesión en tu cuenta',
          style: AppTextStyles.authSubtitle.copyWith(
            color: const Color(0xE6FFFFFF), // Colors.white.withValues(alpha: 0.9) precalculado
            fontSize: isSmallScreen ? 15 : (isMediumScreen ? 16 : 17),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Método auxiliar para construir el contenido del formulario
  Widget _buildFormContent(bool isLoading, dynamic authNotifier, bool isSmallScreen, bool isMediumScreen) {
    return Column(
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
            if (value.contains('@')) {
              return AuthValidators.email(value);
            }
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
        // Recordar y olvidar contraseña
        LayoutBuilder(
          builder: (context, constraints) {
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
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
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
        // Divider - OPTIMIZACIÓN: Usar const donde sea posible
        Row(
          children: [
            const Expanded(
              child: Divider(
                color: Color(0xFFE0E0E0), // Colors.grey[300] precalculado
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
            const Expanded(
              child: Divider(
                color: Color(0xFFE0E0E0), // Colors.grey[300] precalculado
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 20 : 24),
        // Botones de autenticación social
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
        // Botón de Acceso Rápido (Solo Debug)
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () {
                  _emailController.text = 'domi@gmail.com';
                  _passwordController.text = 'domi321321';
                },
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text('⚡ DEV QUICK ACCESS'),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMIZACIÓN: Cachear MediaQuery para evitar múltiples llamadas
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;
    
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

    // Padding responsive
    final horizontalPadding = isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final formPadding = isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final topSpacing = isSmallScreen ? 10.0 : (isMediumScreen ? 16.0 : 20.0);
    // Logo con tamaño aumentado y prominente
    final logoSize = isSmallScreen ? 150.0 : (isMediumScreen ? 180.0 : 200.0);
    final logoIconSize = isSmallScreen ? 75.0 : (isMediumScreen ? 90.0 : 100.0);

    return Scaffold(
      // OPTIMIZACIÓN: resizeToAvoidBottomInset: false evita que el Scaffold redimensione el body
      // Esto previene rebuilds masivos cuando aparece el teclado
      // El padding del SingleChildScrollView maneja el espacio del teclado
      resizeToAvoidBottomInset: false,
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
            // OPTIMIZACIÓN: Agregar padding inferior cuando el teclado está visible
            // Usar _keyboardHeight en lugar de mediaQuery.viewInsets para evitar rebuilds
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: 16.0,
              bottom: _keyboardHeight > 0 ? _keyboardHeight + 16.0 : 16.0,
            ),
            clipBehavior: Clip.none,
            // OPTIMIZACIÓN: Mejorar comportamiento del scroll con el teclado
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500, // Limitar ancho máximo para tablets
                  // OPTIMIZACIÓN: No usar minHeight cuando el teclado está visible para mejor rendimiento
                  minHeight: _keyboardHeight > 0 
                      ? 0 
                      : (mediaQuery.size.height - 
                         mediaQuery.padding.top - 
                         mediaQuery.padding.bottom - 32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  SizedBox(height: topSpacing),
                  
                  // Logo y título - OPTIMIZACIÓN: RepaintBoundary para aislar repaints
                  // El logo no cambia cuando aparece el teclado, así que no necesita rebuilds
                  RepaintBoundary(
                    child: _buildLogoSection(logoSize, logoIconSize, isSmallScreen, isMediumScreen),
                  ),

                  SizedBox(height: isSmallScreen ? 20 : 28),

                  // Formulario de login
                  // OPTIMIZACIÓN: RepaintBoundary para aislar repaints del formulario
                  // OPTIMIZACIÓN: Deshabilitar animación cuando el teclado está visible para mejor rendimiento
                  RepaintBoundary(
                    child: Container(
                      padding: EdgeInsets.all(formPadding),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000), // Colors.black.withValues(alpha: 0.1) precalculado
                            blurRadius: 10,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: _buildFormContent(
                          isLoading,
                          authNotifier,
                          isSmallScreen,
                          isMediumScreen,
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
