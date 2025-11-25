import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/models/user_model.dart';

class RoleSelector extends StatelessWidget {
  final UserRole selectedRole;
  final void Function(UserRole) onRoleChanged;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de cuenta',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RoleOption(
                role: UserRole.user,
                title: 'Usuario',
                subtitle: 'Escuchar música',
                icon: Icons.headphones,
                isSelected: selectedRole == UserRole.user,
                onTap: () => onRoleChanged(UserRole.user),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleOption(
                role: UserRole.artist,
                title: 'Artista',
                subtitle: 'Subir música',
                icon: Icons.music_note,
                isSelected: selectedRole == UserRole.artist,
                onTap: () => onRoleChanged(UserRole.artist),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final UserRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? NeumorphismTheme.coffeeMedium.withValues(alpha:0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? NeumorphismTheme.coffeeMedium : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? NeumorphismTheme.coffeeMedium : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? NeumorphismTheme.coffeeMedium : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
