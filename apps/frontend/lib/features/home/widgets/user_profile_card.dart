import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/user_model.dart';

class UserProfileCard extends StatelessWidget {
  final User user;

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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: user.avatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          user.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 30,
                              color: const Color(0xFF667eea),
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 30,
                        color: const Color(0xFF667eea),
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
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(user.role).withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getRoleText(user.role),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getRoleColor(user.role),
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
                          decoration: BoxDecoration(
                            color: _getSubscriptionColor(user.subscriptionStatus).withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getSubscriptionText(user.subscriptionStatus),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getSubscriptionColor(user.subscriptionStatus),
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
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(20),
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

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.user:
        return Colors.blue;
      case UserRole.artist:
        return Colors.purple;
      case UserRole.admin:
        return Colors.red;
    }
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

  Color _getSubscriptionColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.free:
        return Colors.grey;
      case SubscriptionStatus.premium:
        return Colors.orange;
      case SubscriptionStatus.vip:
        return Colors.purple;
      case SubscriptionStatus.inactive:
        return Colors.red;
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
          color: const Color(0xFF667eea),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            decoration: TextDecoration.none,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
