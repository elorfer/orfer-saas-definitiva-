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
import '../widgets/landing_info_section.dart';
import '../utils/validators.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/exceptions/auth_exception.dart';

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
    // SVG se carga eficientemente, precache eliminado para la versión vectorial
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
        ClipRRect(
          borderRadius: BorderRadius.circular(24.0), // Bordes redondeados
          child: Image.asset(
            'assets/images/Logo principal.webp',
            width: logoSize * 0.7, // Reducido significativamente
            height: logoSize * 0.7,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: logoSize * 0.7,
              height: logoSize * 0.7,
              color: Colors.white24,
              child: const Icon(Icons.music_note, size: 40, color: Colors.white),
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        Text(
          'Struky',
          style: AppTextStyles.authTitle.copyWith(
            fontSize: isSmallScreen ? 36 : (isMediumScreen ? 42 : 48),
            fontWeight: FontWeight.w900,
            color: const Color(0xFFD7CCC8), // NeumorphismTheme.accentLight (Light Mode)
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
          focusedBorderColor: const Color(0xFF8D6E63), // NeumorphismTheme.coffeeMedium (Light Mode)
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
          focusedBorderColor: const Color(0xFF8D6E63), // NeumorphismTheme.coffeeMedium (Light Mode)
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
                        activeColor: const Color(0xFF8D6E63), // NeumorphismTheme.coffeeMedium (Light Mode)
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
                        activeColor: const Color(0xFF8D6E63), // NeumorphismTheme.coffeeMedium (Light Mode)
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
          backgroundColor: const Color(0xFF8D6E63), // NeumorphismTheme.coffeeMedium (Light Mode)
          text: 'Iniciar Sesión',
          isLoading: isLoading,
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                await authNotifier.login(
                  email: _emailController.text.trim(),
                  password: _passwordController.text,
                );
              } catch (e) {
                // 📧 Si el usuario no verificó su email, redirigir a la pantalla OTP
                if (e is AuthException && e.code == 'EMAIL_NOT_VERIFIED') {
                  final emailToVerify = e.email ?? _emailController.text.trim();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('📧 Te enviamos un nuevo código de verificación. Revisa tu correo.'),
                        backgroundColor: const Color(0xFF8D6E63),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    context.push('/verify-code/${Uri.encodeComponent(emailToVerify)}');
                  }
                  return;
                }
                // Para otros errores, dejar que el listener del provider lo muestre
                rethrow;
              }
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
                    onPressed: isLoading ? null : () async {
                      await authNotifier.signInWithGoogle();
                    },
                  ),
                  const SizedBox(height: 12),
                  SocialAuthButton(
                    icon: Icons.facebook,
                    text: 'Facebook',
                    onPressed: isLoading ? null : () async {
                      await authNotifier.signInWithFacebook();
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
                      onPressed: isLoading ? null : () async {
                        await authNotifier.signInWithGoogle();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 1,
                    child: SocialAuthButton(
                      icon: Icons.facebook,
                      text: 'Facebook',
                      onPressed: isLoading ? null : () async {
                        await authNotifier.signInWithFacebook();
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
                  color: const Color(0xFF8D6E63), // NeumorphismTheme.coffeeMedium (Light Mode)
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
                  _emailController.text = 'damian23@gmail.com';
                  _passwordController.text = 'damian233';
                },
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text('⚡ USER QUICK ACCESS'),
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
    final isMaxSmallScreen = screenWidth < 450;
    
    // Detectar si debemos usar el layout Web (Split Screen)
    // Usamos kIsWeb y un ancho mínimo para tablet/desktop
    final useWebLayout = kIsWeb && screenWidth > 900;

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
    
    if (useWebLayout) {
      return _buildWebLayout(context, isLoading, authNotifier);
    }

    // MOBILE LAYOUT (Original)
    return _buildMobileLayout(context, mediaQuery, screenWidth, isMaxSmallScreen, isLoading, authNotifier);
  }

  // ===========================================================================
  // 📱 MOBILE LAYOUT (Preserved Exactly)
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context, 
    MediaQueryData mediaQuery, 
    double screenWidth, 
    bool isSmallScreen, // Now checking < 450 roughly
    bool isLoading,
    dynamic authNotifier,
  ) {
    final isThinkingSmall = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;
    
    // Padding responsive
    final horizontalPadding = isThinkingSmall ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final formPadding = isThinkingSmall ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final topSpacing = isThinkingSmall ? 10.0 : (isMediumScreen ? 16.0 : 20.0);
    // Logo con tamaño aumentado y prominente
    final logoSize = isThinkingSmall ? 150.0 : (isMediumScreen ? 180.0 : 200.0);
    final logoIconSize = isThinkingSmall ? 75.0 : (isMediumScreen ? 90.0 : 100.0);

    return Scaffold(
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
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: 16.0,
              bottom: _keyboardHeight > 0 ? _keyboardHeight + 16.0 : 16.0,
            ),
            clipBehavior: Clip.none,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500, // Limitar ancho máximo para tablets en modo vertical
                  minHeight: _keyboardHeight > 0 
                      ? 0 
                      : (mediaQuery.size.height - 
                         mediaQuery.padding.top - 
                         mediaQuery.padding.bottom - 32).clamp(0.0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  SizedBox(height: topSpacing),
                  
                  RepaintBoundary(
                    child: _buildLogoSection(logoSize, logoIconSize, isThinkingSmall, isMediumScreen),
                  ),

                  SizedBox(height: isThinkingSmall ? 20 : 28),

                  RepaintBoundary(
                    child: Container(
                      padding: EdgeInsets.all(formPadding),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000),
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
                          isThinkingSmall,
                          isMediumScreen,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isThinkingSmall ? 16 : 24),

                  // Info Section (Only visible on Web - Android stays untouched)
                  if (kIsWeb) ...[
                    const SizedBox(height: 40),
                    const LandingInfoSection(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 💻 WEB LAYOUT (Split Screen)
  // ===========================================================================
  Widget _buildWebLayout(BuildContext context, bool isLoading, dynamic authNotifier) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HERO SECTION (Full Screen Split)
            SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Row(
                children: [
                  // LEFT PANEL: BRANDING & HERO (50%)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            NeumorphismTheme.accent.withOpacity(0.9), // Color principal
                            const Color(0xFF1E1B19), // Darker tone
                          ],
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Decorative Abstract Circle (Top Left)
                          Positioned(
                            left: -100,
                            top: -100,
                            child: Container(
                              width: 500,
                              height: 500,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          // Decorative Abstract Circle (Bottom Right)
                          Positioned(
                            right: -150,
                            bottom: -150,
                            child: Container(
                              width: 600,
                              height: 600,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.03),
                              ),
                            ),
                          ),
                          
                          // Content
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Glassy Logo Container
                                Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(40),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 30,
                                        offset: const Offset(0, 15),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24.0),
                                    child: Image.asset(
                                      'assets/images/Logo principal.webp',
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                Text(
                                  'Struky',
                                  style: AppTextStyles.displayLarge.copyWith(
                                    color: Colors.white,
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Música que conecta.',
                                  style: AppTextStyles.headlineMedium.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                          ),


                  // Animated Scroll Indicator (Professional Flutter Animate)
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: RepaintBoundary( // <--- OPTIMIZATION: Isolates painting
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DESCUBRE MÁS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 4,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4, // <--- OPTIMIZATION: Reduced from 10
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 36,
                            shadows: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4, // <--- OPTIMIZATION: Reduced from 10
                                  offset: const Offset(0, 2),
                                ),
                              ],
                          ),
                        ],
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                      .moveY(begin: -10, end: 5, duration: 1200.ms, curve: Curves.easeInOut)
                      .then(delay: 600.ms) 
                      .fadeOut(duration: 600.ms, curve: Curves.easeIn),
                    ),
                  ),
                      ],
                      ),
                    ),
                  ),

                  // RIGHT PANEL: FORM (50%)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(60),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Bienvenido de nuevo',
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.start,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ingresa tus credenciales para continuar.',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.start,
                              ),
                              const SizedBox(height: 40),
                              
                              Form(
                                key: _formKey,
                                child: _buildFormContent(
                                  isLoading,
                                  authNotifier,
                                  false, 
                                  false, 
                                ),
                              ),
                              
                              const SizedBox(height: 40),
                              Center(
                                child: Text(
                                  '© 2024 Struky Music. Todos los derechos reservados.',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // LANDING PAGE CONTENT (Below Fold)
            const LandingInfoSection(),
          ],
        ),
      ),
    );
  }
}
