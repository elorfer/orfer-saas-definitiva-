import 'package:flutter/material.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/theme_provider.dart';

class HomeMessageBanner extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 Refresh on Theme Change
    ref.watch(themeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: NeumorphismTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: NeumorphismTheme.isDark 
                ? const Color(0x1FFFFFFF) 
                : const Color(0xFFF3EBE3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.campaign_outlined,
                color: NeumorphismTheme.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: NeumorphismTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NOVEDAD',
                      style: AppTextStyles.caption.copyWith(
                        color: NeumorphismTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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

