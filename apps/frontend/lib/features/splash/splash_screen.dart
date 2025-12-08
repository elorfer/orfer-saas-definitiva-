import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;
    
    // Logo con tamaño aumentado y prominente (igual que en login)
    final logoSize = isSmallScreen ? 150.0 : (isMediumScreen ? 180.0 : 200.0);
    final logoIconSize = isSmallScreen ? 75.0 : (isMediumScreen ? 90.0 : 100.0);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF3E2723), // Marrón oscuro (igual que login)
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo con tamaño aumentado
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback a icono si la imagen no se carga
                      return Icon(
                        Icons.music_note,
                        size: logoIconSize,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'struky',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 28 : (isMediumScreen ? 32 : 36),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 32),
              SizedBox(
                width: isSmallScreen ? 32 : 40,
                height: isSmallScreen ? 32 : 40,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
















