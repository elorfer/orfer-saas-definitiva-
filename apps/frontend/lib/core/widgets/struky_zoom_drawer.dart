import 'package:flutter/material.dart';

class StrukyZoomDrawer extends StatefulWidget {
  final Widget menuScreen;
  final Widget mainScreen;

  const StrukyZoomDrawer({
    super.key, 
    required this.menuScreen, 
    required this.mainScreen
  });

  @override
  State<StrukyZoomDrawer> createState() => StrukyZoomDrawerState();
}

class StrukyZoomDrawerState extends State<StrukyZoomDrawer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // Spotify Style: Más slider, menos 3D para rendimiento máximo
  final double maxSlide = 280.0; // Un poco más ancho para dejar ver más menú
  
  // Trackear dirección del arrastre para umbrales asimétricos
  bool _isOpeningDirection = true;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // ⚡ OPTIMIZACIÓN: 250ms para sensación instantánea
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggle() {
    if (_controller.isDismissed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }
  
  bool get isOpen => !_controller.isDismissed;

  @override
  Widget build(BuildContext context) {
    // 🔥 OPTIMIZACIÓN "ZERO LAG" + "DIRECT TOUCH" + "EDGE SWIPE":
    // 1. Edge Swipe: Abrir desde el borde izquierdo (eliminamos Bypass).
    // 2. Drag 1:1: Control total del movimiento.
    // 3. Curve: easeOutQuart para respuesta rápida inicial y frenado suave.
    
    final animation = CurvedAnimation(
      parent: _controller, 
      curve: Curves.easeOutQuart, 
      reverseCurve: Curves.easeInQuart,
    );

    return AnimatedBuilder(
      animation: _controller,
      child: widget.mainScreen, 
      builder: (context, cachedMainScreen) {
        
        // NO HAY BYPASS: Necesitamos renderizar siempre para detectar el gesto en el borde.
        // ColoredBox es tan barato que no impacta el rendimiento.

        double slide = maxSlide * animation.value;

        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor, 
          child: Stack(
            children: [
              // A. El Menú (Solo visible si hay apertura para ahorrar GPU)
              if (_controller.value > 0)
                Positioned.fill(
                  child: RepaintBoundary( 
                    child: SafeArea(
                      child: Align(
                         alignment: Alignment.centerLeft,
                         child: SizedBox(
                          width: maxSlide,
                          child: widget.menuScreen,
                         ),
                      ),
                    ),
                  ),
                ),

              // B. La App Principal (Móvil)
              Transform.translate(
                offset: Offset(slide, 0),
                child: Stack( // Stack wrapper para Sombra + Contenido + Gestos
                  clipBehavior: Clip.none, 
                  children: [
                    // B1. Sombra "Zero Cost" (Gradient Strip)
                    Positioned(
                      left: -15, 
                      top: 0, 
                      bottom: 0,
                      width: 15,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.1), 
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),

                    // B2. El Contenido Real
                    RepaintBoundary(
                      child: cachedMainScreen, 
                    ),
                    
                    // B3. DETECTOR PANTALLA COMPLETA (Solo cuando está ABIERTO o MOVIÉNDOSE)
                    // Permite cerrar tocando o arrastrando desde cualquier lado.
                     // B3. DETECTOR PANTALLA COMPLETA (Solo cuando está ABIERTO o MOVIÉNDOSE)
                    // Permite cerrar tocando o arrastrando desde cualquier lado.
                    if (_controller.value > 0)
                      Positioned.fill(
                        child: GestureDetector(
                           onTap: toggle,
                           behavior: HitTestBehavior.translucent, // Deja pasar toques visuales, captura drags
                           onHorizontalDragUpdate: (details) {
                              // Drag reverso (Cerrar) O Forward
                              // Actualizar dirección para la física al soltar
                              if (details.primaryDelta! != 0) {
                                _isOpeningDirection = details.primaryDelta! > 0;
                              }
                              _controller.value += details.primaryDelta! / maxSlide;
                           },
                            onHorizontalDragEnd: (details) {
                              // 🔥 ACTUALIZACIÓN: Física Asimétrica
                              // 1. Velocidad (Fling): Prioridad absoluta.
                              // 2. Posición:
                              //    - Si estaba ABRIENDO: Umbral = Mitad del Drawer (Más fácil de abrir)
                              //    - Si estaba CERRANDO: Umbral = Mitad de la Pantalla (Más fácil de cerrar/devolver)
                              
                              final double velocity = details.velocity.pixelsPerSecond.dx;
                              final double currentSlide = maxSlide * _controller.value;
                              final double screenWidth = MediaQuery.of(context).size.width;
                              
                              // Definir el umbral según la intención (dirección)
                              double snapThreshold;
                              if (_isOpeningDirection) {
                                // ✅ FIX: Umbral reducido al 30% para que sea MÁS FÁCIL abrir
                                // Antes 50% requería arrastrar mucho. Ahora con un pequeño arrastre ya se abre.
                                snapThreshold = maxSlide * 0.3;
                              } else {
                                // "Para CERRAR se toma LA MITAD DE LA PANTALLA"
                                snapThreshold = (screenWidth * 0.5).clamp(50.0, maxSlide - 10.0);
                              }

                              if (velocity.abs() > 400) {
                                // FLING: Movimiento rápido manda
                                if (velocity > 0) {
                                  _controller.forward();
                                } else {
                                  _controller.reverse();
                                }
                              } else {
                                // DRAG STOP: Decisión por umbral asimétrico
                                if (currentSlide > snapThreshold) {
                                  _controller.forward();
                                } else {
                                  _controller.reverse();
                                }
                              }
                           },
                        ),
                      ),

                    // B4. DETECTOR DE BORDE (SIEMPRE ACTIVO)
                    // Permite ABRIR arrastrando desde el borde izquierdo (30px).
                    Positioned(
                       left: 0,
                       top: 0,
                       bottom: 0,
                       width: 30.0, 
                       child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                             if (details.primaryDelta! > 0 || _controller.value > 0) {
                                if (details.primaryDelta! != 0) {
                                  _isOpeningDirection = details.primaryDelta! > 0;
                                }
                                _controller.value += details.primaryDelta! / maxSlide;
                             }
                          },
                          onHorizontalDragEnd: (details) {
                              // Logica duplicada para consistencia (Mismo comportamiento asimétrico)
                              final double velocity = details.velocity.pixelsPerSecond.dx;
                              final double currentSlide = maxSlide * _controller.value;
                              final double screenWidth = MediaQuery.of(context).size.width;
                              
                              double snapThreshold;
                              if (_isOpeningDirection) {
                                snapThreshold = maxSlide * 0.3; // ✅ 30% para abrir fácil
                              } else {
                                snapThreshold = (screenWidth * 0.5).clamp(50.0, maxSlide - 10.0);
                              }
                              
                              if (velocity.abs() > 400) {
                                if (velocity > 0) _controller.forward();
                                else _controller.reverse();
                              } else {
                                if (currentSlide > snapThreshold) _controller.forward();
                                else _controller.reverse();
                              }
                          },
                          child: const ColoredBox(color: Colors.transparent), 
                       ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
