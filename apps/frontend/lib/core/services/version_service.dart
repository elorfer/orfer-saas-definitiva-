import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'http_client_service.dart';
import '../utils/logger.dart';

class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  bool _hasChecked = false;
  bool get hasChecked => _hasChecked;

  /// Verifica la versión contra el backend y retorna si es necesario actualizar.
  /// Retorna un mapa con: { 'mustUpdate': bool, 'shouldUpdate': bool, 'storeUrl': String? }
  Future<Map<String, dynamic>> checkVersion() async {
    try {
      final client = HttpClientService();
      // El endpoint /public/ads/algorithm-config devuelve todos los ajustes públicos
      final response = await client.get('/public/ads/algorithm-config');
      
      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        final minRequiredBuild = data['min_required_build'] as int? ?? 0;
        final latestBuild = data['latest_build'] as int? ?? 0;
        
        AppLogger.info('[VersionService] 🆙 Verificando versión: Local=${AppConfig.buildNumber}, Min=$minRequiredBuild, Latest=$latestBuild');

        final mustUpdate = AppConfig.buildNumber < minRequiredBuild;
        final shouldUpdate = AppConfig.buildNumber < latestBuild;

        final storeUrl = data['store_url'] as String? ?? AppConfig.updateUrl;

        _hasChecked = true;
        return {
          'mustUpdate': mustUpdate,
          'shouldUpdate': shouldUpdate,
          'storeUrl': storeUrl,
        };
      }
    } catch (e) {
      AppLogger.error('[VersionService] ❌ Error verificando versión', e);
    }
    
    return {'mustUpdate': false, 'shouldUpdate': false};
  }
}
