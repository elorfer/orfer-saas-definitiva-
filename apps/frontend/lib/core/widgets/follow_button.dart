import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/follow_provider.dart';
import '../utils/logger.dart';
import '../theme/neumorphism_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Botón para seguir/dejar de seguir un artista
/// Estados: "Seguir" (azul) / "Siguiendo" (oscuro, borde blanco)
class FollowButton extends ConsumerStatefulWidget {
  final String artistId;
  final bool? isFollowing; // Opcional: si se proporciona, se usa este valor inicial
  final VoidCallback? onToggle; // Callback opcional cuando cambia el estado
  final double? width;
  final double? height;
  final bool compact; // Si true, muestra solo el icono

  const FollowButton({
    super.key,
    required this.artistId,
    this.isFollowing,
    this.onToggle,
    this.width,
    this.height,
    this.compact = false,
  });

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOut,
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
      // Animación
      await _scaleController.forward();
      await _scaleController.reverse();

      // Obtener estado actual
      final followNotifier = ref.read(followProvider.notifier);
      final currentlyFollowing = widget.isFollowing ?? 
          ref.read(followProvider).isFollowing(widget.artistId);

      // Toggle en el provider
      if (currentlyFollowing) {
        await followNotifier.unfollowArtist(widget.artistId);
      } else {
        await followNotifier.followArtist(widget.artistId);
      }

      // Callback opcional
      widget.onToggle?.call();
    } catch (e, stackTrace) {
      AppLogger.error('[FollowButton] Error al toggle seguimiento: $e', stackTrace);
      
      _scaleController.reset();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
    // Observar el estado de seguimiento
    final followState = ref.watch(followProvider);
    
    // Determinar si está siguiendo
    final isFollowing = widget.isFollowing ?? followState.isFollowing(widget.artistId);
    
    if (widget.compact) {
      // Versión compacta: solo icono
      return ScaleTransition(
        scale: _scaleAnimation,
        child: IconButton(
          icon: Icon(
            isFollowing ? Icons.check_circle : Icons.add_circle_outline,
            color: isFollowing ? NeumorphismTheme.accentDark : NeumorphismTheme.accent,
            size: 28,
          ),
          onPressed: _isToggling ? null : _handleTap,
          tooltip: isFollowing ? 'Dejar de seguir' : 'Seguir',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    }

    // Versión completa: botón con texto
    final buttonHeight = widget.height ?? 36.0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.width ?? 130.0,
          minHeight: buttonHeight,
        ),
        child: OutlinedButton(
          onPressed: _isToggling ? null : _handleTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: isFollowing 
                ? NeumorphismTheme.accentDark 
                : Colors.transparent,
            foregroundColor: isFollowing 
                ? Colors.white 
                : NeumorphismTheme.accent,
            side: BorderSide(
              color: isFollowing 
                  ? Colors.white 
                  : NeumorphismTheme.accent,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: buttonHeight <= 32 ? 10 : 12, 
              vertical: buttonHeight <= 32 ? 6 : 8,
            ),
            minimumSize: Size(0, buttonHeight),
            elevation: 0,
          ),
          child: _isToggling
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFollowing ? Colors.white : NeumorphismTheme.accent,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFollowing ? Icons.check : Icons.add,
                      size: buttonHeight <= 32 ? 14 : 16, // Más pequeño si height <= 32
                      color: isFollowing 
                          ? Colors.white 
                          : NeumorphismTheme.accent,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        isFollowing ? 'Siguiendo' : 'Seguir',
                        style: GoogleFonts.inter(
                          fontSize: buttonHeight <= 32 ? 12 : 13, // Más pequeño si height <= 32
                          fontWeight: FontWeight.w600,
                          color: isFollowing 
                              ? Colors.white 
                              : NeumorphismTheme.accent,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

