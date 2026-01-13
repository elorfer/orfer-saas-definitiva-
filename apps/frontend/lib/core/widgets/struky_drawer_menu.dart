import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/theme_provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:go_router/go_router.dart';
import '../../features/premium/widgets/premium_upsell_dialog.dart';
import '../../core/providers/offline_manager_provider.dart';
import 'optimized_image.dart';

class StrukyDrawerMenu extends ConsumerWidget {
  const StrukyDrawerMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchar cambios de usuario
    final user = ref.watch(authStateProvider.select((state) => state.user));
    final userName = '${user?.firstName ?? 'Usuario'} ${user?.lastName ?? ''}'.trim();
    final userEmail = user?.email ?? 'usuario@ejemplo.com';
    final userRole = user?.role.toString() ?? 'Usuario';
    final isPremium = user != null &&
        (user.subscriptionStatus == SubscriptionStatus.premium ||
            user.subscriptionStatus == SubscriptionStatus.vip);

    // Permitir acceso a descargas si hay canciones descargadas, incluso si offline/free
    final hasDownloads = ref.watch(offlineManagerProvider.select((s) => s.downloadedSongs.isNotEmpty));

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    // Colores derivados del tema para consistencia
    final Color textColorPrimary = colorScheme.onSurface;
    final Color textColorSecondary = colorScheme.onSurface.withOpacity(0.6);
    final Color dividerColor = colorScheme.onSurface.withOpacity(0.1);
    final Color iconColor = colorScheme.onSurface.withOpacity(0.7);

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER (Reduced top padding for better space usage)
          Padding(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + Logout Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(color: dividerColor, width: 1),
                      ),
                      child: ClipOval(
                        child: OptimizedImage(
                          imageUrl: user?.avatarUrl,
                          width: 60,
                          height: 60,
                          placeholder: Icon(Icons.person_rounded, size: 30, color: iconColor),
                          errorWidget: Icon(Icons.person_rounded, size: 30, color: iconColor),
                          maxCacheHeight: 100,
                          maxCacheWidth: 100,
                        ),
                      ),
                    ),
                    
                    // Top Right Logout Icon
                    IconButton(
                      onPressed: () => _showLogoutConfirmation(context, ref),
                      icon: const Icon(Icons.logout_rounded),
                      color: colorScheme.error, // Red
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.error.withValues(alpha: 0.1),
                        highlightColor: colorScheme.error.withValues(alpha: 0.2),
                      ),
                      tooltip: 'Cerrar Sesión',
                    ),
                  ],
                ),
                
                
                const SizedBox(height: 10), // Reduced from 16
                Text(
                  userName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: textColorPrimary, 
                  ),
                ),
                const SizedBox(height: 2), // Reduced from 4
                Text(
                  userEmail,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: textColorSecondary,
                  ),
                ),
                const SizedBox(height: 8), // Reduced from 12
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        userRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. PREMIUM BADGE / UPSELL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0), // Tightened vertical padding
            child: isPremium
                ? _buildPremiumBadge()
                : _buildUpsellBadge(context),
          ),
          
          const SizedBox(height: 8), // Reduced from 12
          Divider(color: dividerColor, indent: 24, endIndent: 24),
          const SizedBox(height: 8), // Reduced from 12

          // 3. MENU OPTIONS
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4), // Reduced from 8
              child: Column(
                children: [
                   _MenuOption(
                    icon: Icons.person_outline_rounded,
                    label: 'Mi Perfil',
                    onTap: () {},
                    textColor: textColorPrimary,
                    iconColor: iconColor,
                  ),
                   // Toggle Modo Oscuro
                   _MenuOption(
                    icon: Theme.of(context).brightness == Brightness.dark 
                        ? Icons.light_mode_rounded 
                        : Icons.dark_mode_rounded,
                    label: Theme.of(context).brightness == Brightness.dark 
                        ? 'Modo Claro' 
                        : 'Modo Oscuro',
                    onTap: () async {
                      await HapticFeedback.selectionClick();
                      ref.read(themeProvider.notifier).toggleTheme();
                    },
                    textColor: textColorPrimary,
                    iconColor: iconColor,
                    trailing: Switch.adaptive(
                      value: Theme.of(context).brightness == Brightness.dark,
                      onChanged: (val) {
                         ref.read(themeProvider.notifier).toggleTheme();
                      },
                      activeColor: colorScheme.primary,
                      activeTrackColor: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                   _MenuOption(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notificaciones',
                    onTap: () {},
                    textColor: textColorPrimary,
                    iconColor: iconColor,
                  ),
                   _MenuOption(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacidad',
                    onTap: () {
                      GoRouter.of(context).push('/privacy');
                    },
                    textColor: textColorPrimary,
                    iconColor: iconColor,
                  ),
                   _MenuOption(
                    icon: Icons.download_outlined,
                    label: 'Descargas',
                    onTap: () {
                      if (isPremium || hasDownloads) {
                        context.push('/downloads');
                      } else {
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Cerrar',
                          barrierColor: Colors.black54,
                          pageBuilder: (context, animation, secondaryAnimation) => const PremiumUpsellDialog(),
                          transitionBuilder: (context, animation, secondaryAnimation, child) {
                            final curvedAnimation = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            );
                            
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(curvedAnimation),
                              child: FadeTransition(
                                opacity: curvedAnimation,
                                child: child,
                              ),
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 150),
                        );
                      }
                    },
                    textColor: textColorPrimary,
                    iconColor: iconColor,
                  ),
                  
                  // COMPOSER PROMO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Material(
                       color: Colors.transparent,
                       child: InkWell(
                         onTap: () => context.push('/composer-promo'),
                         borderRadius: BorderRadius.circular(12),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           decoration: BoxDecoration(
                             color: colorScheme.surface,
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: dividerColor),
                           ),
                           child: Row(
                             children: [
                                Icon(Icons.music_note_rounded, color: colorScheme.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '¿Eres compositor?',
                                    style: TextStyle(color: textColorPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: iconColor),
                             ],
                           ),
                         ),
                       ),
                     ),
                  ),

                   _MenuOption(
                    icon: Icons.help_outline_rounded,
                    label: 'Ayuda y Soporte',
                    onTap: () {},
                    textColor: textColorPrimary,
                    iconColor: iconColor,
                  ),
                  _MenuOption(
                    icon: Icons.info_outline_rounded,
                    label: 'Acerca de',
                    onTap: () => _showAboutDialog(context),
                    textColor: textColorPrimary,
                    iconColor: iconColor,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Version Text
                  Center(
                    child: Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: textColorSecondary.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // SPACER FOR MINIPLAYER (Crucial)
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    // Usar diálogo adaptativo para sensación nativa (iOS/Android)
    showAdaptiveDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog.adaptive(
          title: const Text('¿Cerrar Sesión?'),
          content: const Text('Estás a punto de salir de tu cuenta.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
              },
            ),
            TextButton(
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red), // Destructive action
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar diálogo
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) {
                   GoRouter.of(context).go('/login');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPremiumBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20), // Dark green
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.greenAccent, size: 20),
          SizedBox(width: 8),
          Text(
            'Premium Activo',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUpsellBadge(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/premium'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B7A6A), Color(0xFF5D4D3E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hazte Premium',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                    Text(
                      'Apoya a los artistas',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Struky app',
      applicationVersion: 'v1.0',
      applicationIcon: const Icon(Icons.library_music, color: Color(0xFF8B7A6A), size: 40),
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 16.0),
          child: Text(
            'Struky app es una plataforma dedicada a mostrar el catálogo musical de los compositores.',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final Color iconColor;
  final Widget? trailing;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      shape: const RoundedRectangleBorder(),
      onTap: onTap,
      trailing: trailing,
    );
  }
}
