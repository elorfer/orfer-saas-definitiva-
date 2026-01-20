
import 'package:flutter/material.dart';

/// Widget de utilidad para renderizar diferentes diseños según el ancho de pantalla.
/// 
/// Actúa como un "semáforo" que decide qué widget mostrar:
/// - [mobile]: Se muestra por defecto en pantallas estrechas (< 600px).
/// - [tablet]: (Opcional) Se muestra en pantallas medianas (600px - 1100px).
/// - [desktop]: (Opcional) Se muestra en pantallas anchas (> 1100px).
/// 
/// Si no se proporcina [tablet] o [desktop], se usará [mobile] (o [tablet] para desktop).
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  static const double kTabletBreakpoint = 600.0;
  static const double kDesktopBreakpoint = 800.0; // ⚡ BAJADO DE 1100 A 800 PARA ACTIVARSE MÁS FÁCIL

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Retorna true si el dispositivo actual se considera "móvil"
  static bool isMobile(BuildContext context) => 
      MediaQuery.of(context).size.width < kTabletBreakpoint;

  /// Retorna true si el dispositivo actual se considera "tablet"
  static bool isTablet(BuildContext context) => 
      MediaQuery.of(context).size.width >= kTabletBreakpoint && 
      MediaQuery.of(context).size.width < kDesktopBreakpoint;

  /// Retorna true si el dispositivo actual se considera "escritorio"
  static bool isDesktop(BuildContext context) => 
      MediaQuery.of(context).size.width >= kDesktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kDesktopBreakpoint) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= kTabletBreakpoint) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}
