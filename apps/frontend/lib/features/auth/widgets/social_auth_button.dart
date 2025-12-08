import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SocialAuthButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;

  const SocialAuthButton({
    super.key,
    required this.icon,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });

  // Constantes para optimización
  static const _defaultHeight = 56.0;
  static const _iconSize = 20.0;
  static const _spacing = 12.0;
  static const _borderRadius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    // Usar InkWell en lugar de OutlinedButton para evitar problemas con Expanded/Flexible
    return SizedBox(
      height: _defaultHeight,
      child: InkWell(
        onTap: onPressed,
        borderRadius: _borderRadius,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: _borderRadius,
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            // ✅ CORRECCIÓN: No usar mainAxisSize.min cuando hay Flexible
            children: [
              Icon(
                icon,
                size: _iconSize,
                color: iconColor ?? Colors.grey[600],
              ),
              const SizedBox(width: _spacing),
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
