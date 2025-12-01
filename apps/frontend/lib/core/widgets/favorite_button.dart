import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../utils/logger.dart';

/// Botón de favorito optimizado con animación sencilla y eficiente
/// Animación simple de escala tipo "bounce" rápido
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
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    
    // 🆕 Controlador único de escala - Animación rápida y suave
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Más rápido
    );
    
    // 🆕 Animación simple de escala tipo bounce suave
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2, // Escala más pequeña para ser más sutil
    ).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOut, // Curva suave sin rebote excesivo
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isToggling) return;

    setState(() {
      _isToggling = true;
    });

    try {
      // 🆕 Animación simple: escala hacia arriba y luego vuelve
      await _scaleController.forward();
      await _scaleController.reverse();

      // Toggle en el provider
      await ref.read(favoritesProvider.notifier).toggleFavorite(widget.songId);

      // Callback opcional
      widget.onToggle?.call();
    } catch (e, stackTrace) {
      AppLogger.error('[FavoriteButton] Error al toggle favorito: $e', stackTrace);
      
      // Resetear animación en caso de error
      _scaleController.reset();
      
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

    // 🆕 Widget simple con solo animación de escala
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? Colors.red : iconColor,
          size: iconSize,
        ),
        onPressed: _isToggling ? null : _handleTap,
        tooltip: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
        padding: EdgeInsets.zero, // 🆕 Sin padding para mejor rendimiento
        constraints: const BoxConstraints(), // 🆕 Sin constraints innecesarios
      ),
    );
  }
}

