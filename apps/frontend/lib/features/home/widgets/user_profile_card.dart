import 'package:flutter/material.dart';

import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/optimized_image.dart';

class UserProfileCard extends StatelessWidget {
  final User user;

  // Estilos cacheados
  // Estilos cacheados nativos (Sin GoogleFonts)
  static const TextStyle _nameStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Color(0xFF3D2E20),
    decoration: TextDecoration.none,
  );
  static const TextStyle _usernameStyle = TextStyle(
    fontSize: 14,
    color: Color(0xFF8B7A6A),
    decoration: TextDecoration.none,
  );
  static const TextStyle _statValueStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Color(0xFF3D2E20),
    decoration: TextDecoration.none,
  );
  static const TextStyle _statLabelStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF8B7A6A),
    decoration: TextDecoration.none,
  );

  const UserProfileCard({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // Hex sólido reducido
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3EBE3), // Sólido
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(30)),
                  child: OptimizedImage(
                    imageUrl: user.avatarUrl,
                    fit: BoxFit.cover,
                    width: 60,
                    height: 60,
                    borderRadius: 30,
                    maxCacheWidth: 160,
                    maxCacheHeight: 160,
                    skipFade: true,
                    errorWidget: Container(
                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.person,
                        color: NeumorphismTheme.coffeeMedium,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Información del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: _nameStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: _usernameStyle,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3EBE3),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            _getRoleText(user.role),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B7A6A),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF2E6),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            _getSubscriptionText(user.subscriptionStatus),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE67E22),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Estado de verificación
              if (user.isUserVerified)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Estadísticas
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.music_note,
                  label: 'Canciones',
                  value: '0',
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.favorite,
                  label: 'Favoritos',
                  value: '0',
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.playlist_play,
                  label: 'Playlists',
                  value: '0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.user:
        return 'Usuario';
      case UserRole.artist:
        return 'Artista';
      case UserRole.admin:
        return 'Admin';
    }
  }


  String _getSubscriptionText(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.free:
        return 'Gratis';
      case SubscriptionStatus.premium:
        return 'Premium';
      case SubscriptionStatus.vip:
        return 'VIP';
      case SubscriptionStatus.inactive:
        return 'Inactivo';
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  static final TextStyle _statValueStyle = UserProfileCard._statValueStyle;
  static final TextStyle _statLabelStyle = UserProfileCard._statLabelStyle;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: NeumorphismTheme.coffeeMedium,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: _statValueStyle,
        ),
        Text(
          label,
          style: _statLabelStyle,
        ),
      ],
    );
  }
}
