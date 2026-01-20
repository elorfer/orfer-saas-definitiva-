
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/neumorphism_theme.dart';
import '../theme/text_styles.dart';

class WebSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const WebSidebar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280, // Ancho fijo del sidebar
      height: double.infinity,
      decoration: BoxDecoration(
        color: NeumorphismTheme.isDark ? const Color(0xFF1E1B19) : const Color(0xFFF5F2F0), 
        border: Border(
          right: BorderSide(
            color: NeumorphismTheme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 40),
            child: Row(
              children: [
                 Image.asset(
                  'assets/images/logo.webp',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Vintage Music',
                  style: AppTextStyles.titleLarge.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),

          // Menu Items
          _buildMenuItem(context, 0, Icons.home_filled, 'Inicio'),
          _buildMenuItem(context, 1, Icons.search, 'Buscar'),
          _buildMenuItem(context, 2, Icons.library_music, 'Tu Biblioteca'),
          _buildMenuItem(context, 3, Icons.diamond, 'Premium'),
          
          const Spacer(),
          
          // Opciones de cuenta al final
          Divider(color: NeumorphismTheme.textSecondary.withOpacity(0.1)),
          const SizedBox(height: 20),
          _buildSimpleItem(context, Icons.person_outline, 'Mi Cuenta', () {}),
          _buildSimpleItem(context, Icons.settings_outlined, 'Configuración', () {}),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, int index, IconData icon, String label) {
    final isActive = currentIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTabSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: isActive ? BoxDecoration(
              color: NeumorphismTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ) : null,
            child: Row(
              children: [
                Icon(
                  icon, 
                  color: isActive ? NeumorphismTheme.accent : NeumorphismTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? NeumorphismTheme.textPrimary : NeumorphismTheme.textSecondary,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

    Widget _buildSimpleItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon, 
                  color: NeumorphismTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: NeumorphismTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
