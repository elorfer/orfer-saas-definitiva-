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
    return SizedBox(
      height: _defaultHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white,
          foregroundColor: textColor ?? Colors.grey[700],
          side: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: _borderRadius,
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
