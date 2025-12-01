import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/fast_scroll_physics.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// ProfileScreen optimizado con AutomaticKeepAliveClientMixin
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Mantener estado al cambiar de pestaña

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
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    // Usar ref.read cuando solo necesitamos el valor una vez (no reconstruir)
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    return Scaffold(
      key: const ValueKey('profile_scaffold'), // Key estable para evitar rebuilds
      body: Container(
        decoration: const BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header mejorado con icono
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                        NeumorphismTheme.coffeeDark.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icono de perfil grande
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              NeumorphismTheme.coffeeMedium,
                              NeumorphismTheme.coffeeDark,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Información
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Perfil',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: NeumorphismTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.settings_rounded,
                                  size: 16,
                                  color: NeumorphismTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Configuración y cuenta',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: NeumorphismTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // User info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: NeumorphismTheme.neumorphismShadow,
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: NeumorphismTheme.coffeeMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // User name
                      Text(
                        '${user?.firstName ?? 'Usuario'} ${user?.lastName ?? ''}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NeumorphismTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // User email
                      Text(
                        user?.email ?? 'usuario@ejemplo.com',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: NeumorphismTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // User role
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user?.role.toString() ?? 'Usuario',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: NeumorphismTheme.coffeeMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Settings sections optimizadas
                Expanded(
                  child: ListView.builder(
                    cacheExtent: 300, // Optimizado: lista pequeña (máx 5-6 elementos), reducir de 800 a 300
                    physics: const FastScrollPhysics(), // Scroll más rápido y fluido
                    itemCount: _settingsSections.length + 1, // +1 para el botón de logout
                    itemBuilder: (context, index) {
                      if (index < _settingsSections.length) {
                        final section = _settingsSections[index];
                        return RepaintBoundary(
                          key: ValueKey('settings_section_$index'),
                          child: _buildSettingsSection(
                            icon: section['icon'] as IconData,
                            title: section['title'] as String,
                            onTap: section['onTap'] as VoidCallback,
                          ),
                        );
                      } else {
                        // Botón de logout
                        return RepaintBoundary(
                          key: const ValueKey('logout_button'),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: TextButton(
                                onPressed: () async {
                                  await ref.read(authStateProvider.notifier).logout();
                                  if (context.mounted) {
                                    context.go('/login');
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.logout,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cerrar Sesión',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: NeumorphismTheme.neumorphismShadow,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: NeumorphismTheme.coffeeMedium,
          size: 24,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: NeumorphismTheme.textPrimary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: NeumorphismTheme.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
