import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/widgets/professional_audio_player.dart';
import '../../../core/theme/neumorphism_theme.dart';

/// Pantalla del reproductor completo
/// Se abre cuando el usuario toca el mini player
class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(unifiedAudioProviderFixed);

    // Si no hay canción, regresar
    if (audioState.currentSong == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.pop();
        }
      });
      return const Scaffold(
        backgroundColor: NeumorphismTheme.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      body: Stack(
        children: [
          // Reproductor profesional completo
          const ProfessionalAudioPlayer(),
          
          // Botón de cerrar en la esquina izquierda
          Positioned(
            top: 12,
            left: 16,
            child: SafeArea(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
