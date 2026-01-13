import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';

/// Provider del historial de reproducción
/// 🔒 PROFESIONAL: Soporta separación de datos por usuario
/// 🛡️ Usando Notifier regular para evitar problemas con state después de async
/// 📦 Migrado a Hive para mayor consistencia y rendimiento
class PlayHistoryNotifier extends Notifier<List<Song>> {
  static const String _historyBoxPrefix = 'play_history_v3'; // v3 para nueva estructura
  static const int _maxHistorySize = 50;
  static const Duration _saveDebounceDuration = Duration(seconds: 1);

  // 🔒 ID del usuario actual - CRÍTICO para separación de datos
  String? _currentUserId;
  bool _isInitialized = false;

  Box<String>? _box;
  Timer? _saveDebounceTimer;
  bool _isMounted = true;
  bool _isLoading = false;

  @override
  List<Song> build() {
    _isMounted = true;
    
    ref.onDispose(() {
      _isMounted = false;
      _saveDebounceTimer?.cancel();
    });
    
    // NO inicializar automáticamente - esperar a que se establezca el userId
    return [];
  }

  /// 🔒 Inicializar para un usuario específico
  /// DEBE ser llamado cuando un usuario inicia sesión
  Future<void> initializeForUser(String userId) async {
    if (_currentUserId == userId && _isInitialized) {
      AppLogger.info('[PlayHistory] ✅ Ya inicializado para usuario: $userId');
      return;
    }

    AppLogger.info('[PlayHistory] 🔑 Inicializando para usuario: $userId');
    
    // Si había un usuario anterior, cerrar su sesión primero
    if (_currentUserId != null && _currentUserId != userId) {
      AppLogger.info('[PlayHistory] 🔄 Cerrando sesión anterior: $_currentUserId');
      await closeCurrentUserSession();
    }

    _currentUserId = userId;
    _isLoading = true;
    
    try {
      // Abrir Hive Box específico del usuario
      final boxName = _getUserBoxName(userId);
      AppLogger.info('[PlayHistory] 📦 Abriendo Hive box: $boxName');
      
      _box = await Hive.openBox<String>(boxName);
      
      if (_box == null || !_box!.isOpen) {
        throw Exception('Failed to open Hive box: $_box is ${_box?.isOpen ?? "null"}');
      }
      
      AppLogger.success('[PlayHistory] 📦 Hive box abierto exitosamente: $boxName (keys: ${_box!.keys.length})');
      
      // Cargar historial del usuario
      await _loadHistoryFromLocal();
      _isInitialized = true;
      
      AppLogger.success('[PlayHistory] ✅ Inicialización COMPLETADA para usuario: $userId (historial: ${state.length} canciones)');
    } catch (e, stackTrace) {
      AppLogger.error('[PlayHistory] ❌ ERROR CRÍTICO inicializando: $e');
      AppLogger.error('[PlayHistory] 📍 StackTrace: $stackTrace');
      _isLoading = false;
      _isInitialized = false;
      _box = null; // Asegurar que el box esté limpio si falló
      rethrow; // Re-lanzar para que auth_provider sepa que falló
    }
  }

  /// Cerrar sesión del usuario actual (sin eliminar sus datos)
  /// DEBE ser llamado cuando un usuario cierra sesión
  Future<void> closeCurrentUserSession() async {
    try {
      AppLogger.info('[PlayHistory] 🔄 Cerrando sesión de usuario: $_currentUserId');
      
      // Guardar cambios pendientes
      _saveDebounceTimer?.cancel();
      if (_box != null && _isMounted) {
        await _saveHistoryToLocal();
      }
      
      // Cerrar Hive box si está abierto
      if (_box != null && _box!.isOpen) {
        await _box!.close();
        _box = null;
      }
      
      // Limpiar estado
      state = [];
      _isInitialized = false;
      _currentUserId = null;
      
      AppLogger.debug('[PlayHistory] ✅ Sesión cerrada correctamente');
    } catch (e) {
      AppLogger.error('[PlayHistory] Error cerrando sesión: $e');
    }
  }

  /// 🗑️ Eliminar TODOS los datos del usuario actual
  /// Solo usar si quieres borrar el historial permanentemente
  Future<void> clearCurrentUserData() async {
    if (_currentUserId == null) {
      AppLogger.warning('[PlayHistory] No hay usuario activo para limpiar');
      return;
    }

    try {
      AppLogger.info('[PlayHistory] 🧹 Eliminando datos de usuario: $_currentUserId');
      
      // Eliminar y cerrar Hive box del usuario
      if (_box != null) {
        final boxName = _getUserBoxName(_currentUserId!);
        await _box!.clear();
        await _box!.close();
        await Hive.deleteBoxFromDisk(boxName);
        _box = null;
      }
      
      // Limpiar estado
      state = [];
      _isInitialized = false;
      
      AppLogger.info('[PlayHistory] ✅ Datos eliminados correctamente');
    } catch (e) {
      AppLogger.error('[PlayHistory] Error eliminando datos: $e');
    }
  }

  /// Obtener nombre del Hive Box para un usuario específico
  String _getUserBoxName(String userId) {
    // Sanitizar userId para nombre de archivo seguro
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${_historyBoxPrefix}_$safeUserId';
  }

  /// Agregar canción al historial
  /// 🧠 LÓGICA BURBUJA: Si la canción ya existe, la mueve al final (más reciente)
  /// en lugar de duplicarla. Esto mantiene el historial limpio y relevante.
  void addToHistory(Song song) {
    // 🔍 DIAGNÓSTICO MEJORADO: Log detallado de estado
    if (!_isInitialized || _currentUserId == null) {
      AppLogger.warning('[PlayHistory] ⚠️ BLOQUEADO: No se puede agregar sin inicialización');
      AppLogger.warning('[PlayHistory] 🔍 Estado: _isInitialized=$_isInitialized, _currentUserId=$_currentUserId, _box=${_box != null ? "abierto" : "null"}');
      
      // 🔧 INTENTO DE RECUPERACIÓN: Si tenemos box abierto pero el flag está mal, corregir
      if (_box != null && _box!.isOpen && _currentUserId != null && !_isInitialized) {
        AppLogger.warning('[PlayHistory] 🔧 RECUPERACIÓN: Box abierto pero flag mal - corrigiendo...');
        _isInitialized = true;
        // Continuar con el agregado
      } else {
        return; // No podemos recuperar - abortar
      }
    }

    if (song.id.isEmpty) {
      AppLogger.warning('[PlayHistory] ⚠️ Intento de añadir canción sin ID al historial');
      return;
    }

    AppLogger.info('[PlayHistory] ➕ Añadiendo: ${song.title} (${song.id}) - Usuario: $_currentUserId');
    
    final current = List<Song>.from(state);
    
    // ✅ SANITIZACIÓN: Asegurar que guardamos URLs válidas/normalizadas
    String? cleanCover = song.coverArtUrl;
    if (cleanCover != null) {
        cleanCover = UrlNormalizer.normalizeImageUrl(cleanCover);
    }
    
    String? cleanFile = song.fileUrl;
    if (cleanFile != null && cleanFile.isNotEmpty && (cleanFile.startsWith('http') || cleanFile.startsWith('/'))) {
       try {
         cleanFile = UrlNormalizer.normalizeUrl(cleanFile);
       } catch (_) {}
    }

    final sanitizedSong = song.copyWith(
        coverArtUrl: cleanCover,
        fileUrl: cleanFile,
    );

    // 🧼 DEDUPLICACIÓN INTELIGENTE (Bubble Logic)
    // 1. Si existe, la removemos de su posición antigua
    current.removeWhere((s) => s.id == song.id);
    
    // 2. Agregamos la nueva versión al final (más reciente)
    current.add(sanitizedSong);
    
    // 3. Limitar tamaño del historial
    if (current.length > _maxHistorySize) {
      current.removeRange(0, current.length - _maxHistorySize);
    }
    
    state = current;
    
    // 💾 Persistencia debounced
    if (!_isLoading) {
      _scheduleSaveDebounced();
    }
    
    AppLogger.info('[PlayHistory] 🫧 Historial actualizado: ${song.title} es ahora el más reciente. Total: ${state.length}');
  }

  /// Obtener canción anterior (elimina la actual y retorna la anterior)
  Song? getPreviousSong() {
    if (!_isInitialized) {
      AppLogger.warning('[PlayHistory] ⚠️ No se puede obtener anterior sin usuario inicializado');
      return null;
    }

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

  void _scheduleSaveDebounced() {
    if (!_isMounted) return;
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

  /// Guardar historial en Hive
  Future<void> _saveHistoryToLocal() async {
    if (!_isMounted || _box == null || !_isInitialized) return;
    
    try {
      final currentState = state;
      AppLogger.debug('[PlayHistory] 💾 Guardando ${currentState.length} canciones (Usuario: $_currentUserId)...');
      
      // Limpiar y guardar de nuevo
      await _box!.clear();
      
      for (int i = 0; i < currentState.length; i++) {
        final song = currentState[i];
        try {
          final json = jsonEncode(song.toJson());
          await _box!.put('song_$i', json);
        } catch (e) {
          AppLogger.error('[PlayHistory] ❌ Error serializando canción ${song.id}: $e');
        }
      }
      
      AppLogger.success('[PlayHistory] 💾 Historial persistido correctamente');
    } catch (e) {
      AppLogger.error('[PlayHistory] ❌ Error guardando historial: $e');
    }
  }

  /// Cargar historial desde Hive
  Future<void> _loadHistoryFromLocal() async {
    if (!_isMounted || _box == null) {
      _isLoading = false;
      return;
    }

    try {
      final keys = _box!.keys.toList();
      if (keys.isEmpty) {
        AppLogger.info('[PlayHistory] 📂 Historial vacío para usuario: $_currentUserId');
        _isLoading = false;
        return;
      }

      final decodedList = <Map<String, dynamic>>[];
      keys.sort((a, b) {
        final indexA = int.tryParse(a.toString().replaceFirst('song_', '')) ?? 0;
        final indexB = int.tryParse(b.toString().replaceFirst('song_', '')) ?? 0;
        return indexA.compareTo(indexB);
      });

      for (final key in keys) {
        final jsonStr = _box!.get(key);
        if (jsonStr != null) {
          try {
            final decoded = jsonDecode(jsonStr);
            if (decoded is Map<String, dynamic>) {
              decodedList.add(decoded);
            }
          } catch (_) {}
        }
      }

      List<Song> loadedSongs = [];
      if (decodedList.isNotEmpty) {
        try {
          loadedSongs = await Song.parseList(decodedList);
        } catch (_) {
          for (final m in decodedList) {
            try {
              loadedSongs.add(Song.fromJson(m));
            } catch (_) {}
          }
        }
      }

      if (_isMounted) {
        state = loadedSongs;
        AppLogger.success('[PlayHistory] 📂 Historial recuperado: ${state.length} canciones (Usuario: $_currentUserId)');
      }
    } catch (e) {
      AppLogger.error('[PlayHistory] ❌ Error cargando historial: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Obtener historial ordenado (más reciente primero)
  List<Song> getRecentHistory({int limit = 50}) {
    final history = List<Song>.from(state.reversed);
    return history.take(limit).toList();
  }

  /// 🔍 DIAGNÓSTICO: Verificar estado del historial
  void debugHistoryStatus() {
    AppLogger.info('═══════════════════════════════════════════════════');
    AppLogger.info('[PlayHistory] 🔍 ESTADO DEL HISTORIAL');
    AppLogger.info('[PlayHistory] Usuario actual: $_currentUserId');
    AppLogger.info('[PlayHistory] Inicializado: $_isInitialized');
    AppLogger.info('[PlayHistory] Box abierto: ${_box != null && _box!.isOpen}');
    AppLogger.info('[PlayHistory] Box keys: ${_box?.keys.length ?? 0}');
    AppLogger.info('[PlayHistory] Canciones en estado: ${state.length}');
    AppLogger.info('[PlayHistory] Is loading: $_isLoading');
    AppLogger.info('[PlayHistory] Is mounted: $_isMounted');
    if (state.isNotEmpty) {
      AppLogger.info('[PlayHistory] Última canción: ${state.last.title} (${state.last.id})');
    }
    AppLogger.info('═══════════════════════════════════════════════════');
  }

  /// Limpiar historial completo
  Future<void> clearHistory() async {
    state = [];
    if (_box != null) {
      await _box!.clear();
    }
    AppLogger.info('[PlayHistory] 🗑️ Historial limpiado');
  }
}

/// Provider del historial de reproducción
/// 🛡️ Usando NotifierProvider regular para evitar problemas de dispose durante async
final playHistoryProvider = NotifierProvider<PlayHistoryNotifier, List<Song>>(() {
  return PlayHistoryNotifier();
});
