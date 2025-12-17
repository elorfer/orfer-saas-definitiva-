import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../utils/logger.dart';

/// Servicio centralizado para manejar la navegación del reproductor
/// ✅ MEJOR PRÁCTICA: Separar lógica de navegación de los widgets UI
class PlayerNavigationService {
  /// Abrir el reproductor extendido de forma segura
  /// Maneja toda la lógica de estado y navegación en un solo lugar
  static Future<void> openFullPlayer({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      final audioState = ref.read(unifiedAudioProviderFixed);
      
      // Verificar condiciones para abrir
      final hasContent = audioState.currentSong != null || audioState.currentAd != null;
      final isNotExpanded = !audioState.isPlayerExpanded;
      
      if (!hasContent || !isNotExpanded) {
        AppLogger.debug('[PlayerNavigationService] No se puede abrir reproductor: hasContent=$hasContent, isNotExpanded=$isNotExpanded');
        return;
      }
      
      // Actualizar estado ANTES de navegar
      ref.read(unifiedAudioProviderFixed.notifier).openFullPlayer();
      
      // Navegar solo si el contexto sigue montado
      if (context.mounted) {
        await context.push('/player');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[PlayerNavigationService] Error al abrir reproductor: $e', stackTrace);
    }
  }
  
  /// Cerrar el reproductor extendido de forma segura
  /// Maneja toda la lógica de estado y navegación en un solo lugar
  static Future<void> closeFullPlayer({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      // Actualizar estado ANTES de navegar
      ref.read(unifiedAudioProviderFixed.notifier).closeFullPlayer();
      
      // Navegar solo si el contexto sigue montado
      if (context.mounted) {
        context.pop();
      }
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

