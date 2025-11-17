import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key});

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actividad Reciente',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  decoration: TextDecoration.none,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ver toda la actividad próximamente'),
                    ),
                  );
                },
                child: Text(
                  'Ver todo',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF667eea),
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Lista de actividades (placeholder)
          _ActivityItem(
            icon: Icons.music_note,
            title: 'Bienvenido a Vintage Music',
            subtitle: 'Tu cuenta ha sido creada exitosamente',
            time: 'Ahora',
            color: const Color(0xFF667eea),
          ),
          const SizedBox(height: 12),
          _ActivityItem(
            icon: Icons.check_circle,
            title: 'Cuenta verificada',
            subtitle: 'Tu cuenta está lista para usar',
            time: 'Hace 1 minuto',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _ActivityItem(
            icon: Icons.info,
            title: 'Explora la aplicación',
            subtitle: 'Descubre todas las funciones disponibles',
            time: 'Hace 2 minutos',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[500],
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
