import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
                  
                  // ⚡ OPTIMIZADO: Tarjeta de perfil compacta con sombra reducida
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NeumorphismTheme.coffeeMedium.withValues(alpha: 0.12),
                          NeumorphismTheme.coffeeDark.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      boxShadow: [
                        // ⚡ OPTIMIZACIÓN: Reducir blurRadius para mejor rendimiento
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8, // Reducido de 16 a 8
                          offset: const Offset(0, 3), // Reducido de 6 a 3
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar más pequeño
                        Container(
                          width: 70, // 🔥 Tamaño reducido
                          height: 70,
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
                              // ⚡ OPTIMIZACIÓN: Reducir sombra del avatar
                              BoxShadow(
                                color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.25),
                                blurRadius: 8, // Reducido de 12 a 8
                                offset: const Offset(0, 2), // Reducido de 4 a 2
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 35, // 🔥 Icono reducido
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        
                        // Nombre del usuario
                        Text(
                          userName,
                          style: GoogleFonts.inter(
                            fontSize: 18, // 🔥 Tamaño reducido
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
                          style: GoogleFonts.inter(
                            fontSize: 13, // 🔥 Tamaño reducido
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
                                style: GoogleFonts.inter(
                                  fontSize: 11, // 🔥 Tamaño reducido
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
                  
                  // 🔥 Sección de configuración con título
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Configuración',
                      style: GoogleFonts.inter(
                        fontSize: 16, // 🔥 Tamaño reducido
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
                                style: GoogleFonts.inter(
                                  fontSize: 14, // 🔥 Tamaño reducido
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
    // ⚡ OPTIMIZACIÓN: Reducir sombras para mejor rendimiento
    return Container(
      decoration: BoxDecoration(
        color: NeumorphismTheme.beigeMedium.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, // Reducido de 8 a 4
            offset: const Offset(0, 1), // Reducido de 2 a 1
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // 🔥 Padding reducido
            child: Row(
              children: [
                // Icono con fondo más pequeño
                Container(
                  width: 36, // 🔥 Tamaño reducido
                  height: 36,
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    icon,
                    color: NeumorphismTheme.coffeeMedium,
                    size: 18, // 🔥 Icono reducido
                  ),
                ),
                const SizedBox(width: 12),
                // Título
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14, // 🔥 Tamaño reducido
                      fontWeight: FontWeight.w600,
                      color: NeumorphismTheme.textPrimary,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Chevron más pequeño
                Icon(
                  Icons.chevron_right_rounded,
                  color: NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                  size: 20, // 🔥 Tamaño reducido
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
      // Usuario Premium - Mensaje en verde
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.verified_rounded,
              color: Colors.green[700],
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'Eres un usuario premium activo',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Disfruta de música única en el mundo',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // Usuario NO Premium - Botón para actualizar
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NeumorphismTheme.coffeeMedium,
              NeumorphismTheme.coffeeDark,
            ],
          ),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'Estado de Suscripción',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Actualiza a Premium para disfrutar de música sin límites',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop(); // Cerrar drawer
                    context.go('/premium'); // Navegar a pantalla premium
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Center(
                    child: Text(
                      'Actualizar Premium',
                      style: GoogleFonts.inter(
                        fontSize: 14,
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

