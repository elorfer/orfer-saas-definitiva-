import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../theme/neumorphism_theme.dart';

/// Drawer lateral premium para promoción y perfil
/// Se abre desde la izquierda ocupando un poco más de la mitad de la pantalla
/// ⚡ OPTIMIZADO: RepaintBoundary y const constructors para evitar lag
class PremiumProfileDrawer extends ConsumerStatefulWidget {
  const PremiumProfileDrawer({super.key});

  @override
  ConsumerState<PremiumProfileDrawer> createState() => _PremiumProfileDrawerState();
}

class _PremiumProfileDrawerState extends ConsumerState<PremiumProfileDrawer> {
  // Lista de secciones estáticas para optimización
  static final List<Map<String, dynamic>> _settingsSections = [
    {
      'icon': Icons.person_outline,
      'title': 'Editar Perfil',
      'onTap': () {},
    },
    {
      'icon': Icons.notifications_outlined,
      'title': 'Notificaciones',
      'onTap': () {},
    },
    {
      'icon': Icons.privacy_tip_outlined,
      'title': 'Privacidad',
      'onTap': () {},
    },
    {
      'icon': Icons.download_outlined,
      'title': 'Descargas',
      'onTap': () {},
    },
    {
      'icon': Icons.help_outline,
      'title': 'Ayuda y Soporte',
      'onTap': () {},
    },
    {
      'icon': Icons.info_outline,
      'title': 'Acerca de',
      'onTap': () {},
    },
  ];

  @override
  Widget build(BuildContext context) {
    // ⚡ OPTIMIZACIÓN: Usar select para evitar reconstrucciones innecesarias
    // Solo escuchar cambios en el usuario, no en todo el authState
    final user = ref.watch(authStateProvider.select((state) => state.user));
    final userName = '${user?.firstName ?? 'Usuario'} ${user?.lastName ?? ''}'.trim();
    final userEmail = user?.email ?? 'usuario@ejemplo.com';
    final userRole = user?.role.toString() ?? 'Usuario';
    
    // Calcular isPremium de forma explícita para asegurar que se actualice
    final isPremium = user != null && 
                      (user.subscriptionStatus == SubscriptionStatus.premium || 
                       user.subscriptionStatus == SubscriptionStatus.vip);
    
    // Ancho del drawer: un poco más de la mitad (55%)
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.55;

    // ⚡ OPTIMIZACIÓN: RepaintBoundary para aislar el drawer del resto de la UI
    return RepaintBoundary(
      child: SizedBox(
        width: drawerWidth,
        child: Drawer(
          backgroundColor: NeumorphismTheme.background,
          child: Container(
            decoration: const BoxDecoration(
              gradient: NeumorphismTheme.backgroundGradient,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // 🔥 Estado de Suscripción - Arriba
                  _buildSubscriptionStatus(isPremium),
                  
                  const SizedBox(height: 24),
                  
                  // ⚡ GAMA BAJA: Tarjeta de perfil simplificada
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // ⚡ GAMA BAJA: Color sólido en lugar de gradiente + sombra
                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        // Avatar simplificado
                        Container(
                          width: 60, // ⚡ GAMA BAJA: Reducido
                          height: 60,
                          decoration: const BoxDecoration(
                            // ⚡ GAMA BAJA: Color sólido sin sombra
                            color: NeumorphismTheme.coffeeMedium,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        
                        // Nombre del usuario
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16, // ⚡ GAMA BAJA
                            fontWeight: FontWeight.bold,
                            color: NeumorphismTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        
                        // Email del usuario
                        Text(
                          userEmail,
                          style: const TextStyle(
                            fontSize: 12, // ⚡ GAMA BAJA
                            color: NeumorphismTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        
                        // Badge de rol compacto
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            border: Border.all(
                              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 14, // 🔥 Icono reducido
                                color: NeumorphismTheme.coffeeMedium,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                userRole,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: NeumorphismTheme.coffeeMedium,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // ⚡ GAMA BAJA: Sección de configuración
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Configuración',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: NeumorphismTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  
                  // ⚡ OPTIMIZADO: Lista de opciones de configuración con RepaintBoundary
                  ...List.generate(
                    _settingsSections.length,
                    (index) {
                      final section = _settingsSections[index];
                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildSettingsSection(
                            icon: section['icon'] as IconData,
                            title: section['title'] as String,
                            onTap: section['onTap'] as VoidCallback,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 🔥 Botón de cerrar sesión compacto
                  Container(
                    width: double.infinity,
                    height: 48, // 🔥 Altura reducida
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await ref.read(authStateProvider.notifier).logout();
                          if (context.mounted) {
                            Navigator.of(context).pop(); // Cerrar drawer
                            context.go('/login');
                          }
                        },
                            borderRadius: const BorderRadius.all(Radius.circular(14)),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: Colors.red,
                                size: 18, // 🔥 Icono reducido
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cerrar Sesión',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    // ⚡ GAMA BAJA: Sin sombra para mejor rendimiento
    return Container(
      decoration: BoxDecoration(
        color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        // ⚡ GAMA BAJA: Sin boxShadow
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Icono simplificado
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Icon(
                    icon,
                    color: NeumorphismTheme.coffeeMedium,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                // Título
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: NeumorphismTheme.textPrimary,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Widget para mostrar el estado de suscripción
  Widget _buildSubscriptionStatus(bool isPremium) {
    if (isPremium) {
      // Usuario Premium - Mensaje en verde simplificado
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.verified_rounded,
              color: Colors.green[700],
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'Eres usuario premium',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Disfruta de música única',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // Usuario NO Premium - Botón simplificado
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          // ⚡ GAMA BAJA: Color sólido sin gradiente ni sombra
          color: NeumorphismTheme.coffeeMedium,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 10),
            const Text(
              'Actualiza a Premium',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Música sin límites',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/premium');
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  child: const Center(
                    child: Text(
                      'Ver planes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: NeumorphismTheme.coffeeDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
