import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/time_ago_formatter.dart';

import '../../../core/widgets/struky_zoom_drawer.dart';
/// Widget del header scrolleable (avatar, bienvenido, nombre, logo, última actualización)
/// Extracted for performance isolation and cleaner HomeScreen code.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 Refresh UI on Theme Change
    ref.watch(themeProvider);

    // ⚡ OPTIMIZACIÓN: Usar select para escuchar solo los valores necesarios
    // Solo observar firstName, no isLoading (evita rebuilds innecesarios)
    final userFirstName = ref.watch(currentUserProvider.select((u) => u?.firstName));
    
    // 🔥 NUEVO: Obtener timestamp de última actualización
    final lastUpdateTime = ref.watch(homeStateProvider.select((state) => state.lastUpdateTime));
    
    // ⚡ OPTIMIZACIÓN: Remover watch de isLoading - solo se usa para skeleton inicial
    final isLoading = userFirstName == null;
    
    // OPTIMIZACIÓN: RepaintBoundary para aislar el header y evitar rebuilds innecesarios
    return RepaintBoundary(
      child: SizedBox(
        height: 74, // ✅ Altura aumentada para timestamp (era 64)
        child: isLoading
            ? _buildHeaderSkeleton()
            : Row(
                children: [
                  // ⚡ Avatar clickeable para abrir drawer (GestureDetector para 0 lag)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.findAncestorStateOfType<StrukyZoomDrawerState>()?.toggle();
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NeumorphismTheme.isDark 
                            ? const Color(0xFFD7CCC8) 
                            : NeumorphismTheme.coffeeMedium,
                      ),
                      child: Center(
                        child: Text(
                          _getInitialsFromFirstName(userFirstName),
                          style: AppTextStyles.titleMedium.copyWith(
                            color: NeumorphismTheme.isDark 
                                ? const Color(0xFF3E2723) 
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Texto de bienvenida
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center, // Centrar verticalmente
                      children: [
                        Text(
                          'Bienvenido',
                          style: AppTextStyles.welcomeText,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userFirstName ?? '',
                          style: AppTextStyles.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // 🔥 NUEVO: Mostrar timestamp de última actualización
                        if (lastUpdateTime != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            TimeAgoFormatter.format(lastUpdateTime),
                            style: AppTextStyles.welcomeText.copyWith(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

              const Spacer(), // Push buttons to right
              
              // Theme Toggle Button
              Tooltip(
                message: NeumorphismTheme.isDark ? 'Modo Claro' : 'Modo Oscuro',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ref.read(themeProvider.notifier).toggleTheme();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.isDark 
                            ? Colors.white.withOpacity(0.05) 
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        NeumorphismTheme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 20,
                        color: NeumorphismTheme.isDark 
                            ? Colors.white.withOpacity(0.7) 
                            : Colors.black.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12), // Space between buttons

              // Logout Button
              Tooltip(
                message: 'Cerrar Sesión',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ref.read(authStateProvider.notifier).logout();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.isDark 
                            ? Colors.white.withOpacity(0.05) 
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: NeumorphismTheme.isDark 
                            ? Colors.white.withOpacity(0.7) 
                            : Colors.black.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildHeaderSkeleton() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NeumorphismTheme.shimmerBaseColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 16,
                width: 100,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.shimmerBaseColor,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 20,
                width: 150,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.shimmerBaseColor,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitialsFromFirstName(String? firstName) {
    if (firstName == null || firstName.isEmpty) return 'U';
    return firstName[0].toUpperCase();
  }
}
