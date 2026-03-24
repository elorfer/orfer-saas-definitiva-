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
  // Spotify Style: MÃ¡s slider, menos 3D para rendimiento mÃ¡ximo
  final double maxSlide = 280.0; // Un poco mÃ¡s ancho para dejar ver mÃ¡s menÃº
  
  // Trackear direcciÃ³n del arrastre para umbrales asimÃ©tricos
  bool _isOpeningDirection = true;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // âš¡ OPTIMIZACIÃ“N: 250ms para sensaciÃ³n instantÃ¡nea
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
    // ðŸ”¥ OPTIMIZACIÃ“N "ZERO LAG" + "DIRECT TOUCH" + "EDGE SWIPE":
    // 1. Edge Swipe: Abrir desde el borde izquierdo (eliminamos Bypass).
    // 2. Drag 1:1: Control total del movimiento.
    // 3. Curve: easeOutQuart para respuesta rÃ¡pida inicial y frenado suave.
    
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
              // A. El MenÃº (Solo visible si hay apertura para ahorrar GPU)
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

              // B. La App Principal (MÃ³vil)
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
                              Colors.black.withValues(alpha: 0.1), 
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
                    
                    // B3. DETECTOR PANTALLA COMPLETA (Solo cuando estÃ¡ ABIERTO o MOVIÃ‰NDOSE)
                    // Permite cerrar tocando o arrastrando desde cualquier lado.
                     // B3. DETECTOR PANTALLA COMPLETA (Solo cuando estÃ¡ ABIERTO o MOVIÃ‰NDOSE)
                    // Permite cerrar tocando o arrastrando desde cualquier lado.
                    if (_controller.value > 0)
                      Positioned.fill(
                        child: GestureDetector(
                           onTap: toggle,
                           behavior: HitTestBehavior.translucent, // Deja pasar toques visuales, captura drags
                           onHorizontalDragUpdate: (details) {
                              // Drag reverso (Cerrar) O Forward
                              // Actualizar direcciÃ³n para la fÃ­sica al soltar
                              if (details.primaryDelta! != 0) {
                                _isOpeningDirection = details.primaryDelta! > 0;
                              }
                              _controller.value += details.primaryDelta! / maxSlide;
                           },
                            onHorizontalDragEnd: (details) {
                              // ðŸ”¥ ACTUALIZACIÃ“N: FÃ­sica AsimÃ©trica
                              // 1. Velocidad (Fling): Prioridad absoluta.
                              // 2. PosiciÃ³n:
                              //    - Si estaba ABRIENDO: Umbral = Mitad del Drawer (MÃ¡s fÃ¡cil de abrir)
                              //    - Si estaba CERRANDO: Umbral = Mitad de la Pantalla (MÃ¡s fÃ¡cil de cerrar/devolver)
                              
                              final double velocity = details.velocity.pixelsPerSecond.dx;
                              final double currentSlide = maxSlide * _controller.value;
                              final double screenWidth = MediaQuery.of(context).size.width;
                              
                              // Definir el umbral segÃºn la intenciÃ³n (direcciÃ³n)
                              double snapThreshold;
                              if (_isOpeningDirection) {
                                // âœ… FIX: Umbral reducido al 30% para que sea MÃS FÃCIL abrir
                                // Antes 50% requerÃ­a arrastrar mucho. Ahora con un pequeÃ±o arrastre ya se abre.
                                snapThreshold = maxSlide * 0.3;
                              } else {
                                // "Para CERRAR se toma LA MITAD DE LA PANTALLA"
                                snapThreshold = (screenWidth * 0.5).clamp(50.0, maxSlide - 10.0);
                              }

                              if (velocity.abs() > 400) {
                                // FLING: Movimiento rÃ¡pido manda
                                if (velocity > 0) {
                                  _controller.forward();
                                } else {
                                  _controller.reverse();
                                }
                              } else {
                                // DRAG STOP: DecisiÃ³n por umbral asimÃ©trico
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
                              // Logica duplicada para consistencia (Mismo comportamiento asimÃ©trico)
                              final double velocity = details.velocity.pixelsPerSecond.dx;
                              final double currentSlide = maxSlide * _controller.value;
                              final double screenWidth = MediaQuery.of(context).size.width;
                              
                              double snapThreshold;
                              if (_isOpeningDirection) {
                                snapThreshold = maxSlide * 0.3; // âœ… 30% para abrir fÃ¡cil
                              } else {
                                snapThreshold = (screenWidth * 0.5).clamp(50.0, maxSlide - 10.0);
                              }
                              
                              if (velocity.abs() > 400) {
                                if (velocity > 0) {
                                  _controller.forward();
                                } else {
                                  _controller.reverse();
                                }
                              } else {
                                if (currentSlide > snapThreshold) {
                                  _controller.forward();
                                } else {
                                  _controller.reverse();
                                }
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

