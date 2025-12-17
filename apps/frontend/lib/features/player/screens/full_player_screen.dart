import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/services/player_navigation_service.dart';
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
    // ✅ FIX: Cerrar el reproductor completo cuando se desmonta
    // Asegurar que se cierre inmediatamente para evitar bloqueos
    try {
      ref.read(unifiedAudioProviderFixed.notifier).closeFullPlayer();
    } catch (e) {
      // Ignorar errores si el provider ya fue disposed
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ OPTIMIZACIÓN: Escuchar tanto canción como anuncio
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    final currentSong = playbackState.lastConfirmedSong ?? playbackState.currentSong;
    final isPlayingAd = playbackState.isPlayingAd;
    
    // ✅ FIX: Abrir el reproductor completo cuando se construye, pero solo una vez
    // Usar un flag para evitar múltiples llamadas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final audioState = ref.read(unifiedAudioProviderFixed);
        if (!audioState.isPlayerExpanded) {
          ref.read(unifiedAudioProviderFixed.notifier).openFullPlayer();
        }
      }
    });

    // ✅ FIX: Si no hay canción ni anuncio, regresar de forma segura
    // ✅ CORRECCIÓN: Usar Future.delayed para evitar conflictos con animaciones Hero
    if (currentSong == null && !isPlayingAd) {
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
        
        // ✅ MEJOR PRÁCTICA: Usar servicio centralizado para cerrar
        if (mounted && context.mounted) {
          await PlayerNavigationService.closeFullPlayer(
            context: context,
            ref: ref,
          );
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
              // Key única basada en el ID de la canción o anuncio para forzar reconstrucción cuando cambia
              ProfessionalAudioPlayer(
                key: ValueKey(
                  isPlayingAd 
                      ? 'full_player_ad_${playbackState.currentAd?.id ?? 'none'}'
                      : 'full_player_${currentSong?.id ?? 'none'}',
                ),
              ),
              
              // Botón de cerrar - OPTIMIZADO con const
              Positioned(
                top: 12,
                left: 16,
                child: SafeArea(
                  child: RepaintBoundary(
                    child: _CloseButton(
                      onPressed: () async {
                        if (mounted && context.mounted) {
                          // ✅ MEJOR PRÁCTICA: Usar servicio centralizado para cerrar
                          await PlayerNavigationService.closeFullPlayer(
                            context: context,
                            ref: ref,
                          );
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
