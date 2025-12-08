import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import 'dart:convert';

/// Provider del historial de reproducción
class PlayHistoryNotifier extends Notifier<List<Song>> {
  static const String _historyKey = 'play_history';
  static const int _maxHistorySize = 50;

  @override
  List<Song> build() {
    _loadHistoryFromLocal();
    return [];
  }

  /// Agregar canción al historial (solo si no es la misma que la última)
  void addToHistory(Song song) {
    final current = state;
    
    // Solo agregar si está vacío o si no es la misma canción que la última
    if (current.isEmpty || current.last.id != song.id) {
      final newHistory = [...current, song];
      
      // Limitar tamaño del historial
      if (newHistory.length > _maxHistorySize) {
        newHistory.removeAt(0);
      }
      
      state = newHistory;
      _saveHistoryToLocal();
      
      AppLogger.info('[PlayHistory] ➕ Agregada: ${song.title} (Total: ${state.length})');
    }
  }

  /// Obtener canción anterior (elimina la actual y retorna la anterior)
  Song? getPreviousSong() {
    if (state.length < 2) {
      AppLogger.info('[PlayHistory] ⚠️ No hay canción anterior (historial: ${state.length})');
      return null;
    }

    // Eliminar la canción actual
    final newHistory = List<Song>.from(state);
    newHistory.removeLast();
    
    // Retornar la anterior
    final previous = newHistory.last;
    state = newHistory;
    _saveHistoryToLocal();
    
    AppLogger.info('[PlayHistory] ⏮️ Canción anterior: ${previous.title}');
    return previous;
  }

  /// Limpiar historial
  void clearHistory() {
    state = [];
    _saveHistoryToLocal();
    AppLogger.info('[PlayHistory] 🗑️ Historial limpiado');
  }

  /// Guardar historial en almacenamiento local
  Future<void> _saveHistoryToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = state.map((s) => s.id).toList();
      await prefs.setStringList(_historyKey, ids);
      
      // Guardar también los datos completos de las canciones (serializadas)
      final songsJson = state.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList('${_historyKey}_data', songsJson);
      
      AppLogger.info('[PlayHistory] 💾 Historial guardado: ${ids.length} canciones');
    } catch (e) {
      AppLogger.error('[PlayHistory] ❌ Error guardando historial: $e');
    }
  }

  /// Cargar historial desde almacenamiento local
  Future<void> _loadHistoryFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getStringList('${_historyKey}_data') ?? [];
      
      if (songsJson.isEmpty) {
        AppLogger.info('[PlayHistory] 📂 No hay historial guardado');
        return;
      }

      final loadedSongs = songsJson
          .map((json) {
            try {
              return Song.fromJson(jsonDecode(json));
            } catch (e) {
              return null;
            }
          })
          .whereType<Song>()
          .toList();

      state = loadedSongs;
      AppLogger.info('[PlayHistory] 📂 Historial cargado: ${loadedSongs.length} canciones');
    } catch (e) {
      AppLogger.error('[PlayHistory] ❌ Error cargando historial: $e');
    }
  }

  /// Obtener historial ordenado (más reciente primero)
  List<Song> getRecentHistory({int limit = 50}) {
    final history = List<Song>.from(state.reversed);
    return history.take(limit).toList();
  }
}

/// Provider del historial de reproducción
/// ⚡ OPTIMIZACIÓN: autoDispose para liberar memoria cuando no hay listeners
final playHistoryProvider = NotifierProvider.autoDispose<PlayHistoryNotifier, List<Song>>(() {
  return PlayHistoryNotifier();
});










