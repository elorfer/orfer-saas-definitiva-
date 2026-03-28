import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/auth_button.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyCodeScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isAutoRedirecting = false;

  @override
  void initState() {
    super.initState();
    // ðŸ” Auto-redirecciÃ³n si el usuario ya estÃ¡ verificado (Modo DEV o verificÃ³ en otro lugar)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoRedirect();
    });
  }

  void _checkAutoRedirect() {
    final authState = ref.read(authStateProvider);
    // Si ya estÃ¡ autenticado (lo que implica verificado en este flujo)
    if (authState.isAuthenticated && !_isAutoRedirecting) {
      setState(() => _isAutoRedirecting = true);
      debugPrint('ðŸš€ [VerifyCode] Usuario ya autenticado, redirigiendo a Onboarding...');
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    
    // Si se llena el Ãºltimo campo, intentar verificar automÃ¡ticamente
    if (index == 5 && value.isNotEmpty) {
      _verifyCode();
    }
  }

  void _onKeyPress(int index, KeyEvent event) {
    if (event is KeyDownEvent && 
        event.logicalKey == LogicalKeyboardKey.backspace && 
        _controllers[index].text.isEmpty && 
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() => _isVerifying = true);

    try {
      await ref.read(authStateProvider.notifier).verifyCode(
        email: widget.email,
        code: code,
      );
      
      if (mounted) {
        // Feedback de Ã©xito rÃ¡pido y transiciÃ³n limpia
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Â¡Email Verificado! Empezando...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Delay mÃ­nimo para permitir que el snackbar se vea un poco antes de la transiciÃ³n slide
        await Future.delayed(const Duration(milliseconds: 1000));
        
        if (mounted) {
          context.go('/onboarding');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3E2723), // MarrÃ³n Struky
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.mail_lock_outlined, color: Color(0xFFD7CCC8), size: 80),
              const SizedBox(height: 32),
              Text(
                'Verifica tu Email',
                style: AppTextStyles.authFormTitle.copyWith(color: Colors.white, fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Hemos enviado un cÃ³digo de 6 dÃ­gitos a:',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Campos del cÃ³digo OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildCodeField(index)),
              ),
              
              const SizedBox(height: 48),
              
              AuthButton(
                text: 'VERIFICAR CÃ“DIGO',
                isLoading: _isVerifying,
                onPressed: _verifyCode,
                backgroundColor: const Color(0xFF8D6E63),
              ),
              
              const SizedBox(height: 32),
              
              TextButton(
                onPressed: _isVerifying ? null : () {
                  // TODO: Implementar reenvÃ­o de cÃ³digo si el usuario lo pide
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reenviando cÃ³digo...'))
                  );
                },
                child: Text(
                  'Â¿No recibiste el cÃ³digo? Reenviar',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeField(int index) {
    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: KeyboardListener(
        focusNode: FocusNode(), // Nodo dummy para atrapar el backspace
        onKeyEvent: (event) => _onKeyPress(index, event),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
          ),
          onChanged: (value) => _onCodeChanged(index, value),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ),
    );
  }
}

