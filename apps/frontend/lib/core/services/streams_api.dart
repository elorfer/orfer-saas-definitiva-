import '../services/http_client_service.dart';
import '../utils/logger.dart';
import 'dart:async';

/// Servicio para tracking de streams de reproducción
class StreamsApi {
  static final StreamsApi _instance = StreamsApi._internal();
  factory StreamsApi() => _instance;
  StreamsApi._internal();

  final HttpClientService _httpClient = HttpClientService();
  
  /// Timestamp del último tracking para rate limiting
  DateTime? _lastTrackTime;
  final Duration _minTrackInterval = const Duration(seconds: 5); // Enviar cada 5 segundos como máximo
  
  /// Trackear progreso de reproducción
  /// Solo envía al backend si han pasado al menos 5 segundos desde el último tracking
  Future<void> trackProgress({
    required String songId,
    required int progressMs,
    required int durationMs,
    double volume = 1.0,
    bool isForeground = true,
  }) async {
    try {
      // Rate limiting local: no enviar más de una vez cada 5 segundos
      final now = DateTime.now();
      if (_lastTrackTime != null && now.difference(_lastTrackTime!) < _minTrackInterval) {
        return; // Skip si es muy pronto - sin logs
      }
      
      _lastTrackTime = now;
      
      // Verificar que el HttpClientService esté inicializado
      if (!_httpClient.isInitialized) {
        await _httpClient.initialize();
      }
      
      final response = await _httpClient.dio.post(
        '/streams/track-progress',
        data: {
          'songId': songId,
          'progressMs': progressMs,
          'durationMs': durationMs,
          'volume': volume,
          'isForeground': isForeground,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final streamRegistered = data['streamRegistered'] as bool? ?? false;
        
        // Solo loggear si el stream fue registrado (evento importante)
        if (streamRegistered) {
          AppLogger.success('[StreamsApi] ✅ Stream registrado: $songId');
        }
      }
    } catch (e) {
      // Solo loggear errores críticos (no autenticación, que es normal)
      final errorStr = e.toString();
      if (!errorStr.contains('401') && !errorStr.contains('Unauthorized')) {
        AppLogger.error('[StreamsApi] ❌ Error: $e');
      }
    }
  }
  
  /// Resetear el rate limit (útil cuando cambia de canción)
  void resetRateLimit() {
    _lastTrackTime = null;
  }
}

