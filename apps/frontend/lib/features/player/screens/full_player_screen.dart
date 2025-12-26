import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final currentAd = playbackState.currentAd;
    final isInsertingAd = playbackState.isInsertingAd;
    
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

    // ✅ FIX CRÍTICO: NO cerrar el reproductor durante transiciones (skip ad, cambio de canción)
    // Esperar un poco más para permitir que el estado se sincronice después de saltar anuncio
    final hasAnyContent = currentSong != null || isPlayingAd || currentAd != null || isInsertingAd;
    
    if (!hasAnyContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          // ✅ AUMENTAR delay para dar tiempo a que se sincronice el estado después de skip
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && context.mounted) {
              // Verificar una vez más antes de cerrar
              final finalState = ref.read(unifiedAudioProviderFixed);
              final stillNoContent = finalState.currentSong == null && 
                                   !finalState.isPlayingAd && 
                                   finalState.currentAd == null;
              
              if (stillNoContent) {
                try {
                  PlayerNavigationService.closeFullPlayer(
                    context: context,
                    ref: ref,
                  );
                } catch (e) {
                  // Ignorar errores de navegación si el contexto ya no es válido
                }
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
              // 🆕 FIX PARPADEO: Eliminada la Key dinámica que causaba reconstrucción
              // al cambiar de canción, reiniciando el estado del Seekbar
              const ProfessionalAudioPlayer(),
              
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
