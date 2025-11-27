import 'package:flutter/material.dart';

/// 🚀 CONFIGURACIÓN DE RENDIMIENTO GLOBAL
/// Centraliza todas las optimizaciones de rendimiento de la aplicación

class PerformanceConfig {
  // 🖼️ CONFIGURACIÓN DE IMÁGENES
  static const int defaultImageCacheSize = 100; // MB
  static const int maxImageCacheWidth = 800;
  static const int maxImageCacheHeight = 800;
  static const int thumbnailCacheWidth = 200;
  static const int thumbnailCacheHeight = 200;
  
  // 📱 CONFIGURACIÓN DE SCROLL
  static const double defaultCacheExtent = 1000.0; // px
  static const double listCacheExtent = 800.0; // px
  static const double gridCacheExtent = 1200.0; // px
  
  // 🎵 CONFIGURACIÓN DE AUDIO
  static const int audioBufferSize = 4096;
  static const Duration audioUpdateInterval = Duration(milliseconds: 100);
  
  // 🔄 CONFIGURACIÓN DE PROVIDERS
  static const Duration providerDebounceTime = Duration(milliseconds: 300);
  static const Duration networkTimeout = Duration(seconds: 10);
  static const int maxRetryAttempts = 3;
  
  // 📊 CONFIGURACIÓN DE LISTAS
  static const int defaultPageSize = 20;
  static const int maxItemsInMemory = 100;
  static const bool enableLazyLoading = true;
  
  // 🎨 CONFIGURACIÓN DE UI
  static const bool enableRepaintBoundaries = true;
  static const bool enableKeepAlive = true;
  static const Duration animationDuration = Duration(milliseconds: 200);
  
  // 🌐 CONFIGURACIÓN DE RED
  static const Duration httpCacheMaxAge = Duration(hours: 1);
  static const int maxConcurrentRequests = 5;
  
  /// Configuración optimizada para dispositivos de gama baja
  static const Map<String, dynamic> lowEndDeviceConfig = {
    'imageCacheSize': 50, // MB reducido
    'cacheExtent': 600.0, // px reducido
    'pageSize': 10, // Elementos por página reducido
    'enableAnimations': false,
    'maxImageWidth': 400,
    'maxImageHeight': 400,
  };
  
  /// Configuración optimizada para dispositivos de gama alta
  static const Map<String, dynamic> highEndDeviceConfig = {
    'imageCacheSize': 200, // MB aumentado
    'cacheExtent': 1500.0, // px aumentado
    'pageSize': 30, // Más elementos por página
    'enableAnimations': true,
    'maxImageWidth': 1200,
    'maxImageHeight': 1200,
  };
  
  /// Detectar si es un dispositivo de gama baja
  static bool isLowEndDevice() {
    // Implementar lógica de detección basada en:
    // - RAM disponible
    // - Versión del OS
    // - Capacidad de procesamiento
    // Por ahora, retorna false (asumir gama alta)
    return false;
  }
  
  /// Obtener configuración según el dispositivo
  static Map<String, dynamic> getDeviceConfig() {
    return isLowEndDevice() ? lowEndDeviceConfig : highEndDeviceConfig;
  }
}

/// 🚀 MIXIN PARA OPTIMIZACIONES COMUNES DE WIDGETS
mixin PerformanceOptimizedWidget {
  /// Configurar RepaintBoundary si está habilitado
  Widget wrapWithRepaintBoundary(Widget child) {
    if (PerformanceConfig.enableRepaintBoundaries) {
      return RepaintBoundary(child: child);
    }
    return child;
  }
  
  /// Configurar AutomaticKeepAlive si está habilitado
  bool get shouldKeepAlive => PerformanceConfig.enableKeepAlive;
}

/// 🚀 EXTENSIONES PARA OPTIMIZAR WIDGETS COMUNES
extension OptimizedListView on ListView {
  /// ListView optimizado con configuración de rendimiento
  static ListView optimized({
    Key? key,
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
  }) {
    return ListView.builder(
      key: key,
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      physics: physics,
      padding: padding,
      cacheExtent: PerformanceConfig.listCacheExtent,
      addAutomaticKeepAlives: PerformanceConfig.enableKeepAlive,
      addRepaintBoundaries: PerformanceConfig.enableRepaintBoundaries,
    );
  }
}

extension OptimizedGridView on GridView {
  /// GridView optimizado con configuración de rendimiento
  static GridView optimized({
    Key? key,
    required SliverGridDelegate gridDelegate,
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
  }) {
    return GridView.builder(
      key: key,
      gridDelegate: gridDelegate,
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      physics: physics,
      padding: padding,
      cacheExtent: PerformanceConfig.gridCacheExtent,
      addAutomaticKeepAlives: PerformanceConfig.enableKeepAlive,
      addRepaintBoundaries: PerformanceConfig.enableRepaintBoundaries,
    );
  }
}
