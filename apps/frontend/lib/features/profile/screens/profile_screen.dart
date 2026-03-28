import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/optimized_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final theme = ref.watch(themeProvider);
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: NeumorphismTheme.isDark 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: NeumorphismTheme.textPrimary, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // Fallback: Volver a la raíz de la rama actual en lugar de forzar /library
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Mi Perfil',
          style: GoogleFonts.inter(
            color: NeumorphismTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- HEADER: AVATAR & INFO ---
            Center(
              child: Column(
                children: [
                  // Avatar with subtle glow
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NeumorphismTheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: NeumorphismTheme.coffeeMedium
                              .withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: OptimizedImage(
                        imageUrl: user.avatarUrl,
                        width: 100,
                        height: 100,
                        placeholder: Icon(Icons.person_rounded,
                            size: 50, color: NeumorphismTheme.coffeeMedium),
                        errorWidget: Icon(Icons.person_rounded,
                            size: 50, color: NeumorphismTheme.coffeeMedium),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Username / Name
                  Text(
                    user.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: NeumorphismTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    user.email,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: NeumorphismTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Premium Badge (Minimalist)
                  if (user.isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.coffeeMedium
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: NeumorphismTheme.coffeeMedium
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.diamond_rounded,
                              size: 14, color: NeumorphismTheme.coffeeMedium),
                          const SizedBox(width: 8),
                          Text(
                            'USUARIO PREMIUM',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: NeumorphismTheme.coffeeMedium,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- SECTIONS ---
            _buildSectionTitle('CUENTA'),
            _buildMenuItem(
              icon: Icons.person_outline_rounded,
              title: 'Editar Datos',
              onTap: () {},
            ),
            _buildMenuItem(
              icon: Icons.lock_outline_rounded,
              title: 'Privacidad y Seguridad',
              onTap: () => context.push('/privacy'),
            ),
            _buildMenuItem(
              icon: Icons.notifications_none_rounded,
              title: 'Notificaciones',
              onTap: () => context.push('/notifications'),
            ),

            const SizedBox(height: 24),

            _buildSectionTitle('CONTENIDO'),
            _buildMenuItem(
              icon: Icons.favorite_border_rounded,
              title: 'Mis Favoritos',
              onTap: () => context.push('/favorites'),
            ),
            _buildMenuItem(
              icon: Icons.download_done_rounded,
              title: 'Descargas',
              onTap: () => context.push('/downloads'),
            ),

            const SizedBox(height: 24),

            _buildSectionTitle('SISTEMA'),
            _buildMenuItem(
              icon: Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              title: Theme.of(context).brightness == Brightness.dark
                  ? 'Modo Claro'
                  : 'Modo Oscuro',
              trailing: Switch.adaptive(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (val) {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
                activeThumbColor: NeumorphismTheme.coffeeMedium,
              ),
              onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),

            const SizedBox(height: 32),

            // Logout Button (Minimalist Red)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton(
                onPressed: () => _handleLogout(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Cerrar Sesión',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 120), // Spacer for MiniPlayer
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: NeumorphismTheme.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: NeumorphismTheme.textPrimary, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: NeumorphismTheme.textPrimary,
                    ),
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right_rounded,
                        color: NeumorphismTheme.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('¿Cerrar Sesión?'),
        content: const Text('Tu música y descargas te esperarán aquí.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: NeumorphismTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Cerrar Sesión',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
