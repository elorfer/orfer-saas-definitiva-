import 'package:flutter/foundation.dart';
import 'http_client_service.dart';
import '../utils/logger.dart';

/// 🎛️ CONFIGURACIÓN DINÁMICA DEL ALGORITMO
/// 
/// Este servicio obtiene la configuración del algoritmo desde el backend,
/// permitiendo ajustar los parámetros sin actualizar la app.
/// 
/// Ejemplo de uso:
/// ```dart
/// final config = await AlgorithmConfigService.instance.getConfig();
/// final historySize = config.historySize; // 100 o lo que esté en el Admin
/// ```
class AlgorithmConfigService {
  static AlgorithmConfigService? _instance;
  static AlgorithmConfigService get instance {
    _instance ??= AlgorithmConfigService._();
    return _instance!;
  }
  
  AlgorithmConfigService._();
  
  final HttpClientService _http = HttpClientService();
  
  // Cache de configuración
  AlgorithmConfig? _cachedConfig;
  DateTime? _lastFetch;
  static const Duration _cacheTtl = Duration(minutes: 10);
  
  /// Obtiene la configuración del algoritmo.
  /// Usa cache de 10 minutos para evitar llamadas excesivas.
  Future<AlgorithmConfig> getConfig({bool forceRefresh = false}) async {
    // Verificar cache
    if (!forceRefresh && _cachedConfig != null && _lastFetch != null) {
      final elapsed = DateTime.now().difference(_lastFetch!);
      if (elapsed < _cacheTtl) {
        return _cachedConfig!;
      }
    }
    
    try {
      final response = await _http.get('/public/ads/algorithm-config');
      
      if (response.statusCode == 200 && response.data != null) {
        _cachedConfig = AlgorithmConfig.fromJson(response.data);
        _lastFetch = DateTime.now();
        
        AppLogger.info('[AlgorithmConfig] ✅ Configuración cargada: $_cachedConfig');
        return _cachedConfig!;
      }
    } catch (e) {
      AppLogger.warning('[AlgorithmConfig] ⚠️ Error obteniendo config, usando valores por defecto: $e');
    }
    
    // Retornar valores por defecto si falla
    return AlgorithmConfig.defaults();
  }
  
  /// Forzar recarga de la configuración
  Future<AlgorithmConfig> refreshConfig() => getConfig(forceRefresh: true);
  
  /// Obtener configuración actual (desde cache o defaults)
  AlgorithmConfig get currentConfig => _cachedConfig ?? AlgorithmConfig.defaults();
}

/// 🎛️ Modelo de Configuración del Algoritmo
class AlgorithmConfig {
  /// Historial de exclusión (canciones a evitar repetir)
  final int historySize;
  
  /// Canciones que solicita FASE 2.0
  final int phase2Count;
  
  /// Canciones que solicita FASE 3.1
  final int phase31Count;
  
  /// Buffer inicial FASE 1
  final int bufferSize;
  
  /// Umbral para disparar precarga
  final int preloadThreshold;
  
  /// Canciones críticas a agregar por precarga
  final int criticalSongs;
  
  /// Total de canciones en el catálogo
  final int catalogSize;
  
  /// Umbral para considerar "catálogo pequeño"
  final int smallCatalogThreshold;
  
  const AlgorithmConfig({
    required this.historySize,
    required this.phase2Count,
    required this.phase31Count,
    required this.bufferSize,
    required this.preloadThreshold,
    required this.criticalSongs,
    required this.catalogSize,
    required this.smallCatalogThreshold,
  });
  
  /// Valores por defecto (fallback)
  factory AlgorithmConfig.defaults() => const AlgorithmConfig(
    historySize: 100,
    phase2Count: 6,
    phase31Count: 20,
    bufferSize: 5,
    preloadThreshold: 3,
    criticalSongs: 5,
    catalogSize: 0,
    smallCatalogThreshold: 150,
  );
  
  /// Crear desde JSON del backend
  factory AlgorithmConfig.fromJson(Map<String, dynamic> json) {
    return AlgorithmConfig(
      historySize: json['historySize'] as int? ?? 100,
      phase2Count: json['phase2Count'] as int? ?? 6,
      phase31Count: json['phase31Count'] as int? ?? 20,
      bufferSize: json['bufferSize'] as int? ?? 5,
      preloadThreshold: json['preloadThreshold'] as int? ?? 3,
      criticalSongs: json['criticalSongs'] as int? ?? 5,
      catalogSize: json['catalogSize'] as int? ?? 0,
      smallCatalogThreshold: json['smallCatalogThreshold'] as int? ?? 150,
    );
  }
  
  /// Verificar si el catálogo es pequeño
  bool get isSmallCatalog => catalogSize > 0 && catalogSize < smallCatalogThreshold;
  
  /// Obtener historial de exclusión ajustado según tamaño del catálogo
  int get effectiveHistorySize {
    if (isSmallCatalog) {
      // Para catálogos pequeños, reducir historial proporcionalmente
      // Mínimo: 30% del catálogo o 10 canciones
      final reduced = (catalogSize * 0.3).round().clamp(10, historySize);
      debugPrint('[AlgorithmConfig] 📦 Catálogo pequeño ($catalogSize): historial reducido a $reduced');
      return reduced;
    }
    return historySize;
  }
  
  @override
  String toString() => 'AlgorithmConfig(historySize: $historySize, phase2Count: $phase2Count, '
      'phase31Count: $phase31Count, bufferSize: $bufferSize, preloadThreshold: $preloadThreshold, '
      'criticalSongs: $criticalSongs, catalogSize: $catalogSize, smallCatalogThreshold: $smallCatalogThreshold)';
}
