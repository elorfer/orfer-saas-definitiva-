import 'dart:async';
import 'package:flutter/material.dart';
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
  
  // Estados para validación en tiempo real
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
    
    // Limpiar estado si el campo está vacío
    if (username.isEmpty) {
      setState(() {
        _usernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }
    
    // Verificar desde la primera letra, pero solo si tiene al menos 1 carácter
    // Validar formato básico (solo letras, números y guiones bajos)
    if (!RegExp(r'^[a-zA-Z0-9_]*$').hasMatch(username)) {
      // Si tiene caracteres inválidos, no verificar disponibilidad
      setState(() {
        _usernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }
    
    // Si tiene al menos 1 carácter válido, verificar disponibilidad
    setState(() {
      _isCheckingUsername = true;
      _usernameAvailable = null; // Limpiar resultado anterior mientras verifica
    });
    
    _usernameCheckTimer = Timer(const Duration(milliseconds: 800), () async {
      // Verificar que el valor no haya cambiado mientras esperábamos
      if (_usernameController.text != username) {
        return; // El usuario siguió escribiendo, cancelar esta verificación
      }
      
      final authNotifier = ref.read(authStateProvider.notifier);
      try {
        final available = await authNotifier.checkUsernameAvailability(username);
        if (mounted && _usernameController.text == username) {
          setState(() {
            _usernameAvailable = available;
            _isCheckingUsername = false;
          });
          // Forzar validación del campo
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
          // Forzar validación del campo
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
      // OPTIMIZACIÓN: Evitar redimensionamiento cuando aparece el teclado para reducir lag
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Obtener el tamaño del teclado
              final viewInsets = MediaQuery.of(context).viewInsets;
              final keyboardHeight = viewInsets.bottom;
              
              return SingleChildScrollView(
                // OPTIMIZACIÓN: Agregar padding inferior cuando el teclado está visible
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 24.0,
                  bottom: keyboardHeight > 0 ? keyboardHeight + 24.0 : 24.0,
                ),
                // OPTIMIZACIÓN: Mejorar comportamiento del scroll con el teclado
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Header con botón de regreso
                FadeInDown(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      // Botón de regreso alineado a la izquierda
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
                                color: Color(0xFF3E2723), // Marrón oscuro
                                size: 20,
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Título y subtítulo centrados
                      Text(
                        'Crear Cuenta',
                        style: AppTextStyles.authFormTitle.copyWith(
                          color: const Color(0xFF3E2723), // Marrón muy oscuro
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Únete a la comunidad musical',
                        style: AppTextStyles.authFormSubtitle.copyWith(
                          color: NeumorphismTheme.coffeeDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Formulario de registro
                FadeInUp(
                  duration: const Duration(milliseconds: 350), // Optimizado: reducido de 800ms a 350ms
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
                        children: [
                          // Selector de rol eliminado - solo se permite registro como usuario

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
                                    // Forzar validación cuando el usuario escribe
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
                                    // Forzar validación cuando el usuario escribe
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
                            label: 'Correo electrónico',
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
                                return 'Este email ya está registrado';
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
                              // Primero validar formato básico (longitud mínima, caracteres válidos)
                              final basicValidation = AuthValidators.username(value);
                              if (basicValidation != null) {
                                return basicValidation; // Si hay error de formato, retornar ese
                              }
                              
                              // Verificar disponibilidad si ya se verificó (independientemente de la longitud)
                              // Esto permite mostrar el error de disponibilidad incluso si el usuario está escribiendo
                              if (value != null && _usernameAvailable != null && _usernameAvailable == false) {
                                return 'Este nombre de usuario no está disponible';
                              }
                              
                              return null;
                            },
                            onChanged: (value) {
                              _checkUsernameAvailability(value);
                              // Forzar validación cuando el usuario escribe
                              _formKey.currentState?.validate();
                            },
                          ),

                          // Campo de nombre artístico eliminado - solo se permite registro como usuario

                          const SizedBox(height: 20),

                          // Campo de contraseña
                          AuthTextField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            hint: 'Mínimo 6 caracteres',
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
                              // Forzar validación cuando el usuario escribe
                              _formKey.currentState?.validate();
                            },
                          ),

                          const SizedBox(height: 20),

                          // Campo de confirmar contraseña
                          AuthTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirmar contraseña',
                            hint: 'Repite tu contraseña',
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
                              // Forzar validación cuando el usuario escribe
                              _formKey.currentState?.validate();
                            },
                          ),

                          const SizedBox(height: 20),

                          // Checkbox de términos y condiciones
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
                                          text: 'Términos y Condiciones',
                                          style: AppTextStyles.authTextSecondary,
                                        ),
                                        const TextSpan(text: ' y la '),
                                        TextSpan(
                                          text: 'Política de Privacidad',
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

                          // Botón de registro
                          AuthButton(
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
                                  role: UserRole.user, // Siempre usuario
                                  stageName: null, // No aplica para usuarios
                                );
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
                                  'O regístrate con',
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
                                            // El error ya se maneja en el provider
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
                                            // El error ya se maneja en el provider
                                          }
                                        },
                                  backgroundColor: const Color(0xFF1877F2), // Azul de Facebook
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
                                '¿Ya tienes cuenta? ',
                                style: AppTextStyles.authText,
                              ),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: Text(
                                  'Inicia sesión',
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
              );
            },
          ),
        ),
      ),
    );
  }
}
