import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';
import 'dart:convert';
import 'dart:async';

/// Provider del historial de reproducción
/// 🛡️ Usando Notifier regular para evitar problemas con state después de async
class PlayHistoryNotifier extends Notifier<List<Song>> {
  static const String _historyKey = 'play_history';
  static const int _maxHistorySize = 50;
  static const Duration _saveDebounceDuration = Duration(seconds: 1);

  Timer? _saveDebounceTimer;
  bool _isMounted = true;

  @override
  List<Song> build() {
    _isMounted = true;
    ref.onDispose(() {
      _isMounted = false;
      _saveDebounceTimer?.cancel();
    });
    _loadHistoryFromLocal();
    return [];
  }

  /// Agregar canción al historial (solo si no es la misma que la última)
  void addToHistory(Song song) {
    final current = state;
    
    // Solo agregar si está vacío o si no es la misma canción que la última
    if (current.isEmpty || current.last.id != song.id) {
      
      // ✅ SANITIZACIÓN: Asegurar que guardamos URLs válidas/normalizadas
      // Esto corrige el bug donde se guardan IPs viejas (192.168...) en el historial
      String? cleanCover = song.coverArtUrl;
      if (cleanCover != null) {
          cleanCover = UrlNormalizer.normalizeImageUrl(cleanCover);
      }
      
      String? cleanFile = song.fileUrl;
      // Solo normalizar si parece una URL completa y no es nula
      if (cleanFile != null && cleanFile.isNotEmpty && (cleanFile.startsWith('http') || cleanFile.startsWith('/'))) {
         try {
           cleanFile = UrlNormalizer.normalizeUrl(cleanFile);
         } catch (_) {
           // Si falla normalización (ej. url extraña), mantener original
         }
      }

      final sanitizedSong = song.copyWith(
          coverArtUrl: cleanCover,
          fileUrl: cleanFile,
      );

      final newHistory = [...current, sanitizedSong];
      
      // Limitar tamaño del historial
      if (newHistory.length > _maxHistorySize) {
        newHistory.removeAt(0);
      }
      
      state = newHistory;
      _scheduleSaveDebounced();
      
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
    _scheduleSaveDebounced();
    
    AppLogger.info('[PlayHistory] ⏮️ Canción anterior: ${previous.title}');
    return previous;
  }

  /// Limpiar historial
  void clearHistory() {
    state = [];
    _saveHistoryToLocal();
    AppLogger.info('[PlayHistory] 🗑️ Historial limpiado');
  }

  void _scheduleSaveDebounced() {
    if (!_isMounted) return; // 🛡️ No programar si ya fue disposed
    try {
      _saveDebounceTimer?.cancel();
      _saveDebounceTimer = Timer(_saveDebounceDuration, () {
        if (_isMounted) {
          _saveHistoryToLocal();
        }
      });
    } catch (e) {
      AppLogger.error('[PlayHistory] ❌ Error programando guardado: $e');
    }
  }

  /// Guardar historial en almacenamiento local
  Future<void> _saveHistoryToLocal() async {
    if (!_isMounted) return; // 🛡️ No guardar si ya fue disposed
    try {
      final currentState = state; // Capturar estado antes de async
      final prefs = await SharedPreferences.getInstance();
      if (!_isMounted) return; // 🛡️ Verificar después de async
      
      final ids = currentState.map((s) => s.id).toList();
      await prefs.setStringList(_historyKey, ids);
      
      // Guardar también los datos completos de las canciones (serializadas)
      final songsJson = currentState.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList('${_historyKey}_data', songsJson);
      
      AppLogger.info('[PlayHistory] 💾 Historial guardado: ${ids.length} canciones');
    } catch (e) {
      if (_isMounted) {
        AppLogger.error('[PlayHistory] ❌ Error guardando historial: $e');
      }
    }
  }

  /// Cargar historial desde almacenamiento local
  Future<void> _loadHistoryFromLocal() async {
    if (!_isMounted) return; // 🛡️ No cargar si ya fue disposed
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isMounted) return; // 🛡️ Verificar después de async
      
      final songsJson = prefs.getStringList('${_historyKey}_data') ?? [];
      
      if (songsJson.isEmpty) {
        AppLogger.info('[PlayHistory] 📂 No hay historial guardado');
        return;
      }

      final decodedList = <Map<String, dynamic>>[];
      for (final s in songsJson) {
        try {
          final d = jsonDecode(s);
          if (d is Map<String, dynamic>) decodedList.add(d);
        } catch (_) {}
      }

      List<Song> loadedSongs = [];
      if (decodedList.isNotEmpty) {
        try {
          loadedSongs = await Song.parseList(decodedList);
        } catch (_) {
          // Fallback individual parse
          for (final m in decodedList) {
            try {
              loadedSongs.add(Song.fromJson(m));
            } catch (_) {}
          }
        }
      }

      if (_isMounted) {
        // ✅ FIX RACE CONDITION: Mezclar historial cargado con canciones añadidas mientras cargaba
        // Si addToHistory se llamó antes de que esto terminara, 'state' ya tiene canciones nuevas
        final pendingSongs = state;
        
        if (pendingSongs.isEmpty) {
            state = loadedSongs;
        } else {
            // Combinar: Historial antiguo + Canciones nuevas pendientes
            // Evitar duplicar si la última de disco es igual a la primera nueva
            final merged = [...loadedSongs];
            
            for (final newSong in pendingSongs) {
                if (merged.isEmpty || merged.last.id != newSong.id) {
                    merged.add(newSong);
                }
            }
            state = merged;
            // Guardar inmediatamente la fusión para persistir lo nuevo
            _scheduleSaveDebounced();
        }
        
        AppLogger.info('[PlayHistory] 📂 Historial cargado y fusionado: ${state.length} canciones');
      }
    } catch (e) {
      if (_isMounted) {
        AppLogger.error('[PlayHistory] ❌ Error cargando historial: $e');
      }
    }
  }

  /// Obtener historial ordenado (más reciente primero)
  List<Song> getRecentHistory({int limit = 50}) {
    final history = List<Song>.from(state.reversed);
    return history.take(limit).toList();
  }
}

/// Provider del historial de reproducción
/// 🛡️ Usando NotifierProvider regular para evitar problemas de dispose durante async
final playHistoryProvider = NotifierProvider<PlayHistoryNotifier, List<Song>>(() {
  return PlayHistoryNotifier();
});










