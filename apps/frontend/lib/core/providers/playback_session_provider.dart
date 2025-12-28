import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

/// 🎯 FASE 3: Servicio de HISTORIAL PERSISTENTE
/// 
/// Mantiene un historial de canciones reproducidas que sobrevive a reinicios de la app.
/// Esencial para evitar repeticiones a largo plazo.
/// 
/// Características:
/// - Persistencia real usando Hive (NoSQL local rápido)
/// - Límite ampliado a 100 IDs (vs 30 en memoria)
/// - Carga asíncrona pero inicialización "optimista" de estado
/// - Manejo thread-safe
class PlaybackSessionNotifier extends Notifier<List<String>> {
  static const int _maxPlayedSongIds = 100; // 🎯 Límite aumentado para historial persistente
  static const String _boxName = 'playback_history_v1';
  static const String _historyKey = 'played_songs_list';
  
  Box? _box;
  bool _isInitialized = false;

  @override
  List<String> build() {
    // Iniciar carga asíncrona sin bloquear la UI
    _initPersistence();
    return []; // Estado inicial vacío mientras carga
  }

  /// Inicializar Hive y cargar historial
  Future<void> _initPersistence() async {
    if (_isInitialized) return;

    try {
      // 1. Inicializar Hive si no se ha hecho (seguro de llamar múltiples veces)
      await Hive.initFlutter();

      // 2. Abrir la caja
      _box = await Hive.openBox(_boxName);
      
      // 3. Cargar datos guardados
      final savedHistory = _box?.get(_historyKey);
      
      if (savedHistory != null && savedHistory is List) {
        // Convertir dynamic list a List<String> y limpiar datos corruptos
        final historyContext = savedHistory.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        
        // Aplicar límite si es necesario
        if (historyContext.length > _maxPlayedSongIds) {
          final trimmed = historyContext.sublist(historyContext.length - _maxPlayedSongIds);
          state = trimmed;
          AppLogger.info('[PlaybackSession] 📦 Historial recortado cargado (${trimmed.length} items)');
        } else {
          state = historyContext;
          AppLogger.info('[PlaybackSession] 📦 Historial persistente cargado: ${state.length} canciones');
        }
      } else {
        AppLogger.info('[PlaybackSession] 📦 No hay historial previo o es inválido');
      }
      
      _isInitialized = true;
    } catch (e) {
      AppLogger.error('[PlaybackSession] ❌ Error inicializando persistencia', e);
      // En caso de error, funcionamos en "Ram Only Mode"
    }
  }

  /// Guardar estado actual en disco
  Future<void> _persistState() async {
    if (_box == null || !_isInitialized) return;
    try {
      await _box!.put(_historyKey, state);
    } catch (e) {
      AppLogger.error('[PlaybackSession] ❌ Error guardando historial', e);
    }
  }

  /// Registrar una canción como reproducida
  /// 
  /// Si el buffer ya tiene el límite, elimina el más antiguo (FIFO).
  /// Persiste el cambio automáticamente.
  void registerPlayedSong(String songId) {
    if (songId.isEmpty) {
      // Log reducido para evitar spam en logs
      // AppLogger.warning('[PlaybackSession] ⚠️ Intento de registrar ID vacío');
      return;
    }

    final current = List<String>.from(state);
    
    // Si ya existe, moverlo al final (actualizar orden de "recencia")
    if (current.contains(songId)) {
      current.remove(songId);
      current.add(songId);
      state = current;
      _persistState(); // 💾
      return;
    }

    // Si el buffer está lleno, eliminar el más antiguo (primero)
    if (current.length >= _maxPlayedSongIds) {
      current.removeAt(0); // Eliminar el más antiguo (FIFO)
      // Log reducido
    }

    // Agregar el nuevo ID al final
    current.add(songId);
    state = current;
    
    // Persistir asíncronamente
    _persistState();
    
    AppLogger.debug('[PlaybackSession] ➕ Registrada: ${songId.substring(0, songId.length > 8 ? 8 : songId.length)}... (Historial: ${state.length}/$_maxPlayedSongIds)');
  }

  /// Registrar múltiples canciones
  void registerPlayedSongs(Iterable<String> songIds) {
    bool changed = false;
    final current = List<String>.from(state);

    for (final songId in songIds) {
      if (songId.isNotEmpty) {
        if (current.contains(songId)) {
          current.remove(songId);
          current.add(songId);
          changed = true;
        } else {
          if (current.length >= _maxPlayedSongIds) {
            current.removeAt(0);
          }
          current.add(songId);
          changed = true;
        }
      }
    }

    if (changed) {
      state = current;
      _persistState(); // 💾
    }
  }

  /// Obtener todos los IDs reproducidos (para usar como excludeIds)
  /// 
  /// Retorna un Set con máximo [limit] IDs recientes.
  Set<String> getPlayedSongIds({int? limit}) {
    // Si no se especifica límite, usar el máximo configurado o el tamaño actual
    final userLimit = limit ?? _maxPlayedSongIds;
    
    if (state.isEmpty) return {};
    
    // Tomar los últimos N items
    final start = state.length > userLimit ? state.length - userLimit : 0;
    return Set<String>.from(state.sublist(start));
  }

  /// Obtener los IDs reproducidos como lista separada por comas
  String getPlayedSongIdsAsString({int? limit}) {
    if (state.isEmpty) return '';
    
    final userLimit = limit ?? _maxPlayedSongIds;
    final start = state.length > userLimit ? state.length - userLimit : 0;
    return state.sublist(start).join(',');
  }

  /// Limpiar el historial (reseteo total)
  void clear() {
    final count = state.length;
    state = [];
    _box?.delete(_historyKey); // 🗑️ Borrar físicamente
    AppLogger.info('[PlaybackSession] 🗑️ Historial purgado ($count IDs eliminados)');
  }

  /// Obtener el número de IDs actuales
  int get count => state.length;

  /// Verificar si un ID está en el buffer
  bool contains(String songId) {
    return state.contains(songId);
  }

  /// Recortar agresivamente el historial (para nueva sesión de algoritmo)
  void trimForNewSession({int keep = 5}) {
    if (state.length <= keep) return;
    final removed = state.length - keep;
    final trimmed = state.sublist(state.length - keep);
    state = trimmed;
    _persistState(); // 💾
    AppLogger.info('[PlaybackSession] ✂️ Historial recortado: $removed IDs eliminados, quedan $keep');
  }
}

/// Provider del servicio de sesión de reproducción
/// 
/// 🚨 PERSISTENCIA: El provider mantiene la interfaz síncrona pero carga datos en background.
final playbackSessionProvider = NotifierProvider<PlaybackSessionNotifier, List<String>>(() {
  return PlaybackSessionNotifier();
});
