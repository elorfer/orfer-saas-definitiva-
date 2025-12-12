import 'package:flutter/material.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';

class HomeMessageBanner extends StatelessWidget {
  final String message;
  final DateTime? updatedAt;

  const HomeMessageBanner({
    super.key,
    required this.message,
    this.updatedAt,
  });

  String _formatUpdatedAt() {
    if (updatedAt == null) return '';
    return 'Actualizado ${updatedAt!.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' a las ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: NeumorphismTheme.accentDark.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: NeumorphismTheme.accentLight.withOpacity(0.22),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NeumorphismTheme.accentLight.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  color: NeumorphismTheme.coffeeDark,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.coffeeDark.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NOVEDAD',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: NeumorphismTheme.textPrimary,
                      height: 1.32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_formatUpdatedAt().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatUpdatedAt(),
                      style: AppTextStyles.caption.copyWith(
                        color: NeumorphismTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

