import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../features/ads/models/audio_ad_model.dart';
import '../services/audio_service.dart';
import '../utils/logger.dart';

/// ✅ MEJOR PRÁCTICA: Gestor dedicado para inserción de anuncios
/// Maneja toda la lógica de inserción de forma reactiva y profesional
/// Elimina la necesidad de delays arbitrarios y flags de estado
class AdInsertionManager {
  final AudioService audioService;
  
  AdInsertionManager(this.audioService);

  /// Insertar anuncio de forma reactiva usando streams de just_audio
  /// ✅ PROFESIONAL: Usa el stream para detectar cuando el anuncio está listo
  /// en lugar de delays arbitrarios
  Future<bool> insertAd(AudioAd ad, int targetIndex) async {
    // #region agent log
    AppLogger.debugLog('ad_insertion_manager.dart:18', 'insertAd ENTRY', {'adId': ad.id, 'targetIndex': targetIndex}, 'A');
    // #endregion
    try {
      final player = audioService.player;
      
      // #region agent log
      AppLogger.debugLog('ad_insertion_manager.dart:22', 'BEFORE pause check', {'isPlaying': player.playing, 'currentIndex': player.currentIndex}, 'B');
      // #endregion
      
      // 1. Crear AudioSource del anuncio
      final adSource = AudioSource.uri(
        Uri.parse(ad.audioUrl),
        tag: ad,
      );
      
      // 2. Insertar en la cola
      // El AudioPlayer de just_audio 0.10.5+ maneja internamente la cola
      // y expone métodos directos para manipularla.
      if (player.audioSources.isEmpty) {
        AppLogger.warning('[AdInsertionManager] ⚠️ No hay cola activa. Intentando inserción directa no soportada.');
        return false;
      }
      
      // 🔍 LOG: Estado de la cola ANTES de insertar
      AppLogger.info('[AdInsertionManager] 🔍 Estado pre-inserción: Length=${player.audioSources.length}, Index=${player.currentIndex}, Target=$targetIndex');
      
      // ✅ OPTIMIZACIÓN: Insertar anuncio SIN interrumpir la canción actual
      // El anuncio se insertará después de la canción actual, sin hacer seek al inicio
      // Esto evita interrupciones y hace que la inserción sea más limpia
      final currentIndexBeforeInsert = player.currentIndex ?? 0;
      final isCurrentlyPlaying = player.playing;
      
      // #region agent log
      AppLogger.debugLog('ad_insertion_manager.dart:37', 'BEFORE insert', {
        'isCurrentlyPlaying': isCurrentlyPlaying,
        'currentIndex': currentIndexBeforeInsert,
        'targetIndex': targetIndex
      }, 'B');
      // #endregion
      
      // ✅ OPTIMIZACIÓN: Solo pausar si realmente es necesario (cuando vamos a hacer seek)
      // Si la canción está reproduciéndose y vamos a insertar después de ella, no necesitamos pausar
      // Solo pausaremos cuando hagamos el seek al anuncio
      
      // ✅ OPTIMIZACIÓN: Insertar anuncio directamente sin interrumpir la canción actual
      // El anuncio se insertará en la posición correcta y luego haremos seek cuando sea necesario
      AppLogger.info('[AdInsertionManager] 🛠️ Intentando insertar en cola interna (Length: ${player.audioSources.length})...');
      await player.insertAudioSource(targetIndex, adSource);
      AppLogger.info('[AdInsertionManager] ✅ Anuncio insertado en índice $targetIndex sin interrumpir reproducción actual (Nueva longitud: ${player.audioSources.length})');
        
        // #region agent log
        AppLogger.debugLog('ad_insertion_manager.dart:61', 'AFTER insert', {'currentIndex': player.currentIndex, 'playing': player.playing}, 'A');
        // #endregion
        
        // ✅ FIX CRÍTICO: Verificar inmediatamente después de insertar que el anuncio esté en la cola
        final sequenceStateAfterInsert = player.sequenceState;
        if (targetIndex >= sequenceStateAfterInsert.sequence.length) {
          AppLogger.error('[AdInsertionManager] ❌ El anuncio no se insertó correctamente en el índice $targetIndex');
          return false;
        }
        
        final sourceAfterInsert = sequenceStateAfterInsert.sequence[targetIndex];
        if (sourceAfterInsert.tag is! AudioAd || (sourceAfterInsert.tag as AudioAd).id != ad.id) {
          AppLogger.error('[AdInsertionManager] ❌ El anuncio insertado no coincide en el índice $targetIndex');
          return false;
        }
        
      // 🎯 PATRÓN "PROXY SOURCE": Solo insertar el anuncio en la cola
      // El reproductor nativo (ExoPlayer) manejará la transición automáticamente cuando la canción termine
      // NO hacer seek ni pausar - dejar que el reproductor nativo haga su trabajo
      AppLogger.info('[AdInsertionManager] 🎯 [PROXY SOURCE] Anuncio insertado en índice $targetIndex - el reproductor nativo manejará la transición automáticamente');
      
      // #region agent log
      AppLogger.debugLog('ad_insertion_manager.dart:112', 'insertAd EXIT success', {'playing': player.playing, 'currentIndex': player.currentIndex}, 'A');
      // #endregion
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[AdInsertionManager] Error al insertar anuncio: $e', stackTrace);
      return false;
    }
  }
  
  /// Eliminar anuncio de un índice específico
  Future<bool> removeAdAt(int index) async {
    try {
      final player = audioService.player;
      // El AudioPlayer de just_audio 0.10.5+ maneja internamente la cola.
      if (player.audioSources.isEmpty) {
        AppLogger.warning('[AdInsertionManager] No hay cola activa para eliminar anuncio');
        return false;
      }
      
      final sequenceState = player.sequenceState;
      if (index < 0 || index >= sequenceState.sequence.length) {
        AppLogger.warning('[AdInsertionManager] Índice $index fuera de rango');
        return false;
      }
      
      final source = sequenceState.sequence[index];
      if (source.tag is! AudioAd) {
        AppLogger.warning('[AdInsertionManager] El índice $index no contiene un anuncio');
        return false;
      }
      
      await player.removeAudioSourceAt(index);
      AppLogger.info('[AdInsertionManager] ✅ Anuncio eliminado del índice $index');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[AdInsertionManager] Error al eliminar anuncio: $e', stackTrace);
      return false;
    }
  }
  
}

