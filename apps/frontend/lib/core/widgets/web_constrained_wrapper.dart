import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';

class WebConstrainedWrapper extends StatelessWidget {
  final Widget child;

  const WebConstrainedWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Solo aplicar en Web (y opcionalmente en escritorio)
    final isDesktopOrWeb = PlatformUtils.isWeb || 
                          PlatformUtils.isWindows || 
                          PlatformUtils.isLinux || 
                          PlatformUtils.isMacOS;

    if (!isDesktopOrWeb) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Si la pantalla es lo suficientemente pequeña (móvil), no forzar wrapper
        if (constraints.maxWidth < 600) {
          return child;
        }

        return Stack(
          children: [
            // 1. Fondo Premium (Gradients + Blur)
            // 1. Fondo Premium (Color Beige + Imagen Logo)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5DC), // Beige natural (Cream)
                ),
                child: Stack(
                  children: [
                    // Imagen de fondo (Logo repetido o grande)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1, // Sutil para no distraer
                        child: Image.asset(
                          'assets/images/web_background_logo.png',
                          fit: BoxFit.cover, // Cubrir todo el fondo
                          errorBuilder: (c, e, s) => const SizedBox(), // Fallback silencioso
                        ),
                      ),
                    ),
                    
                    // Capa de blur sutil para suavizar
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.transparent),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Contenedor Central (App Simulada)
            Center(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 480, // Ancho típico de móvil grande
                  maxHeight: 900, // Altura máxima
                ),
                // Margen vertical para que no toque bordes en pantallas altas
                margin: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black, // Fondo base de la app
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    // Sombra elegante para dar profundidad
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 20),
                    ),
                    // Borde sutil brillante
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1),
                      blurRadius: 0,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: child,
                ),
              ),
            ),
            
            // 3. Branding Discreto (Opcional)
            const Positioned(
              bottom: 20,
              right: 30,
              child: Text(
                'Struky Web Beta',
                style: TextStyle(
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

