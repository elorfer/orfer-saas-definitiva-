import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import 'package:go_router/go_router.dart';

/// Drawer lateral ultra-ligero para perfil de usuario
class UltraLightProfileDrawer extends ConsumerWidget {
  const UltraLightProfileDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider.select((state) => state.user));
    final userName = '${user?.firstName ?? 'Usuario'} ${user?.lastName ?? ''}'.trim();
    final userEmail = user?.email ?? 'usuario@ejemplo.com';
    final userRole = user?.role.toString() ?? 'Usuario';
    final isPremium = user != null &&
        (user.subscriptionStatus == SubscriptionStatus.premium ||
            user.subscriptionStatus == SubscriptionStatus.vip);
    final screenWidth = MediaQuery.sizeOf(context).width; // 🚀 OPTIMIZACIÓN: Solo escuchar tamaño
    final drawerWidth = screenWidth * 0.70; // Aumentado ligeramente para legibilidad

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        backgroundColor: Colors.white,
        child: RepaintBoundary( // 🚀 OPTIMIZACIÓN: Aislar el renderizado del drawer
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado de suscripción
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: isPremium
                      ? const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.green, size: 22),
                            SizedBox(width: 8),
                            Text('Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        )
                      : const Row(
                          children: [
                            Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                            SizedBox(width: 8),
                            Text('Gratis', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        ),
                ),
                // Avatar y nombre
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B7A6A), // 🚀 Sólido
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded, size: 30, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF3D2E20))),
                      const SizedBox(height: 4),
                      Text(userEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF8B7A6A))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3EBE3), // 🚀 Sólido (Marrón muy pálido)
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 13, color: Color(0xFF8B7A6A)),
                            const SizedBox(width: 4),
                            Text(userRole, style: const TextStyle(fontSize: 11, color: Color(0xFF8B7A6A), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Opciones
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      const _DrawerOption(icon: Icons.person_outline, label: 'Mi Perfil'),
                      const _DrawerOption(icon: Icons.notifications_outlined, label: 'Notificaciones'),
                      _DrawerOption(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacidad',
                        onTap: () {
                          Navigator.of(context).pop();
                          GoRouter.of(context).push('/privacy');
                        },
                      ),
                      const _DrawerOption(icon: Icons.download_outlined, label: 'Descargas'),
                      const _DrawerOption(icon: Icons.help_outline, label: 'Ayuda y Soporte'),
                      _DrawerOption(
                        icon: Icons.info_outline,
                        label: 'Acerca de',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Struky app',
                            applicationVersion: 'v1.0',
                            applicationIcon: const Icon(Icons.library_music, color: Color(0xFF8B7A6A), size: 40),
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 16.0),
                                child: Text(
                                  'Struky app es una plataforma dedicada a mostrar el catálogo musical de los compositores.\n\nNuestra misión es dar a conocer y visibilizar a quienes durante años estuvieron en las sombras, brindando un espacio para que su música llegue a nuevas audiencias y generaciones.\n\nAquí podrás descubrir, explorar y valorar el trabajo de los verdaderos creadores detrás de la música.',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      _DrawerOption(
                        icon: Icons.speed_rounded,
                        label: 'Pro Experience V2 (Beta)',
                        onTap: () {
                          context.pop();
                          context.push('/home-v2');
                        },
                      ),
                    ],
                  ),
                ),
                // Cerrar sesión
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F), size: 18),
                      label: const Text('Cerrar Sesión', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: const Color(0xFFFFEBEE), // Fondo ligero para el botón de salida
                      ),
                      onPressed: () async {
                        await ref.read(authStateProvider.notifier).logout();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          await Future.delayed(const Duration(milliseconds: 250));
                          if (context.mounted) {
                            GoRouter.of(context).go('/login');
                          }
                        }
                      },
                    ),
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

class _DrawerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _DrawerOption({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      leading: Icon(icon, color: Colors.brown, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
      onTap: onTap,
      minLeadingWidth: 0,
      horizontalTitleGap: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      hoverColor: const Color(0xFFF3EBE3), // 🚀 Sólido

    );
  }
}
