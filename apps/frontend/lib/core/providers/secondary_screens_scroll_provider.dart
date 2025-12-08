import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 💾 Provider para mantener posiciones de scroll de pantallas secundarias
/// Persiste en disco usando SharedPreferences para sobrevivir al cierre de la app
/// ⚡ OPTIMIZACIÓN: NO usar autoDispose porque queremos que persista
final secondaryScreensScrollProvider = 
    NotifierProvider<SecondaryScreensScrollNotifier, Map<String, double>>(() {
  return SecondaryScreensScrollNotifier();
});

class SecondaryScreensScrollNotifier extends Notifier<Map<String, double>> {
  static const String _storageKey = 'secondary_screens_scroll_positions';
  Timer? _saveTimer;
  static const Duration _saveDebounceDuration = Duration(milliseconds: 500);
  bool _hasLoadedFromDisk = false;
  
  @override
  Map<String, double> build() {
    // 💾 Cargar posiciones guardadas desde disco al inicializar (async, no bloquea)
    if (!_hasLoadedFromDisk) {
      _hasLoadedFromDisk = true;
      _loadFromDisk();
    }
    // Retornar estado vacío inicial, se actualizará cuando se cargue desde disco
    return {};
  }
  
  /// 💾 Cargar posiciones desde SharedPreferences (disco)
  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        final loadedPositions = <String, double>{};
        
        // Convertir valores a double de forma segura
        decoded.forEach((key, value) {
          if (value is num) {
            loadedPositions[key] = value.toDouble();
          }
        });
        
        // Actualizar estado con posiciones cargadas
        // Solo actualizar si el estado está vacío para no sobrescribir valores más recientes
        if (loadedPositions.isNotEmpty) {
          if (state.isEmpty) {
            state = loadedPositions;
          } else {
            // Si ya hay estado, fusionar (los valores en memoria tienen prioridad)
            final merged = {...loadedPositions, ...state};
            state = merged;
          }
        }
      }
    } catch (e) {
      // Si falla la carga, continuar con estado vacío
      if (kDebugMode) {
        debugPrint('💾 [ScrollProvider] Error cargando desde disco: $e');
      }
    }
  }
  
  /// 💾 Guardar posiciones en SharedPreferences (disco) con debounce
  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('💾 [ScrollProvider] Error guardando en disco: $e');
    }
  }
  
  /// Guardar posición de scroll para una pantalla secundaria
  /// 💾 Guarda en memoria inmediatamente y en disco con debounce
  void saveScrollPosition(String screenKey, double position) {
    if (position < 0) return;
    
    // Actualizar estado en memoria inmediatamente
    state = {...state, screenKey: position};
    
    // 💾 Guardar en disco con debounce para evitar escrituras excesivas
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, () {
      _saveToDisk();
    });
  }
  
  /// Obtener posición de scroll guardada
  double? getScrollPosition(String screenKey) {
    return state[screenKey];
  }
  
  /// Limpiar posición guardada (opcional, para liberar memoria)
  void clearScrollPosition(String screenKey) {
    final updated = Map<String, double>.from(state);
    updated.remove(screenKey);
    state = updated;
    
    // 💾 Guardar cambio en disco
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, () {
      _saveToDisk();
    });
  }
  
  /// 💾 Limpiar todas las posiciones guardadas
  Future<void> clearAll() async {
    state = {};
    _saveTimer?.cancel();
    await _saveToDisk();
  }
}

