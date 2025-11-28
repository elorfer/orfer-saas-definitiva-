import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../utils/logger.dart';

/// Botón de favorito reutilizable con animaciones chidas
/// Muestra un corazón que cambia de estado al tocar con efectos visuales
class FavoriteButton extends ConsumerStatefulWidget {
  final String songId;
  final bool? isFavorite; // Opcional: si se proporciona, se usa este valor inicial
  final Color? iconColor;
  final double? iconSize;
  final VoidCallback? onToggle; // Callback opcional cuando cambia el estado

  const FavoriteButton({
    super.key,
    required this.songId,
    this.isFavorite,
    this.iconColor,
    this.iconSize,
    this.onToggle,
  });

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _particlesController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  
  bool _isToggling = false;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    
    // Controlador de escala (bounce effect)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.4).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 1.0).chain(
          CurveTween(curve: Curves.elasticOut),
        ),
        weight: 50,
      ),
    ]).animate(_scaleController);
    
    // Controlador de rotación
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Controlador de pulso (para cuando está activo)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Controlador de partículas
    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isToggling) return;

    setState(() {
      _isToggling = true;
      _showParticles = true;
    });

    try {
      // Animaciones simultáneas chidas
      await Future.wait([
        _scaleController.forward(),
        _rotationController.forward(),
        _particlesController.forward(),
      ]);

      // Toggle en el provider
      await ref.read(favoritesProvider.notifier).toggleFavorite(widget.songId);

      // Callback opcional
      widget.onToggle?.call();
      
      // Resetear animaciones
      _scaleController.reset();
      _rotationController.reset();
      
      // Ocultar partículas después de un delay
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _showParticles = false;
          });
          _particlesController.reset();
        }
      });
    } catch (e, stackTrace) {
      AppLogger.error('[FavoriteButton] Error al toggle favorito: $e', stackTrace);
      
      // Resetear animaciones en caso de error
      _scaleController.reset();
      _rotationController.reset();
      _particlesController.reset();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar favorito: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observar el estado de favoritos
    final favoritesState = ref.watch(favoritesProvider);
    
    // Determinar si es favorita
    // Prioridad: 1) prop isFavorite, 2) estado del provider
    final isFavorite = widget.isFavorite ?? favoritesState.isFavorite(widget.songId);
    
    final iconColor = widget.iconColor ?? Colors.white;
    final iconSize = widget.iconSize ?? 24.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Partículas de fondo (solo cuando se agrega a favoritos)
        if (_showParticles && isFavorite)
          ...List.generate(8, (index) {
            final angle = (index * 2 * math.pi) / 8;
            return AnimatedBuilder(
              animation: _particlesController,
              builder: (context, child) {
                final progress = _particlesController.value;
                final distance = progress * 30;
                final opacity = 1.0 - progress;
                
                return Positioned(
                  left: math.cos(angle) * distance,
                  top: math.sin(angle) * distance,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        
        // Icono principal con animaciones
        RotationTransition(
          turns: _rotationAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedBuilder(
              animation: isFavorite ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
              builder: (context, child) {
                return Transform.scale(
                  scale: isFavorite ? _pulseAnimation.value : 1.0,
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : iconColor,
                      size: iconSize,
                    ),
                    onPressed: _isToggling ? null : _handleTap,
                    tooltip: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

