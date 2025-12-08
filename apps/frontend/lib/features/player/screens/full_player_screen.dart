import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/widgets/professional_audio_player.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// Pantalla del reproductor completo
/// Se abre cuando el usuario toca el mini player
/// OPTIMIZADO: Usa select para evitar rebuilds innecesarios
class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Cerrar el reproductor completo cuando se desmonta
    Future.microtask(() {
      try {
        ref.read(unifiedAudioProviderFixed.notifier).closeFullPlayer();
      } catch (e) {
        // Ignorar errores si el provider ya fue disposed
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Abrir el reproductor completo cuando se construye
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(unifiedAudioProviderFixed.notifier).openFullPlayer();
      }
    });
    
    // ✅ OPTIMIZACIÓN: Solo escuchar currentSong, no todo el estado
    final currentSong = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentSong),
    );

    // Si no hay canción, regresar de forma segura
    // ✅ CORRECCIÓN: Usar Future.delayed para evitar conflictos con animaciones Hero
    if (currentSong == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          // Pequeño delay para permitir que las animaciones Hero terminen
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && context.mounted) {
              try {
                context.pop();
              } catch (e) {
                // Ignorar errores de navegación si el contexto ya no es válido
              }
            }
          });
        }
      });
      return const Scaffold(
        backgroundColor: NeumorphismTheme.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ✅ OPTIMIZACIÓN: Mostrar UI básica primero, luego cargar fondo premium
    return PopScope(
      canPop: false, // ✅ Prevenir cierre automático con botón de retroceso
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return; // Ya se cerró, no hacer nada
        
        // ✅ Manejar cierre del reproductor sin afectar la reproducción
        if (mounted && context.mounted) {
          ref.read(unifiedAudioProviderFixed.notifier).closeFullPlayer();
          if (context.mounted) {
            try {
              context.pop();
            } catch (e) {
              // Ignorar errores de navegación si el contexto ya no es válido
            }
          }
        }
      },
      child: RepaintBoundary(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true, // ✅ Extender el body debajo del sistema
          extendBodyBehindAppBar: true, // ✅ Extender detrás de la app bar
          body: RepaintBoundary(
          child: Stack(
            children: [
              // ✅ Reproductor profesional completo (con fondo lazy)
              // Key única basada en el ID de la canción para forzar reconstrucción cuando cambia
              ProfessionalAudioPlayer(key: ValueKey('full_player_${currentSong.id}')),
              
              // Botón de cerrar - OPTIMIZADO con const
              Positioned(
                top: 12,
                left: 16,
                child: SafeArea(
                  child: RepaintBoundary(
                    child: _CloseButton(
                      onPressed: () {
                        if (mounted && context.mounted) {
                          ref.read(unifiedAudioProviderFixed.notifier).closeFullPlayer();
                          try {
                            context.pop();
                          } catch (e) {
                            // Ignorar errores de navegación si el contexto ya no es válido
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// Botón de cerrar optimizado como widget separado
class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
