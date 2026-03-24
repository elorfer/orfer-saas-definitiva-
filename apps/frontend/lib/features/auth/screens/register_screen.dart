import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter_svg/flutter_svg.dart'; // Para Logo
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../widgets/social_auth_button.dart';
import '../utils/validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  final bool _registrationSuccess = false;
  
  // Estados para validaciÃ³n en tiempo real
  bool? _usernameAvailable;
  bool? _emailAvailable;
  Timer? _usernameCheckTimer;
  Timer? _emailCheckTimer;
  bool _isCheckingUsername = false;
  bool _isCheckingEmail = false;

  @override
  void dispose() {
    _usernameCheckTimer?.cancel();
    _emailCheckTimer?.cancel();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  // Verificar disponibilidad de username con debounce
  void _checkUsernameAvailability(String username) {
    _usernameCheckTimer?.cancel();
    
    // Limpiar estado si el campo estÃ¡ vacÃ­o
    if (username.isEmpty) {
      setState(() {
        _usernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }
    
    // Verificar desde la primera letra, pero solo si tiene al menos 1 carÃ¡cter
    // Validar formato bÃ¡sico (solo letras, nÃºmeros y guiones bajos)
    if (!RegExp(r'^[a-zA-Z0-9_]*$').hasMatch(username)) {
      // Si tiene caracteres invÃ¡lidos, no verificar disponibilidad
      setState(() {
        _usernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }
    
    // Si tiene al menos 1 carÃ¡cter vÃ¡lido, verificar disponibilidad
    setState(() {
      _isCheckingUsername = true;
      _usernameAvailable = null; // Limpiar resultado anterior mientras verifica
    });
    
    _usernameCheckTimer = Timer(const Duration(milliseconds: 800), () async {
      // Verificar que el valor no haya cambiado mientras esperÃ¡bamos
      if (_usernameController.text != username) {
        return; // El usuario siguiÃ³ escribiendo, cancelar esta verificaciÃ³n
      }
      
      final authNotifier = ref.read(authStateProvider.notifier);
      try {
        final available = await authNotifier.checkUsernameAvailability(username);
        if (mounted && _usernameController.text == username) {
          setState(() {
            _usernameAvailable = available;
            _isCheckingUsername = false;
          });
          // Forzar validaciÃ³n del campo
          _formKey.currentState?.validate();
        }
      } catch (e) {
        if (mounted && _usernameController.text == username) {
          setState(() {
            _usernameAvailable = null;
            _isCheckingUsername = false;
          });
        }
      }
    });
  }

  // Verificar disponibilidad de email con debounce
  void _checkEmailAvailability(String email) {
    _emailCheckTimer?.cancel();
    
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _emailAvailable = null;
        _isCheckingEmail = false;
      });
      return;
    }
    
    setState(() {
      _isCheckingEmail = true;
    });
    
    _emailCheckTimer = Timer(const Duration(milliseconds: 800), () async {
      final authNotifier = ref.read(authStateProvider.notifier);
      try {
        final available = await authNotifier.checkEmailAvailability(email);
        if (mounted) {
          setState(() {
            _emailAvailable = available;
            _isCheckingEmail = false;
          });
          // Forzar validaciÃ³n del campo
          _formKey.currentState?.validate();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _emailAvailable = null;
            _isCheckingEmail = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMIZACIÃ“N: usar select para escuchar solo isLoading y evitar rebuilds innecesarios
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

    // Detectar si debemos usar el layout Web (Split Screen)
    final screenWidth = MediaQuery.of(context).size.width;
    final useWebLayout = kIsWeb && screenWidth > 900;

    if (useWebLayout) {
      return _buildWebLayout(context, isLoading, authNotifier);
    }

    return _buildMobileLayout(context, isLoading, authNotifier);
  }

  // ===========================================================================
  // ðŸ’» WEB LAYOUT (Split Screen)
  // ===========================================================================
  Widget _buildWebLayout(BuildContext context, bool isLoading, dynamic authNotifier) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
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
                    NeumorphismTheme.accent.withValues(alpha: 0.9), // Color principal
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
                        color: Colors.white.withValues(alpha: 0.05),
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
                        color: Colors.white.withValues(alpha: 0.03),
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
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: SvgPicture.asset(
                            'assets/images/logo.svg',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'Ãšnete a Struky',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Descubre, comparte y vive la mÃºsica.',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
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
                  constraints: const BoxConstraints(maxWidth: 550),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Crear Cuenta',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Completa el formulario para comenzar.',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildFormContent(isLoading, authNotifier),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          'Â© 2024 Struky Music. Todos los derechos reservados.',
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
    );
  }

  // ===========================================================================
  // ðŸ“± MOBILE LAYOUT (Preserved)
  // ===========================================================================
  Widget _buildMobileLayout(BuildContext context, bool isLoading, dynamic authNotifier) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF3E2723), // MarrÃ³n oscuro
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewInsets = MediaQuery.of(context).viewInsets;
              final keyboardHeight = viewInsets.bottom;
              
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 24.0,
                  bottom: keyboardHeight > 0 ? keyboardHeight + 24.0 : 24.0,
                ),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Header con botÃ³n de regreso
                    FadeInDown(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => context.go('/login'),
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2), // TraslÃºcido
                                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white, // Blanco para resaltar sobre cafÃ© 
                                    size: 20,
                                  ),
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crear Cuenta',
                            style: AppTextStyles.authFormTitle.copyWith(
                              color: Colors.white, // Blanco
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ãšnete a la comunidad musical',
                            style: AppTextStyles.authFormSubtitle.copyWith(
                              color: Colors.white70, // Blanco atenuado
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Formulario de registro
                    FadeInUp(
                      duration: const Duration(milliseconds: 350), 
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.all(Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _buildFormContent(isLoading, authNotifier),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ðŸ“ SHARED FORM CONTENT
  // ===========================================================================
  List<Widget> _buildFormContent(bool isLoading, dynamic authNotifier) {
    return [
      // Campos de nombre
      Row(
        children: [
          Expanded(
            child: AuthTextField(
              controller: _firstNameController,
              label: 'Nombre',
              hint: 'Tu nombre',
              prefixIcon: Icons.person_outline,
              validator: (value) => AuthValidators.name(value, fieldName: 'nombre'),
              onChanged: (value) {
                _formKey.currentState?.validate();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AuthTextField(
              controller: _lastNameController,
              label: 'Apellido',
              hint: 'Tu apellido',
              prefixIcon: Icons.person_outline,
              validator: (value) => AuthValidators.name(value, fieldName: 'apellido'),
              onChanged: (value) {
                _formKey.currentState?.validate();
              },
            ),
          ),
        ],
      ),

      const SizedBox(height: 20),

      // Campo de email
      AuthTextField(
        controller: _emailController,
        label: 'Correo electrÃ³nico',
        hint: 'tu@email.com',
        keyboardType: TextInputType.emailAddress,
        prefixIcon: Icons.email_outlined,
        suffixIcon: _isCheckingEmail
            ? SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      NeumorphismTheme.coffeeMedium,
                    ),
                  ),
                ),
              )
            : _emailAvailable == false
                ? const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  )
                : _emailAvailable == true
                    ? const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 20,
                      )
                    : null,
        validator: (value) {
          final emailError = AuthValidators.email(value);
          if (emailError != null) return emailError;
          if (_emailAvailable == false) {
            return 'Este email ya estÃ¡ registrado';
          }
          return null;
        },
        onChanged: (value) {
          _checkEmailAvailability(value);
        },
      ),

      const SizedBox(height: 20),

      // Campo de username
      AuthTextField(
        controller: _usernameController,
        label: 'Nombre de usuario',
        hint: '@tu_usuario',
        prefixIcon: Icons.alternate_email,
        suffixIcon: _isCheckingUsername
            ? SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      NeumorphismTheme.coffeeMedium,
                    ),
                  ),
                ),
              )
            : _usernameAvailable == false
                ? const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  )
                : _usernameAvailable == true
                    ? const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 20,
                      )
                    : null,
        validator: (value) {
          final basicValidation = AuthValidators.username(value);
          if (basicValidation != null) {
            return basicValidation;
          }
          if (value != null && _usernameAvailable != null && _usernameAvailable == false) {
            return 'Este nombre de usuario no estÃ¡ disponible';
          }
          return null;
        },
        onChanged: (value) {
          _checkUsernameAvailability(value);
          _formKey.currentState?.validate();
        },
      ),

      const SizedBox(height: 20),

      // Campo de contraseÃ±a
      AuthTextField(
        controller: _passwordController,
        label: 'ContraseÃ±a',
        hint: 'MÃ­nimo 6 caracteres',
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
        onChanged: (value) {
          _formKey.currentState?.validate();
        },
      ),

      const SizedBox(height: 20),

      // Campo de confirmar contraseÃ±a
      AuthTextField(
        controller: _confirmPasswordController,
        label: 'Confirmar contraseÃ±a',
        hint: 'Repite tu contraseÃ±a',
        obscureText: _obscureConfirmPassword,
        prefixIcon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey[600],
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        validator: (value) => AuthValidators.confirmPassword(value, _passwordController.text),
        onChanged: (value) {
          _formKey.currentState?.validate();
        },
      ),

      const SizedBox(height: 20),

      // Checkbox de tÃ©rminos y condiciones
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() {
                _acceptTerms = value ?? false;
              });
            },
            activeColor: NeumorphismTheme.coffeeMedium,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.authText,
                  children: [
                    const TextSpan(text: 'Acepto los '),
                    TextSpan(
                      text: 'TÃ©rminos y Condiciones',
                      style: AppTextStyles.authTextSecondary,
                    ),
                    const TextSpan(text: ' y la '),
                    TextSpan(
                      text: 'PolÃ­tica de Privacidad',
                      style: AppTextStyles.authTextSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 24),

      // BotÃ³n de registro
      AuthButton(
        backgroundColor: const Color(0xFF8D6E63), // NeumorphismTheme.coffeeMedium
        text: 'Crear Cuenta',
        isLoading: isLoading,
        onPressed: _acceptTerms ? () async {
          if (_formKey.currentState!.validate()) {
            await authNotifier.register(
              email: _emailController.text.trim(),
              username: _usernameController.text.trim(),
              password: _passwordController.text,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              role: UserRole.user,
              stageName: null,
            );

            if (mounted) {
              // ðŸ“§ Si el usuario ya estÃ¡ autenticado (Modo DEV auto-verify),
              // ir directamente al onboarding saltando la verificaciÃ³n manual.
              final isAuthenticated = ref.read(authStateProvider).isAuthenticated;
              if (isAuthenticated) {
                context.go('/onboarding');
              } else {
                // Navegar a la pantalla de verificaciÃ³n
                context.push('/verify-code/${Uri.encodeComponent(_emailController.text.trim())}');
              }
            }
          }
        } : null,
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
              'O regÃ­strate con',
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

      // Botones de autenticaciÃ³n social
      Row(
        children: [
          Flexible(
            flex: 1,
            child: SocialAuthButton(
              icon: Icons.g_mobiledata,
              text: 'Google',
              onPressed: isLoading
                  ? null
                  : () async {
                      try {
                        await authNotifier.signInWithGoogle();
                      } catch (e) {
                      }
                    },
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 1,
            child: SocialAuthButton(
              icon: Icons.facebook,
              text: 'Facebook',
              onPressed: isLoading
                  ? null
                  : () async {
                      try {
                        await authNotifier.signInWithFacebook();
                      } catch (e) {
                      }
                    },
              backgroundColor: const Color(0xFF1877F2), 
              textColor: Colors.white,
              iconColor: Colors.white,
            ),
          ),
        ],
      ),

      const SizedBox(height: 32),

      // Enlace a login
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Â¿Ya tienes cuenta? ',
            style: AppTextStyles.authText,
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Inicia sesiÃ³n',
              style: AppTextStyles.authLink.copyWith(
                color: const Color(0xFF8D6E63), // NeumorphismTheme.coffeeMedium
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

