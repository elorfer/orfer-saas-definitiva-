import 'package:flutter/material.dart';
import '../../../core/theme/neumorphism_theme.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
  });

  // Constantes para optimización
  static const _defaultHeight = 56.0;
  static const _borderRadius = BorderRadius.all(Radius.circular(12));
  static const _loadingSize = 20.0;
  static const _strokeWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? _defaultHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? NeumorphismTheme.coffeeMedium,
          foregroundColor: textColor ?? Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: _borderRadius,
          ),
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
        ),
        child: isLoading
            ? SizedBox(
                width: _loadingSize,
                height: _loadingSize,
                child: CircularProgressIndicator(
                  strokeWidth: _strokeWidth,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Colors.white,
                  ),
                ),
              )
            : Text(
                text,
                // OPTIMIZACIÓN: Usar estilo constante en lugar de GoogleFonts.inter()
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
