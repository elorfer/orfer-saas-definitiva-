import 'package:flutter/material.dart';
import '../theme/neumorphism_theme.dart';
import '../theme/text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTapMore;
  final String? actionLabel;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.onTapMore,
    this.actionLabel = 'Ver más',
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5, // 🚀 PREMIUM: Tight tracking
            ),
          ),
          if (onTapMore != null)
            TextButton(
              onPressed: onTapMore,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: NeumorphismTheme.accentDark,
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NeumorphismTheme.accentDark,
                  letterSpacing: -0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
