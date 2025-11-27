/// Optimización mínima del shuffle - IMPLEMENTAR PRIMERO
/// Solo esta clase ya mejorará significativamente el rendimiento
library;

import 'dart:math' as math;
import 'playback_context.dart';

class ShuffleOptimizer {
  static const int _threshold = 20; // Cambiar algoritmo según tamaño
  
  /// Obtiene índice aleatorio optimizado según el tamaño de la lista
  static int? getRandomIndex(
    int totalItems, 
    List<int> excludedIndices, 
    math.Random random
  ) {
    if (totalItems <= 0) return null;
    if (excludedIndices.length >= totalItems) return null;

    // Para listas pequeñas: algoritmo directo (rápido y simple)
    if (totalItems <= _threshold) {
      return _getRandomIndexDirect(totalItems, excludedIndices, random);
    }

    // Para listas grandes: rejection sampling (mucho más eficiente)
    return _getRandomIndexOptimized(totalItems, excludedIndices, random);
  }

  /// Algoritmo directo para listas pequeñas
  static int? _getRandomIndexDirect(
    int totalItems, 
    List<int> excludedIndices, 
    math.Random random
  ) {
    final availableIndices = <int>[];
    for (int i = 0; i < totalItems; i++) {
      if (!excludedIndices.contains(i)) {
        availableIndices.add(i);
      }
    }
    
    if (availableIndices.isEmpty) return null;
    return availableIndices[random.nextInt(availableIndices.length)];
  }

  /// Algoritmo optimizado para listas grandes (rejection sampling)
  static int? _getRandomIndexOptimized(
    int totalItems, 
    List<int> excludedIndices, 
    math.Random random
  ) {
    const maxAttempts = 50;
    final excludedSet = Set<int>.from(excludedIndices); // O(1) lookup
    
    // Si hay muy pocos elementos disponibles, usar método directo
    if (excludedIndices.length > totalItems * 0.7) {
      return _getRandomIndexDirect(totalItems, excludedIndices, random);
    }
    
    // Intentar encontrar índice válido rápidamente
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = random.nextInt(totalItems);
      if (!excludedSet.contains(candidate)) {
        return candidate;
      }
    }
    
    // Fallback al método directo si no encontramos rápido
    return _getRandomIndexDirect(totalItems, excludedIndices, random);
  }
}

/// Extensión para usar fácilmente en PlaybackContext existente
extension PlaybackContextShuffleOptimization on PlaybackContext {
  /// Reemplaza el método _getRandomIndexExcluding original
  int? getOptimizedRandomIndex(List<int> excludedIndices, math.Random random) {
    return ShuffleOptimizer.getRandomIndex(songIds.length, excludedIndices, random);
  }
}

/// Ejemplo de uso en el PlaybackContext original
/// REEMPLAZAR el método _getRandomIndexExcluding con esto:
/*
int? _getRandomIndexExcluding(List<int> excludedIndices, math.Random random) {
  // Usar el optimizador en lugar del algoritmo original
  return ShuffleOptimizer.getRandomIndex(songIds.length, excludedIndices, random);
}
*/
