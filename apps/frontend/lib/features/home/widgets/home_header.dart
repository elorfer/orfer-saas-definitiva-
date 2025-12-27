import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';

/// Widget del header scrolleable (avatar, bienvenido, nombre, logo)
/// Extracted for performance isolation and cleaner HomeScreen code.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚡ OPTIMIZACIÓN: Usar select para escuchar solo los valores necesarios
    // Solo observar firstName, no isLoading (evita rebuilds innecesarios)
    final userFirstName = ref.watch(currentUserProvider.select((u) => u?.firstName));
    
    // ⚡ OPTIMIZACIÓN: Remover watch de isLoading - solo se usa para skeleton inicial
    final isLoading = userFirstName == null;
    
    // OPTIMIZACIÓN: RepaintBoundary para aislar el header y evitar rebuilds innecesarios
    return RepaintBoundary(
      child: isLoading
          ? _buildHeaderSkeleton()
          : Row(
            children: [
              // ⚡ Avatar clickeable para abrir drawer
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
                  child: RepaintBoundary(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: NeumorphismTheme.coffeeMedium,
                      ),
                      child: Center(
                        child: Text(
                          _getInitialsFromFirstName(userFirstName),
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
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
                  children: [
                    const Text(
                      'Bienvenido',
                      style: AppTextStyles.welcomeText,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userFirstName ?? '', // Ensure non-null string
                      style: AppTextStyles.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Logo - Tamaño aumentado con caché optimizado
              Image.asset(
                  'assets/images/logo.webp',
                  width: 90,
                  height: 90,
                  cacheWidth: 180, // High-DPI cache
                  cacheHeight: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EBE3), // 🚀 Sólido
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: NeumorphismTheme.coffeeDark,
                        size: 40,
                      ),
                    );
                  },
                ),
            ],
          ),
    );
  }

  Widget _buildHeaderSkeleton() {
    // ✅ OPTIMIZACIÓN: Skeleton estático sin animaciones pesadas de Shimmer
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 16,
                width: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFDED1C4), // 🚀 Sólido
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 20,
                width: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFDED1C4), // 🚀 Sólido
                  borderRadius: BorderRadius.all(Radius.circular(4)),
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
