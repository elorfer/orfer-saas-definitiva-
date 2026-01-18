import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
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
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F0F13), // Negro profundo
                      Color(0xFF1A1A2E), // Azul oscuro
                      Color(0xFF2C2C3E), // Gris azulado
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Orbes de color difuminados para ambiente
                    Positioned(
                      top: -100,
                      right: -100,
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.purple.withOpacity(0.15),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -100,
                      left: -100,
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.15),
                        ),
                      ),
                    ),
                    // Capa de blur sutil
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 20),
                    ),
                    // Borde sutil brillante
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
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
