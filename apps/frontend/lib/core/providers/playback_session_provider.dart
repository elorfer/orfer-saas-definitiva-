import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

/// 🎯 FASE 1: Servicio centralizado de playedSongIds con buffer circular
/// 
/// Mantiene un buffer circular de máximo 30 IDs de canciones reproducidas
/// durante la sesión actual. Se usa para construir excludeIds de forma
/// consistente en todo el sistema.
/// 
/// Características:
/// - Buffer circular FIFO (First In, First Out)
/// - Límite estricto de 30 IDs
/// - Solo persiste durante la sesión (no se guarda en disco)
/// - Thread-safe mediante Riverpod
class PlaybackSessionNotifier extends Notifier<List<String>> {
  static const int _maxPlayedSongIds = 40; // 🎯 Límite estricto de 40 IDs (historial corto)

  @override
  List<String> build() {
    AppLogger.info('[PlaybackSession] 🆕 Sesión iniciada - Buffer circular de $_maxPlayedSongIds IDs');
    return [];
  }

  /// Registrar una canción como reproducida
  /// 
  /// Si el buffer ya tiene 30 IDs, elimina el más antiguo (FIFO) antes de agregar el nuevo.
  void registerPlayedSong(String songId) {
    if (songId.isEmpty) {
      AppLogger.warning('[PlaybackSession] ⚠️ Intento de registrar ID vacío');
      return;
    }

    final current = List<String>.from(state);
    
    // Si ya existe, moverlo al final (actualizar orden de "recencia")
    if (current.contains(songId)) {
      current.remove(songId);
      current.add(songId);
      state = current;
      // ⚡ OPTIMIZACIÓN: Log reducido a debug (solo cuando realmente cambia algo importante)
      // AppLogger.debug('[PlaybackSession] 🔄 ID re-registrado: ${songId.substring(0, 8)}... (Total: ${current.length})');
      return;
    }

    // Si el buffer está lleno (30 IDs), eliminar el más antiguo (primero)
    if (current.length >= _maxPlayedSongIds) {
      final removedId = current.removeAt(0); // Eliminar el más antiguo (FIFO)
      AppLogger.debug('[PlaybackSession] 🔄 Buffer lleno - Eliminado ID antiguo: ${removedId.substring(0, 8)}...');
    }

    // Agregar el nuevo ID al final
    current.add(songId);
    state = current;
    
    AppLogger.debug('[PlaybackSession] ➕ Registrada: ${songId.substring(0, 8)}... (Total: ${state.length}/$_maxPlayedSongIds)');
  }

  /// Registrar múltiples canciones (útil cuando se carga una cola completa)
  void registerPlayedSongs(Iterable<String> songIds) {
    for (final songId in songIds) {
      registerPlayedSong(songId);
    }
  }

  /// Obtener todos los IDs reproducidos (para usar como excludeIds)
  /// 
  /// Retorna un Set con máximo [limit] IDs recientes (default 40), ordenados por recencia.
  Set<String> getPlayedSongIds({int limit = _maxPlayedSongIds}) {
    if (state.isEmpty) return {};
    final start = state.length > limit ? state.length - limit : 0;
    return Set<String>.from(state.sublist(start));
  }

  /// Obtener los IDs reproducidos como lista separada por comas (para API)
  /// 
  /// Útil para pasar a endpoints que esperan una cadena separada por comas.
  String getPlayedSongIdsAsString({int limit = _maxPlayedSongIds}) {
    if (state.isEmpty) return '';
    final start = state.length > limit ? state.length - limit : 0;
    return state.sublist(start).join(',');
  }

  /// Limpiar el buffer (útil para resetear la sesión)
  void clear() {
    final count = state.length;
    state = [];
    AppLogger.info('[PlaybackSession] 🗑️ Buffer limpiado ($count IDs eliminados)');
  }

  /// Obtener el número de IDs actuales
  int get count => state.length;

  /// Verificar si un ID está en el buffer
  bool contains(String songId) {
    return state.contains(songId);
  }

  /// Recortar agresivamente el historial (para nueva sesión de algoritmo)
  /// Mantiene solo los últimos [keep] IDs (default 5).
  void trimForNewSession({int keep = 5}) {
    if (state.length <= keep) return;
    final removed = state.length - keep;
    final trimmed = state.sublist(state.length - keep);
    state = trimmed;
    AppLogger.info('[PlaybackSession] ✂️ Historial recortado: $removed IDs eliminados, quedan $keep');
  }
}

/// Provider del servicio de sesión de reproducción
/// 
/// 🚨 IMPORTANTE: NO usar autoDispose porque el buffer debe persistir durante toda la sesión.
/// El estado se mantiene vivo mientras la app esté abierta, permitiendo que el buffer
/// circular de 30 IDs funcione correctamente.
final playbackSessionProvider = NotifierProvider<PlaybackSessionNotifier, List<String>>(() {
  return PlaybackSessionNotifier();
});

