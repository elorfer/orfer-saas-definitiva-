import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../utils/logger.dart';

/// Servicio centralizado para manejar la navegación del reproductor
/// ✅ SIMPLIFICADO: Ya no usa GoRouter. El SpotifyPlayerSheet maneja las animaciones
/// directamente como overlay en el widget tree.
class PlayerNavigationService {

  /// Abrir el reproductor extendido de forma segura.
  /// El SpotifyPlayerSheet escucha `isPlayerExpanded` y anima automáticamente.
  static void openFullPlayer({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    try {
      final audioState = ref.read(unifiedAudioProviderFixed);
      final hasContent = audioState.currentSong != null || audioState.currentAd != null;
      if (!hasContent || audioState.isPlayerExpanded) return;

      ref.read(unifiedAudioProviderFixed.notifier).openFullPlayer();
    } catch (e, stackTrace) {
      AppLogger.error('[PlayerNavigationService] Error al abrir reproductor: $e', stackTrace);
    }
  }

  /// Cerrar el reproductor extendido de forma segura.
  /// El SpotifyPlayerSheet escucha `isPlayerExpanded` y anima automáticamente.
  static void closeFullPlayer({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    try {
      ref.read(unifiedAudioProviderFixed.notifier).closeFullPlayer();
    } catch (e, stackTrace) {
      AppLogger.error('[PlayerNavigationService] Error al cerrar reproductor: $e', stackTrace);
    }
  }

  /// Verificar si se puede abrir el reproductor extendido
  static bool canOpenFullPlayer(WidgetRef ref) {
    try {
      final audioState = ref.read(unifiedAudioProviderFixed);
      final hasContent = audioState.currentSong != null || audioState.currentAd != null;
      final isNotExpanded = !audioState.isPlayerExpanded;
      return hasContent && isNotExpanded;
    } catch (e) {
      return false;
    }
  }
}
