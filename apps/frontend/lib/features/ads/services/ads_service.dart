import 'package:dio/dio.dart';
import '../models/audio_ad_model.dart';
import '../../../core/services/http_client_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/url_normalizer.dart';

/// Servicio para comunicarse con la API de anuncios
/// Implementa los métodos que el PlaybackNotifier y el AdsProvider necesitarán
class AdsService {
  final Dio _dio;
  // ✅ FIX: baseUrl ya incluye /api/v1, solo usar /public/ads
  static const String _publicAdsPath = '/public/ads';

  AdsService() : _dio = HttpClientService().dio;

  /// Obtener siguiente anuncio (Consumido por PlaybackNotifier/AdsProvider)
  /// 
  /// [genre]: Género de la canción actual (para targeting)
  /// [artist]: Artista de la canción actual (para targeting)
  /// [playlistId]: ID de playlist si aplica (para targeting)
  /// [isPremium]: Si el usuario es premium (no se hace llamada si es premium)
  /// 
  /// Retorna el anuncio o null si no hay anuncios disponibles o el usuario es premium
  Future<AudioAd?> getNextAd({
    String? genre,
    String? artist,
    String? playlistId,
    required bool isPremium,
  }) async {
    // 🛠️ DEBUG MODE: Forzar anuncio de prueba (mock)
    // Esto permite probar la inserción sin depender del backend
    const bool _forceDebugAd = false;
    
    // Si es premium, no perder tiempo llamando a la API
    if (isPremium && !_forceDebugAd) {
      AppLogger.debug('[AdsService] Usuario premium, no se solicita anuncio');
      return null;
    }

    // 🛠️ DEBUG: Retornar anuncio mock si el flag está activo
    if (_forceDebugAd) {
      AppLogger.warning('[AdsService] 🛠️ MOCK AD MODE ACTIVE: Retornando anuncio de prueba local');
      return AudioAd(
        id: 'debug-ad-123',
        title: 'Anuncio de Prueba (Debug)',
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', // Audio público fiable
        // durationSeconds: 30, // ❌ ERROR
        duration: const Duration(seconds: 30), // ✅ FIX
        advertiserName: 'Debug Advertiser',
        isSkippable: true,
        skipAfterSeconds: 5,
        clickThroughUrl: 'https://google.com',
        coverImageUrl: 'https://picsum.photos/500/500', // Imagen placeholder
      );
    }

    try {
      final queryParameters = <String, dynamic>{};
      if (artist != null) queryParameters['artist'] = artist;
      if (playlistId != null) queryParameters['playlistId'] = playlistId;

      // 🔍 DEBUG: Log URL completa
      final fullUrl = '${_dio.options.baseUrl}$_publicAdsPath/next';
      AppLogger.info('[AdsService] 📢 REQUEST: GET $fullUrl');
      AppLogger.info('[AdsService] 📢 Params: $queryParameters');
      
      final response = await _dio.get(
        '$_publicAdsPath/next',
        queryParameters: queryParameters,
      );
      
      AppLogger.info('[AdsService] 📢 RESPONSE STATUS: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // El backend retorna { ad: {...} } o { ad: null }
        if (data['ad'] == null) {
          AppLogger.warning('[AdsService] ⚠️ BACKEND RETURNED NULL AD (Valid 200 OK)');
          return null;
        }

        final adData = data['ad'] as Map<String, dynamic>;
        
        // 🔍 LOG: Ver qué está llegando del backend
        AppLogger.debug('[AdsService] Datos recibidos del backend: ${adData.keys.join(", ")}');
        AppLogger.debug('[AdsService] audioUrl presente: ${adData.containsKey('audioUrl') || adData.containsKey('audio_url')}');
        if (adData.containsKey('audioUrl')) {
          AppLogger.debug('[AdsService] audioUrl (camelCase): ${adData['audioUrl']}');
        }
        if (adData.containsKey('audio_url')) {
          AppLogger.debug('[AdsService] audio_url (snake_case): ${adData['audio_url']}');
        }
        
        // ✅ NORMALIZACIÓN: Asegurar que los campos estén en camelCase
        // El backend puede devolver snake_case o camelCase dependiendo de la configuración
        final normalizedAdData = <String, dynamic>{...adData};
        
        // Normalizar audioUrl (verificar ambas variantes)
        if (normalizedAdData['audio_url'] != null && normalizedAdData['audioUrl'] == null) {
          normalizedAdData['audioUrl'] = normalizedAdData['audio_url'];
        }
        if (normalizedAdData['audioUrl'] != null && normalizedAdData['audio_url'] == null) {
          normalizedAdData['audio_url'] = normalizedAdData['audioUrl'];
        }
        
        // Normalizar coverImageUrl
        if (normalizedAdData['cover_image_url'] != null && normalizedAdData['coverImageUrl'] == null) {
          normalizedAdData['coverImageUrl'] = normalizedAdData['cover_image_url'];
        }
        if (normalizedAdData['coverImageUrl'] != null && normalizedAdData['cover_image_url'] == null) {
          normalizedAdData['cover_image_url'] = normalizedAdData['coverImageUrl'];
        }
        
        // Normalizar advertiserName
        if (normalizedAdData['advertiser_name'] != null && normalizedAdData['advertiserName'] == null) {
          normalizedAdData['advertiserName'] = normalizedAdData['advertiser_name'];
        }
        
        // Normalizar clickThroughUrl
        if (normalizedAdData['click_through_url'] != null && normalizedAdData['clickThroughUrl'] == null) {
          normalizedAdData['clickThroughUrl'] = normalizedAdData['click_through_url'];
        }
        
        // Normalizar durationSeconds
        if (normalizedAdData['duration_seconds'] != null && normalizedAdData['durationSeconds'] == null) {
          normalizedAdData['durationSeconds'] = normalizedAdData['duration_seconds'];
        }
        
        // Normalizar isSkippable
        if (normalizedAdData['is_skippable'] != null && normalizedAdData['isSkippable'] == null) {
          normalizedAdData['isSkippable'] = normalizedAdData['is_skippable'];
        }
        
        // Normalizar skipAfterSeconds
        if (normalizedAdData['skip_after_seconds'] != null && normalizedAdData['skipAfterSeconds'] == null) {
          normalizedAdData['skipAfterSeconds'] = normalizedAdData['skip_after_seconds'];
        }
        
        // ✅ NORMALIZAR URL: Aplicar normalización de URL para emulador Android
        if (normalizedAdData['audioUrl'] != null && normalizedAdData['audioUrl'] is String) {
          final rawAudioUrl = normalizedAdData['audioUrl'] as String;
          if (rawAudioUrl.isNotEmpty) {
            final normalizedUrl = UrlNormalizer.normalizeUrl(rawAudioUrl);
            normalizedAdData['audioUrl'] = normalizedUrl;
            AppLogger.debug('[AdsService] URL de audio normalizada: $rawAudioUrl -> $normalizedUrl');
          }
        }
        
        // Normalizar también coverImageUrl si existe
        if (normalizedAdData['coverImageUrl'] != null && normalizedAdData['coverImageUrl'] is String) {
          final rawCoverUrl = normalizedAdData['coverImageUrl'] as String;
          if (rawCoverUrl.isNotEmpty) {
            final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
            if (normalizedCoverUrl != null) {
              normalizedAdData['coverImageUrl'] = normalizedCoverUrl;
              AppLogger.debug('[AdsService] URL de portada normalizada: $rawCoverUrl -> $normalizedCoverUrl');
            }
          }
        }
        
        final ad = AudioAd.fromJson(normalizedAdData);
        AppLogger.info('[AdsService] ✅ Anuncio obtenido y normalizado: ${ad.title} (audioUrl: ${ad.audioUrl})');
        return ad;
      }

      return null;
    } catch (e, stackTrace) {
      // 🚨 ERROR DETAILED LOGGING
      AppLogger.error('[AdsService] ❌ ERROR CRÍTICO al obtener anuncio: $e');
      if (e is DioException) {
         AppLogger.error('[AdsService] ❌ DioError Type: ${e.type}');
         AppLogger.error('[AdsService] ❌ DioError Message: ${e.message}');
         AppLogger.error('[AdsService] ❌ DioError Path: ${e.requestOptions.path}');
         AppLogger.error('[AdsService] ❌ DioError Final URL: ${e.requestOptions.uri}');
         if (e.response != null) {
            AppLogger.error('[AdsService] ❌ Response Status: ${e.response?.statusCode}');
            AppLogger.error('[AdsService] ❌ Response Data: ${e.response?.data}');
         }
      }
      return null;
    }
  }

  /// Registrar reproducción de anuncio (Consumido por PlaybackNotifier)
  /// 
  /// [adId]: ID del anuncio reproducido
  /// [durationSeconds]: Duración reproducida en segundos
  /// [wasCompleted]: Si se reprodujo completo
  /// [wasSkipped]: Si fue saltado
  /// [genre]: Género de la canción que precedió (contexto)
  /// [artist]: Artista de la canción que precedió (contexto)
  /// [playlistId]: ID de playlist si aplica (contexto)
  Future<void> logPlay(
    String adId, {
    required int durationSeconds,
    required bool wasCompleted,
    required bool wasSkipped,
    String? genre,
    String? artist,
    String? playlistId,
  }) async {
    try {
      await _dio.post(
        '$_publicAdsPath/$adId/log-play',
        data: {
          'durationPlayed': durationSeconds,
          'wasCompleted': wasCompleted,
          'wasSkipped': wasSkipped,
          if (genre != null) 'genre': genre,
          if (artist != null) 'artist': artist,
          if (playlistId != null) 'playlistId': playlistId,
        },
      );
      AppLogger.debug('[AdsService] Reproducción registrada: adId=$adId, duration=${durationSeconds}s, completed=$wasCompleted, skipped=$wasSkipped');
    } catch (e, stackTrace) {
      // No lanzar error, solo registrar
      // Esto evita que errores de logging bloqueen la reproducción
      AppLogger.error('[AdsService] Error al registrar reproducción: $e', e, stackTrace);
    }
  }

  /// Registrar click en anuncio (Consumido por la UI)
  /// 
  /// [adId]: ID del anuncio en el que se hizo click
  Future<void> logClick(String adId) async {
    try {
      await _dio.post('$_publicAdsPath/$adId/log-click');
      AppLogger.debug('[AdsService] Click registrado: adId=$adId');
    } catch (e, stackTrace) {
      // No lanzar error, solo registrar
      AppLogger.error('[AdsService] Error al registrar click: $e', e, stackTrace);
    }
  }
  /// Obtener frecuencia de anuncios desde el backend
  /// 
  /// Retorna la frecuencia configurada (ej: 3 canciones) o un valor por defecto
  Future<int> getAdFrequency() async {
    try {
      AppLogger.info('[AdsService] 📢 Obteniendo frecuencia de anuncios desde API...');
      
      final response = await _dio.get('$_publicAdsPath/frequency');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('frequency') && data['frequency'] is int) {
          final frequency = data['frequency'] as int;
          AppLogger.info('[AdsService] ✅ Frecuencia obtenida: $frequency');
          return frequency;
        }
      }
      
      AppLogger.warning('[AdsService] ⚠️ Respuesta inválida o sin frecuencia, usando valor por defecto (3)');
      return 3;
    } catch (e) {
      AppLogger.error('[AdsService] ❌ Error al obtener frecuencia: $e');
      return 3; // Valor por defecto en caso de error
    }
      return 3; // Valor por defecto en caso de error
    }

  // ===========================================================================
  // 🔐 ADMIN METHODS (Require Auth)
  // ===========================================================================
  static const String _adminAdsPath = '/ads';

  /// Obtener todos los anuncios (Admin)
  Future<List<AudioAd>> getAllAds() async {
    try {
      final response = await _dio.get('$_adminAdsPath');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('ads') && data['ads'] is List) {
          final adsList = data['ads'] as List;
          return adsList.map((json) => AudioAd.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      AppLogger.error('[AdsService] ❌ Error al obtener anuncios (Admin): $e');
      return [];
    }
  }

  /// Obtener estadísticas detalladas de un anuncio (Admin)
  Future<Map<String, dynamic>?> getAdStats(String adId) async {
    try {
      final response = await _dio.get('$_adminAdsPath/$adId/stats');
      
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.error('[AdsService] ❌ Error al obtener estadísticas (Admin): $e');
      return null;
    }
  }
}

