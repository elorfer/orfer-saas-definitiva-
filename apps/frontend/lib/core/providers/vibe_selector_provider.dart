import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/genre_model.dart';
import '../utils/logger.dart';

/// 🎛️ VIBE SELECTOR PROVIDER - ARQUITECTURA LIMPIA
/// 
/// Implementación basada en "Sincronización de Contexto":
/// - La UI refleja EXACTAMENTE lo que el motor de audio está reproduciendo
/// - Sin timers, cooldowns ni parches temporales
/// - El Backend es la Única Fuente de Verdad (SSOT)
/// 
/// Flujo:
/// 1. Usuario toca chip → Optimistic UI (cambio inmediato)
/// 2. Backend responde → syncWithBackendContext() reconcilia el estado
/// 3. Si backend dice "fallback a Mix" → UI cambia a Mix (es la realidad)

/// Estado de selección de vibe
class VibeSelection {
  final bool isMixMode;
  final String? genreId;
  final String? genreName;
  final String? colorHex;
  
  /// 🎯 Indica si este estado fue confirmado por el backend
  /// true = el backend ya envió canciones de este género/mix
  /// false = estado optimista esperando confirmación
  final bool isConfirmed;

  const VibeSelection({
    this.isMixMode = true,
    this.genreId,
    this.genreName,
    this.colorHex,
    this.isConfirmed = false,
  });

  /// Modo Mix (aleatorio)
  const VibeSelection.mix({bool confirmed = false}) : this(
    isMixMode: true,
    isConfirmed: confirmed,
  );

  /// Modo género específico
  VibeSelection.genre(Genre genre, {bool confirmed = false}) : this(
    isMixMode: false,
    genreId: genre.id,
    genreName: genre.name,
    colorHex: genre.colorHex,
    isConfirmed: confirmed,
  );
  
  /// Crear desde respuesta del backend (siempre confirmado)
  VibeSelection.fromBackend({
    required bool isMix,
    String? genreId,
    String? genreName,
  }) : this(
    isMixMode: isMix,
    genreId: genreId,
    genreName: genreName,
    isConfirmed: true,
  );

  VibeSelection copyWith({
    bool? isMixMode,
    String? genreId,
    String? genreName,
    String? colorHex,
    bool? isConfirmed,
  }) {
    return VibeSelection(
      isMixMode: isMixMode ?? this.isMixMode,
      genreId: genreId ?? this.genreId,
      genreName: genreName ?? this.genreName,
      colorHex: colorHex ?? this.colorHex,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VibeSelection &&
        other.isMixMode == isMixMode &&
        other.genreId == genreId;
  }

  @override
  int get hashCode => Object.hash(isMixMode, genreId);

  @override
  String toString() {
    final confirmed = isConfirmed ? '✓' : '?';
    if (isMixMode) return 'VibeSelection(Mix $confirmed)';
    return 'VibeSelection(genre: $genreName $confirmed)';
  }
}

/// 🎛️ Notifier con Arquitectura de Sincronización de Contexto
/// 
/// Principios:
/// 1. Optimistic UI: Cambios del usuario se reflejan inmediatamente
/// 2. Backend como SSOT: syncWithBackendContext() reconcilia con la realidad
/// 3. Sin parches temporales: Cero timers, cooldowns o flags manuales
class VibeSelectorNotifier extends Notifier<VibeSelection> {
  
  /// 🎯 El genreId que el usuario QUIERE (intención)
  /// Puede diferir de state.genreId si el backend hizo fallback
  String? _userIntentGenreId;
  
  @override
  VibeSelection build() {
    return const VibeSelection.mix(confirmed: true);
  }

  /// 🔀 Seleccionar modo Mix - ACCIÓN DEL USUARIO (Optimistic UI)
  void selectMixMode() {
    if (state.isMixMode && state.isConfirmed) return;

    AppLogger.info('[VibeSelectorNotifier] 🔀 Usuario seleccionó Mix');
    _userIntentGenreId = null;
    state = const VibeSelection.mix(confirmed: false);
    
    // Notificar al playback para limpiar cola y recargar
    _onVibeChanged();
  }

  /// 🎵 Seleccionar un género - ACCIÓN DEL USUARIO (Optimistic UI)
  void selectGenre(Genre genre) {
    if (state.genreId == genre.id && state.isConfirmed) {
      AppLogger.info('[VibeSelectorNotifier] ℹ️ Género ${genre.name} ya está seleccionado y confirmado');
      return;
    }

    AppLogger.info('[VibeSelectorNotifier] 🎵 Usuario seleccionó género: ${genre.name}');
    AppLogger.info('  ├─ genre.id: ${genre.id}');
    AppLogger.info('  ├─ Estableciendo _userIntentGenreId = ${genre.id}');
    AppLogger.info('  └─ Creando estado optimista (confirmed: false)');
    
    _userIntentGenreId = genre.id;
    state = VibeSelection.genre(genre, confirmed: false);
    
    // Notificar al playback para limpiar cola y recargar
    _onVibeChanged();
  }

  /// 🔄 MÉTODO CENTRAL: Sincronizar con respuesta del Backend
  /// 
  /// Este es el ÚNICO método que debe llamarse cuando el backend responde.
  /// Reconcilia el estado optimista con la realidad del motor de audio.
  /// 
  /// [responseGenreId]: El género que el backend realmente procesó (null = Mix)
  /// [isFallback]: true si el backend hizo fallback a Mix por agotamiento
  /// [originalGenre]: El género que se agotó (para mostrar mensaje)
  void syncWithBackendContext({
    required String? responseGenreId,
    required bool isFallback,
    String? originalGenre,
  }) {
    // 🎯 CASO 3: Backend hizo fallback a Mix (género agotado) - VERIFICAR PRIMERO
    if (isFallback) {
      AppLogger.info('[VibeSelectorNotifier] 🔀 CAMBIO A MIX: género "$originalGenre" agotado');
      _userIntentGenreId = null; // Limpiar intención ya que no es posible
      state = const VibeSelection.mix(confirmed: true);
      return;
    }
    
    // 🎯 CASO 1: Backend confirmó el género que pedimos
    if (responseGenreId == _userIntentGenreId && _userIntentGenreId != null) {
      if (!state.isConfirmed) {
        AppLogger.info('[VibeSelectorNotifier] ✅ Género confirmado: ${state.genreName}');
        state = state.copyWith(isConfirmed: true);
      }
      return;
    }
    
    // 🎯 CASO 2: Backend confirmó Mix (pedimos Mix o era el default)
    if (responseGenreId == null && _userIntentGenreId == null) {
      if (!state.isConfirmed) {
        AppLogger.info('[VibeSelectorNotifier] ✅ Mix confirmado');
        state = state.copyWith(isConfirmed: true);
      }
      return;
    }
    
    // 🎯 CASO 4: Desincronización (no debería pasar)
    AppLogger.warning('[VibeSelectorNotifier] ⚠️ Desincronización: pedimos=$_userIntentGenreId, recibimos=$responseGenreId');
  }
  
  /// 🔀 DEPRECADO: Usar syncWithBackendContext() en su lugar
  /// Mantenido temporalmente para compatibilidad
  @Deprecated('Usar syncWithBackendContext() para arquitectura limpia')
  void switchToMixSilently({String? originalGenre}) {
    syncWithBackendContext(
      responseGenreId: null,
      isFallback: true,
      originalGenre: originalGenre,
    );
  }

  /// 🔄 Notificar cambio de vibe al sistema de playback
  /// Función de selección de género eliminada - ya no se procesa el cambio de género
  void _onVibeChanged() {
    // Función eliminada - no hace nada
  }

  /// Obtener el género actual para el discovery
  String? get currentGenreId => state.isMixMode ? null : state.genreId;
  
  /// Obtener el nombre del género para logging
  String get currentVibeName => state.isMixMode ? 'Mix' : (state.genreName ?? 'Unknown');
  
  /// 🎯 Obtener la intención del usuario (puede diferir del estado actual)
  String? get userIntentGenreId => _userIntentGenreId;
}

/// Provider global del Vibe Selector
final vibeSelectorProvider = NotifierProvider<VibeSelectorNotifier, VibeSelection>(() {
  return VibeSelectorNotifier();
});
